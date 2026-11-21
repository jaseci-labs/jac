node Base {
    has v: int = 0;
}

node Expr(Base) {}

node Pair(Base) {
    has key: str = "";
}

def obj_keys_same_type -> int {
    d: dict[Pair, int] = {};
    a = Pair(key="a");
    b = Pair(key="b");
    d[a] = 1;
    d[b] = 2;
    return len(d) * 10 + d[a];
}

def union_keys -> int {
    d: dict[Expr | Pair, int] = {};
    a = Pair(key="a");
    b = Pair(key="b");
    c = Expr();
    d[a] = 1;
    d[b] = 2;
    d[c] = 3;
    return len(d) * 100 + d[a] * 10 + d[b];
}

def union_keys_optional_values -> int {
    d: dict[Expr | Pair, Base | None] = {};
    a = Pair(key="a");
    b = Pair(key="b");
    d[a] = a;
    d[b] = b;
    n = 0;
    for (k, v) in d.items() {
        if k is v {
            n += 1;
        }
    }
    return len(d) * 10 + n;
}

def equal_field_keys -> int {
    d: dict[Pair, int] = {};
    a = Pair(key="a");
    b = Pair(key="a");
    d[a] = 1;
    d[b] = 2;
    return len(d);
}

def union_set -> int {
    s: set[Expr | Pair] = set();
    a = Pair(key="a");
    b = Pair(key="b");
    s.add(a);
    s.add(b);
    s.add(a);
    return len(s) * 10 + (1 if b in s else 0);
}

def union_keys_filled(items: list[Pair]) -> dict[Expr | Pair, int] {
    d: dict[Expr | Pair, int] = {};
    for (i, it) in enumerate(items) {
        d[it] = i;
    }
    return d;
}

def union_keys_returned -> int {
    d = union_keys_filled([Pair(key="x"), Pair(key="y"), Pair(key="z")]);
    total = 0;
    for (k, v) in d.items() {
        total += v;
    }
    return len(d) * 10 + total;
}

def str_keys_still_by_value -> int {
    d: dict[str, int] = {};
    k1 = "ab";
    k2 = "a" + "b";
    d[k1] = 1;
    d[k2] = 2;
    return len(d) * 10 + d["ab"];
}
