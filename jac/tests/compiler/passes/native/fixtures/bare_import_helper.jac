"""Plain .jac helper consumed via a bare `import bare_import_helper;`."""

def fn() -> int {
    return 41;
}

def twice(n: int) -> int {
    return n * 2;
}

glob COUNT: int = 7;
