"""Implementations: Forward declarations and impl blocks for deferred definitions."""

# Forward declarations
def compute(x: int, y: int) -> int;
obj Vehicle;
enum Priority;

obj Calculator {
    has total: float = 0.0;

    def add(
    # Implement function

    # Implement object

    # Implement enum

    # Implement object methods

        value: float
    );
    def subtract(value: float);
    def multiply(value: float);
    def get_result -> float;
}

impl compute(x: int, y: int) -> int {
    return x + y;
}

impl Vehicle{
    has name: str = "Car",
        speed: int = 0;
    def accelerate {
        self.speed += 10;
    }
}

impl Priority{
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3
}

impl Calculator.add(value: float) {
    self.total += value;
}

impl Calculator.subtract(value: float) {
    self.total -= value;
}

impl Calculator.multiply(value: float) {
    self.total *= value;
}

impl Calculator.get_result -> float {
    return self.total;
}

# Test implementations
glob result = compute(5, 3),
     v = Vehicle();

with entry {
    v.accelerate();
}

glob p = Priority.HIGH,
     calc = Calculator();

with entry {
    calc.add(10.5);
    calc.multiply(2.0);
    calc.subtract(5.0);

    print(result, v.name, v.speed, p.value);
    print("Calculator result:", calc.get_result());
}
