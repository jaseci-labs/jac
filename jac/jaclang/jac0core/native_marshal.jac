import ctypes;
import logging;
import from dataclasses { field }
import from jaclang.jac0core.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_MAGIC,
    HDR_RC_OFF,
    RC_SENTINEL,
    STR_LEN_TAG_BIT,
    STR_LEN_TAG_SHIFT
}

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

def _build_cfunctype(finfo: any) -> type {
    if finfo.func_ret_type == "jacstr3" {
        ret_ct = JacStrRet3;
    } elif finfo.func_ret_type == "jacstr2" {
        ret_ct = JacStrRet2;
    } else {
        ret_ct = LLVM_TO_CTYPES.get(finfo.func_ret_type);
        if ret_ct is None {
            ret_ct = ctypes.c_void_p if finfo.func_ret_type != "void" else None;
        }
    }
    param_cts: list = [];
    for pt in (finfo.func_param_types or []) {
        if pt == "jacstr3" {
            param_cts.extend([ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]);
        } elif pt == "jacstr2" {
            param_cts.extend([ctypes.c_void_p, ctypes.c_int64]);
        } else {
            param_cts.append(LLVM_TO_CTYPES.get(pt, ctypes.c_void_p));
        }
    }
    return ctypes.CFUNCTYPE(ret_ct, *param_cts);
}


class JacStrRet3(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}

class JacStrRet2(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("data", ctypes.c_void_p),
        ("slen", ctypes.c_int64)
    ];
}

def layout_str_header_stamped(layout: any) -> bool {
    return layout?.str_headerless is False;
}


def native_stamped_str_len(addr: int, header_stamped: bool) -> (int | None) {
    if not header_stamped {
        return None;
    }
    if ctypes.c_uint64.from_address(addr + HDR_RC_OFF).value != RC_SENTINEL {
        _aid = ctypes.c_uint64.from_address(addr + HDR_ALLOC_ID_OFF).value;
        if ((_aid >> 32) & 0xFFFF) != HDR_MAGIC {
            return None;
        }
    }
    _dv = ctypes.c_uint64.from_address(addr + HDR_DTOR_OFF).value;
    if not (_dv & STR_LEN_TAG_BIT) {
        return None;
    }
    return _dv >> STR_LEN_TAG_SHIFT;
}


def decode_native_str(addr: any, header_stamped: bool = False) -> str {
    if (addr is None or not addr) {
        return "";
    }
    _a = int(addr);
    stamped = native_stamped_str_len(_a, header_stamped);
    if stamped is None {
        return ctypes.string_at(_a).decode("utf-8", errors="replace");
    }
    if stamped <= 0 {
        return "";
    }
    return ctypes.string_at(_a, stamped).decode("utf-8", errors="replace");
}


def elem_hints_for(
    elem_key: str, keys: any, ctypes_classes: dict
) -> tuple[(str | None, str | None)] {
    if (elem_key != "ptr" or not keys or len(keys) != 1 or not keys[0]) {
        return (None, None);
    }
    if keys[0] == "str" {
        return (None, "str");
    }
    if keys[0] in ctypes_classes {
        return (keys[0], None);
    }
    return (None, None);
}


class NativeList(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("len", ctypes.c_int64),
        ("cap", ctypes.c_int64),
        ("data", ctypes.c_void_p)
    ];
}


class NativeJacVal(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("tag", ctypes.c_uint8),
        ("payload", ctypes.c_int64)
    ];
}


def decode_jacval(tag: int, payload: int, header_stamped: bool = False) -> any {
    if tag == 1 {
        import struct as _struct;
        return _struct.unpack("<d", _struct.pack("<q", payload))[0];
    }
    if tag == 2 {
        return decode_native_str(payload, header_stamped);
    }
    if tag == 7 {
        return payload != 0;
    }
    if tag == 8 {
        return None;
    }
    return int(payload);
}


def _decode_jacval_at(addr: any, slots: list, header_stamped: bool = False) -> list {
    if (not slots or not addr) {
        return [];
    }
    arr = (NativeJacVal * (max(slots) + 1)).from_address(addr);
    return [
        decode_jacval(int(arr[s].tag), int(arr[s].payload), header_stamped)
        for s in slots
    ];
}


class NativeDict(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("len", ctypes.c_int64),
        ("cap", ctypes.c_int64),
        ("keys", ctypes.c_void_p),
        ("vals", ctypes.c_void_p),
        ("ctrl", ctypes.c_void_p),
        ("used", ctypes.c_int64),
        ("order", ctypes.c_void_p)
    ];
}


class NativeSet(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("len", ctypes.c_int64),
        ("cap", ctypes.c_int64),
        ("keys", ctypes.c_void_p),
        ("ctrl", ctypes.c_void_p),
        ("used", ctypes.c_int64),
        ("order", ctypes.c_void_p)
    ];
}


obj NativeStructView {
    has addr: int,
        ct_cls: any = None,
        struct_name: str = "",
        layout: any = None,
        ctypes_classes: dict = field(default_factory=`dict),
        enum_maps: dict = field(default_factory=`dict),
        _native: any = field(default=None, repr=False),
        _field_meta: dict = field(default_factory=`dict, repr=False),
        _view_memo: dict = field(default_factory=`dict, repr=False);

    def postinit -> None;
    def __getattr__(name: str) -> any;
    def __setattr__(name: str, value: any) -> None;
    def _resolve(name: str, raw: any) -> any;
    def __getitem__(key: str) -> any;
    def __contains__(key: str) -> bool;
    def __eq__(other: any) -> any;
    def __hash__ -> int;
    def keys -> any;
    def items -> any;
    def __repr__ -> str;
}


obj NativeListView {
    has list_ptr: int = 0,
        elem_key: str = "",
        ctypes_classes: dict = field(default_factory=`dict),
        enum_maps: dict = field(default_factory=`dict),
        layout: any = None,
        struct_hint: (str | None) = None,
        elem_hint: (str | None) = None,
        _count: int = field(default=0, repr=False),
        _arr: any = field(default=None, repr=False),
        _ct_cls: any = field(default=None, repr=False),
        _struct_name: (str | None) = field(default=None, repr=False),
        _view_memo: dict = field(default_factory=`dict, repr=False);

    def postinit -> None;
    @classmethod
    def empty(cls: type) -> NativeListView {
        return cls(list_ptr=0, elem_key="");
    }

    def __len__ -> int;
    def __getitem__(index: any) -> any;
    def __iter__ -> any;
    def __eq__(other: any) -> any;
    def __repr__ -> str;
}


def get_struct_view(
    addr: int,
    ct_cls: any,
    struct_name: str,
    layout: any,
    ctypes_classes: dict,
    enum_maps: dict,
    view_memo: (dict | None) = None
) -> NativeStructView {
    if view_memo is None {
        view_memo = {};
    }
    memo_key = ("s", addr, struct_name);
    cached = view_memo.get(memo_key);
    if cached is not None {
        return cached;
    }
    view = NativeStructView(
        addr,
        ct_cls,
        struct_name,
        layout,
        ctypes_classes,
        enum_maps,
        _view_memo=view_memo
    );
    view_memo[memo_key] = view;
    return view;
}


def get_list_view(
    list_ptr: int,
    elem_key: str,
    ctypes_classes: dict,
    enum_maps: dict,
    layout: any = None,
    struct_hint: (str | None) = None,
    elem_hint: (str | None) = None,
    view_memo: (dict | None) = None
) -> NativeListView {
    if (list_ptr is None or list_ptr == 0) {
        return NativeListView.empty();
    }
    if view_memo is None {
        view_memo = {};
    }
    memo_key = ("l", list_ptr, elem_key, struct_hint, elem_hint);
    cached = view_memo.get(memo_key);
    if cached is not None {
        return cached;
    }
    view = NativeListView(
        list_ptr,
        elem_key,
        ctypes_classes,
        enum_maps,
        layout,
        struct_hint=struct_hint,
        elem_hint=elem_hint,
        _view_memo=view_memo
    );
    view_memo[memo_key] = view;
    return view;
}


def _decode_scalar_array(
    addr: any,
    count: int,
    type_name: str,
    as_str: bool = False,
    header_stamped: bool = False
) -> list {
    if (count <= 0 or not addr) {
        return [];
    }
    if type_name == "i64" {
        return [int(x) for x in (ctypes.c_int64 * count).from_address(addr)];
    }
    if type_name == "f64" {
        return [float(x) for x in (ctypes.c_double * count).from_address(addr)];
    }
    ptrs = (ctypes.c_void_p * count).from_address(addr);
    if as_str {
        return [decode_native_str(p, header_stamped) for p in ptrs];
    }
    if type_name == "bytes" {
        return [
            ctypes.string_at(p).decode("utf-8", errors="replace") if p else ""
            for p in ptrs
        ];
    }
    return [int(p) if p is not None else 0 for p in ptrs];
}


def _decode_scalar_at(
    addr: any,
    slots: list,
    type_name: str,
    as_str: bool = False,
    header_stamped: bool = False
) -> list {
    if (not slots or not addr) {
        return [];
    }
    if type_name == "i64" {
        arr = (ctypes.c_int64 * (max(slots) + 1)).from_address(addr);
        return [int(arr[s]) for s in slots];
    }
    if type_name == "f64" {
        arr = (ctypes.c_double * (max(slots) + 1)).from_address(addr);
        return [float(arr[s]) for s in slots];
    }
    ptrs = (ctypes.c_void_p * (max(slots) + 1)).from_address(addr);
    if as_str {
        return [decode_native_str(ptrs[s], header_stamped) for s in slots];
    }
    if type_name == "bytes" {
        return [
            ctypes.string_at(ptrs[s]).decode("utf-8", errors="replace")
                if ptrs[s]
                else "" for s in slots
        ];
    }
    return [int(ptrs[s]) if ptrs[s] is not None else 0 for s in slots];
}


def _marshal_dict(
    dict_ptr: int,
    spec: str,
    func_layout: any = None,
    elem_keys: any = None,
    layout: any = None
) -> any {
    parts = spec.split(".", 1);
    if len(parts) != 2 {
        return dict_ptr;
    }
    (key_name, val_name) = (parts[0], parts[1]);
    if (
        key_name not in ("i64", "f64", "bytes", "ptr")
        or val_name not in ("i64", "f64", "ptr", "jacval")
    ) {
        return dict_ptr;
    }
    nd = NativeDict.from_address(dict_ptr);
    count = int(nd.len) if nd.len > 0 else 0;
    cap = int(nd.cap) if nd.cap > 0 else 0;
    if (count <= 0 or cap <= 0 or not nd.order) {
        return {};
    }
    ret_keys = elem_keys;
    if (ret_keys is None and func_layout is not None) {
        ret_keys = func_layout?.ret_elem_keys;
    }
    _hs = layout_str_header_stamped(layout);
    key_as_str = bool(
        key_name == "ptr" and ret_keys and len(ret_keys) == 2 and ret_keys[0] == "str"
    );
    val_as_str = bool(
        val_name == "ptr" and ret_keys and len(ret_keys) == 2 and ret_keys[1] == "str"
    );
    order = (ctypes.c_int64 * count).from_address(nd.order);
    slots = [
        int(s)
        for s in order
        if 0 <= int(s) and int(s) < cap
    ];
    dkeys = _decode_scalar_at(
        nd.keys, slots, key_name, as_str=key_as_str, header_stamped=_hs
    );
    if val_name == "jacval" {
        dvals = _decode_jacval_at(nd.vals, slots, header_stamped=_hs);
    } else {
        dvals = _decode_scalar_at(
            nd.vals, slots, val_name, as_str=val_as_str, header_stamped=_hs
        );
    }
    return dict(zip(dkeys, dvals));
}


def _marshal_set(
    set_ptr: int,
    elem_name: str,
    func_layout: any = None,
    elem_keys: any = None,
    layout: any = None
) -> any {
    if elem_name not in ("i64", "f64", "bytes", "ptr") {
        return set_ptr;
    }
    ns = NativeSet.from_address(set_ptr);
    count = int(ns.len) if ns.len > 0 else 0;
    cap = int(ns.cap) if ns.cap > 0 else 0;
    if (count <= 0 or cap <= 0 or not ns.order) {
        return set();
    }
    ret_keys = elem_keys;
    if (ret_keys is None and func_layout is not None) {
        ret_keys = func_layout?.ret_elem_keys;
    }
    as_str = bool(
        elem_name == "ptr" and ret_keys and len(ret_keys) == 1 and ret_keys[0] == "str"
    );
    order = (ctypes.c_int64 * count).from_address(ns.order);
    slots = [
        int(s)
        for s in order
        if 0 <= int(s) and int(s) < cap
    ];
    return set(
        _decode_scalar_at(
            ns.keys,
            slots,
            elem_name,
            as_str=as_str,
            header_stamped=layout_str_header_stamped(layout)
        )
    );
}


glob _OPT_CTYPES: dict = {};

def _opt_ctype(payload_type: str) -> type {
    cached = _OPT_CTYPES.get(payload_type);
    if cached is not None {
        return cached;
    }
    pct = LLVM_TO_CTYPES.get(payload_type);
    if pct is None or payload_type.endswith("*") or payload_type == "ptr" {
        pct = ctypes.c_void_p;
    }
    cls = type(
        f"NativeOpt_{payload_type.replace('*', 'p').replace('.', '_')}",
        (ctypes.Structure, ),
        {"_fields_": [("tag", ctypes.c_int8), ("payload", pct)]}
    );
    _OPT_CTYPES[payload_type] = cls;
    return cls;
}

def build_ctypes_classes(layout: any) -> dict {
    classes: dict = {};
    for (name, struct_layout) in layout.structs.items() {
        fields: list = [];
        for f in struct_layout.fields {
            if f.is_func_ptr {
                ct = ctypes.c_void_p;
            } elif f.llvm_type.startswith("opt.") {
                ct = _opt_ctype(f.llvm_type[4:]);
            } else {
                ct = LLVM_TO_CTYPES.get(f.llvm_type);
                if (ct is None or f.llvm_type == "i8*") {
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


def build_enum_maps(layout: any, module_ns: dict) -> dict {
    maps: dict = {};
    for (enum_name, enum_layout) in layout.enums.items() {
        py_enum_cls = module_ns.get(enum_name);
        if py_enum_cls is None {
            continue;
        }

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


def marshal_value(
    raw: any,
    llvm_type: str,
    ctypes_classes: dict,
    enum_maps: dict,
    py_classes: dict,
    field_info: any = None,
    func_layout: any = None,
    layout: any = None,
    view_memo: (dict | None) = None
) -> any {
    if (field_info and field_info.is_func_ptr) {
        if (raw is None or raw == 0) {
            return None;
        }
        fn_type = _build_cfunctype(field_info);
        return fn_type(raw);
    }

    if llvm_type.startswith("opt.") {
        if raw is None {
            return None;
        }
        if int(raw.tag) == 0 {
            return None;
        }
        return marshal_value(
            raw.payload,
            llvm_type[4:],
            ctypes_classes,
            enum_maps,
            py_classes,
            None,
            func_layout,
            layout,
            view_memo
        );
    }

    if llvm_type in ("i64", "i32", "i16", "i8") {
        val = int(raw);

        if (field_info and field_info.enum_type) {
            emap = enum_maps.get(field_info.enum_type);
            if (emap and 0 <= val < len(emap) and emap[val] is not None) {
                return emap[val];
            }
        }

        _ret_enum = func_layout?.ret_enum_type if func_layout else None;
        if _ret_enum {
            emap = enum_maps.get(_ret_enum);
            if (emap and 0 <= val < len(emap) and emap[val] is not None) {
                return emap[val];
            }
            return None;
        }
        return val;
    }
    if llvm_type == "i1" {
        return bool(raw);
    }
    if llvm_type in ("f64", "f32") {
        return float(raw);
    }
    if llvm_type == "jacstr3" {
        return decode_native_str(raw?.data, layout_str_header_stamped(layout));
    }
    if llvm_type == "jacstr2" {
        _d = raw?.data;
        if not _d {
            return "";
        }
        return ctypes.string_at(_d, int(raw.slen)).decode("utf-8", errors="replace");
    }
    if llvm_type == "i8*" {
        if (raw is None or raw == 0) {
            return "";
        }
        if isinstance(raw, bytes) {
            return raw.decode("utf-8", errors="replace");
        }

        if isinstance(raw, int) {
            return decode_native_str(raw, layout_str_header_stamped(layout));
        }
        return str(raw);
    }

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
                layout,
                view_memo=view_memo
            );
        }
        return raw;
    }

    if (llvm_type.startswith("Dict.") and llvm_type.endswith("*")) {
        if (raw is None or raw == 0) {
            return {};
        }
        return _marshal_dict(raw, llvm_type[5:-1], func_layout, layout=layout);
    }

    if (llvm_type.startswith("Set.") and llvm_type.endswith("*")) {
        if (raw is None or raw == 0) {
            return set();
        }
        return _marshal_set(raw, llvm_type[4:-1], func_layout, layout=layout);
    }

    if (llvm_type.endswith("*") and not llvm_type.startswith("List.")) {
        struct_name = llvm_type[:-1];
        if struct_name == "ptr" {
            return raw;
        }
        ct_cls = ctypes_classes.get(struct_name);
        if (ct_cls is None or raw is None or raw == 0) {
            return raw;
        }
        return get_struct_view(
            raw,
            ct_cls,
            struct_name,
            layout,
            ctypes_classes,
            enum_maps,
            view_memo=view_memo
        );
    }

    if (llvm_type.startswith("List.") and llvm_type.endswith("*")) {
        elem_key = llvm_type[5:-1];
        if (raw is None or raw == 0) {
            return NativeListView.empty();
        }
        ret_keys = func_layout?.ret_elem_keys if func_layout is not None else None;
        (struct_hint, elem_hint) = elem_hints_for(elem_key, ret_keys, ctypes_classes);
        return get_list_view(
            raw,
            elem_key,
            ctypes_classes,
            enum_maps,
            layout,
            struct_hint=struct_hint,
            elem_hint=elem_hint,
            view_memo=view_memo
        );
    }

    return raw;
}


def _marshal_tuple(
    tuple_ptr: int,
    tuple_layout: any,
    ctypes_classes: dict,
    enum_maps: dict,
    py_classes: dict,
    layout: any = None,
    view_memo: (dict | None) = None
) -> tuple {
    elem_types = tuple_layout.element_types;
    struct_hints = tuple_layout.element_struct_hints or [];

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

        if (et == "List.ptr*" and hint and raw_val and raw_val != 0) {
            result.append(
                get_list_view(
                    raw_val,
                    "ptr",
                    ctypes_classes,
                    enum_maps,
                    layout,
                    struct_hint=hint,
                    view_memo=view_memo
                )
            );
        } else {
            marshalled = marshal_value(
                raw_val,
                et,
                ctypes_classes,
                enum_maps,
                py_classes,
                layout=layout,
                view_memo=view_memo
            );
            result.append(marshalled);
        }
    }

    return tuple(result);
}


def wrap_native_function(
    engine: any,
    func_layout: any,
    ctypes_classes: dict,
    enum_maps: dict,
    py_classes: dict,
    layout: any = None
) -> any {
    addr = engine.get_function_address(func_layout.name);
    if not addr {
        return None;
    }

    if any(pt.startswith("opt.") for pt in func_layout.param_types) {
        return None;
    }

    c_arg_types: list = [];
    for pt in func_layout.param_types {
        if pt == "jacstr3" {
            c_arg_types.extend([ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]);
            continue;
        }
        if pt == "jacstr2" {
            c_arg_types.extend([ctypes.c_void_p, ctypes.c_int64]);
            continue;
        }
        ct = LLVM_TO_CTYPES.get(pt);
        if ct is None {
            ct = ctypes.c_void_p;
        }
        c_arg_types.append(ct);
    }

    ret_type = func_layout.ret_type;
    if ret_type == "jacstr3" {
        c_ret = JacStrRet3;
    } elif ret_type == "jacstr2" {
        c_ret = JacStrRet2;
    } else {
        c_ret = LLVM_TO_CTYPES.get(ret_type);
    }
    if c_ret is None {
        if ret_type == "void" {
            c_ret = None;
        } elif ret_type.startswith("opt.") {
            c_ret = _opt_ctype(ret_type[4:]);
        } else {
            c_ret = ctypes.c_void_p;
        }
    }

    fn_type = ctypes.CFUNCTYPE(c_ret, *c_arg_types);
    native_fn = fn_type(addr);

    param_types = func_layout.param_types;
    fl = func_layout;

    str_new_fn: any = None;
    if any(pt in ("i8*", "jacstr3", "jacstr2") for pt in param_types) {
        _sn_addr = 0;
        for _sn_name in ("jac_str_new", "__jac_str_new") {
            try {
                _sn_addr = engine.get_function_address(_sn_name);
            } except Exception {
                _sn_addr = 0;
            }
            if _sn_addr {
                break;
            }
        }
        if _sn_addr {
            _sn_type = ctypes.CFUNCTYPE(
                ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64
            );
            str_new_fn = _sn_type(_sn_addr);
        }
    }

    def wrapper(*args: any) -> any {
        c_args: list = [];
        _keepalive: list = [];
        for (arg, pt) in zip(args, param_types) {
            if pt in ("jacstr3", "jacstr2") and isinstance(arg, (str, bytes)) {
                _b = arg.encode("utf-8") if isinstance(arg, str) else arg;
                if str_new_fn is not None {
                    _sp = str_new_fn(_b, len(_b));
                } else {
                    _keep = ctypes.create_string_buffer(_b);
                    _keepalive.append(_keep);
                    _sp = ctypes.cast(_keep, ctypes.c_void_p).value;
                }
                if pt == "jacstr3" {
                    c_args.extend([_sp, _sp, len(_b)]);
                } else {
                    c_args.extend([_sp, len(_b)]);
                }
            } elif (pt == "i8*" and isinstance(arg, str)) {
                _b = arg.encode("utf-8");
                if str_new_fn is not None {
                    _sp = str_new_fn(_b, len(_b));
                    c_args.append(ctypes.cast(_sp, ctypes.c_char_p));
                } else {
                    c_args.append(_b);
                }
            } elif isinstance(arg, NativeStructView) {
                c_args.append(arg.addr);
            } elif isinstance(arg, NativeListView) {
                c_args.append(arg.list_ptr);
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
            layout=layout,
            view_memo={}
        );
    }

    wrapper.__name__ = func_layout.name;
    wrapper.__qualname__ = func_layout.name;
    wrapper.__wrapped__ = True;
    return wrapper;
}


def init_native_globals(engine: any, manifest: any) {
    import ctypes;
    import from jaclang.jac0core.codeinfo { native_safe_sym }
    srcs = manifest.native_transitive_sources if manifest is not None else [];
    for src in (srcs or []) {
        if not src {
            continue;
        }

        safe = native_safe_sym(src);
        addr = engine.get_function_address(f"__jac_glob_init_{safe}");
        if addr {
            ctypes.CFUNCTYPE(None)(addr)();
        }
    }
    main_addr = engine.get_function_address("__jac_glob_init");
    if main_addr {
        ctypes.CFUNCTYPE(None)(main_addr)();
    }
}

def install_native_wrappers(
    module: any, engine: any, layout: any, py_classes: (dict | None) = None
) -> int {
    module_ns = module.__dict__;

    ctypes_classes = build_ctypes_classes(layout);

    enum_maps = build_enum_maps(layout, module_ns);

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
    mod_name = module?.__name__;
    for (func_name, func_layout) in layout.functions.items() {
        if func_name not in module_ns {
            continue;
        }

        existing = module_ns[func_name];
        owner = existing?.__module__;
        if owner is None or mod_name is None or owner != mod_name {
            continue;
        }
        wrapper = wrap_native_function(
            engine, func_layout, ctypes_classes, enum_maps, py_classes, layout=layout
        );
        if wrapper is not None {
            module_ns[f"_py_{func_name}"] = existing;
            module_ns[func_name] = wrapper;
            wrapped_count += 1;
            logger.debug(f"Installed native wrapper for {func_name}");
        }
    }

    return wrapped_count;
}
