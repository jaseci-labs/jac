"""Must fence (E1406): an owned heap object used as a dict key. The key is
stored in the container just like a value, so it must be fenced too."""
obj Box {
    has tag: int = 0;
}

def run -> int {
    d = {};
    d[Box(tag=1)] = 1;
    return len(d);
}

with entry {
    print(run());
}
