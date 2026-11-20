"""Conditional expressions inside f-string interpolations (roadmap N8a).

Every interpolation here holds a ternary whose two branches lower to the SAME
representation, so the result needs no boxing: two `str` branches, two `int`
branches, a ternary carrying a format spec, a ternary of calls, and a ternary
nested inside an inner f-string. The interpolation value must go through
ordinary expression codegen, so each of these renders exactly as the sv
(bytecode) backend renders it.
"""

def pick_str(c: int) -> str {
    a = "yes";
    b = "no";
    return f"[{a if c else b}]";
}

def pick_int(c: int) -> str {
    a = 10;
    b = 20;
    return f"[{a if c else b}]";
}

def pick_literal(c: int) -> str {
    return f"[{"on" if c else "off"}]";
}

def pick_spec(c: int) -> str {
    a = "yes";
    b = "no";
    return f"[{a if c else b:>8}]";
}

def pick_nested(c: int) -> str {
    a = "in";
    b = "out";
    return f"<{f"[{a if c else b}]"}>";
}

def pick_call(c: int) -> str {
    return f"[{pick_str(c)}]";
}

def pick_call_ternary(c: int) -> str {
    return f"[{pick_str(c) if c else pick_int(c)}]";
}

def pick_chained(c: int) -> str {
    a = "yes";
    b = "no";
    return f"{a if c else b}-{pick_int(c)}-{"t" if c else "f"}";
}
