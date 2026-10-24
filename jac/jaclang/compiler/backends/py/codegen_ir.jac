import struct;

glob CIR_MAGIC: bytes = b"JCIR",
     CIR_FORMAT_VERSION: int = 1,
     CIR_TERMINATOR: int = 254,
     OP_NONE: int = 1,
     OP_TRUE: int = 2,
     OP_FALSE: int = 3,
     OP_ELLIPSIS: int = 4,
     OP_INT: int = 5,
     OP_INT_BIG: int = 6,
     OP_FLOAT: int = 7,
     OP_STR: int = 8,
     OP_BYTES: int = 9,
     OP_LIST: int = 10,
     OP_TUPLE: int = 11,
     OP_NODE: int = 12,
     OP_LOC: int = 13,
     OP_PARSE_SPLICE: int = 14,
     OP_END: int = 15,
     DIAG_WARNING: int = 0,
     DIAG_ERROR: int = 1,
     _I64_MIN: int = -9223372036854775808,
     _I64_MAX: int = 9223372036854775807;

class CodegenIrError(RuntimeError) {}

class CodegenIrVersionError(CodegenIrError) {}

class CodegenIrFormatError(CodegenIrError) {}

def cir_python_version -> int;

obj CirDiag {
    has message: str,
        code_str: str = "",
        mod_path: str = "",
        severity: int = DIAG_ERROR,
        help: str = "",
        first_line: int = 0,
        col_start: int = 0,
        last_line: int = 0,
        col_end: int = 0;
}

obj CirModule {
    has mod_path: str,
        code: bytes;
}

obj CirContainer {
    has format_version: int = CIR_FORMAT_VERSION,
        python_version: int = 0,
        class_names: list[str] = [],
        key_names: list[str] = [],
        strings: list[str] = [],
        modules: list[CirModule] = [],
        diags: list[CirDiag] = [];
}

def _w_varint(buf: bytearray, v: int) -> None;

def int_literal_magnitude(text: str) -> bytes;

def _w_svarint(buf: bytearray, v: int);

def _r_varint(data: bytes, pos: int, what: str) -> tuple[int, int];

def _r_svarint(data: bytes, pos: int, what: str) -> tuple[int, int];

def _w_str_entry(buf: bytearray, s: str);

def _r_str_entry(data: bytes, pos: int, what: str) -> tuple[str, int];

obj CodegenIrWriter {
    has class_names: list[str] = [],
        class_idx: dict[str, int] = {},
        key_names: list[str] = [],
        key_idx: dict[str, int] = {},
        strings: list[str] = [],
        string_idx: dict[str, int] = {},
        modules: list[CirModule] = [],
        diags: list[CirDiag] = [],
        _code: bytearray = bytearray(),
        _open: bool = False,
        _mod_path: str = "",
        _depth: int = 0,
        _loc_set: bool = False,
        _loc_l1: int = 0,
        _loc_c1: int = 0,
        _loc_l2: int = 0,
        _loc_c2: int = 0;

    def class_ref(name: str) -> int;
    def key_ref(name: str) -> int;
    def str_ref(s: str) -> int;
    def _require_open;
    def begin_module(mod_path: str);
    def emit_none;
    def emit_true;
    def emit_false;
    def emit_ellipsis;
    def emit_int(v: int);
    def emit_int_wide(negative: bool, magnitude: bytes);
    def emit_float(v: float);
    def emit_str(s: str);
    def emit_bytes(b: bytes);
    def emit_list(n: int);
    def emit_tuple(n: int);
    def emit_loc(first_line: int, col_start: int, last_line: int, col_end: int);
    def emit_loc_needed(first_line: int, col_start: int, last_line: int, col_end: int);
    def emit_node(class_name: str, field_names: list[str]);
    def emit_parse_splice(src: str, line_offset: int = 0);
    def end_module;
    def add_diag(diag: CirDiag);
    def to_bytes -> bytes;
}

def read_container(data: bytes) -> CirContainer;
