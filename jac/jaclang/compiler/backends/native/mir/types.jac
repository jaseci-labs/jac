enum MirKind {
    VOID = "void",
    NONE = "none",
    BOOL = "bool",
    INT = "int",
    FLOAT = "float",
    STR = "str",
    STR_REF = "str.ref",
    BYTES = "bytes",
    BYTEARRAY = "bytearray",
    OPT = "opt",
    OPT_REF = "opt.ref",
    ANY = "any",
    LIST = "list",
    LIST_AOS = "list.aos",
    DICT = "dict",
    SET = "set",
    TUPLE = "tuple",
    OBJ = "obj",
    OSP = "osp",
    ENUM = "enum",
    FN = "fn",
    ITER = "iter",
    RANGE = "range",
    COMPLEX = "complex",
    SLICE = "slice",
    REGION = "region",
    CLASS = "class",
    TYPEVAR = "typevar",
    C_PTR = "c.ptr",
    C_STRUCT = "c.struct",
    C_VIEW = "c.view",
    C_FN = "c.fn"
}

obj MirType {
    has kind: MirKind,
        width: int = 0,
        signed: bool = False,
        name: str = "",
        args: list[MirType] = [],
        key: str = "";

    def is_scalar -> bool;
    def is_numeric -> bool;
    def is_ref -> bool;
    def is_sized -> bool;
    def payload -> MirType;
    def render -> str;
}

glob _MIR_TYPES: dict[str, MirType] = {};

def mir_type(
    kind: MirKind,
    width: int = 0,
    signed: bool = False,
    name: str = "",
    args: (list[MirType] | None) = None
) -> MirType;

def mir_void -> MirType;

def mir_none -> MirType;

def mir_bool -> MirType;

def mir_int(width: int = 64, signed: bool = True, sized: bool = False) -> MirType;

def mir_float(width: int = 64) -> MirType;

def mir_str -> MirType;

def mir_str_ref -> MirType;

def mir_bytes -> MirType;

def mir_bytearray -> MirType;

def mir_opt(payload: MirType) -> MirType;

def mir_opt_ref(payload: MirType) -> MirType;

def mir_any -> MirType;

def mir_list(elem: MirType) -> MirType;

def mir_list_aos(elem: MirType) -> MirType;

def mir_dict(key: MirType, value: MirType) -> MirType;

def mir_set(elem: MirType) -> MirType;

def mir_tuple(elems: list[MirType]) -> MirType;

def mir_obj(name: str) -> MirType;

def mir_osp(kind: str) -> MirType;

def mir_enum(name: str, underlying: MirType) -> MirType;

def mir_fn(params: list[MirType], ret: MirType) -> MirType;

def mir_iter(elem: MirType) -> MirType;

def mir_range -> MirType;

def mir_complex -> MirType;

def mir_slice -> MirType;

def mir_region -> MirType;

def mir_class(name: str) -> MirType;

def mir_typevar(name: str) -> MirType;

def mir_c_ptr(elem: MirType) -> MirType;

def mir_c_struct(name: str) -> MirType;

def mir_c_view(elem: MirType) -> MirType;

def mir_c_fn(params: list[MirType], ret: MirType) -> MirType;

def mir_holds_ref(t: MirType) -> bool;

def mir_list(elem: MirType) -> MirType;

def mir_dict(key: MirType, value: MirType) -> MirType;

def mir_set(elem: MirType) -> MirType;

def mir_ref -> MirType;

def mir_is_container(t: MirType) -> bool;

def mir_obj(name: str) -> MirType;
