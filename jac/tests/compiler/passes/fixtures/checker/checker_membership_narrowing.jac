"""`x in (...)` narrows x when every element is a literal; `not in` narrows its else.
Only the cases marked below still report an error."""

def in_tuple(ak: str | None) -> str {
    return ak if ak in ("node", "walker") else "obj";
}

def not_in_tuple(ak: str | None) -> str {
    return "obj" if ak not in ("node", "walker") else ak;
}

def in_list(ak: str | None) -> str {
    return ak if ak in ["node", "walker"] else "obj";
}

def not_in_list(ak: str | None) -> str {
    return "obj" if ak not in ["node", "walker"] else ak;
}

def in_narrows_to_the_literals(ak: str | None) -> None {
    if ak in ("node", "walker") {
        k: Literal["node", "walker"] = ak;
    }
    return None;
}

def in_tuple_int(n: int | None) -> int {
    return n if n in (1, 2, 3) else 0;
}

def in_tuple_float(f: float | None) -> float {
    return f if f in (1.5, 2.5) else 0.0;
}

def in_tuple_bool(b: bool | None) -> bool {
    return b if b in (True, False) else False;
}

def in_literal_union(k: Literal["a", "b", "c"]) -> None {
    if k in ("a", "b") {
        ab: Literal["a", "b"] = k;
    }
    return None;
}

def fstring_element_is_not_a_literal(ak: str | None, x: str) -> str {
    return ak if ak in (f"{x}", "walker") else "obj";  # <-- Error: f-string element
}

def variable_element_is_not_a_literal(ak: str | None, other: str) -> str {
    return ak if ak in (other, "walker") else "obj";  # <-- Error: variable element
}

def in_false_branch_keeps_type(ak: str | None) -> str {
    if ak in ("node", "walker") {
        return "matched";
    }
    return ak;  # <-- Error: only the literals are ruled out, ak is still str | None
}

def not_in_true_branch_keeps_type(ak: str | None) -> str {
    if ak not in ("node", "walker") {
        return ak;  # <-- Error: only the literals are ruled out, ak is still str | None
    }
    return "in";
}

# `not in` does not narrow a literal union yet, so the error names every literal.
def not_in_literal_union(k: Literal["a", "b", "c"]) -> None {
    if k not in ("a", "b") {
        c: Literal["c"] = k;  # <-- Error: not narrowed yet
    }
    return None;
}
