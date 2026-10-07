"""Tuples read back out of a list through enumerate and zip."""
obj Node {
    has v: int = 0;
}

obj Member {
    has name: str,
        ordinal: int;
}

def build(names: list[str], with_values: bool) -> list[Member] {
    raw: list[tuple[(str, (Node | None))]] = [];
    for n in names {
        raw.append((n, Node(v=1) if with_values else None));
    }
    vals: list[(str | int | None)] = [];
    for i in range(len(raw)) {
        vals.append(i + 1);
    }
    out: list[Member] = [];
    for (ordinal, member) in enumerate(raw) {
        mname: str = member[0];
        mval = vals[ordinal];
        out.append(Member(name=mname, ordinal=ordinal + (mval if isinstance(mval, int) else 0)));
    }
    return out;
}

with entry {
    a = build(["WORK", "PERSONAL", "SHOPPING", "HEALTH", "FITNESS", "OTHER"], False);
    b = build(["PIECE", "LB", "OZ", "CUP", "TBSP", "TSP", "BUNCH"], False);
    c = build(["X", "Y"], True);
    print(len(a), a[0].name, len(b), b[6].name, c[1].name);
    pairs: list[tuple[(str, int)]] = [("p", 1), ("q", 2)];
    joined = "";
    tags: list[str] = ["x", "y"];
    for (pair, tag) in zip(pairs, tags) {
        joined = joined + pair[0] + tag;
    }
    print(joined);
}
