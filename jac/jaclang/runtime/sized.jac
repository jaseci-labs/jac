import math;
import struct;

glob JS_SAFE_INT: int = (1 << 53) - 1,
     OVERFLOW_MESSAGE: str = "integer overflow",
     SHIFT_MESSAGE: str = "shift count out of range",
     FW: dict[str, any] = {},
     SIZED_TYPES: dict[str, any] = {},
     _F32: any = struct.Struct("f");

def round_f32(value: float) -> float;

def _mk_check(lo: int, hi: int) -> any;

def _mk_shl(lo: int, hi: int, width: int) -> any;

def _mk_shr(width: int) -> any;

def _mk_pow(lo: int, hi: int, width: int) -> any;

def _mk_invert(mask: int) -> any;

def _mk_int_class(name: str, lo: int, hi: int) -> type;

def _mk_float_class(name: str, narrow: bool) -> type;

def _fw_wrapping(name: str, op: str, a: any, b: any = 0) -> int;

def _build_family;

def json_wire_form(name: str, value: any) -> any;

def json_wire_read(name: str, value: any) -> any;

def _wrapping_unavailable(name: str) -> any;

def __getattr__(name: str) -> object;

with entry {
    _build_family();
}
