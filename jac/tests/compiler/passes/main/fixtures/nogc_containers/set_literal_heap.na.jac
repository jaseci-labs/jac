"""Must fence (E1406): set literal with an owned heap element."""
obj Box {
    has tag: int = 0;
}

def run -> int {
    s = {Box(tag=1)};
    return len(s);
}

with entry {
    print(run());
}
