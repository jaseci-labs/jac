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

def concat_len() -> int {
    c = b"x" + b"y";
    return len(c);
}

def concat_embedded_nul_len() -> int {
    c = b"a\x00" + b"\x00b";
    return len(c);
}

def concat_idx() -> int {
    c = b"AB" + b"CD";
    return c[2];
}

def ctor_len() -> int {
    d = bytes([65, 0, 66]);
    return len(d);
}

def ctor_idx_after_nul() -> int {
    d = bytes([65, 0, 66]);
    return d[2];
}

def bytearray_ctor_len() -> int {
    d = bytearray([65, 0, 66]);
    return len(d);
}

# ─── #6749: operations the i8*→jacbytes* migration (#6727) left behind ───
# Each mirrors a `bytes` op that still assumed the old NUL-terminated i8*.
# Every embedded-NUL case is the one a strlen/strstr/strcmp path gets wrong.

# 1. repeat: b * n
def repeat_len() -> int { return len(b"ab" * 3); }
def repeat_idx() -> int { r = b"ab" * 3; return r[5]; }
def repeat_nul_len() -> int { return len(b"\x00x" * 3); }
def repeat_nul_idx() -> int { r = b"\x00x" * 3; return r[2]; }
def repeat_zero() -> int { return len(b"ab" * 0); }

# 2. membership: x in b  (length-aware — must match past an embedded NUL)
def in_true() -> int { return 1 if b"bc" in b"abcd" else 0; }
def in_false() -> int { return 1 if b"xy" in b"abcd" else 0; }
def in_nul() -> int { return 1 if b"\x00c" in b"a\x00cd" else 0; }
def not_in_true() -> int { return 1 if b"xy" not in b"abcd" else 0; }
def in_empty() -> int { return 1 if b"" in b"abc" else 0; }

# 3. iteration: for x in b  (yields the int byte values); also the iterator
#    protocol via iter() (the _make_iter_from_value path)
def iter_sum() -> int { s = 0; for x in b"abc" { s += x; } return s; }
def iter_count_nul() -> int { c = 0; for x in b"a\x00b" { c += 1; } return c; }
def iter_sum_nul() -> int { s = 0; for x in b"a\x00b" { s += x; } return s; }
def iter_protocol_sum() -> int { s = 0; for x in iter(b"abc") { s += x; } return s; }

# 4. truthiness: `if b` and bool(b)  (empty is falsy; a lone NUL is truthy)
def truthy_empty() -> int { return 1 if b"" else 0; }
def truthy_nonempty() -> int { return 1 if b"x" else 0; }
def truthy_nul() -> int { return 1 if b"\x00" else 0; }
def bool_empty() -> int { return 1 if bool(b"") else 0; }
def bool_nonempty() -> int { return 1 if bool(b"x") else 0; }

# 5. repr: str(b)  (exact CPython b'...' form, compared in-language so the
#    result need not cross the JIT boundary)
def repr_abc_ok() -> int { return 1 if str(b"abc") == "b'abc'" else 0; }
def repr_nul_ok() -> int { return 1 if str(b"a\x00b") == "b'a\\x00b'" else 0; }
def repr_empty_ok() -> int { return 1 if str(b"") == "b''" else 0; }
def repr_quote_ok() -> int { return 1 if str(bytes([97, 39, 98])) == "b\"a'b\"" else 0; }
def repr_special_ok() -> int { return 1 if str(b"a\tb\n") == "b'a\\tb\\n'" else 0; }
def repr_backslash_ok() -> int { return 1 if str(b"a\\b") == "b'a\\\\b'" else 0; }
def repr_hi_ok() -> int { return 1 if str(b"a\xff\x01z") == "b'a\\xff\\x01z'" else 0; }

# 6. dict key: {b: v}  (length-aware key compare — distinguishes keys that
#    differ only by an embedded NUL or by length)
def dict_get() -> int { d = {b"k": 7}; return d[b"k"]; }
def dict_nul() -> int { d = {b"a\x00b": 5}; return d[b"a\x00b"]; }
def dict_distinct_len() -> int { d = {b"a\x00": 1, b"a\x00\x00": 2}; return d[b"a\x00\x00"]; }
def dict_distinct_len2() -> int { d = {b"a\x00": 1, b"a\x00\x00": 2}; return d[b"a\x00"]; }

# 7. ordering: b < b, > , <= , >=  (lexicographic, unsigned bytes)
def lt_true() -> int { return 1 if b"a" < b"b" else 0; }
def lt_false() -> int { return 1 if b"b" < b"a" else 0; }
def lt_prefix() -> int { return 1 if b"ab" < b"abc" else 0; }
def gt_true() -> int { return 1 if b"b" > b"a" else 0; }
def lte_eq() -> int { return 1 if b"ab" <= b"ab" else 0; }
def gte_eq() -> int { return 1 if b"ab" >= b"ab" else 0; }
def cmp_nul() -> int { return 1 if b"a\x00" < b"a\x00b" else 0; }
def cmp_hi() -> int { return 1 if b"\xff" > b"\x01" else 0; }

# ─── #6751: comparing (bytes | None) to bytes must null-guard, not deref ───
# A None-valued `bytes | None` is a null jacbytes*; == / != must follow CPython
# identity semantics (equal iff both None) instead of loading through null
# (which segfaulted for a branchy union and silently vanished for a const-None
# once the optimizer dropped the null-deref UB).
def _maybe_bytes(h: bool) -> bytes | None { if h { return b"AB"; } return None; }
def _none_bytes() -> bytes | None { return None; }

def none_eq_bytes() -> int { z = _maybe_bytes(False); return 1 if z == b"AB" else 0; }
def bytes_eq_none() -> int { z = _maybe_bytes(False); return 1 if b"AB" == z else 0; }
def none_ne_bytes() -> int { z = _maybe_bytes(False); return 1 if z != b"AB" else 0; }
def some_eq_bytes() -> int { z = _maybe_bytes(True); return 1 if z == b"AB" else 0; }
def some_eq_diff() -> int { z = _maybe_bytes(True); return 1 if z == b"XY" else 0; }
def cnone_eq_bytes() -> int { z = _none_bytes(); return 1 if z == b"AB" else 0; }
def cnone_ne_bytes() -> int { z = _none_bytes(); return 1 if z != b"AB" else 0; }
def both_none_eq() -> int { a = _none_bytes(); b = _none_bytes(); return 1 if a == b else 0; }
def both_none_ne() -> int { a = _none_bytes(); b = _none_bytes(); return 1 if a != b else 0; }

# Ordering a None operand raises TypeError (CPython parity) rather than
# dereferencing null; returns the count of operators that raised (expect 4).
def none_ordering_raises() -> int {
    z = _none_bytes();
    c = 0;
    try { if z < b"AB" { c += 0; } } except Exception as e { c += 1; }
    try { if z > b"AB" { c += 0; } } except Exception as e { c += 1; }
    try { if z <= b"AB" { c += 0; } } except Exception as e { c += 1; }
    try { if z >= b"AB" { c += 0; } } except Exception as e { c += 1; }
    return c;
}
