import from xmod_flat_split_base { SplitSource }

obj SplitTree(SplitSource);

impl SplitTree {
    def trace(x: int) -> int;
}

impl SplitTree.trace {
    return x + 7;
}

with entry {
    tree = SplitTree();
    print(f"spot={tree.spot(1)}");
}
