"""Iterating a union of one container class at two element types."""

obj Lit {
    has text: str = "";
}

obj Fmt {
    has parts: list[str] = [];
}

def pieces(many: list[Lit | Fmt], one: Lit, flag: bool) -> list[str] {
    xs = many if flag else [one];
    out: list[str] = [];
    for x in xs {
        site: Lit | Fmt = x;
        out.append(type(site).__name__);
    }
    first: Lit | Fmt = xs[0];
    out.append(type(first).__name__);
    wrong: int = xs[0];
    for y in xs {
        bad: int = y;
    }
    return out;
}
