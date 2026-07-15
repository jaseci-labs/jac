"""Must stay clean: `.append`/`.add` on a user type is not a container write,
so the heap-element container fence must not fire (guards against a false
positive from the method-name match). The param is `own` so the unrelated
E1401 parameter rule stays silent and this fixture isolates the fence."""
obj Box {
    has tag: int = 0;
}

obj Bag {
    has n: int = 0;

    def append(b: own Box) {
        self.n += b.tag;
    }
}

def run -> int {
    bag = Bag();
    bag.append(Box(tag=5));
    return bag.n;
}

with entry {
    print(run());
}
