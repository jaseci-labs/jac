import from .operations { add, subtract, multiply, divide }
import from .constants { PI }

obj Calculator {
    has last_result: float = 0.0;

    def compute(a: float, b: float, operation: str) -> float {
        if operation == "add" {
            self.last_result = add(a, b);
        } elif operation == "subtract" {
            self.last_result = subtract(a, b);
        } elif operation == "multiply" {
            self.last_result = multiply(a, b);
        } elif operation == "divide" {
            self.last_result = divide(a, b);
        }
        return self.last_result;
    }

    def get_pi -> float {
        return PI;
    }
}
