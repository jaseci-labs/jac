enum MirOp {
    CONST_INT = "const.int",
    CONST_FLOAT = "const.float",
    CONST_BOOL = "const.bool",
    CONST_STR = "const.str",
    CONST_NONE = "const.none",
    SLOT = "slot",
    LOAD = "load",
    STORE = "store",
    BIN = "bin",
    OVF = "ovf",
    CMP = "cmp",
    NEG = "neg",
    NOT = "not",
    CONV = "conv",
    CALL = "call",
    CALL_RUNTIME = "call.runtime",
    RAISE = "raise",
    BR = "br",
    COND_BR = "cond_br",
    RET = "ret",
    UNREACHABLE = "unreachable"
}

obj MirValue {
    has id: int,
        type: MirType,
        name: str = "";

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
        type: MirType;
}

obj MirModule {
    has path: str,
        prefix: str,
        functions: list[MirFunction] = [],
        externs: dict[str, MirExtern] = {};

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
    def call(callee: str, args: list[MirValue], ret: MirType) -> (MirValue | None);
    def branch(target: MirBlock);
    def cond_branch(cond: MirValue, then: MirBlock, otherwise: MirBlock);
    def ret(value: (MirValue | None));
    def unreachable;
}
