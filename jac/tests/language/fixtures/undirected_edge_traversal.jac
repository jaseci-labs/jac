"""Fixture for undirected edge traversal regression test.

Verifies that nodes connected via <+:edge:+> (typed bidirectional) or
<++> (generic bidirectional) can be traversed from both endpoints.
Prior to the fix, [b ->:friend:->] returned [] when the edge was created
as a <+:friend:+> b — only [a ->:friend:->] worked.
"""

node person {
    has name: str;
}

edge friend {}

with entry {
    a = person(name="Alice");
    b = person(name="Bob");
    c = person(name="Carol");
    d = person(name="Dave");

    # Typed bidirectional: <+:edge:+>
    a <+:friend:+> b;

    # Generic bidirectional: <++>
    c <++> d;

    # Typed: forward (source -> target, always worked)
    print([a ->:friend:->]);

    # Typed: reverse (target -> source, was broken)
    print([b ->:friend:->]);

    # Typed: with explicit target
    print([b ->:friend:-> a]);

    # Generic: forward
    print([c -->]);

    # Generic: reverse (was broken)
    print([d -->]);

    # Edge object reachable from both endpoints via [edge ...]
    edges_from_a = [edge a ->:friend:->];
    edges_from_b = [edge b ->:friend:->];
    print(len(edges_from_a));
    print(len(edges_from_b));
}
