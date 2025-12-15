"""Test fixture for class with separate impl file."""

cl {
    obj Calculator {
        has value: float;

        def init(initial_value: float);
        def add(amount: float) -> float;
        def multiply(factor: float) -> float;
        def get_value -> float;
    }

    obj ScientificCalculator(Calculator) {
        def power(exponent: float) -> float;
    }
}
