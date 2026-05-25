"""UTF-8 byte primitives the rune-aware lexer relies on.

These must behave identically in the native and Python backends:
  - len(s.encode())            -> byte length
  - int.from_bytes(enc[i:i+1]) -> byte value at index (portable byte accessor)
  - enc[a:c].decode()          -> byte-range -> str (needs native bytes.decode)
"""

def byte_len(s: str) -> int {
    return len(s.encode("utf-8"));
}

def byte_at(s: str, i: int) -> int {
    return int.from_bytes(s.encode("utf-8")[i:i + 1], "big");
}

def roundtrip(s: str) -> str {
    return s.encode("utf-8").decode("utf-8");
}

def slice_decode(s: str, a: int, c: int) -> str {
    return s.encode("utf-8")[a:c].decode("utf-8");
}
