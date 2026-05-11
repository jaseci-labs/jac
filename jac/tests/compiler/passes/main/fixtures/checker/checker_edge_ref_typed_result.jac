# Issue #5885 gap 6: edge-ref expression types must propagate parametric
# element type from EdgeOpRef. `[edge ... ->:T:-> ...]` previously
# degraded to `list[<Any>]`, forcing casts and flooding downstream
# assignments with E1001 noise. Typed forms now resolve to `list[T]`.

node Place {
    has name: str = "x";
}

edge MyEdge {
    has weight: int = 1;
}

edge OtherEdge {
    has tag: str = "t";
}

with entry {
    a: Place = Place();
    b: Place = Place();
    a +>: MyEdge :+> b;

    # Typed-edge form on edges_only must yield list[MyEdge].
    edges_typed: list[MyEdge] = [edge a ->:MyEdge:-> b];          # Ok

    # Wrong typed-edge result element type — must error: the RHS is
    # list[MyEdge], not list[OtherEdge].
    bad_edges: list[OtherEdge] = [edge a ->:MyEdge:-> b];         # Error
}
