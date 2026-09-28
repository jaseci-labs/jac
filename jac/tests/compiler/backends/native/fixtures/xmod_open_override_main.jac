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

with entry {
    tree = TreeSource();
    print(f"spot={tree.spot(1)}");
    held: OpenSource = tree;
    print(f"held={held.spot(2)}");
    extended = Extended();
    print(f"flat={extended.spot(3)} {extended.label()}");
}
