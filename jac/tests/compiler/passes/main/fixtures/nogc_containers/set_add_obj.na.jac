"""Must fence (E1406): adding an owned heap object to a set."""
obj Box {
    has tag: int = 0;
}

def run -> int {
    s = set();
    s.add(Box(tag=1));
    return len(s);
}

with entry {
    print(run());
}
