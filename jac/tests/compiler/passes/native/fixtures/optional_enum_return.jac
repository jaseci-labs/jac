"""Fixture: a function returning `<enum> | None`.

`pick` returns `Color | None`. The native backend must lower this to an i64
(enum ordinal, with a sentinel for `None`) and record the enum name so the
marshaller maps the ordinal back to a `Color` member -- exactly like a plain
`-> Color` return. The optional wrapper must not collapse the return type to
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
