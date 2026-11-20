"""A fresh archetype index-assigned as a dict value moves into the dict (#8984 rule 3)."""
obj Box {
    has tag: int = 0;
}

def run -> int {
    d: dict[int, own Box] = {};
    d[1] = Box(tag=1);
    return len(d);
}

with entry {
    print(run());
}
