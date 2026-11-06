enum MirOp {
    CONST_INT = "const.int",
    CONST_FLOAT = "const.float",
    CONST_BOOL = "const.bool",
    CONST_STR = "const.str",
    CONST_BYTES = "const.bytes",
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
    OPT_MAKE = "opt.make",
    TUPLE_MAKE = "tuple.make",
    TUPLE_GET = "tuple.get",
    ANY_BOX = "any.box",
    ANY_MAKE = "any.make",
    ANY_TAG = "any.tag",
    ANY_PAYLOAD = "any.payload",
    OPT_PRESENT = "opt.present",
    OPT_GET = "opt.get",
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
    SIZEOF = "sizeof",
    EXC_FRAME = "exc.frame",
    ALLOCA = "alloca",
    SETJMP = "setjmp",
    LONGJMP = "longjmp",
    VA_START = "va.start",
    VTABLE_ADDR = "vtable.addr",
    CLASS_ADDR = "class.addr",
    FN_ADDR = "fn.addr",
    CALL_DTOR = "call.dtor",
    GLOBAL_ADDR = "global.addr",
    CALL_C = "call.c",
    CALL_FNPTR = "call.fnptr",
    CALL_PYTHON = "call.python",
    YIELD = "yield",
    FRAME_NEW = "frame.new",
    FRAME_FIELD = "frame.field",
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
        is_temp: bool = False,
        owned: bool = False,
        hold: str = "",
        borrows: bool = False;

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
        targets: list[str] = [],
        consumes: list[int] = [];

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
        manual_rc: bool = False,
        ownership: bool = False,
        borrow_return: bool = False,
        resumable: bool = False,
        variadic: bool = False,
        c_symbol: str = "",
        cc: str = "",
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
        params: list[MirType] = [],
        variadic: bool = False,
        c_abi: bool = False,
        cc: str = "";
}

obj MirConst {
    has kind: str,
        int_value: int = 0,
        float_value: float = 0.0,
        symbol: str = "",
        data: bytes = b"",
        items: list[MirConst] = [],
        offset: int = 0;
}

obj MirGlobal {
    has name: str,
        symbol: str,
        type: MirType,
        int_value: int = 0,
        float_value: float = 0.0,
        linkage: str = "",
        c_data: bool = False,
        opaque: bool = False,
        count: int = -1,
        thread_local: bool = False,
        c_init: (MirConst | None) = None;
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

obj MirObjectField {
    has name: str,
        type: MirType,
        index: int,
        borrowed: bool = False;
}

obj MirObjectDef {
    has name: str,
        slot_count: int,
        fields: list[MirObjectField] = [],
        vtable_slot: int = -1,
        tag_slot: int = -1,
        reports_slot: int = -1,
        vtable_symbol: str = "",
        class_symbol: str = "",
        vtable_methods: list[str] = [],
        vtable_names: list[str] = [],
        vtable_entries: dict[int, str] = {},
        ancestry: list[str] = [],
        field_remaps: dict[str, list[int]] = {},
        drop_symbol: str = "",
        glue_symbol: str = "",
        drop_slot: str = "",
        trace_symbol: str = "",
        is_acyclic: bool = False,
        local: bool = False,
        osp_kind: str = "";

    def field(name: str) -> (MirObjectField | None);
}

obj MirFrame {
    has size: int,
        drop_symbol: str,
        offsets: dict[int, int] = {};
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
        objects: dict[str, MirObjectDef] = {},
        demoted: dict[str, str] = {},
        bridged: dict[str, str] = {},
        python_imports: list[str] = [],
        public: list[str] = [],
        defaults: dict[str, list[str]] = {},
        frames: dict[str, MirFrame] = {},
        deps: list[str] = [],
        clib_specs: list[tuple[str, list[str], int]] = [],
        headerless: bool = False,
        clib_symbols: dict[str, int] = {};

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

def mir_selector_symbol(name: str) -> str;

def mir_selector_global(name: str) -> MirGlobal;
