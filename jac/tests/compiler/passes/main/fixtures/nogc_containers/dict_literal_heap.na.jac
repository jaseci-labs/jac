"""Must fence (E1406): dict literal with an owned heap value."""
obj Box {
    has tag: int = 0;
}

def run -> int {
    d = {1: Box(tag=1)};
    return len(d);
}

with entry {
    print(run());
}
