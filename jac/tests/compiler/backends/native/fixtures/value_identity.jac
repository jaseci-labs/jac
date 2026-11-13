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

def maybe_flag(flag: bool, absent: bool) -> (bool | None) {
    if absent {
        return None;
    }
    return flag;
}

def maybe_count(n: int, absent: bool) -> (int | None) {
    if absent {
        return None;
    }
    return n;
}

def options(flag: bool, n: int, absent: bool) -> list[bool] {
    got = maybe_flag(flag, absent);
    again = maybe_flag(flag, absent);
    count = maybe_count(n, absent);
    return [
        got is True,
        got is False,
        got is not True,
        got is not False,
        True is got,
        got is again,
        got is not again,
        got is None,
        count is n,
        count is not n,
        count is None
    ];
}

with entry {
    print(tuples(3));
    print(options(True, 5, False));
    print(options(False, 7, False));
    print(options(True, 5, True));
    print(scalars(True, 5, 2.5));
    print(scalars(False, 7, -1.0));
}
