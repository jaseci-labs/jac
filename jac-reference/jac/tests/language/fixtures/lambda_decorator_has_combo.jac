"""A class whose decorator AND `has`-default are both multi-statement lambdas.

Each must hoist to the enclosing module scope (before the class def) so the
decorator -- evaluated at module scope at definition time -- and the `has`
factory -- evaluated in the class body -- both resolve. Single-underscore
helper names avoid Python private-name mangling inside the class body.
"""

def deco(marker: object) -> type {
    return lambda (c: type) -> type { c };
}

@deco(
    lambda (x: int) -> int {
        a = x + 1;
        a * 2
    }
)
obj A {
    has cb: object = lambda (y: int) -> int {
        b = y * 2;
        b + 1
    };
}

with entry {
    inst = A();
    print(inst.cb(5));
}
