"""Union writes reach a member declared on a secondary common base."""
obj Node {
    has loc: int = 0;
}

obj Expr(Node) {
    has _kind: int = 0,
        depth: int = 0;

    has kind: int { getter; setter(value: int); }
}

impl Expr.kind.getter -> int {
    return self._kind;
}

impl Expr.kind.setter(value: int) {
    self._kind = value * 10;
}

obj Token(Node) {
    has text: str = "";
}

obj AtomExpr(Expr) {}

obj NameAtom(AtomExpr) {
    has category: int = 0;
}

obj Literal(Token, AtomExpr) {}

obj Name(Token, NameAtom) {}

obj Str(Literal) {}

def stamp(parts: list[(Name | Str)]) -> int {
    total = 0;
    for (idx, part) in enumerate(parts) {
        typed: Expr = part;
        typed.kind = idx + 1;
        part.depth = idx + 100;
        part.kind = typed.kind + 1;
        total += part.kind + part.depth;
    }
    return total;
}

def probe(pick: int) -> int {
    parts: list[(Name | Str)] = [Name(text="a"), Str(text="b"), Name(text="c")];
    total = stamp(parts);
    if pick == 0 {
        return total;
    }
    return parts[pick].kind + parts[pick].depth;
}
