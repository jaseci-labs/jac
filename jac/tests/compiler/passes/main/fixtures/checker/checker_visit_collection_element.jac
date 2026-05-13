"""Visit target validation.

`visit` accepts (per `JacWalker.visit` in jac0core/runtime.jac):
    Node | Edge | ObjectSpatialPath
    | list/tuple/set/frozenset of (Node | Edge)

The element type of a parameterized collection must itself be a valid
visit target. Unparameterized collections and Any/Unknown are accepted.
"""

node Place { has name: str; }
node City { has population: int; }

edge Friend { has since: int = 0; }
edge Road { has length: int = 0; }

obj NotANode { has v: int; }

walker Bad {
    can on_entry with entry {
        # Element type is a non-node, non-edge literal — should error.
        visit ["a", "b"];                         # E1094
        visit [1, 2, 3];                          # E1094
        visit (NotANode(1), NotANode(2));         # E1094

        # Typed local of non-node element — should error.
        xs: list[str] = ["a"];
        visit xs;                                 # E1094

        ys: set[int] = {1, 2};
        visit ys;                                 # E1094

        zs: frozenset[str] = frozenset(["a"]);
        visit zs;                                 # E1094

        nas: list[NotANode] = [NotANode(1)];
        visit nas;                                # E1094

        # Single non-archetype value — should error.
        v: NotANode = NotANode(1);
        visit v;                                  # E1094

        # Union containing a non-archetype member — strict, every member
        # must be valid.
        ms: list[Place | str] = [Place(name="a"), "b"];
        visit ms;                                 # E1094
    }
}

walker Good {
    can on_entry with entry {
        # Single node — valid.
        p: Place = Place(name="p");
        visit p;

        # Single edge — valid (runtime accepts EdgeArchetype).
        f: Friend = Friend(since=1);
        visit f;

        # Parameterized list/tuple/set of nodes — valid.
        ps: list[Place] = [Place(name="a"), Place(name="b")];
        visit ps;

        cs: tuple[City, Place] = (City(population=1), Place(name="x"));
        visit cs;

        # Parameterized list of edges — valid.
        fs: list[Friend] = [Friend(since=1), Friend(since=2)];
        visit fs;

        # Mixed list of nodes and edges — valid.
        mix: list[Place | Friend] = [Place(name="a"), Friend(since=1)];
        visit mix;

        # Mixed list literal of nodes — valid (inferred element is union of
        # nodes).
        visit [Place(name="a"), City(population=1)];

        # Edge-ref expression — lowers to list[NodeArchetype], must be valid.
        visit [-->];
    }
}
