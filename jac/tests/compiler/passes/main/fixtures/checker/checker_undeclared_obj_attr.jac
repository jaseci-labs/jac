"""Test fixture for W2080: undeclared obj attribute assigned in init/postinit.

obj/node/edge/walker types should declare instance attributes with 'has'.
Annotated self-assignments in init/postinit are resolved for type checking
but produce a W2080 warning guiding the user to add a 'has' declaration.
"""

# Case 1: obj with annotated self-assignment in init — should warn W2080
obj Foo {
    has x: int = 5;

    def init(val: str) {
        self.y: str = val;        # <-- W2080: should be 'has y: str'
    }
}

# Case 2: obj with annotated self-assignment in postinit — should warn W2080
obj Bar {
    has name: str = "bar";

    def postinit {
        self.count: int = 0;      # <-- W2080: should be 'has count: int'
        self.label: str = "x";    # <-- W2080: should be 'has label: str'
    }
}

# Case 3: Attribute should resolve despite warning (no cascading E1030)
def use_attrs() {
    f = Foo(val="hello");
    print(f.x);                   # <-- OK: declared has field
    print(f.y);                   # <-- OK: resolved from init (with W2080)

    b = Bar();
    print(b.name);                # <-- OK: declared has field
    print(b.count);               # <-- OK: resolved from postinit (with W2080)
    print(b.label);               # <-- OK: resolved from postinit (with W2080)
}

# Case 4: node with annotated self-assignment — should warn W2080
node MyNode {
    has data: int = 0;

    def postinit {
        self.cached: str = "";    # <-- W2080: should be 'has cached: str'
    }
}

# Case 5: class (Python-style) with self-assignment — no warning (allowed)
class PyStyle {
    def init(v: int) {
        self.v: int = v;          # <-- OK for class: no W2080
    }
}

# Case 6: Unannotated self-assignment on obj — NOT resolved, should produce E1030
obj Baz {
    def init() {
        self.secret = 42;         # <-- No annotation, not resolved
    }
}

def use_baz() {
    z = Baz();
    print(z.secret);              # <-- E1030: has no attribute 'secret'
}
