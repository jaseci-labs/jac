"""Regression fixture for method-default-params-arg-underflow.

Calling a method or free function while omitting trailing default-valued
parameters previously crashed the compiler with `list index out of range`
in builder.call.  These functions verify correct codegen.
"""

obj Adder {
    has base: int;

    def add(x: int, offset: int = 10) -> int {
        return self.base + x + offset;
    }
}

def bias(x: int, b: int = 100) -> int {
    return x + b;
}

# method call omitting the trailing default (offset = 10)
def test_method_default_omitted() -> int {
    a: Adder = Adder(base=5);
    return a.add(7);   # expected: 5 + 7 + 10 = 22
}

# free-function call omitting the trailing default (b = 100)
def test_free_fn_default_omitted() -> int {
    return bias(42);   # expected: 42 + 100 = 142
}
