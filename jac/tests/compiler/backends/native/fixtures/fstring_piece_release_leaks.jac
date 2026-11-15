"""F-string pieces whose text is already owned: optionals, `!r` and format specs.

Each piece below is released exactly once: an optional string that the
caller still holds, a `!r` of a slice, a slice formatted with a spec, and a
`!r` of a list made just for the f-string, whose repr releases it. A debug
build reports a double free as it happens and every leaked object in the
live-object dump at exit.
"""

def opt_piece(o: str | None) -> str {
    return f"[{o}]";
}

def repr_piece(w: str) -> str {
    return f"<{w[1:]!r}>";
}

def spec_piece(w: str) -> str {
    return f"|{w.upper():>12}|";
}

def pair(n: int) -> list[int] {
    return [n, n * 2];
}

def container_piece(n: int) -> str {
    return f"{[n, n + 1]!r} {pair(n)!r} {n!r}";
}

def containers -> str {
    total = 0;
    for i in range(3) {
        total += len(container_piece(i));
    }
    return f"{total} {container_piece(4)}";
}

def run -> str {
    base = "hello world";
    held: str | None = base[1:];
    total = 0;
    for i in range(3) {
        total += len(opt_piece(held)) + len(repr_piece(base)) + len(spec_piece(base));
    }
    return f"{total} {held} {opt_piece(held)} {repr_piece(base)} {spec_piece(base)}";
}

with entry {
    print(run());
    print(containers());
    __rc_collect_cycles();
    __rc_debug_enable();
}
