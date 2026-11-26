"""Defines its own `eval`; calling it is not the Python builtin."""
def eval(s: str) -> int {
    return len(s);
}

def caller -> int {
    return eval("abc");
}
