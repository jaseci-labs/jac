"""isinstance tells str from bytes whatever representation the union has."""

obj Tok {
    has raw: str = "",
        data: bytes = b"",
        use_bytes: bool = False;

    has lit: str | bytes { getter; }
}

impl Tok.lit.getter -> str | bytes {
    if self.use_bytes {
        return self.data;
    }
    return self.raw;
}

def narrow(t: Tok) -> str {
    v = t.lit;
    if isinstance(v, str) {
        return "str:" + v;
    }
    if isinstance(v, bytes) {
        return f"bytes:{len(v)}";
    }
    return "other";
}

def wide(v: int | str | bytes | float | bool | None) -> str {
    if isinstance(v, str) {
        return "str";
    }
    if isinstance(v, bytes) {
        return "bytes";
    }
    return "other";
}

def pick(flag: bool) -> str | bytes {
    return b"ab" + b"c" if flag else "x" + "yz";
}

def literal(flag: bool) -> str | bytes {
    return b"lit" if flag else "lit";
}

def main {
    print(narrow(Tok(raw="hi")), narrow(Tok(data=b"xyz", use_bytes=True)));
    print(wide("s"), wide(b"b"), wide(3), wide(None));
    for f in [True, False] {
        v = pick(f);
        w = literal(f);
        print(
            isinstance(v, str),
            isinstance(v, bytes),
            isinstance(w, str),
            isinstance(w, bytes)
        );
    }
}

with entry {
    main();
}
