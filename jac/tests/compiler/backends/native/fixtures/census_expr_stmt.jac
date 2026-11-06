"""Expression statements whose value is dropped still run, comprehensions
included, and hasattr answers from the value's declared members."""
node A {}

glob calls: list[int] = [];

def note(i: int) -> int {
    calls.append(i);
    return i;
}

with entry {
    [note(i) for i in range(3)];
    {i: note(i * 10) for i in range(2)};
    print(calls);
    print(hasattr(A, "9876"), hasattr("text", "9876"), hasattr(A(), "9876"));
    print(hasattr("text", "upper"), hasattr(3, "real"), hasattr([1], "nope"));
    a: object = A();
    a: object = A;
    print("done");
}
