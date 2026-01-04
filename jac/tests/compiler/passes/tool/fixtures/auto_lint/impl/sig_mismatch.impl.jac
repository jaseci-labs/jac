"""Implementation file with mismatched signatures."""

impl Calculator.add(a: int, b: int) -> int {
    # Wrong param names: should be x, y but is a, b
    return a + b;
}

impl Calculator.multiply(x: int) -> int {
    # Wrong signature: missing second param, should be (a: int, b: int)
    return x * 2;
}

impl Calculator.no_change(val: int) -> int {
    # This one matches the declaration
    return val;
}
