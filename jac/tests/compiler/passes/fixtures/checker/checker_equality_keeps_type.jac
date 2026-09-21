"""`==` proves a value, not a type, so narrowing keeps the variable's own type.
Only the cases marked below report an error."""

obj Tag {
    def __eq__(other: object) -> bool {
        return True;
    }
}

def str_eq_str(v: str | None) -> str {
    if v == "node" {
        return v;
    }
    return "";
}

def literal_union_eq(k: Literal["a", "b", "c"]) -> None {
    if k == "a" {
        a: Literal["a"] = k;
    }
    return None;
}

def ne_else_narrows(v: str | None) -> str {
    if v != "node" {
        return "";
    }
    return v;
}

def custom_eq_keeps_type(t: Tag | None) -> Tag {
    if t == "node" {
        return t;
    }
    return Tag();
}

def isinstance_and_eq(x: int | Tag) -> int {
    if isinstance(x, int) and x == 5 {
        return x + 1;
    }
    return 0;
}

def unrelated_member_dropped(x: int | bytes) -> int {
    if x == 1 {
        return x;
    }
    return 0;
}

def str_eq_int(v: str | None) -> int {
    if v == 1 {
        return v;  # <-- Error: neither str nor None equals 1, so v is not narrowed
    }
    return 0;
}

def int_eq_true(n: int | None) -> bool {
    if n == True {
        return n;  # <-- Error: 1 == True, so n is int, not bool
    }
    return False;
}

def float_ne_int(f: float | None) -> int {
    if f != 1 {
        return 0;
    }
    return f;  # <-- Error: 1.0 == 1, so f is float, not int
}

def eq_inside_and(n: int | None, ready: bool) -> bool {
    if n == True and ready {
        return n;  # <-- Error: `and` keeps the equality rule
    }
    return False;
}

def eq_under_not(n: int | None) -> bool {
    if not (n != True) {
        return n;  # <-- Error: `not` keeps the equality rule
    }
    return False;
}
