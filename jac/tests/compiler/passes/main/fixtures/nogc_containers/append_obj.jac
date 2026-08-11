"""OK since #7857 Phase B: a fresh archetype moves into a list append."""
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
