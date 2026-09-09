"""Must stay clean under enforcement: unmarked locals infer their state from the
right-hand side (#8984 rule 1). A string literal is `imm`, a concatenation or
call is `own`, a field or element read borrows its root (mutable when the
root allows it and the local is written through), a reborrow follows its
source, a conditional whose arms agree takes their state, and a literal that
is later rebound is `own`."""
obj Cfg {
    has name: str = "svc",
        tags: list[int] = [];
}

obj Item {
    has id: int = 0,
        name: str = "";
}

def summarize(c: &Cfg, flag: bool) -> int {
    lit = "a,b,c";
    cat = "a" + str(1);
    tern = "yes" if flag else "no";
    n = c.name;
    t = c.tags;
    m = n;
    return len(lit) + len(cat) + len(tern) + len(n) + len(t) + len(m);
}

def first_name(xs: &list[Item]) -> int {
    it = xs[0];
    nm = it.name;
    return it.id + len(nm);
}

def rename_first(xs: &mut list[Item]) -> int {
    it = xs[0];
    it.name = "z";
    return len(it.name);
}

def accumulate(n: int) -> int {
    s = "";
    for i in range(n) {
        s = s + str(i);
    }
    return len(s);
}

with entry {
    c: own Cfg = Cfg();
    xs: own list[own Item] = [Item(id=1, name="a"), Item(id=2, name="b")];
    print(
        summarize(&c, True) + first_name(&xs) + rename_first(&mut xs) + accumulate(3)
    );
}
