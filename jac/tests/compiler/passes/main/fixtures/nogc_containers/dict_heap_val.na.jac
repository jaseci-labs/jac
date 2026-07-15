"""Must fence (E1406): index-assigning an owned heap object as a dict value."""
obj Box {
    has tag: int = 0;
}

def run -> int {
    d = {};
    d[1] = Box(tag=1);
    return len(d);
}

with entry {
    print(run());
}
