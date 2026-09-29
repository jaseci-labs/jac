import ctypes;
import json;
import os;
import sys;
import from jaclang.runtime.scalars { numeric_shapes }

def _scalar_ctypes -> dict[str, any] {
    out: dict[str, any] = {};
    for shape in numeric_shapes() {
        if shape.name == "bool" {
            out[shape.name] = ctypes.c_bool;
        } elif shape.is_float {
            out[shape.name] = ctypes.c_float if shape.width == 32 else ctypes.c_double;
        } else {
            prefix = "c_int" if shape.signed else "c_uint";
            out[shape.name] = getattr(ctypes, f"{prefix}{shape.width}");
        }
    }
    return out;
}

glob _SCALAR_CTYPES: dict[str, any] = _scalar_ctypes(),
     _LIBS: dict[str, any] = {},
     _VIEW_RANGE: str = "PtrView index out of range";

class JacCOpaque {}

class JacCStruct(ctypes.Structure) {
    def init(self: JacCStruct, *args: any, **kwargs: any) {
        ctypes.Structure.__init__(self);
        cls: any = type(self);
        names = [f[0] for f in cls._jac_fields_];
        if len(args) > len(names) {
            raise TypeError(
                f"{type(self).__name__}() takes at most {len(
                    names
                )} positional arguments"
            );
        }
        for (i, value) in enumerate(args) {
            setattr(self, names[i], value);
        }
        for (key, value) in kwargs.items() {
            if key not in names {
                raise TypeError(
                    f"{type(self).__name__}() got an unexpected keyword argument '{key}'"
                );
            }
            setattr(self, key, value);
        }
    }

    def __repr__(self: JacCStruct) -> str {
        cls: any = type(self);
        parts = [f"{f[0]}={getattr(self, f[0])!r}" for f in cls._jac_fields_];
        return f"{cls.__name__}({', '.join(parts)})";
    }
}

class JacPtr {
    with entry {
        _jac_elem: any = None;
        _jac_views: dict[int, type] = {};
    }

    def init(self: JacPtr, address: any = None) {
        if address is None {
            self._addr = 0;
        } elif isinstance(address, JacPtr) {
            self._addr = address._addr;
        } else {
            raise TypeError(f"ptr() expects a pointer, not '{type(address).__name__}'");
        }
    }

    @classmethod
    def __class_getitem__(cls: type, elem: any) -> type {
        key = id(elem);
        cached = JacPtr._jac_views.get(key);
        if cached is None {
            name = getattr(elem, "__name__", str(elem));
            cached = `type(f"ptr[{name}]", (JacPtr, ), {"_jac_elem": elem});
            JacPtr._jac_views[key] = cached;
        }
        return cached;
    }

    def is_null(self: JacPtr) -> bool {
        return self._addr == 0;
    }

    def view(self: JacPtr, n: int) -> JacPtrView {
        cls: any = type(self);
        elem = cls._jac_elem;
        if elem is None {
            raise TypeError("a bare ptr has no element type to view");
        }
        if n < 0 {
            raise ValueError("PtrView length must not be negative");
        }
        if self._addr == 0 and n > 0 {
            raise ValueError("cannot view elements of a null pointer");
        }
        return JacPtrView(self._addr, n, elem);
    }

    def __eq__(self: JacPtr, other: any) -> bool {
        return isinstance(other, JacPtr) and other._addr == self._addr;
    }

    def __ne__(self: JacPtr, other: any) -> bool {
        return not self.__eq__(other);
    }

    def __hash__(self: JacPtr) -> int {
        return hash(self._addr);
    }

    def __bool__(self: JacPtr) -> bool {
        return self._addr != 0;
    }

    def __repr__(self: JacPtr) -> str {
        return str(self._addr);
    }
}

class JacPtrView {
    @classmethod
    def __class_getitem__(cls: type, elem: any) -> type {
        return cls;
    }

    def init(self: JacPtrView, addr: int, n: int, elem: any) {
        self._addr = addr;
        self._n = n;
        self._elem = elem;
        self._ctype = _elem_ctype(elem);
        self._size = ctypes.sizeof(self._ctype);
    }

    def __len__(self: JacPtrView) -> int {
        return self._n;
    }

    def _slot(self: JacPtrView, i: int) -> int {
        idx = int(i);
        if idx < 0 {
            idx += self._n;
        }
        if idx < 0 or idx >= self._n {
            raise IndexError(_VIEW_RANGE);
        }
        return self._addr + idx * self._size;
    }

    def __getitem__(self: JacPtrView, i: int) -> any {
        addr = self._slot(i);
        if _is_struct_class(self._elem) {
            return self._elem.from_address(addr);
        }
        return _from_c(self._elem, self._ctype.from_address(addr).value);
    }

    def __setitem__(self: JacPtrView, i: int, value: any) -> None {
        addr = self._slot(i);
        if _is_struct_class(self._elem) {
            ctypes.memmove(addr, ctypes.addressof(value), self._size);
            return;
        }
        self._ctype.from_address(addr).value = _to_c_scalar(self._elem, value);
    }
}

class JacPinned {
    @classmethod
    def __class_getitem__(cls: type, elem: any) -> type {
        return cls;
    }

    def init(self: JacPinned, payload: any, elem: any) {
        self._jac_obj = payload;
        self._jac_elem = elem;
    }

    has value: any {
        getter {
            if _is_struct_class(self._jac_elem) {
                return self._jac_obj;
            }
            return _from_c(self._jac_elem, self._jac_obj.value);
        }
        setter(self: JacPinned, new: any) -> None {
            if _is_struct_class(self._jac_elem) {
                ctypes.memmove(
                    ctypes.addressof(self._jac_obj),
                    ctypes.addressof(new),
                    ctypes.sizeof(self._jac_obj)
                );
                return;
            }
            self._jac_obj.value = _to_c_scalar(self._jac_elem, new);
        }
    }
}

class CCell {
    def init(self: CCell, elem: any, value: any) {
        self._jac_elem = elem;
        self.c = _elem_ctype(elem)(_to_c_scalar(elem, value));
    }

    def get(self: CCell) -> any {
        return _from_c(self._jac_elem, self.c.value);
    }
}

def _is_struct_class(elem: any) -> bool {
    return isinstance(elem, `type) and issubclass(elem, JacCStruct);
}

def _elem_ctype(elem: any) -> any {
    if _is_struct_class(elem) {
        return elem;
    }
    if isinstance(elem, `type) and issubclass(elem, JacPtr) {
        return ctypes.c_void_p;
    }
    if isinstance(elem, `type) and issubclass(elem, JacCOpaque) {
        raise TypeError(f"opaque C type '{elem.__name__}' has no known size");
    }
    name = _scalar_name(elem);
    if name is None {
        raise TypeError(f"'{elem}' is not C plain data");
    }
    return _SCALAR_CTYPES[name];
}

def _scalar_name(elem: any) -> (str | None) {
    if isinstance(elem, str) {
        return elem if elem in _SCALAR_CTYPES else None;
    }
    sized = elem?.__jac_sized__;
    if isinstance(sized, str) {
        return sized;
    }
    if elem is bool {
        return "bool";
    }
    if elem is int {
        return "int";
    }
    if elem is float {
        return "float";
    }
    return None;
}

def _from_c(elem: any, raw: any) -> any {
    if isinstance(elem, `type) and issubclass(elem, JacPtr) {
        return _make_ptr(elem, raw);
    }
    name = _scalar_name(elem);
    if name == "bool" {
        return bool(raw);
    }
    return raw;
}

def _to_c_scalar(elem: any, value: any) -> any {
    if isinstance(elem, `type) and issubclass(elem, JacPtr) {
        return value._addr if isinstance(value, JacPtr) else None;
    }
    return value;
}

def _make_ptr(cls: any, raw: any) -> any {
    out: any = cls.__new__(cls);
    out._addr = int(raw or 0);
    return out;
}

def c_copy(value: any) -> any {
    if isinstance(value, ctypes.Structure) {
        cls: any = type(value);
        return cls.from_buffer_copy(value);
    }
    return value;
}

def jac_pin(value: any, spec: any = None) -> JacPinned {
    if isinstance(value, ctypes.Structure) {
        cls: any = type(value);
        return JacPinned(cls.from_buffer_copy(value), cls);
    }
    elem = _spec_scalar_elem(spec) if spec is not None else _scalar_name(type(value));
    if elem is None {
        raise TypeError(f"pin() needs C plain data, not '{type(value).__name__}'");
    }
    return JacPinned(_SCALAR_CTYPES[elem](value), elem);
}

def _spec_scalar_elem(spec: any) -> (str | None) {
    if isinstance(spec, str) {
        spec = json.loads(spec);
    }
    if isinstance(spec, list) and spec and spec[0] == "s" {
        return spec[1];
    }
    return None;
}

def c_cell(spec: str, value: any, scope: any) -> CCell {
    return CCell(_resolve_elem(json.loads(spec), scope), value);
}

def _resolve_elem(spec: list[any], scope: any) -> any {
    kind = spec[0];
    if kind == "s" {
        return spec[1];
    }
    if kind in ("struct", "opaque") {
        found = scope.get(spec[1]);
        if found is None {
            raise NameError(f"C type '{spec[1]}' is not bound");
        }
        return found;
    }
    if kind == "ptr" {
        if spec[1] is None {
            return JacPtr;
        }
        return JacPtr[_resolve_elem(spec[1], scope)];
    }
    if kind == "opt" {
        return _resolve_elem(spec[1], scope);
    }
    raise TypeError(f"unsupported C element spec {spec!r}");
}

def _field_ctype(spec: list[any], scope: any) -> any {
    kind = spec[0];
    if kind == "s" {
        return _SCALAR_CTYPES[spec[1]];
    }
    if kind == "struct" {
        return scope[spec[1]];
    }
    if kind == "ptr" {
        return ctypes.c_void_p;
    }
    if kind == "fn" {
        return _fn_ctype(spec, scope);
    }
    raise TypeError(f"'{spec!r}' is not a C struct field type");
}

def _fn_ctype(spec: list[any], scope: any) -> any {
    params = [_arg_ctype(p, scope) for p in spec[1]];
    ret = _ret_ctype(spec[2], scope);
    return ctypes.CFUNCTYPE(ret, *params);
}

def _arg_ctype(spec: list[any], scope: any) -> any {
    kind = spec[0];
    if kind == "s" {
        return _SCALAR_CTYPES[spec[1]];
    }
    if kind == "str" {
        return ctypes.c_char_p;
    }
    if kind == "struct" {
        return scope[spec[1]];
    }
    if kind == "fn" {
        return _fn_ctype(spec, scope);
    }
    return ctypes.c_void_p;
}

def _ret_ctype(spec: list[any], scope: any) -> any {
    kind = spec[0];
    if kind == "void" {
        return None;
    }
    if kind == "s" {
        return _SCALAR_CTYPES[spec[1]];
    }
    if kind == "str" {
        return ctypes.c_char_p;
    }
    if kind == "struct" {
        return scope[spec[1]];
    }
    if kind == "ptr" or kind == "opt" {
        return ctypes.c_void_p;
    }
    return ctypes.c_int64;
}

def _field_property(name: str, raw: str, elem: any) -> property {
    def fetch(self: any) -> any {
        return _make_ptr(elem, getattr(self, raw));
    }
    def put(self: any, value: any) {
        setattr(self, raw, value._addr if isinstance(value, JacPtr) else None);
    }
    return property(fetch, put);
}

def _callback_property(name: str, raw: str, spec: list[any], scope: any) -> property {
    fn_type = _fn_ctype(spec, scope);
    def fetch(self: any) -> any {
        return getattr(self, raw);
    }
    def put(self: any, value: any) {
        wrapped = value
            if isinstance(value, fn_type)
            else fn_type(_callback_trampoline(spec, value, scope));
        keep = self.__dict__.setdefault("_jac_keep", {});
        keep[name] = wrapped;
        setattr(self, raw, wrapped);
    }
    return property(fetch, put);
}

def _callback_trampoline(spec: list[any], fn: any, scope: any) -> any {
    params: list[any] = spec[1];
    ret: list[any] = spec[2];
    def tramp(*raw: any) -> any {
        args = [
            _callback_arg(params[i], raw[i], scope) if i < len(params) else raw[i]
            for i in range(len(raw))
        ];
        result = fn(*args);
        if ret[0] == "ptr" {
            return result._addr if isinstance(result, JacPtr) else None;
        }
        return result;
    }
    return tramp;
}

def _callback_arg(spec: list[any], raw: any, scope: any) -> any {
    kind = spec[0];
    if kind == "ptr" {
        return _make_ptr(_resolve_elem(spec, scope), raw);
    }
    if kind == "str" {
        return raw.decode("utf-8") if raw is not None else "";
    }
    if kind == "s" and spec[1] == "bool" {
        return bool(raw);
    }
    return raw;
}

def _lib_candidates(desc: dict[str, any], module_file: str) -> list[str] {
    module_dir = os.path.dirname(os.path.abspath(module_file))
        if module_file
        else os.getcwd();
    if "path" in desc {
        raw = desc["path"];
        out = [raw];
        if not os.path.isabs(raw) {
            out.append(os.path.join(module_dir, raw));
        }
        return out;
    }
    names: list[str] = desc["names"];
    base = names[-1];
    if sys.platform == "darwin" {
        fname = f"lib{base}.dylib";
    } elif sys.platform.startswith("win") {
        fname = f"{base}.dll";
    } else {
        fname = f"lib{base}.so";
    }
    rel = os.path.join(*(names[:-1] + [fname]));
    if desc.get("level", 0) > 0 or len(names) > 1 {
        return [os.path.join(module_dir, rel)];
    }
    return [fname, os.path.join(module_dir, fname)];
}

def _load_library(desc: dict[str, any], module_file: str) -> any {
    errors: list[str] = [];
    for cand in _lib_candidates(desc, module_file) {
        lib = _LIBS.get(cand);
        if lib is not None {
            return lib;
        }
        try {
            lib = ctypes.CDLL(cand);
        } except OSError as e {
            errors.append(str(e));
            continue;
        }
        _LIBS[cand] = lib;
        return lib;
    }
    raise ImportError(f"cannot load C library: {'; '.join(errors)}");
}

class CFunction {
    def init(
        self: CFunction,
        lib: any,
        name: str,
        params: list[any],
        ret: list[any],
        variadic: bool,
        scope: any
    ) {
        self._lib = lib;
        self._name = name;
        self._params = params;
        self._ret = ret;
        self._variadic = variadic;
        self._scope = scope;
        self._fn = None;
    }

    def _bind(self: CFunction) -> any {
        fn = getattr(self._lib, self._name);
        fn.argtypes = [_arg_ctype(p[1], self._scope) for p in self._params];
        fn.restype = _ret_ctype(self._ret, self._scope);
        self._fn = fn;
        return fn;
    }

    def __call__(self: CFunction, *args: any) -> any {
        fn = self._fn if self._fn is not None else self._bind();
        keep: list[any] = [];
        c_args: list[any] = [];
        for (i, value) in enumerate(args) {
            if i < len(self._params) {
                c_args.append(self._to_c(self._params[i][1], value, keep));
            } else {
                c_args.append(value);
            }
        }
        raw = fn(*c_args);
        return self._from_c(self._ret, raw);
    }

    def _to_c(self: CFunction, spec: list[any], value: any, keep: list[any]) -> any {
        kind = spec[0];
        if kind == "opt" {
            return None if value is None else self._to_c(spec[1], value, keep);
        }
        if kind == "str" {
            return value.encode("utf-8") if isinstance(value, str) else value;
        }
        if kind == "bytes" {
            buf = ctypes.create_string_buffer(bytes(value), len(value));
            keep.append(buf);
            return ctypes.addressof(buf);
        }
        if kind == "ptr" {
            return value._addr if isinstance(value, JacPtr) else None;
        }
        if kind == "pinned" {
            return None if value is None else ctypes.addressof(value._jac_obj);
        }
        if kind == "ref" {
            return self._ref_addr(spec[2], value, keep);
        }
        if kind == "fn" {
            wrapped = _fn_ctype(spec, self._scope)(
                _callback_trampoline(spec, value, self._scope)
            );
            keep.append(wrapped);
            return wrapped;
        }
        return value;
    }

    def _ref_addr(
        self: CFunction, spec: list[any], value: any, keep: list[any]
    ) -> any {
        if value is None {
            return None;
        }
        if isinstance(value, CCell) {
            return ctypes.addressof(value.c);
        }
        if isinstance(value, JacPinned) {
            return ctypes.addressof(value._jac_obj);
        }
        if isinstance(value, ctypes.Structure) {
            return ctypes.addressof(value);
        }
        inner = spec[1] if spec[0] == "opt" else spec;
        cell = CCell(_resolve_elem(inner, self._scope), value);
        keep.append(cell);
        return ctypes.addressof(cell.c);
    }

    def _from_c(self: CFunction, spec: list[any], raw: any) -> any {
        kind = spec[0];
        if kind == "void" {
            return None;
        }
        if kind == "str" {
            return raw.decode("utf-8") if raw is not None else "";
        }
        if kind == "ptr" {
            return _make_ptr(_resolve_elem(spec, self._scope), raw);
        }
        if kind == "s" and spec[1] == "bool" {
            return bool(raw);
        }
        return raw;
    }
}

def clib_bind(scope: any, desc_json: str) -> dict[str, any] {
    desc = json.loads(desc_json);
    lib = _load_library(desc["lib"], scope.get("__file__") or "");
    local: dict[str, any] = {};
    lookup = _ChainScope(local, scope);
    for name in desc.get("opaque", []) {
        local[name] = `type(name, (JacCOpaque, ), {});
    }
    pending: dict[str, list[any]] = {};
    for entry_desc in desc.get("structs", []) {
        name = entry_desc["name"];
        local[name] = `type(
            name, (JacCStruct, ), {"_jac_fields_": entry_desc["fields"]}
        );
        pending[name] = entry_desc["fields"];
    }
    done: set[str] = set();
    def finish(name: str) {
        if name in done {
            return;
        }
        done.add(name);
        for (fname, spec) in pending[name] {
            if spec[0] == "struct" and spec[1] in pending {
                finish(spec[1]);
            }
        }
        cls = local[name];
        raw_fields: list[tuple[str, any]] = [];
        for (fname, spec) in pending[name] {
            if spec[0] == "ptr" or spec[0] == "fn" {
                raw_fields.append((f"_jac_raw_{fname}", _field_ctype(spec, lookup)));
            } else {
                raw_fields.append((fname, _field_ctype(spec, lookup)));
            }
        }
        cls._fields_ = raw_fields;
        for (fname, spec) in pending[name] {
            if spec[0] == "ptr" {
                setattr(
                    cls,
                    fname,
                    _field_property(
                        fname, f"_jac_raw_{fname}", _resolve_elem(spec, lookup)
                    )
                );
            } elif spec[0] == "fn" {
                setattr(
                    cls,
                    fname,
                    _callback_property(fname, f"_jac_raw_{fname}", spec, lookup)
                );
            }
        }
    }
    for name in pending {
        finish(name);
    }
    for fn_desc in desc.get("functions", []) {
        local[fn_desc["name"]] = CFunction(
            lib,
            fn_desc["name"],
            fn_desc["params"],
            fn_desc["ret"],
            bool(fn_desc.get("variadic", False)),
            lookup
        );
    }
    return local;
}

class _ChainScope {
    def init(self: _ChainScope, first: dict[str, any], second: dict[str, any]) {
        self._first = first;
        self._second = second;
    }

    def get(self: _ChainScope, key: str, fallback: any = None) -> any {
        if key in self._first {
            return self._first[key];
        }
        return self._second.get(key, fallback);
    }

    def __getitem__(self: _ChainScope, key: str) -> any {
        found = self.get(key);
        if found is None {
            raise NameError(f"C type '{key}' is not bound");
        }
        return found;
    }
}
