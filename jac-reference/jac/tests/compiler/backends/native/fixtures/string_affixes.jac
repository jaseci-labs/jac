def suffix(value: str) -> bool {
    return value.endswith((".jac", ".py", ".pyi"));
}

def prefix(value: str) -> bool {
    return value.startswith(("jac", "python"));
}

def bounds(value: str, start: int, end: int) -> bool {
    return value.endswith(("jac", "py"), start, end);
}

def empty(value: str, start: int) -> bool {
    return value.endswith("", start);
}

def long_suffix(value: str) -> bool {
    return value.endswith("a suffix longer than the input");
}
