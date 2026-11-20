"""Scoping consequences of #8060: a block declares into the function.

A typed declaration inside a block is a declaration of a *function* local, so
its annotation still constrains the name after the block ends, and a second
typed declaration of the same name in a sibling block is a redeclaration of
the same variable rather than a fresh one. Both shapes were silently accepted
while the declaration was stranded on the block's own scope.
"""

obj A {
    has ax: int = 1;
}

obj B {
    has bx: int = 2;
}

"""The annotation still binds after the declaring block has closed."""
def outlives_its_block(c: bool) -> int {
    if c {
        z: int = 1;
        print(z);
    }
    z = "oops";
    return 0;
}

"""Sibling blocks declare one variable, not one each."""
def redeclared_in_sibling_block(c: bool) -> int {
    if c {
        v: (A | None) = A();
        print(v);
    } else {
        v: (B | None) = B();
        print(v);
    }
    return 0;
}

with entry {
    print(outlives_its_block(True) + redeclared_in_sibling_block(True));
}
