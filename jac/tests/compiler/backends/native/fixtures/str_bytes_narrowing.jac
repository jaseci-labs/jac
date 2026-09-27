"""Methods called on a `str | bytes` value narrowed by `isinstance`."""

def text_of(v: str | bytes) -> str {
    if isinstance(v, str) {
        return "s:" + v.upper();
    }
    return "b:" + v.decode("utf-8");
}

def size_of(v: str | bytes | None) -> int {
    if v is None {
        return -1;
    }
    if isinstance(v, bytes) {
        return len(v) * 10;
    }
    return len(v);
}

def direct(v: str | bytes) -> str {
    if not isinstance(v, str) {
        return v.decode("utf-8");
    }
    return v;
}

with entry {
    print(text_of("abc"), text_of(b"xy"));
    print(size_of("abcd"), size_of(b"ab"), size_of(None));
    print(direct(b"zz"), direct("w"));
}
