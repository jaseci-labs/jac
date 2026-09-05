"""Bare functions stored in containers must dispatch through {fn, env} boxes.

The Callable read/call convention loads a {fn, env} closure pair; a bare
code pointer written into a container slot is read back as a closure box
and dereferenced (the callable-in-list crash class). Every builder below
returns a value that proves the RIGHT function ran: h_bad returns -99, so
a wrong-target dispatch (or a crash) can never satisfy the asserts.
"""

glob GTBL: list[Callable[[int], int]] = [];

def h_bad(n: int) -> int {
    return -99;
}

def h_one(n: int) -> int {
    return 100 + n;
}

def h_two(n: int) -> int {
    return 200 + n;
}

def pick(fs: list[Callable[[int], int]], i: int, n: int) -> int {
    g: Callable[[int], int] = fs[i];
    return g(n);
}

def dict_pick(d: dict[str, Callable[[int], int]], k: str, n: int) -> int {
    g: Callable[[int], int] = d[k];
    return g(n);
}

def list_append_dispatch(n: int) -> int {
    tbl: list[Callable[[int], int]] = [];
    i: int = 0;
    while i < 8 {
        tbl.append(h_bad);
        i = i + 1;
    }
    tbl[3] = h_one;
    f: Callable[[int], int] = tbl[3];
    return f(n);
}

def list_literal_dispatch(n: int) -> int {
    tbl: list[Callable[[int], int]] = [h_bad, h_one, h_two];
    f: Callable[[int], int] = tbl[1];
    g: Callable[[int], int] = tbl[2];
    return f(n) + g(n);
}

def list_insert_dispatch(n: int) -> int {
    tbl: list[Callable[[int], int]] = [h_bad];
    tbl.insert(0, h_one);
    f: Callable[[int], int] = tbl[0];
    return f(n);
}

def global_list_dispatch(n: int) -> int {
    i: int = 0;
    while i < 4 {
        GTBL.append(h_bad);
        i = i + 1;
    }
    GTBL[2] = h_two;
    f: Callable[[int], int] = GTBL[2];
    return f(n);
}

def list_as_param(n: int) -> int {
    tbl: list[Callable[[int], int]] = [h_one, h_two];
    return pick(tbl, 0, n) + pick(tbl, 1, n);
}

def fn_as_param(n: int) -> int {
    return dispatch_one(h_one, n);
}

def dispatch_one(f: Callable[[int], int], n: int) -> int {
    return f(n);
}

def dict_dispatch(n: int) -> int {
    d: dict[str, Callable[[int], int]] = {"a": h_one};
    d["b"] = h_two;
    return dict_pick(d, "a", n) + dict_pick(d, "b", n);
}

def list_of_dicts_dispatch(n: int) -> int {
    d: dict[str, Callable[[int], int]] = {"a": h_two};
    ds: list[dict[str, Callable[[int], int]]] = [d];
    dd: dict[str, Callable[[int], int]] = ds[0];
    return dict_pick(dd, "a", n);
}

def chained_dispatch(n: int) -> int {
    tbl: list[Callable[[int], int]] = [h_bad, h_bad];
    tbl[0] = h_one;
    tbl[1] = h_two;
    f: Callable[[int], int] = tbl[0];
    g: Callable[[int], int] = tbl[1];
    return g(f(n));
}
