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

def cp_rev_huge(s: str) -> str {
    return "" + s[::-1000000000000];
}

def cp_fwd_huge(s: str) -> str {
    return "" + s[::1000000000000];
}

def cp_rev_huge_from(s: str, a: int) -> str {
    return "" + s[a::-1000000000000];
}

def cp_strip(s: str, c: str) -> str {
    return s.strip(c);
}

def cp_lstrip(s: str, c: str) -> str {
    return s.lstrip(c);
}

def cp_rstrip(s: str, c: str) -> str {
    return s.rstrip(c);
}

def cp_fprec(s: str) -> str {
    return f"[{s:.2}]";
}

def cp_fwidth(s: str) -> str {
    return f"[{s:3}]";
}

def cp_fboth(s: str) -> str {
    return f"[{s:>5.2}]";
}

def cp_fright(s: str) -> str {
    return f"[{s:>4}]";
}

# `v` is a descriptor view into the argument, so these reach the view paths.
def cp_view_len(s: str, a: int) -> int {
    v = s[a:];
    return len(v);
}

def cp_view_at(s: str, a: int, i: int) -> str {
    v = s[a:];
    return v[i];
}

def cp_view_iter(s: str, a: int) -> str {
    v = s[a:];
    r = "";
    for ch in v {
        r = r + ch + "|";
    }
    return r;
}

def cp_view_slice(s: str, a: int, b: int, c: int) -> str {
    v = s[a:];
    return "" + v[b:c];
}

def cp_view_rev(s: str, a: int) -> str {
    v = s[a:];
    return "" + v[::-1];
}

# Natively built roots, so the header's ASCII flag is the one the ops read.
def cp_owned_view_len(s: str, a: int) -> int {
    o = "<" + s;
    v = o[a:];
    return len(v);
}

def cp_owned_at(s: str, i: int) -> str {
    o = s + ">";
    return o[i];
}

# Views into static literals, whose prefix is only 16 bytes.
def cp_static_views -> str {
    t = "héllo wörld";
    v = t[3:];
    w = "abcdef"[1:];
    return f"{len(v)}|{v[0]}|{v[-1]}|{len(w)}|{w[2]}|" + v[1:4] + "|" + w[::-1];
}

# Concat stamps its result from both operands' ASCII flags instead of rescanning.
def cp_concat_flags -> str {
    a = "ab";
    e = "é";
    x = a + a;
    y = a + e;
    z = e + a;
    w = y + a;
    return f"{len(x)}|{len(y)}|{len(z)}|{len(w)}|{y[2]}|{z[0]}|{w[-1]}|" + x[::-1];
}

def cp_concat_len(s: str, t: str) -> int {
    u = s + t;
    return len(u);
}

def cp_concat_at(s: str, t: str, i: int) -> str {
    u = s + t;
    return u[i];
}
