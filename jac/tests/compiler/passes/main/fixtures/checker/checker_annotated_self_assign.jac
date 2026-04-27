"""Test fixture for annotated self-assignment type checking.

Previously, annotated self-assignments like `self.x: int = val` produced
false E1001 "Cannot assign int to int" because the type annotation resolved
to the class type (instantiable) rather than the instance type.
"""

# Case 1: class with annotated self-assignment — no false E1001
class Foo {
    def init(v: int) {
        self.v: int = v;           # <-- Was E1001 "Cannot assign int to int"
        self.name: str = "hello";  # <-- Was E1001 "Cannot assign str to str"
    }
}

# Case 2: obj with annotated self-assignment on declared field — no false E1001
obj Bar {
    has x: int by postinit;

    def postinit {
        self.x = 0;
    }

    def init(v: int) {
        self.x: int = v;           # <-- Was E1001 "Cannot assign int to int"
    }
}

# Case 3: Legitimate type mismatch should still error
class Baz {
    def init() {
        self.x: int = "wrong";     # <-- Real E1001: str to int
    }
}

# Case 4: Local annotated assignments should continue to work
def local_test() {
    x: int = 5;                    # <-- OK
    y: str = "hello";              # <-- OK
    z: int = "bad";                # <-- Real E1001: str to int
}
