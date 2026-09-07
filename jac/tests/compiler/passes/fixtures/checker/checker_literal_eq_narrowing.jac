"""`x == "literal"` narrows x, as it does for an int, float or bool literal.
Every function here is sound narrowing, so this fixture reports no errors.
"""

# The reported repro: a plain string literal.

def eq_str(v: str | None) -> str {
    r: str = "obj";
    if v == "node" {
        r = v;
    }
    return r;
}

def ne_str(v: str | None) -> str {
    r: str = "other";
    if v != "node" {
        return r;
    }
    return v;
}

def eq_str_ternary(v: str | None) -> str {
    return v if v == "node" else "obj";
}

# The same literal, spelled differently.

def eq_str_implicit_concat(v: str | None) -> str {
    r: str = "obj";
    if v == "no" "de" {
        r = v;
    }
    return r;
}

def eq_str_parenthesized(v: str | None) -> str {
    r: str = "obj";
    if v == ("node") {
        r = v;
    }
    return r;
}

# Baselines that already worked and must not regress.

def eq_int(v: int | None) -> int {
    r: int = 0;
    if v == 5 {
        r = v;
    }
    return r;
}

def eq_float(v: float | None) -> float {
    r: float = 0.0;
    if v == 1.5 {
        r = v;
    }
    return r;
}

def eq_bool(v: bool | None) -> bool {
    r: bool = False;
    if v == True {
        r = v;
    }
    return r;
}

# A non-literal operand must not narrow: `v` may still be None in the body.

def eq_non_literal(v: str | None, w: str) -> str {
    r: str = "obj";
    if v == w {
        r = "matched";
    }
    return r;
}

# `!=` narrows only where the members are literals themselves, so that every
# remaining alternative is spelled out.

def ne_literal_union_to_none(v: Literal["a"] | None) -> None {
    if v != "a" {
        return v;
    }
    return None;
}

# Each of `==` and `!=` has one edge that narrows by matching rather than by
# subtracting, and that edge holds for every literal.

def ne_int_else_branch(v: int | None) -> int {
    if v != 5 {
        return 0;
    }
    return v;
}

def ne_str_else_branch(v: str | None) -> str {
    if v != "node" {
        return "obj";
    }
    return v;
}
