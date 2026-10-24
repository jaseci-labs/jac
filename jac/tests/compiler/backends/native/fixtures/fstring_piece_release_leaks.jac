"""F-string pieces whose text is already owned: optionals, `!r` and format specs.

Each piece below is released exactly once: an optional string that the
caller still holds, a `!r` of a slice, and a slice formatted with a spec. A
debug build reports a double free as it happens and every leaked object in
the live-object dump at exit.
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
    __rc_collect_cycles();
    __rc_debug_enable();
}
