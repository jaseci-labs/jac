"""Container shapes that crashed the emitter rather than lowering or refusing.

`dict.keys()` and `dict.values()` build their result under the `ptr` flavor,
whose element type is canonically `i8*`, but handed the emitter the dict's own
pointer type instead. Where the `ptr` helpers already existed the append
argument did not match the list being appended to and the IR builder raised.
"""

obj Nd {
    has n: int = 1,
        tag: str = "";
}


def dict_values_ptr -> int {
    m: dict[int, Nd] = {};
    m[1] = Nd(n=3);
    m[2] = Nd(n=4);
    total = 0;
    for v in list(m.values()) {
        total += v.n;
    }
    return total;
}


def dict_values_count -> int {
    m: dict[int, Nd] = {};
    m[1] = Nd(n=3);
    m[2] = Nd(n=4);
    return len(list(m.values()));
}


def dict_keys_str -> int {
    m: dict[str, int] = {};
    m["ab"] = 1;
    m["cde"] = 2;
    total = 0;
    for k in list(m.keys()) {
        total += len(k);
    }
    return total;
}


def dict_values_then_dedup -> int {
    m: dict[int, Nd] = {};
    a = Nd(n=3);
    m[1] = a;
    m[2] = a;
    seen: set[int] = set();
    for v in list(m.values()) {
        seen.add(id(v));
    }
    return len(seen);
}


def tuple_keyed_set -> int {
    seen: set[tuple[int, int]] = set();
    seen.add((1, 2));
    seen.add((3, 4));
    seen.add((1, 2));
    return len(seen);
}
