"""Test: unused variable should produce a warning."""
def foo() -> None {
    x = 5;
    y = 10;
    print(y);
}
