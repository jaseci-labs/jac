"""Fixture: `x == None` / `x != None` should narrow `T | None` symmetrically with `is`/`is not`.

Pyright/mypy/TypeScript all narrow `T | None` to `T` after both `x is not None`
and `x != None`. The Jac type checker only narrowed on `is`/`is not`, so the
attribute accesses below previously produced E1099 false positives. After the
fix, this fixture must type-check with zero errors.
"""

obj Recipe { has title: str = ""; }

# Positive branch: `x != None` must narrow to non-None.
def title_neq(r: Recipe | None) -> str {
    if r != None { return r.title; }
    return "";
}

# Negative branch fall-through: `x == None` early-returns the None case,
# so the post-if region must be narrowed to non-None.
def title_eq_none_early_return(r: Recipe | None) -> str {
    if r == None { return ""; }
    return r.title;
}

# Compound AND: both operands must narrow in the true branch.
def link(a: Recipe | None, b: Recipe | None) -> str {
    if a != None and b != None {
        return a.title + b.title;
    }
    return "";
}
