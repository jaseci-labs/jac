"""Unmarked locals under enforcement infer their state (#8984 rule 1), and the
inferred states must not change behavior. This prints from literal-, concat-,
projection- and conditional-bound locals, mutates through an inferred mutable
element borrow, reads through an explicit one, copies a borrowed str into an owned list with `own`, appends a
str method result taken on a borrowed element, rebinds a literal-initialized
accumulator, and lets drop hooks show the lifetimes."""
obj Cfg {
    has name: str = "svc",
        tags: list[int] = [1, 2];

    def drop {
        print("drop cfg");
    }
}

obj Item {
    has id: int = 0,
        name: str = "";

    def drop {
        print(f"drop item {self.id}");
    }
}

def summarize(c: &Cfg, flag: bool) -> int {
    lit = "a,b,c";
    cat = "a" + str(1);
    tern = "yes" if flag else "no";
    n = c.name;
    t = c.tags;
    print(f"{lit} {cat} {tern} {n} {len(t)}");
    return len(lit) + len(cat) + len(tern) + len(n) + len(t);
}

def rename_first(xs: &mut list[Item]) -> None {
    it = xs[0];
    it.name = it.name + "!";
}

def words(line: &str) -> int {
    parts = line.split(",");
    out: own list[str] = [];
    for p in &parts {
        out.append(own p);
        out.append(p.upper());
    }
    print(",".join(out));
    return len(out);
}

def accumulate(n: int) -> own str {
    s = "";
    for i in range(n) {
        s = s + str(i);
    }
    return s;
}

def run_all -> None {
    c: own Cfg = Cfg();
    xs: own list[own Item] = [Item(id=1, name="a"), Item(id=2, name="b")];
    print(summarize(&c, True));
    rename_first(&mut xs);
    print(xs[0].name);
    second: &Item = &xs[1];
    print(second.name);
    print(words(&"x,y"));
    print(accumulate(3));
}

with entry {
    run_all();
}
