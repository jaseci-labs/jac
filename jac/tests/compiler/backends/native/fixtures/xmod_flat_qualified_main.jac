import xmod_flat_base;

obj QualTree(xmod_flat_base.FlatSource) {
    def trace(x: int) -> int {
        return x + 7;
    }
}

with entry {
    tree = QualTree();
    print(f"spot={tree.spot(1)}");
}
