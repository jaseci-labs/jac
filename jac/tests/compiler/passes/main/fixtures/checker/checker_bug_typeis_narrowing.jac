"""A user-defined TypeIs predicate narrows its argument on both polarities."""

import from typing { TypeIs }

obj Base {
    has tag: str = "base";
}

obj Sub(Base) {
    has extra: int = 0;
}

obj Other(Base) {
    has name: str = "other";
}

def is_sub(nd: (Base | None)) -> TypeIs[Sub] {
    return isinstance(nd, Sub);
}

obj Holder {
    static def is_sub_static(nd: (Base | None)) -> TypeIs[Sub] {
        return isinstance(nd, Sub);
    }

    def is_sub_method(nd: (Base | None)) -> TypeIs[Sub] {
        return isinstance(nd, Sub);
    }
}

# The positive branch narrows the argument to the guarded type.
def positive(x: (Base | None)) -> int {
    if is_sub(x) {
        return x.extra;
    }
    return 0;
}

# The negative branch subtracts the guarded type from the declared type.
def negative(x: (Sub | Other)) -> str {
    if is_sub(x) {
        return str(x.extra);
    }
    return x.name;
}

def through_static(x: (Base | None)) -> int {
    if Holder.is_sub_static(x) {
        return x.extra;
    }
    return 0;
}

def through_method(h: Holder, x: (Base | None)) -> int {
    if h.is_sub_method(x) {
        return x.extra;
    }
    return 0;
}

def guarded_early_return(x: (Sub | Other)) -> str {
    if not is_sub(x) {
        return x.name;
    }
    return str(x.extra);
}

# A TypeIs result is an ordinary bool everywhere else.
def used_as_bool(x: (Base | None)) -> bool {
    flag: bool = is_sub(x);
    return flag;
}
