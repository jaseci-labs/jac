"""Embedded-NUL round-trips for native `str` (issue #6789).

`chr()` stamps length 1 into the RC header, so a NUL byte survives
concatenation, indexing, and `len()` on the na backend exactly as on sv.
Every function returns a scalar (int) because the JIT test ABI reads
returned string payloads NUL-bounded, which would hide exactly the bytes
these functions exist to prove are there.
"""

def chain_len -> int {
    s: str = chr(65) + chr(0) + chr(66);
    return len(s);
}

def chain_mid_ord -> int {
    s: str = chr(65) + chr(0) + chr(66);
    return ord(s[1]);
}

def chain_last_ord -> int {
    s: str = chr(65) + chr(0) + chr(66);
    return ord(s[2]);
}

def nul_lit_len -> int {
    s: str = "A\x00B";
    return len(s);
}

def nul_lit_mid_ord -> int {
    s: str = "A\x00B";
    return ord(s[1]);
}

def dyn_chain_len(v: int) -> int {
    s: str = chr(65) + chr(v & 0xFF) + chr(66);
    return len(s);
}

def dyn_chain_mid_ord(v: int) -> int {
    s: str = chr(65) + chr(v & 0xFF) + chr(66);
    return ord(s[1]);
}
