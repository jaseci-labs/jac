"""Fixture: comprehension edge classification must NOT over-narrow to true.

The in-body fix classifies a comprehension's synthetic CFG edge by which
branch subtree contains it. The true-positive direction must be preserved:
inside `if r is None { ... }` the narrowed type of `r` really is `None`, so
attribute access inside a comprehension in that block must still raise.

This guards against a regression where the parent-walk over-aggressively
returns the true edge for every nested comprehension, silently dropping
genuine errors. Each comprehension below references `r.parts` while `r` is
narrowed to `None` -- every one must produce an error.
"""

obj R {
    has parts: list[str] = [];
}

# `r` is None inside the then-body of `if r is None`.
def use_then_none(r: R | None) -> list[str] {
    if r is None {
        return [r.parts[i] for i in range(3)];
    }
    return [];
}

# `r` is None inside the else-body of `if r is not None`.
def use_else_none(r: R | None) -> list[str] {
    if r is not None {
        return [];
    } else {
        return [r.parts[i] for i in range(3)];
    }
}
