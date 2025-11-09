"""Example demonstrating native printf support (once implemented)."""

# This will work once function call support is added
def test_printf() -> int {
    # Native printf call - will print to stdout
    x: int = 42;
    # printf("The answer is: %d\n", x);
    return x;
}

def print_calculation(a: int, b: int) -> int {
    result: int = a + b;
    # printf("Result of %d + %d = %d\n", a, b, result);
    return result;
}

def print_float(x: float) -> float {
    # printf("Float value: %f\n", x);
    return x;
}
