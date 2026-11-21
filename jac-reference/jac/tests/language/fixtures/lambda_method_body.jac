"""A multi-statement lambda returned from a method body.

The helper hoists into the method's own scope (top of the method body) and uses
a single-underscore name so Python class private-name mangling does not rewrite
the reference from inside the class body.
"""

obj A {
    def m -> object {
        return lambda (x: int) -> int {
            a = x + 1;
            a
        };
    }
}

with entry {
    print(A().m()(10));
}
