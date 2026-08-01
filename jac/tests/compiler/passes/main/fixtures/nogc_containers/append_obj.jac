"""Must fence (E1406): appending an owned heap object into a list."""
obj Box {
    has tag: int = 0;
}

def run -> int {
    xs = [];
    xs.append(Box(tag=1));
    return len(xs);
}

with entry {
    print(run());
}
