
def foo() -> int {
    return 42;
}

with entry {
    i: int = foo(); # <-- Ok
    s: str = foo(); # <-- Error
}
