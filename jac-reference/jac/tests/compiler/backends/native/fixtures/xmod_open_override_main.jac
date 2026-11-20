import from xmod_flat_base { FlatSource, OpenSource }

"""Adds to a flat base without overriding anything it declares."""
obj Extended(FlatSource) {
    def label -> str {
        return "extended";
    }
}

obj TreeSource(OpenSource) {
    def trace(x: int) -> int {
        return x + 7;
    }
}

"""Replaces the flat base's `spot` outright, so nothing below it inherits
the body that calls `self.trace()`."""
obj Rerouted(FlatSource) {
    def spot(x: int) -> int {
        return 100 + x;
    }
}

"""Overrides `trace` under `Rerouted`: the only `spot` it inherits is
`Rerouted.spot`, which never calls `trace`."""
obj Leaf(Rerouted) {
    def trace(x: int) -> int {
        return x + 7;
    }
}

with entry {
    tree = TreeSource();
    print(f"spot={tree.spot(1)}");
    held: OpenSource = tree;
    print(f"held={held.spot(2)}");
    extended = Extended();
    print(f"flat={extended.spot(3)} {extended.label()}");
    leaf = Leaf();
    print(f"leaf={leaf.spot(1)} {leaf.trace(1)}");
}
