"""Length-aware `bytes` primitives for the native backend (#6404 Track 0).

Unlike the null-terminated `str` (i8*), `bytes` must carry an explicit length
so embedded NUL bytes survive and `len()` is exact — the prerequisite for the
struct module and binary file I/O. Every function returns a scalar so the
ctypes harness can assert behavior directly.
"""

def lit_len() -> int {
    b = b"AB\x00CD";
    return len(b);
}

def idx_nul() -> int {
    b = b"AB\x00CD";
    return b[2];
}

def idx_after_nul() -> int {
    b = b"AB\x00CD";
    return b[3];
}

def neg_index() -> int {
    b = b"AB\x00CD";
    return b[-1];
}

def slice_len() -> int {
    b = b"hello\x00world";
    s = b[6:11];
    return len(s);
}

def slice_idx() -> int {
    b = b"hello\x00world";
    s = b[6:11];
    return s[0];
}

def eq_true() -> int {
    return 1 if b"a\x00b" == b"a\x00b" else 0;
}

def eq_false_after_nul() -> int {
    return 1 if b"a\x00b" == b"a\x00c" else 0;
}

def eq_len_differs() -> int {
    return 1 if b"a\x00" == b"a\x00\x00" else 0;
}

def encode_len() -> int {
    return len("hello".encode("utf-8"));
}

def from_bytes_le() -> int {
    return int.from_bytes(b"\x00\x01", "little");
}

def from_bytes_be() -> int {
    return int.from_bytes(b"\x00\x01", "big");
}

def to_bytes_roundtrip() -> int {
    n = 258;
    e = n.to_bytes(2, "little");
    return int.from_bytes(e, "little");
}

def empty_len() -> int {
    b = b"";
    return len(b);
}
