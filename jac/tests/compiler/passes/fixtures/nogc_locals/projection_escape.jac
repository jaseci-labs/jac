"""Must fail under enforcement: a field read infers a borrow of its root, and a
borrow cannot leave the function as an owned return."""
obj Cfg {
    has name: str = "svc";
}

def steal(c: &Cfg) -> own str {
    n = c.name;
    return n;
}

with entry {
    c: own Cfg = Cfg();
    print(steal(&c));
}
