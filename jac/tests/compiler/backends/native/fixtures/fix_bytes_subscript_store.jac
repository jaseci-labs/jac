"""Fixture for bytes subscript assignment (store) lowering.

NaIRGen already lowers bytes[i] reads; buf[i] = v stores must truncate to
u8 and write through the element pointer.  Used by termios/select FFI floors.
"""

def _put_u32(buf: bytes, off: int, v: int) {
    buf[off] = v & 0xFF;
    buf[off + 1] = (v >> 8) & 0xFF;
    buf[off + 2] = (v >> 16) & 0xFF;
    buf[off + 3] = (v >> 24) & 0xFF;
}


def:pub pack_u32_le(v: int) -> bytes {
    buf: bytes = b"\x00" * 4;
    _put_u32(buf, 0, v);
    return buf;
}


def:pub read_byte(buf: bytes, off: int) -> int {
    return buf[off];
}


def:pub lit_store(v: int) -> bytes {
    buf: bytes = b"\x00\x00\x00\x00";
    buf[0] = v;
    return buf;
}
