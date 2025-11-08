def foo(value: int) {
    if value < 0 {
        raise ValueError("Value must be non-negative");
    }
}

with entry {
    try  {
        foo(-1);
    } except ValueError as e  {
        print("Raised:", e);
    }
}
