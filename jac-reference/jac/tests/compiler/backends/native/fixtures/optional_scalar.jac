"""Tagged scalar optionals (#7626 C5).

`int | None` has no pointer to ride null on, so it lowers as a JacOptional
value: {i8 tag, payload}. Coercions wrap/unwrap at assignment, call, and
return seams; `is None` reads the tag. Pointer-typed optionals keep the
existing null-riding lowering.
"""

def pick(n: int) -> int | None {
    if n > 0 {
        return n * 2;
    }
    return None;
}

def use_pick(n: int) -> int {
    v = pick(n);
    if v is None {
        return -1;
    }
    return v;
}

def opt_local(n: int) -> int {
    x: int | None = None;
    if n > 0 {
        x = n;
    }
    if x is None {
        return -1;
    }
    return x + 1;
}

def opt_param(v: int | None, alt: int) -> int {
    if v is None {
        return alt;
    }
    return v;
}

def use_opt_param(n: int) -> int {
    if n > 0 {
        return opt_param(n, -5);
    }
    return opt_param(None, -5);
}
