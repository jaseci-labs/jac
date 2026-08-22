"""Must fence (E1406): appending a named owned archetype binding into a list."""

obj Box {
    has tag: int = 0;
}

def run -> int {
    xs = [];
    b: own Box = Box(tag=1);
    xs.append(b);
    return len(xs);
}

with entry {
    print(run());
}
