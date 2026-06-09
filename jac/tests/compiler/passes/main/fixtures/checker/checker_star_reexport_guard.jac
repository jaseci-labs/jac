"""Fixture: bytes + str must error; str is not a Buffer (ReadableBuffer)."""

def bytes_plus_str(b: bytes, s: str) -> bytes {
    return b + s;  # Error
}

def bytes_plus_bytes(b: bytes, c: bytes) -> bytes {
    return b + c;  # Ok
}
