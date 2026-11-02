"""The flat base again, declared the split way: the class's members and each
method's body live in `impl` blocks."""
obj SplitSource;

impl SplitSource {
    has seen: int = 0;

    def trace(x: int) -> int;
    def spot(x: int) -> int;
}

impl SplitSource.trace {
    return -1;
}

impl SplitSource.spot {
    self.seen += 1;
    return self.trace(x);
}
