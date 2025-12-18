"""Test fixture for @staticmethod to static keyword conversion."""

class Calculator {
    static def add(a: int, b: int) -> int {
        return a + b;
    }

    @staticmethod
    def multiply(x: int, y: int) -> int {
        return x * y;
    }

    # Method without staticmethod decorator
    def instance_method(self: Calculator) -> int {
        return 42;
    }

    # Method that already has static keyword (should not be modified)
    static def already_static(a: int) -> int {
        return a * 2;
    }
}

# Test with multiple decorators
class MultiDecorator {
    @some_decorator
    @staticmethod
    static def decorated_static(x: int) -> int {
        return x;
    }
}
