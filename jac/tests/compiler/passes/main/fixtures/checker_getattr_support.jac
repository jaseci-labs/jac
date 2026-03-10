"""Test __getattr__ support in type checker."""

class StrProxy {
    def __getattr__(self: StrProxy, name: str) -> str { return ""; }
}

class AnyProxy {
    def __getattr__(self: AnyProxy, name: str) -> Any { return None; }
}

class MixedClass {
    has real_attr: int = 42;
    def __getattr__(self: MixedClass, name: str) -> str { return ""; }
}

# Class without __getattr__ - for negative test
class NoGetAttr {
    has real_attr: int = 42;
}

with entry {
    # Valid: __getattr__ returns str
    p = StrProxy();
    x: str = p.foo;

    # Valid: Any is callable
    a = AnyProxy();
    a.method("arg");

    # Valid: explicit attr keeps its type, dynamic uses __getattr__
    m = MixedClass();
    n: int = m.real_attr;
    s: str = m.dynamic_attr;

    # ERROR: __getattr__ returns str, not int
    bad: int = p.bar;  # <-- type error expected

    # Class without __getattr__ - regular attr should NOT show "dynamic attribute"
    ng = NoGetAttr();
    ng_val: int = ng.real_attr;

    # No __getattr__ - hover should NOT show "dynamic attribute"
    ng.nonexistent;
}
