"""`a or b` and `a and b` over a union and an object return an operand."""
import from typing { cast }

obj Node {
    has name: str = "";
}

obj Expr(Node) {}

obj SliceInfo {
    has start: int = 0;
}

obj Gen {
    has es: Node | Sequence[Node] | SliceInfo | None = None;
}

def first_or(g: Gen, fallback: Expr) -> str {
    picked = cast(Expr, g.es or fallback);
    return picked.name;
}

def both_and(g: Gen, fallback: Expr) -> str {
    picked = g.es and fallback;
    if picked is None {
        return "none";
    }
    return cast(Expr, picked).name;
}

with entry {
    held = Gen(es=Expr(name="held"));
    empty = Gen();
    fallback = Expr(name="fallback");
    for _ in range(3) {
        print(first_or(held, fallback), first_or(empty, fallback));
        print(both_and(held, fallback), both_and(empty, fallback));
    }
}
