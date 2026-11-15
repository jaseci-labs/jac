"""`sort(key=)` and `sorted(key=)`: each key once, stable, forward and reversed.

Keys of every kind the sort takes: ints with many ties (stability shows in
the order of equal keys), owned strings made by the key, floats, tuples and
an object's field; `reverse=True` keeps equal keys in their original order;
empty and one-element lists.
"""

obj Item {
    has name: str = "",
        rank: int = 0;
}

def run -> list[str] {
    out: list[str] = [];
    xs: list[int] = [(i * 7919) % 1009 for i in range(300)];
    by_mod = sorted(xs, key=lambda (v: int) -> int { return v % 7; });
    out.append(str(by_mod[:12]));
    out.append(
        str(sorted(xs, key=lambda (v: int) -> int { return v % 7; }, reverse=True)[:12])
    );
    words = [f"w{(i * 37) % 23}" for i in range(60)];
    out.append(
        ",".join(
            sorted(words, key=lambda (w: str) -> str { return f"{w[1:]}-{len(w)}"; })[:10]
        )
    );
    fs = [((i * 13) % 17) * 0.5 for i in range(40)];
    out.append(str(sorted(fs, key=lambda (f: float) -> float { return -f; })[:8]));
    pts = [((i * 5) % 7, (i * 3) % 4) for i in range(30)];
    out.append(
        str(
            sorted(
                pts,
                key=lambda (p: tuple[int, int]) -> tuple[int, int] { return (
                    p[1],
                    p[0]
                ); }
            )[:8]
        )
    );
    items = [Item(name=f"n{i}", rank=(i * 11) % 5) for i in range(25)];
    items.sort(key=lambda (it: Item) -> int { return it.rank; });
    out.append(",".join([it.name for it in items][:12]));
    items.sort(key=lambda (it: Item) -> int { return it.rank; }, reverse=True);
    out.append(",".join([it.name for it in items][:12]));
    by_name = sorted(items, key=lambda (it: Item) -> str { return it.name; });
    out.append(",".join([it.name for it in by_name][:12]));
    empty: list[int] = [];
    out.append(str(sorted(empty, key=lambda (v: int) -> int { return -v; })));
    one = [5];
    one.sort(key=lambda (v: int) -> int { return -v; });
    out.append(str(one));
    return out;
}

glob seen: list[int] = [];

def record(v: int) -> int {
    seen.append(v);
    return v % 3;
}

def counted -> list[str] {
    out: list[str] = [];
    xs = [5, 3, 9, 1, 7, 2];
    seen.clear();
    ys = sorted(xs, key=record);
    out.append(f"sorted calls {seen} -> {ys}");
    seen.clear();
    xs.sort(key=record, reverse=True);
    out.append(f"sort calls {seen} -> {xs}");
    return out;
}

with entry {
    for line in run() {
        print(line);
    }
    for line in counted() {
        print(line);
    }
}
