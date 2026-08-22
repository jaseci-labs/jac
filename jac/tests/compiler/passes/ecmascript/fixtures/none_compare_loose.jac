"""Fixture: None-ness must absorb JS undefined at comparison sites (#7922).

dict.get is fixed to return null on a miss, but undefined still leaks
into Jac-visible values from other sites (functions that fall off the
end, out-of-range pops, host interop). Lowering None comparisons to
loose equality (`== null`) makes `is None` true for exactly null and
undefined -- Jac None-ness -- at the one place Jac code observes it.
"""

def noret(x: int) {
    y = x + 1;
}

def t_noret_is_none -> bool {
    return noret(1) is None;
}

def t_noret_is_not_none -> bool {
    return noret(1) is not None;
}

def t_pop_empty_is_none -> bool {
    empty: list[int] = [];
    return empty.pop() is None;
}

def t_value_is_not_none -> bool {
    v = 42;
    return v is not None;
}

def none_cmp_all -> dict {
    return {
        "noret_none": t_noret_is_none(),
        "noret_not_none": t_noret_is_not_none(),
        "pop_empty_none": t_pop_empty_is_none(),
        "value_not_none": t_value_is_not_none()
    };
}
