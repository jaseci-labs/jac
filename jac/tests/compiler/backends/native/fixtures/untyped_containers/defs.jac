"""Fixture: globals annotated with an unparameterized frozenset."""

enum Tok { A = "a", B = "b" }

glob OPS: frozenset = frozenset({Tok.A}),
     NAMES: frozenset = frozenset({"x", "y"});

def is_op(t: Tok) -> bool {
    return t in OPS;
}

def is_name(s: str) -> bool {
    return s in NAMES;
}
