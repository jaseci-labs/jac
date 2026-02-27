"""Test walrus operator type narrowing."""

def maybe_int() -> int | None { return 10; }
def maybe_str() -> str | None { return "hi"; }

def test_basic() -> int {
    if (a := maybe_int()) { return a; }
    return 0;
}

def test_multiple() -> int {
    if (a := maybe_int()) and (b := maybe_int()) { return a + b; }
    return 0;
}

def test_str() -> str {
    if (s := maybe_str()) { return s; }
    return "";
}
