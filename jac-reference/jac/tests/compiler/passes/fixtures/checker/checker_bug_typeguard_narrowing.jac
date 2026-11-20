"""A TypeGuard predicate narrows only the positive branch, and replaces the declared type there."""

import from typing { TypeGuard }

obj Base {
    has tag: str = "base";
}

obj Sub(Base) {
    has extra: int = 0;
}

def looks_like_sub(nd: (Base | None)) -> TypeGuard[Sub] {
    return isinstance(nd, Sub);
}

def all_strings(items: (list[int] | None)) -> TypeGuard[list[str]] {
    return items is not None;
}

# The positive branch narrows to the guarded type.
def positive(x: (Base | None)) -> int {
    if looks_like_sub(x) {
        return x.extra;
    }
    return 0;
}

# PEP 647 narrows the positive branch to the guarded type outright, without
# intersecting it with the declared type: the element type is str, not int.
def replaces_declared(xs: (list[int] | None)) -> str {
    if all_strings(xs) {
        return xs[0];
    }
    return "";
}

# The negative branch keeps the declared type; `x.tag` is still an error
# because `x` may be None there.
def negative_keeps_declared(x: (Base | None)) -> str {
    if looks_like_sub(x) {
        return "sub";
    }
    return x.tag;
}
