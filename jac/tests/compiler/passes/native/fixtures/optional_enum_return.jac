"""Fixture: a function returning `<enum> | None`.

`pick` returns `Color | None`. The native backend lowers this through the one
JacOptional rule -- a tagged {i8, i64} value carrying the enum ordinal -- and
records the enum name so the marshaller maps a present ordinal back to a
`Color` member. The optional wrapper must not collapse the return type to
`void` (which made any caller binding `c = pick(...)` fail to lower).
"""

enum Color { RED, GREEN, BLUE }

def pick(flag: int) -> Color | None {
    if flag > 0 {
        return Color.RED;
    }
    return None;
}

def use_pick(flag: int) -> int {
    c = pick(flag);
    return flag;
}
