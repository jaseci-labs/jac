impl Calculator.add(amount: int) -> int {
    return self.value + amount;  # Ok: int + int -> int

}

impl Calculator.multiply(factor: int) -> int {
    return self.value * factor;  # Ok: int * int -> int

}

impl Calculator.bad_return -> str {
    return 42;  # Error: int not assignable to str

}

impl Calculator.bad_op -> int {
    return self.value + "oops";  # Error: int + str not valid

}
