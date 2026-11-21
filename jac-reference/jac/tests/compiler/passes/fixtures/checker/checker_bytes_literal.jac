"""Fixture: byte-string literals (b"...") are typed as bytes, not str."""

def takes_bytes -> bytes {
    x: bytes = b"\x00";
    return x;
}

def encode_and_concat(s: str) -> bytes {
    return s.encode("utf-8") + b"\x00";
}
