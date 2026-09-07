"""`x != "literal"` rules out one value, never the whole class.
Every function here must report exactly one error.
"""

def ne_str(v: str | None) -> None {
    if v != "node" {
        n: None = v;
    }
    return None;
}

def ne_int(v: int | None) -> None {
    if v != 5 {
        n: None = v;
    }
    return None;
}

def ne_float(v: float | None) -> None {
    if v != 1.5 {
        n: None = v;
    }
    return None;
}

def ne_bool(v: bool | None) -> None {
    if v != True {
        n: None = v;
    }
    return None;
}

def eq_str_else_branch(v: str | None) -> None {
    if v == "node" {
        return None;
    }
    n: None = v;
    return None;
}

def eq_int_else_branch(v: int | None) -> None {
    if v == 5 {
        return None;
    }
    n: None = v;
    return None;
}

def eq_float_else_branch(v: float | None) -> None {
    if v == 1.5 {
        return None;
    }
    n: None = v;
    return None;
}

def eq_bool_else_branch(v: bool | None) -> None {
    if v == True {
        return None;
    }
    n: None = v;
    return None;
}

def keeps_sibling(v: Literal["a"] | Literal["b"]) -> None {
    if v != "a" {
        n: None = v;
    }
    return None;
}
