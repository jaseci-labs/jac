"""`obj Foo; obj Foo { ... }` is a hard error (E0077).

Jac's separation model is decl/impl, not decl/decl. A second `obj` block
when one already exists in the same scope is a duplicate declaration,
not a forward declaration. (Module-wide symbol resolution means forward
declarations are unnecessary; mutual references across types just work.)

Each pair below should emit exactly one E0077 against the second `obj`
header. The legitimate decl/impl pattern (`obj Foo;` + `impl Foo {...}`)
stays valid and is covered separately.
"""

# Plain forward-decl + body -- E0077 on line 17
obj Piece;

obj Piece {
    has color: int = 0;
}

# Forward-decl + body, with inheritance on the body -- E0077 on line 27
obj Animal;

obj Animal {
    has name: str = "x";
}

obj Dog(Animal) {
    has bark_count: int = 0;
}
