"""Each call fails overload resolution for a different reason, which E1054 must
name in its help text. The last one stays bare: it fails argument matching, so
there is no rejection to report.
"""

def opt_key(d: dict, extra: int = 0) -> dict {
    return d;
}

with entry {
    rows: list[dict] = [{"n": 2}, {"n": 1}];

    a = sorted(rows, key=lambda (d: dict) { d; });

    b = sorted([3, 1, 2], key=lambda (x: int, y: int) { x; });

    # An extra optional param is arity-compatible, so blame the return type.
    g = sorted(rows, key=opt_key);

    c = sorted([3, 1, 2], key=5);

    d = "5".rjust("wide");

    e = max(5, key="not callable");

    f = sorted([3, 1, 2], nosuch=5);

    print(a, b, c, d, e, f, g);
}
