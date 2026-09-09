"""Must fail under enforcement: a field read off a shared borrow infers a
shared borrow of the root, so mutating through it is rejected."""
obj Cfg {
    has tags: list[int] = [];
}

def grow(c: &Cfg) -> int {
    t = c.tags;
    t.append(1);
    return len(t);
}

with entry {
    c: own Cfg = Cfg();
    print(grow(&c));
}
