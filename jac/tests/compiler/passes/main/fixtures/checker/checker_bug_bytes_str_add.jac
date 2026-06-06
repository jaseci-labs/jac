"""Fixture for #6446: bytes + str must not match bytes.__add__."""

def bytes_plus_str(b: bytes, s: str) -> any {
    return b + s;          # Error: str is not a readable buffer
}

def str_plus_bytes(b: bytes, s: str) -> any {
    return s + b;          # Error: bytes is not a str
}

def bytes_plus_bytes(a: bytes, b: bytes) -> bytes {
    return a + b;          # OK
}
