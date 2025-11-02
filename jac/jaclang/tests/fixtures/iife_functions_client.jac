"""Test Immediately Invoked Function Expressions (IIFE) for client-side (JavaScript) execution."""

cl with entry {
    # Test 1: Basic IIFE with no parameters
    let result1 = (def get_value() -> int {
        return 42;
    })();

    print("Test 1 - Basic IIFE:", result1);
    # Expected: 42

    # Test 2: IIFE with parameters
    let result2 = (def calculate(x: int, y: int) -> int {
        return x * y + x + y;
    })(5, 3);

    print("Test 2 - IIFE with parameters (5, 3):", result2);
    # Expected: 23 (15 + 5 + 3)

    # Test 3: IIFE with local variables
    let result3 = (def compute() -> int {
        let a = 10;
        let b = 20;
        let c = 30;
        return a + b + c;
    })();

    print("Test 3 - IIFE with local variables:", result3);
    # Expected: 60

    # Test 4: IIFE with conditional logic
    let result4 = (def check_number(n: int) -> str {
        if n > 0 {
            return "positive";
        } elif n < 0 {
            return "negative";
        } else {
            return "zero";
        }
    })(15);

    print("Test 4 - IIFE with conditional:", result4);
    # Expected: positive

    # Test 5: IIFE with loop
    let result5 = (def sum_to_n(n: int) -> int {
        let total = 0;
        let i = 1;
        while i <= n {
            total = total + i;
            i = i + 1;
        }
        return total;
    })(5);

    print("Test 5 - IIFE with loop (sum 1 to 5):", result5);
    # Expected: 15

    # Test 6: IIFE returning a function
    let adder = (def make_adder(x: int) {
        return lambda y: int: x + y;
    })(10);

    print("Test 6 - IIFE returning function, adder(5):", adder(5));
    # Expected: 15

    # Test 7: Nested IIFE
    let result7 = (def outer() -> int {
        let x = (def inner() -> int {
            return 100;
        })();
        return x + 50;
    })();

    print("Test 7 - Nested IIFE:", result7);
    # Expected: 150

    # Test 8: IIFE with array operations
    let result8 = (def process_data(data: list) -> int {
        let sum = 0;
        let count = 0;
        for item in data {
            sum = sum + item;
            count = count + 1;
        }
        if count > 0 {
            return sum / count;
        } else {
            return 0;
        }
    })([10, 20, 30, 40, 50]);

    print("Test 8 - IIFE computing average:", result8);
    # Expected: 30

    # Test 9: IIFE used in assignment chain
    let x = 5;
    let result9 = x + (def double(n: int) -> int {
        return n * 2;
    })(x);

    print("Test 9 - IIFE in expression (5 + double(5)):", result9);
    # Expected: 15

    # Test 10: IIFE with object creation
    let result10 = (def create_object() -> dict {
        let obj = {
            "name": "Test",
            "value": 123,
            "active": True
        };
        return obj;
    })();

    print("Test 10 - IIFE creating object:", result10);
    # Expected: {name: 'Test', value: 123, active: true}

    # Test 11: IIFE with string manipulation
    let result11 = (def format_message(name: str, age: int) -> str {
        let message = "Hello, " + name + "!";
        let age_part = " You are " + str(age) + " years old.";
        return message + age_part;
    })("Alice", 25);

    print("Test 11 - IIFE with string manipulation:", result11);
    # Expected: Hello, Alice! You are 25 years old.

    # Test 12: IIFE with closure
    let counter = (def create_counter() {
        let count = 0;
        return lambda () {
            count = count + 1;
            return count;
        };
    })();

    print("Test 12 - IIFE with closure, call 1:", counter());
    print("Test 12 - IIFE with closure, call 2:", counter());
    print("Test 12 - IIFE with closure, call 3:", counter());
    # Expected: 1, 2, 3

    print("\nAll client-side IIFE tests completed!");
}
