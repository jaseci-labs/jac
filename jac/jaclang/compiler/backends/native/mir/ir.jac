enum MirOp {
    CONST_INT = "const.int",
    CONST_FLOAT = "const.float",
    CONST_BOOL = "const.bool",
    CONST_STR = "const.str",
    CONST_NONE = "const.none",
    CONST_NULL = "const.null",
    SLOT = "slot",
    LOAD = "load",
    STORE = "store",
    BIN = "bin",
    OVF = "ovf",
    CMP = "cmp",
    NEG = "neg",
    NOT = "not",
    CONV = "conv",
    SELECT = "select",
    BITCAST = "bitcast",
    MEM_LOAD = "mem.load",
    MEM_STORE = "mem.store",
    ATOMIC_LOAD = "atomic.load",
    ATOMIC_STORE = "atomic.store",
    ATOMIC_RMW = "atomic.rmw",
    ATOMIC_CAS = "atomic.cas",
    FENCE = "fence",
    CALL = "call",
    CALL_RUNTIME = "call.runtime",
    STR_PART = "str.part",
    STR_MAKE = "str.make",
    REF_CAST = "ref.cast",
    RETAIN = "retain",
    RELEASE = "release",
    RAISE = "raise",
    PTR_CAST = "ptr.cast",
    PTR_INT = "ptr.int",
    PTR_NULL = "ptr.null",
    PTR_OFFSET = "ptr.offset",
    CSTR = "cstr",
    VIEW = "view",
    VIEW_LEN = "view.len",
    ELEM_ADDR = "elem.addr",
    FIELD_ADDR = "field.addr",
    TLS_BLOCK = "tls.block",
    GLOBAL_BLOCK = "global.block",
    FN_ADDR = "fn.addr",
    CALL_DTOR = "call.dtor",
    GLOBAL_ADDR = "global.addr",
    CALL_C = "call.c",
    CALL_FNPTR = "call.fnptr",
    BR = "br",
    COND_BR = "cond_br",
    RET = "ret",
    UNREACHABLE = "unreachable"
}

obj MirValue {
    has id: int,
        type: MirType,
        name: str = "",
        is_slot: bool = False,
        owned: bool = False;

    def render -> str;
}

obj MirInstr {
    has op: MirOp,
        result: (MirValue | None) = None,
        operands: list[MirValue] = [],
        sub: str = "",
        callee: str = "",
        int_value: int = 0,
        float_value: float = 0.0,
        str_value: str = "",
        type_arg: (MirType | None) = None,
        targets: list[str] = [];

    def is_terminator -> bool;
    def render -> str;
}

obj MirBlock {
    has label: str,
        instrs: list[MirInstr] = [];

    def terminated -> bool;
}

obj MirParam {
    has name: str,
        value: MirValue;
}

obj MirFunction {
    has name: str,
        symbol: str,
        ret: MirType,
        params: list[MirParam] = [],
        blocks: list[MirBlock] = [],
        linkage: str = "external",
        next_id: int = 0,
        next_label: int = 0;

    def new_value(type: MirType, name: str = "") -> MirValue;
    def new_block(hint: str = "bb") -> MirBlock;
    def block(label: str) -> MirBlock;
    def render -> str;
}

obj MirExtern {
    has symbol: str,
        ret: MirType,
        params: list[MirType] = [];
}

obj MirGlobal {
    has name: str,
        symbol: str,
        type: MirType,
        int_value: int = 0,
        float_value: float = 0.0,
        linkage: str = "";
}

obj MirStructField {
    has name: str,
        type: MirType;
}

obj MirStructDef {
    has name: str,
        fields: list[MirStructField] = [];

    def index_of(field: str) -> int;
}

obj MirModule {
    has path: str,
        prefix: str,
        functions: list[MirFunction] = [],
        externs: dict[str, MirExtern] = {},
        structs: dict[str, MirStructDef] = {},
        globals: dict[str, MirGlobal] = {},
        tls_blocks: dict[str, int] = {},
        global_blocks: dict[str, int] = {},
        deps: list[str] = [];

    def function(symbol: str) -> (MirFunction | None);
    def render -> str;
}

obj MirBuilder {
    has fn: MirFunction,
        block: MirBlock;

    def position(block: MirBlock);
    def emit(instr: MirInstr) -> (MirValue | None);
    def const_int(value: int, type: MirType) -> MirValue;
    def const_float(value: float, type: MirType) -> MirValue;
    def const_bool(value: bool) -> MirValue;
    def slot(type: MirType, name: str = "") -> MirValue;
    def load(slot: MirValue, type: MirType) -> MirValue;
    def store(slot: MirValue, value: MirValue);
    def binary(op: str, left: MirValue, right: MirValue) -> MirValue;
    def overflows(op: str, left: MirValue, right: MirValue) -> MirValue;
    def raise_builtin(exception: str, message: str);
    def compare(op: str, left: MirValue, right: MirValue) -> MirValue;
    def negate(value: MirValue) -> MirValue;
    def logical_not(value: MirValue) -> MirValue;
    def convert(value: MirValue, to: MirType) -> MirValue;
    def select(cond: MirValue, then: MirValue, otherwise: MirValue) -> MirValue;
    def call(callee: str, args: list[MirValue], ret: MirType) -> (MirValue | None);
    def call_runtime(
        callee: str, args: list[MirValue], ret: MirType
    ) -> (MirValue | None);
    def const_str(text: str, type: MirType) -> MirValue;
    def const_null(type: MirType) -> MirValue;
    def str_part(value: MirValue, part: str) -> MirValue;
    def str_make(owner: MirValue, data: MirValue, length: MirValue) -> MirValue;
    def ref_cast(value: MirValue, to: MirType, owned: bool) -> MirValue;
    def branch(target: MirBlock);
    def cond_branch(cond: MirValue, then: MirBlock, otherwise: MirBlock);
    def ret(value: (MirValue | None));
    def unreachable;
}
