import from _zlib_native { z_crc32 }
import from base64 { b64decode, b64encode }


obj:pub Error(ValueError) {}
obj:pub Incomplete(Exception) {}


glob _CRCTAB: list[int] = [];


def _hexval(c: int) -> int;


def _hexdig(v: int) -> int;


def _hqx_tab -> list[int];


def:pub hexlify(data: bytes, sep: bytes = b"", bytes_per_sep: int = 1) -> bytes;


def:pub b2a_hex(data: bytes, sep: bytes = b"", bytes_per_sep: int = 1) -> bytes;


def:pub unhexlify(hexstr: bytes) -> bytes;


def:pub a2b_hex(hexstr: bytes) -> bytes;


def:pub b2a_base64(data: bytes, newline: bool = True) -> bytes;


def:pub a2b_base64(data: bytes, strict_mode: bool = False) -> bytes;


def:pub crc32(data: bytes, value: int = 0) -> int;


def:pub crc_hqx(data: bytes, crc: int) -> int;


def:pub b2a_uu(data: bytes, backtick: bool = False) -> bytes;


def:pub a2b_uu(data: bytes) -> bytes;


def:pub a2b_qp(data: bytes, header: bool = False) -> bytes;


def:pub b2a_qp(
    data: bytes, quotetabs: bool = False, istext: bool = True, header: bool = False
) -> bytes;
