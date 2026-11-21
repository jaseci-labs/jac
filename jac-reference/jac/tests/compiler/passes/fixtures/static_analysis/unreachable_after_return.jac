"""Test: unreachable code after return statement."""
def foo() -> int {
    return 1;
    print("unreachable");
}
