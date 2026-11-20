"""A function whose decorator arg AND body both use multi-statement lambdas.

The decorator lambda hoists to the enclosing scope (before the def, since
decorators evaluate at definition time); the body lambda hoists into the
function body. The two never steal each other's hoist.
"""

def deco(d: object) -> type {
    return lambda (c: type) -> type { c };
}

@deco(
    lambda (x: int) -> int {
        a = x + 1;
        a
    }
)
def topfn -> int {
    inner = lambda (y: int) -> int {
        b = y * 2;
        b
    };
    return inner(3);
}

with entry {
    print(topfn());
}
