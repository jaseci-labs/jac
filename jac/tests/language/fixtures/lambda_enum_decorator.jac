"""Multi-statement lambda passed as an enum decorator argument.

Enum decorators are lowered after the enum body during codegen; hoisted lambda
defs must be emitted into the enclosing scope before the decorated ``ClassDef``.
"""

def tag(g: type) -> type {
    return lambda (cls: type) -> type { cls };
}

@tag(
    lambda (x: int) -> int {
        a = x + 1;
        a * 2
    }
)
enum Status: int {
    OK = 200,
    ERR = 500
}

with entry {
    print(Status.OK);
    print(Status.ERR);
}
