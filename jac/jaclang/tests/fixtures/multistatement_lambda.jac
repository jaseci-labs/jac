"""Test multi-statement lambda expressions."""

with entry {
    # Test 1: Basic multi-statement lambda
    let add_and_multiply = lambda x: int, y: int -> int {
        let sum = x + y;
        let product = x * y;
        return sum + product;
    };

    let result1 = add_and_multiply(3, 4);
    print("Test 1 - Multi-statement lambda (3 + 4) + (3 * 4):", result1);
    # Expected: 19 (7 + 12)

    # Test 2: Lambda with conditional logic
    let get_grade = lambda score: int -> str {
        if score >= 90 {
            return "A";
        } elif score >= 80 {
            return "B";
        } elif score >= 70 {
            return "C";
        } else {
            return "F";
        }
    };

    print("Test 2 - Grade for 85:", get_grade(85));
    print("Test 2 - Grade for 95:", get_grade(95));
    print("Test 2 - Grade for 65:", get_grade(65));
    # Expected: B, A, F

    # Test 3: Lambda with loop
    let sum_range = lambda n: int -> int {
        let total = 0;
        let i = 0;
        while i < n {
            total = total + i;
            i = i + 1;
        }
        return total;
    };

    print("Test 3 - Sum of 0 to 9:", sum_range(10));
    # Expected: 45

    # Test 4: Lambda with multiple statements and variables
    let complex_calc = lambda a: int, b: int, c: int -> int {
        let x = a * 2;
        let y = b + 10;
        let z = c - 5;
        let result = x + y + z;
        return result;
    };

    print("Test 4 - Complex calculation (5, 3, 8):", complex_calc(5, 3, 8));
    # Expected: (10 + 13 + 3) = 26

    # Test 5: Lambda that returns another lambda
    let make_adder = lambda x: int {
        return lambda y: int: x + y;
    };

    let add_five = make_adder(5);
    print("Test 5 - add_five(10):", add_five(10));
    # Expected: 15

    # Test 6: Lambda with try-catch
    let safe_divide = lambda a: int, b: int -> str {
        try {
            let result = a / b;
            return f"Result: {result}";
        } except Exception {
            return "Division by zero error";
        }
    };

    print("Test 6 - safe_divide(10, 2):", safe_divide(10, 2));
    print("Test 6 - safe_divide(10, 0):", safe_divide(10, 0));
    # Expected: Result: 5.0, Division by zero error

    # Test 7: Lambda as higher-order function argument
    let apply_operation = lambda x: int, y: int -> int {
        let multiply = lambda a: int, b: int -> int {
            let result = a * b;
            return result;
        };
        return multiply(x, y);
    };

    print("Test 7 - apply_operation(6, 7):", apply_operation(6, 7));
    # Expected: 42

    # Test 8: Lambda with list operations
    let process_list = lambda items: list {
        let result = [];
        for item in items {
            result.append(item * 2);
        }
        return result;
    };

    print("Test 8 - process_list([1, 2, 3, 4]):", process_list([1, 2, 3, 4]));
    # Expected: [2, 4, 6, 8]

    # Test 9: Lambda with explicit function signature syntax
    let format_pair = lambda (first: str, second: str) -> str {
        let separator = "-";
        return first + separator + second;
    };

    print("Test 9 - format_pair('foo', 'bar'):", format_pair("foo", "bar"));
    # Expected: foo-bar

    print("\nAll multi-statement lambda tests completed!");
}
