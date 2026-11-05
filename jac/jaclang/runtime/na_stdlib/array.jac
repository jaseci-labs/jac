import struct;
import from _typename { typename }


def _arr_itemsize(tc: str) -> int;


def _arr_signed(tc: str) -> bool;


def _arr_float(tc: str) -> bool;


def _arr_cname(tc: str) -> str;


def _arr_bounds(tc: str) -> tuple[int, int];


def _put_le(buf: bytearray, off: int, v: int, size: int);


def _get_le(buf: bytearray, off: int, size: int, signed: bool) -> int;


def _ieqf(a: int, b: float) -> bool;


obj:pub array {
    has typecode: str = "b",
        _buf: bytearray = bytearray(0),
        itemsize: int = 1,
        _sgn: bool = True,
        _flt: bool = False,
        _lo: int = -128,
        _hi: int = 127,
        _enc: bytearray = bytearray(0);

    def init(typecode: str, initial: (list[any] | None) = None);
    def _count -> int;
    def __len__ -> int;
    def _coerce_int(v: any) -> int;
    def _coerce_float(v: any) -> float;
    def _check_range(v: int);
    def _write_elem(off: int, v: int);
    def _read_elem(off: int) -> int;
    def _write_float_elem(off: int, v: float);
    def _read_float_elem(off: int) -> float;
    def _encode_one(v: any, dst: bytearray);
    def append(v: any);
    def extend(seq: list[any]);
    def _extend_array(other: array);
    def _extend_bytes(data: bytes);
    def fromlist(seq: list[any]);
    def insert(i: int, v: any);
    def pop(i: int = -1) -> any;
    def remove(v: any);
    def _elem_eq(v: any, i: int) -> bool;
    def _find(v: any) -> int;
    def index(v: any, start: int = 0, stop: int = 9223372036854775807) -> int;
    def count(v: any) -> int;
    def __contains__(v: any) -> bool;
    def reverse;
    def byteswap;
    def tobytes -> bytes;
    def frombytes(data: bytes);
    def tofile(f: any);
    def fromfile(f: any, n: int);
    def tolist -> list[any];
    def buffer_info -> tuple[int, int];
    def __getitem__(i: int) -> any;
    def __setitem__(i: int, v: any);
    def _same_elem(other: array, i: int) -> bool;
    def __eq__(other: array) -> bool;
    def __ne__(other: array) -> bool;
    def __add__(other: array) -> array;
    def __mul__(n: int) -> array;
}
