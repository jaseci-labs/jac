"""Exception example in Jac."""

def divide_numbers(a: float, b: float) -> float {
    try {
        result = a / b;
    } except ZeroDivisionError as e {
        print("Error: Cannot divide by zero!", e);
        result = None;
        raise ;  # Re-raise the exception
    } finally {
        print("Division operation completed.");
    }
    return result;
}

with entry {
    try {
        numerator = int(input("Enter the numerator: "));
        denominator = int(input("Enter the denominator: "));
        result = divide_numbers(numerator, denominator);
        print("Result:", result);
    } except ValueError {
        print("Error: Invalid input! Please entry valid integers.");
    }
}
