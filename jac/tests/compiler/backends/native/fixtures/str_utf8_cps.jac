"""UTF-8 codepoint semantics: str ops must count codepoints, not bytes (#9423)."""

def cp_len(s: str) -> int {
    return len(s);
}

def cp_at(s: str, i: int) -> str {
    return s[i];
}

def cp_ord_at(s: str, i: int) -> int {
    return ord(s[i]);
}

def cp_slice(s: str, a: int, b: int) -> str {
    # Concat materializes descriptor views into a NUL-terminated buffer so
    # the FFI boundary sees a real C string.
    return "" + s[a:b];
}

def cp_slice_step(s: str, a: int, b: int, k: int) -> str {
    return "" + s[a:b:k];
}

def cp_find(s: str, n: str, st: int, en: int) -> int {
    return s.find(n, st, en);
}

def cp_rfind(s: str, n: str, st: int, en: int) -> int {
    return s.rfind(n, st, en);
}

def cp_count(s: str, n: str, st: int, en: int) -> int {
    return s.count(n, st, en);
}

def cp_startswith(s: str, p: str, st: int, en: int) -> bool {
    return s.startswith(p, st, en);
}

def cp_endswith(s: str, p: str, st: int, en: int) -> bool {
    return s.endswith(p, st, en);
}

def cp_iter(s: str) -> str {
    r = "";
    for ch in s {
        r = r + ch + "|";
    }
    return r;
}

def cp_reverse(s: str) -> str {
    return s[::-1];
}

def cp_ljust(s: str, w: int) -> str {
    return s.ljust(w);
}

def cp_rjust(s: str, w: int) -> str {
    return s.rjust(w);
}

def cp_center(s: str, w: int) -> str {
    return s.center(w);
}

def cp_zfill(s: str, w: int) -> str {
    return s.zfill(w);
}

def cp_expandtabs(s: str, t: int) -> str {
    return s.expandtabs(t);
}

def cp_isascii(s: str) -> bool {
    return s.isascii();
}
