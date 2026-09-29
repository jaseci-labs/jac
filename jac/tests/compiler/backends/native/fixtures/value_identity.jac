"""`is` / `is not` over by-value tuples and scalars answer like CPython."""

obj Res {
    has tag: int = 0;
}

def pair(i: int) -> tuple[int, str] {
    return (i, str(i));
}

def tuples(i: int) -> list[bool] {
    a = (i, "x");
    b = a;
    c = (i, "y");
    r = Res(tag=i);
    d = (1, r);
    e = d;
    f = (1, Res(tag=i));
    g = pair(i);
    h = g;
    return [
        a is b,
        a is not b,
        a is c,
        a is not c,
        a is None,
        a is not None,
        d is e,
        d is f,
        d is not f,
        g is h,
        g is not None
    ];
}

def scalars(flag: bool, n: int, x: float) -> list[bool] {
    m = n;
    y = x;
    return [
        flag is True,
        flag is False,
        flag is not True,
        flag is not False,
        n is m,
        n is not m,
        x is y,
        x is not y,
        n is None,
        n is not None,
        x is None
    ];
}

with entry {
    print(tuples(3));
    print(scalars(True, 5, 2.5));
    print(scalars(False, 7, -1.0));
}
