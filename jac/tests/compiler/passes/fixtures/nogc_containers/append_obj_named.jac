"""A named own archetype binding appended to a list moves into it (#8984 rule 3)."""

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
