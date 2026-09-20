"""Booleans from membership tests and comparisons, rendered as text."""

def membership_fstring(x: int) -> str {
    s = {1, 2};
    return f"{x in s}|{x not in s}|{x in [1, 2]}";
}

def comparison_fstring(x: int) -> str {
    return f"{x > 1}|{x == 2}|{0 < x < 3}";
}

def spec_fstring(x: int) -> str {
    s = {1, 2};
    return f"[{x in s:5}]";
}

def repr_fstring(x: int) -> str {
    s = {1, 2};
    return f"{x in s!r}";
}

def repr_text(x: int) -> str {
    s = {1, 2};
    return repr(x in s) + "|" + repr(x < 0);
}

def str_text(x: int) -> str {
    s = {1, 2};
    return str(x in s) + "|" + str(1 in [x]);
}
