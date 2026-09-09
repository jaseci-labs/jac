"""Must fence (E1406): a borrowed heap object stored as a dict value would alias storage the dict must not free."""
obj Box {
    has tag: int = 0;
}
def run(b: &Box) -> int {
    d: dict[int, own Box] = {};
    d[1] = b;
    return len(d);
}
with entry {
    print(run(&Box(tag=1)));
}
