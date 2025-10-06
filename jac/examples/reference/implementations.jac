"""Implementations: Forward declarations and impl blocks for deferred definitions."""

# Forward declarations
def compute(x: int, y: int) -> int;
obj Vehicle;
enum Priority;

# Implement function
impl compute(x: int, y: int) -> int {
    return x + y;
}

# Implement object
impl Vehicle {
    has name: str = "Car";
    has speed: int = 0;
    def accelerate { self.speed += 10; }
}

# Implement enum
impl Priority {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3
}

with entry {
    # Test implementations
    result = compute(5, 3);
    v = Vehicle();
    v.accelerate();
    p = Priority.HIGH;

    print(result, v.name, v.speed, p.value);
}
