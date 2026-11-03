"""Members reached through a secondary base.

A field or method declared on a base that is not the first base of a
subclass sits at a different slot in that subclass, so a read or call
through the base (or through an isinstance narrow to it) dispatches on the
object's concrete archetype, and a cast between sibling bases is checked.
"""
obj Node {
    has loc: int = 0;
}

obj Expr(Node) {
    has depth: int = 0;
}

obj Sym(Node) {
    has spec: str = "s";

    def show -> str {
        return f"spec={self.spec}";
    }
}

obj Name(Expr, Sym) {
    has value: str = "v";

    def show -> str {
        return f"name {self.value} spec={self.spec}";
    }
}

obj Tag(Sym) {
    has extra: int = 7;
}

def pick(e: Expr) -> str {
    if isinstance(e, Sym) {
        return e.spec + "|" + e.show();
    }
    return "no";
}

def as_sym(e: Expr) -> Sym {
    return e as Sym;
}

def via(s: Sym) -> str {
    return s.spec + ":" + s.show();
}

with entry {
    n = Name(spec="X", value="Y", depth=3);
    print(pick(n), pick(Expr()));
    print(via(n), via(Tag(spec="T")), via(Sym()));
    print(as_sym(n).spec);
    try {
        print(as_sym(Expr()).spec);
    } except Exception as err {
        print("refused");
    }
}
