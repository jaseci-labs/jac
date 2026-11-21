"""Comparing an optional to an int literal must not erase the int arm."""

def fail_eq_int_literal_names_full_union(x: int | None) -> int {
    if x == 0 {
        return 0;
    }
    return x;
}

def fail_ne_int_literal_names_full_union(x: int | None) -> int {
    if x != 0 {
        return x;
    }
    return 0;
}

def ok_eq_literal_then_none_guard(x: int | None) -> int {
    if x == 0 {
        return 0;
    }
    if x is None {
        return -1;
    }
    return x;
}

def fail_eq_literal_else_rejects_none_binding(x: int | None) -> None {
    if x == 0 {
        return None;
    }
    n: None = x;
    return n;
}
