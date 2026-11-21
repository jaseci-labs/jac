"""A dict literal with a fresh archetype value moves it into the dict (#8984 rule 3)."""
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
