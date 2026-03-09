"""Zero-copy ctypes marshalling for native (.na.jac) interop.

Given a NativeModuleLayout (exported by NaIRGenPass), this module:
1. Builds ctypes Structure classes matching LLVM struct layouts
2. Provides NativeStructView/NativeListView for zero-copy field access
3. Wraps native functions with automatic Python<->native marshalling
4. Installs native-backed replacements on Python modules

Structs are accessed via from_address() -- Python reads directly from
native memory with no upfront copying. String fields are decoded on
demand (one copy when accessed, not when struct is created).
"""

import ctypes;
import logging;
import from typing { Any }
import from dataclasses { field }

glob logger = logging.getLogger(__name__),
     LLVM_TO_CTYPES: dict[(str, type)] = {
         "i64": ctypes.c_int64,
         "i32": ctypes.c_int32,
         "i16": ctypes.c_int16,
         "i8": ctypes.c_int8,
         "i1": ctypes.c_bool,
         "f64": ctypes.c_double,
         "f32": ctypes.c_float,
         "i8*": ctypes.c_char_p,
         "void": None
     };

"""Build a ctypes CFUNCTYPE from NativeFieldInfo function pointer metadata."""
def _build_cfunctype(finfo: Any) -> type {
    ret_ct = LLVM_TO_CTYPES.get(finfo.func_ret_type);
    if ret_ct is None {
        ret_ct = ctypes.c_void_p if finfo.func_ret_type != "void" else None;
    }
    param_cts: list = [];
    for pt in (finfo.func_param_types or []) {
        pct = LLVM_TO_CTYPES.get(pt, ctypes.c_void_p);
        param_cts.append(pct);
    }
    return ctypes.CFUNCTYPE(ret_ct, *param_cts);
}


"""Matches LLVM List.{elem} struct: {i64 len, i64 cap, elem* data}."""
class NativeList(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("len", ctypes.c_int64),
        ("cap", ctypes.c_int64),
        ("data", ctypes.c_void_p)
    ];
}


# -- Zero-copy view classes --
"""Zero-copy view over a native struct in C memory.

Field access reads directly from native memory via ctypes descriptors.
String fields are decoded on demand (single copy when accessed).
Supports both attribute (.field) and dict-style (["field"]) access.
"""
obj NativeStructView {
    has addr: int,
        ct_cls: Any = None,
        struct_name: str = "",
        layout: Any = None,
        ctypes_classes: dict = field(default_factory=`dict),
        enum_maps: dict = field(default_factory=`dict),
        _native: Any = field(default=None, repr=False),
        _field_meta: dict = field(default_factory=`dict, repr=False);

    def postinit -> None {
        # from_address: NO copy -- creates view over C memory
        self._native = self.ct_cls.from_address(self.addr);
        # Build field metadata lookup (name -> NativeFieldInfo)
        if (self.layout and hasattr(self.layout, "structs")) {
            sl = self.layout.structs.get(self.struct_name);
            if sl {
                for f in sl.fields {
                    self._field_meta[f.name] = f;
                }
            }
        }
    }

    def __getattr__(self: NativeStructView, name: str) -> Any {
        native = self._native;
        try {
            raw = getattr(native, name);
        } except AttributeError {
            raise AttributeError(f"'{self.struct_name}' has no field '{name}'");
        }
        return self._resolve(name, raw);
    }

    def _resolve(self: NativeStructView, name: str, raw: Any) -> Any {
        finfo = self._field_meta.get(name);
        if finfo is None {
            return raw;
        }
        lt = finfo.llvm_type;
        # Function pointer: wrap raw address as callable ctypes function
        if finfo.is_func_ptr {
            if (raw is None or raw == 0) {
                return None;
            }
            fn_type = _build_cfunctype(finfo);
            return fn_type(raw);
        }
        # String: decode from raw pointer on demand
        if lt == "i8*" {
            if (raw is None or raw == 0) {
                return "";
            }
            return ctypes.string_at(raw).decode("utf-8", errors="replace");
        }
        # Enum field: ordinal -> enum value
        if (lt in ("i64", "i32") and finfo.enum_type) {
            val = int(raw);
            emap = self.enum_maps.get(finfo.enum_type);
            if (emap and 0 <= val < len(emap) and emap[val] is not None) {
                return emap[val];
            }
            return val;
        }
        # Nested struct pointer
        if (lt.endswith("*") and not lt.startswith("List.") and lt != "i8*") {
            sname = lt[:-1];
            if (raw and raw != 0) {
                ct_cls = self.ctypes_classes.get(sname);
                if ct_cls {
                    return NativeStructView(
                        raw,
                        ct_cls,
                        sname,
                        self.layout,
                        self.ctypes_classes,
                        self.enum_maps
                    );
                }
            }
            return None;
        }
        # List pointer
        if (lt.startswith("List.") and lt.endswith("*")) {
            if (raw and raw != 0) {
                elem_key = lt[5:-1];
                return NativeListView(
                    raw, elem_key, self.ctypes_classes, self.enum_maps, self.layout
                );
            }
            return NativeListView.empty();
        }
        return raw;
    }

    def __getitem__(self: NativeStructView, key: str) -> Any {
        return getattr(self, key);
    }

    def __contains__(self: NativeStructView, key: str) -> bool {
        return key in self._field_meta;
    }

    def keys(self: NativeStructView) -> Any {
        return self._field_meta.keys();
    }

    def items(self: NativeStructView) -> Any {
        return ((k, self[k]) for k in self.keys());
    }

    def __repr__(self: NativeStructView) -> str {
        return f"<NativeStructView {self.struct_name}>";
    }
}


"""Zero-copy view over a native list in C memory.

Elements are accessed lazily -- no upfront iteration or copying.
Supports len(), indexing, slicing, iteration, and equality with lists.
"""
obj NativeListView {
    has list_ptr: int = 0,
        elem_key: str = "",
        ctypes_classes: dict = field(default_factory=`dict),
        enum_maps: dict = field(default_factory=`dict),
        layout: Any = None,
        struct_hint: (str | None) = None,
        _count: int = field(default=0, repr=False),
        _arr: Any = field(default=None, repr=False),
        _ct_cls: Any = field(default=None, repr=False),
        _struct_name: (str | None) = field(default=None, repr=False);

    def postinit -> None {
        if (self.list_ptr == 0) {
            self._count = 0;
            self._arr = None;
            self._ct_cls = None;
            self._struct_name = None;
            return;
        }
        nl = NativeList.from_address(self.list_ptr);
        self._count = nl.len if (nl.len > 0 and nl.data) else 0;

        # Resolve struct class for ptr elements
        self._struct_name = self.struct_hint;
        if (self.elem_key == "ptr" and self._struct_name) {
            self._ct_cls = self.ctypes_classes.get(self._struct_name);
        }

        # Create array view over data -- zero-copy via from_address
        if self._count > 0 {
            if self.elem_key == "i64" {
                self._arr = (ctypes.c_int64 * self._count).from_address(nl.data);
            } elif self.elem_key == "f64" {
                self._arr = (ctypes.c_double * self._count).from_address(nl.data);
            } else {
                # 'ptr' and others
                self._arr = (ctypes.c_void_p * self._count).from_address(nl.data);
            }
        }
    }

    @classmethod
    def empty(cls: type) -> NativeListView {
        return cls(list_ptr=0, elem_key="");
    }

    def __len__(self: NativeListView) -> int {
        return self._count;
    }

    def __getitem__(self: NativeListView, index: Any) -> Any {
        if isinstance(index, slice) {
            return [self[i] for i in range(*index.indices(self._count))];
        }
        if index < 0 {
            index += self._count;
        }
        if (index < 0 or index >= self._count) {
            raise IndexError(f"list index {index} out of range");
        }
        raw = self._arr[index];
        if self.elem_key == "i64" {
            return int(raw);
        }
        if self.elem_key == "f64" {
            return float(raw);
        }
        # Struct pointer element
        if (self._ct_cls and raw and raw != 0) {
            return NativeStructView(
                raw,
                self._ct_cls,
                self._struct_name,
                self.layout,
                self.ctypes_classes,
                self.enum_maps
            );
        }
        return raw;
    }

    def __iter__(self: NativeListView) -> Any {
        for i in range(len(self)) {
            yield self[i];
        }
    }

    def __eq__(self: NativeListView, other: Any) -> Any {
        if isinstance(other, list) {
            return (
                len(self) == len(other) and all(a == b for (a, b) in zip(self, other))
            );
        }
        return NotImplemented;
    }

    def __repr__(self: NativeListView) -> str {
        return f"<NativeListView len={len(self)}>";
    }
}


# -- ctypes class generation --
"""Build ctypes Structure classes from NativeModuleLayout.structs.

All pointer fields (including strings) use c_void_p to avoid
auto-copying. NativeStructView handles decoding on demand.
"""
def build_ctypes_classes(layout: Any) -> dict {
    classes: dict = {};
    for (name, struct_layout) in layout.structs.items() {
        fields: list = [];
        for f in struct_layout.fields {
            if f.is_func_ptr {
                # Function pointer fields stored as c_void_p; resolved on access
                ct = ctypes.c_void_p;
            } else {
                ct = LLVM_TO_CTYPES.get(f.llvm_type);
                if (ct is None or f.llvm_type == "i8*") {
                    # All pointers as c_void_p -- no auto-copy for strings
                    ct = ctypes.c_void_p;
                }
            }
            fields.append((f.name, ct));
        }
        cls = type(f"Native_{name}", (ctypes.Structure, ), {"_fields_": fields});
        classes[name] = cls;
    }
    return classes;
}


"""Build ordinal->Python enum value maps from NativeModuleLayout.enums.

For each enum, looks up the Python enum class in module_ns and creates
a list indexed by ordinal.
"""
def build_enum_maps(layout: Any, module_ns: dict) -> dict {
    maps: dict = {};
    for (enum_name, enum_layout) in layout.enums.items() {
        py_enum_cls = module_ns.get(enum_name);
        if py_enum_cls is None {
            continue;
        }
        # Build ordinal->member map
        max_ord = max((m[2] for m in enum_layout.members), default=-1);
        ordinal_map: list = [None] * (max_ord + 1);
        for (member_name, _value, ordinal) in enum_layout.members {
            member = getattr(py_enum_cls, member_name, None);
            if member is not None {
                ordinal_map[ordinal] = member;
            }
        }
        maps[enum_name] = ordinal_map;
    }
    return maps;
}


# -- Value marshalling --
"""Convert a native value to a Python object based on its LLVM type.

Returns zero-copy NativeStructView/NativeListView for composite types.
Scalars (int, float, bool, str) are returned as Python primitives.
"""
def marshal_value(
    raw: Any,
    llvm_type: str,
    ctypes_classes: dict,
    enum_maps: dict,
    py_classes: dict,
    field_info: Any = None,
    func_layout: Any = None,
    layout: Any = None
) -> Any {
    # Function pointer fields
    if (field_info and field_info.is_func_ptr) {
        if (raw is None or raw == 0) {
            return None;
        }
        fn_type = _build_cfunctype(field_info);
        return fn_type(raw);
    }
    # Simple scalars
    if llvm_type in ("i64", "i32", "i16", "i8") {
        val = int(raw);
        # Check if this field is enum-typed
        if (field_info and field_info.enum_type) {
            emap = enum_maps.get(field_info.enum_type);
            if (emap and 0 <= val < len(emap) and emap[val] is not None) {
                return emap[val];
            }
        }
        return val;
    }
    if llvm_type == "i1" {
        return bool(raw);
    }
    if llvm_type in ("f64", "f32") {
        return float(raw);
    }
    if llvm_type == "i8*" {
        if (raw is None or raw == 0) {
            return "";
        }
        if isinstance(raw, bytes) {
            return raw.decode("utf-8", errors="replace");
        }
        # c_void_p returns int (pointer address)
        if isinstance(raw, int) {
            return ctypes.string_at(raw).decode("utf-8", errors="replace");
        }
        return str(raw);
    }

    # Tuple pointer: "Tuple*"
    if llvm_type == "Tuple*" {
        if (raw is None or raw == 0) {
            return None;
        }
        if (func_layout and func_layout.ret_tuple_layout) {
            return _marshal_tuple(
                raw,
                func_layout.ret_tuple_layout,
                ctypes_classes,
                enum_maps,
                py_classes,
                layout
            );
        }
        return raw;  # fallback if no layout info

    }

    # Struct pointer: "StructName*" -- zero-copy NativeStructView
    if (llvm_type.endswith("*") and not llvm_type.startswith("List.")) {
        struct_name = llvm_type[:-1];
        if struct_name == "ptr" {
            return raw;  # Can't auto-marshal opaque pointers

        }
        ct_cls = ctypes_classes.get(struct_name);
        if (ct_cls is None or raw is None or raw == 0) {
            return raw;
        }
        return NativeStructView(
            raw, ct_cls, struct_name, layout, ctypes_classes, enum_maps
        );
    }

    # List pointer: "List.elem*" -- zero-copy NativeListView
    if (llvm_type.startswith("List.") and llvm_type.endswith("*")) {
        elem_key = llvm_type[5:-1];  # e.g., "ptr", "i64", "f64"
        if (raw is None or raw == 0) {
            return NativeListView.empty();
        }
        return NativeListView(raw, elem_key, ctypes_classes, enum_maps, layout);
    }

    return raw;
}


"""Read a native tuple struct and marshal each element.

Tuple elements that are lists or structs get wrapped as
NativeListView/NativeStructView via marshal_value dispatch.
"""
def _marshal_tuple(
    tuple_ptr: int,
    tuple_layout: Any,
    ctypes_classes: dict,
    enum_maps: dict,
    py_classes: dict,
    layout: Any = None
) -> tuple {
    elem_types = tuple_layout.element_types;
    struct_hints = tuple_layout.element_struct_hints or [];

    # Build a ctypes Structure matching the tuple layout
    fields: list = [];
    for (i, et) in enumerate(elem_types) {
        ct = LLVM_TO_CTYPES.get(et, ctypes.c_void_p);
        fields.append((f"e{i}", ct));
    }

    TupleStruct = type("NativeTuple", (ctypes.Structure, ), {"_fields_": fields});
    ptr = ctypes.cast(tuple_ptr, ctypes.POINTER(TupleStruct));
    native = ptr.contents;

    result: list = [];
    for (i, et) in enumerate(elem_types) {
        raw_val = getattr(native, f"e{i}");
        hint = struct_hints[i] if i < len(struct_hints) else None;
        # For List.ptr* with struct hint, create NativeListView with hint
        if (et == "List.ptr*" and hint and raw_val and raw_val != 0) {
            result.append(
                NativeListView(
                    raw_val, "ptr", ctypes_classes, enum_maps, layout, struct_hint=hint
                )
            );
        } else {
            marshalled = marshal_value(
                raw_val, et, ctypes_classes, enum_maps, py_classes, layout=layout
            );
            result.append(marshalled);
        }
    }

    return tuple(result);
}


# -- Function wrapping --
"""Create a Python wrapper for a native function with auto-marshalling.

Returns None if the function can't be wrapped (e.g., unsupported types).
"""
def wrap_native_function(
    engine: Any,
    func_layout: Any,
    ctypes_classes: dict,
    enum_maps: dict,
    py_classes: dict,
    layout: Any = None
) -> Any {
    addr = engine.get_function_address(func_layout.name);
    if not addr {
        return None;
    }

    # Build ctypes arg types
    c_arg_types: list = [];
    for pt in func_layout.param_types {
        ct = LLVM_TO_CTYPES.get(pt);
        if ct is None {
            ct = ctypes.c_void_p;  # pointer types
        }
        c_arg_types.append(ct);
    }

    # Build ctypes return type
    ret_type = func_layout.ret_type;
    c_ret = LLVM_TO_CTYPES.get(ret_type);
    if c_ret is None {
        if ret_type == "void" {
            c_ret = None;
        } else {
            c_ret = ctypes.c_void_p;  # pointer return
        }
    }

    fn_type = ctypes.CFUNCTYPE(c_ret, *c_arg_types);
    native_fn = fn_type(addr);

    param_types = func_layout.param_types;
    fl = func_layout;  # capture for closure

    def wrapper(*args: Any) -> Any {
        # Convert Python args to ctypes
        c_args: list = [];
        for (arg, pt) in zip(args, param_types) {
            if (pt == "i8*" and isinstance(arg, str)) {
                c_args.append(arg.encode("utf-8"));
            } else {
                c_args.append(arg);
            }
        }
        raw_result = native_fn(*c_args);
        return marshal_value(
            raw_result,
            ret_type,
            ctypes_classes,
            enum_maps,
            py_classes,
            func_layout=fl,
            layout=layout
        );
    }

    wrapper.__name__ = func_layout.name;
    wrapper.__qualname__ = func_layout.name;
    wrapper.__wrapped__ = True;
    return wrapper;
}


# -- Module-level installation --
"""Install native-backed function wrappers on a Python module.

Args:
    module: The Python module object
    engine: The native JIT engine
    layout: NativeModuleLayout with struct/enum/function metadata
    py_classes: Optional mapping of struct names to Python classes.
                If None, attempts to find classes in the module namespace.

Returns:
    Number of functions successfully wrapped.
"""
def install_native_wrappers(
    module: Any, engine: Any, layout: Any, py_classes: (dict | None) = None
) -> int {
    module_ns = module.__dict__;

    # Build ctypes classes from layout
    ctypes_classes = build_ctypes_classes(layout);

    # Build enum ordinal maps
    enum_maps = build_enum_maps(layout, module_ns);

    # Resolve Python classes for struct marshalling
    if py_classes is None {
        py_classes = {};
        for struct_name in layout.structs {
            cls = module_ns.get(struct_name);
            if cls is not None {
                py_classes[struct_name] = cls;
            }
        }
    }

    wrapped_count = 0;
    for (func_name, func_layout) in layout.functions.items() {
        # Only wrap functions that exist in the module namespace
        if func_name not in module_ns {
            continue;
        }
        wrapper = wrap_native_function(
            engine, func_layout, ctypes_classes, enum_maps, py_classes, layout=layout
        );
        if wrapper is not None {
            # Save original Python version
            module_ns[f"_py_{func_name}"] = module_ns[func_name];
            module_ns[func_name] = wrapper;
            wrapped_count += 1;
            logger.debug(f"Installed native wrapper for {func_name}");
        }
    }

    return wrapped_count;
}
# -- LLVM type string -> ctypes type mapping --
