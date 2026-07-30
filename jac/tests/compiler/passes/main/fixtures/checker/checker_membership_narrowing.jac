"""Membership (`in`/`not in`) and string-literal (`==`/`!=`) narrowing fixture."""

def test_membership_in_tuple(ak: str | None) -> str {
    return ak if ak in ("node", "walker") else "obj";
}

def test_membership_not_in_tuple(ak: str | None) -> str {
    return "obj" if ak not in ("node", "walker") else ak;
}

def test_membership_in_list(ak: str | None) -> str {
    return ak if ak in ["node", "walker"] else "obj";
}

def test_membership_not_in_list(ak: str | None) -> str {
    return "obj" if ak not in ["node", "walker"] else ak;
}

def test_membership_in_tuple_int(n: int | None) -> int {
    return n if n in (1, 2, 3) else 0;
}

def test_membership_in_tuple_float(f: float | None) -> float {
    return f if f in (1.5, 2.5) else 0.0;
}

def test_membership_in_tuple_bool(b: bool | None) -> bool {
    return b if b in (True, False) else False;
}

def test_string_literal_eq(v: str | None) -> str {
    r: str = "obj";
    if v == "node" {
        r = v;
    }
    return r;
}

def test_string_literal_ne(v: str | None) -> str {
    r: str = "obj";
    if v != "node" {
        r = "obj";
    } else {
        r = v;
    }
    return r;
}

def test_error_membership_non_literal_element(ak: str | None, other: str) -> str {
    return ak
        if ak in (other, "walker")
        else "obj";  # <-- Error: tuple has a non-literal element, no narrowing possible
}

def test_error_membership_false_branch_unnarrowed(ak: str | None) -> str {
    if ak in ("node", "walker") {
        return "matched";
    }
    return ak;  # <-- Error: `in` only narrows the true branch, ak is still str | None here
}
