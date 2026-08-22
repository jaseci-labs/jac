"""Implementation file for Calculator classes."""

impl Calculator.init(initial_value: float) {
    self.value = initial_value;
}

impl Calculator.add(amount: float) -> float {
    self.value = self.value + amount;
    return self.value;
}

impl Calculator.multiply(factor: float) -> float {
    self.value = self.value * factor;
    return self.value;
}

impl Calculator.get_value -> float {
    return self.value;
}

impl ScientificCalculator.power(exponent: float) -> float {
    result = self.value;
    count = 1;
    while count < exponent {
        result = result * self.value;
        count = count + 1;
    }
    self.value = result;
    return self.value;
}
