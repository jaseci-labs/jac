"""Test that direct object.__new__(cls) calls are type-checked correctly.

In Python, __new__ is a staticmethod — cls is NOT auto-bound when accessed
on a class. So object.__new__(SomeClass) should be valid.
"""

class Anchor {
    def __init__(self: Anchor, id: int) -> None {
        self.id = id;
    }

    def make_stub(self: Anchor) -> Anchor {
        # Direct __new__ call — cls is passed explicitly (staticmethod semantics)
        unloaded = object.__new__(self.__class__);  # <-- Ok
        unloaded.id = self.id;  # <-- Ok (dynamic attr, not checked here)
        return unloaded;
    }
}

class Sub(Anchor) {
    def __new__(cls: type, id: int) -> Sub {
        inst = object.__new__(cls);  # <-- Ok
        return inst;
    }
}

with entry {
    a = Anchor(1);
    s = a.make_stub();

    # Direct call with too many args should still error
    bad = object.__new__(int, "extra", "args");  # <-- Error: too many args
}
