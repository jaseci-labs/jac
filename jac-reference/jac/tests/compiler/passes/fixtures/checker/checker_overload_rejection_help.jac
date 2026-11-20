"""Each call fails overload resolution for a different reason, which E1054 names.
The last one stays bare: it fails argument matching, so there is nothing to name.
"""

def opt_key(d: dict[str, int], extra: int = 0) -> dict[str, int] {
    return d;
}

import re;

def to_int(text: str) -> int {
    return len(text);
}

def by_number(n: int) -> int {
    return n;
}

glob rows: list[dict[str, int]] = [{"n": 2}, {"n": 1}],
     words: list[str] = ["b", "a"];

with entry {
    a = sorted(rows, key=lambda (d: dict[str, int]) { d; });

    b = sorted([3, 1, 2], key=lambda (x: int, y: int) { x; });

    # An extra optional param is arity-compatible, so blame the return type.
    g = sorted(rows, key=opt_key);

    h = sorted(words, key=by_number);

    i = sorted(
        rows,
        key=lambda (d) {
            v = d["n"];
            return v;
        }
    );

    c = sorted([3, 1, 2], key=5);

    d = "5".rjust("wide");

    e = max(5, key="not callable");

    j = pow("two", "three");

    k = open("x.txt", 1.5);

    m = sorted([1, 2], key=by_number, reverse="yes");

    n = re.sub("a", to_int, "abc");

    p = max("a", 5, key=to_int);

    f = sorted([3, 1, 2], nosuch=5);

    print(a, b, c, d, e, f, g, h, i, j, k, m, n, p);
}
