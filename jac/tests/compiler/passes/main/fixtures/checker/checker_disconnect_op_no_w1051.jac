# Issue #5885 gap 9: `del` (DisconnectOp) statements used to fall through
# the connect/disconnect branch in operations.jac without setting a result
# type, so every disconnect site emitted a spurious W1051 ("Expression
# type could not be resolved"). Disconnect runs `Jac.disconnect(...)` at
# runtime which returns `bool`, so the typed result is bool — and bare
# disconnect statements should not produce any W1051 noise.

node NodeA {
    has val: int = 0;
}

node NodeB {
    has name: str = "x";
}

edge MyEdge {
    has weight: int = 0;
}

with entry {
    a: NodeA = NodeA(0);
    b: NodeB = NodeB("b");
    a +>: MyEdge :+> b;

    # Bare untyped disconnect — must not emit W1051.
    a del --> b;

    # Typed-edge disconnect — must not emit W1051.
    a del ->:MyEdge:-> b;

    # Reverse-direction disconnect — must not emit W1051.
    a del <-:MyEdge:<- b;

    # Disconnect used as a value — its type must be `bool`.
    removed: bool = a del --> b;
    print(removed);
}
