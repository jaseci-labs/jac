import from xmod_flat_base { FlatSource }

obj TreeSource(FlatSource) {
    has depth: int = 0;

    def trace(x: int) -> int {
        return x + 7;
    }

    def label -> str {
        return "tree";
    }

    def name -> str {
        return "tree";
    }
}

with entry {
    tree = TreeSource();
    print(f"spot={tree.spot(1)}");
}
