"""A3 fixture -- foreign-typed fields lower to opaque, null native slots.

`py_ctx` has a type the native backend does not model (`ast3.AST | None`).
The capability gate must accept the declaration, lower the slot to a nullable
opaque pointer (null at native construction), and reject only native code that
actually dereferences it. The native path here touches only native fields.
"""
import ast as ast3;

obj AstCarrier {
    has name: str,
        py_ctx: ast3.AST | None = None;     # foreign type -> opaque/null native slot

    def label -> str { return self.name; }  # native path touches only native fields
    def name_len -> int { return len(self.name); }
}

def make_label() -> str {
    c = AstCarrier(name="store");
    return c.label();
}

def make_name_len() -> int {
    c = AstCarrier(name="store");
    return c.name_len();
}

with entry {
    c = AstCarrier(name="store");
    print(c.label());                       # expect: store  (py_ctx stays null)
}
