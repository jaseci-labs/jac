"""One function uses a Python-only builtin; the other is plain native code."""
def uses_eval -> int {
    return eval("1 + 1");
}

def add_one(x: int) -> int {
    return x + 1;
}
