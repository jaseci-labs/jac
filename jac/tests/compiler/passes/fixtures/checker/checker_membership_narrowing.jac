"""`x in (...)` narrows x when every element is a literal; `not in` narrows the other way.
Only the cases marked below still report an error."""

def in_tuple_narrows(ak: str | None) -> None {
    if ak in ("node", "walker") {
        k: Literal["node", "walker"] = ak;
    }
    return None;
}

def not_in_list_narrows(ak: str | None) -> str {
    if ak not in ["node", "walker"] {
        return "obj";
    }
    return ak;
}

def in_single_element(ak: str | None) -> None {
    if ak in ("node",) {
        k: Literal["node"] = ak;
    }
    return None;
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
