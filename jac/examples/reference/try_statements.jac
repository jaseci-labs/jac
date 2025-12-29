# Try Statements

# Basic try-except
with entry {
    try {
        x = 5 / 0;
    } except Exception {
        print("caught exception");
    }

    # Try-except with as binding
    try {
        x = 5 / 0;
    } except Exception as e {
        print(f"error: {e}");
    }

    # Multiple except clauses
    try {
        x = int("not a number");
    } except ValueError as ve {
        print(f"ValueError: {ve}");
    } except TypeError as te {
        print(f"TypeError: {te}");
    } except Exception as e {
        print(f"other: {e}");
    }

    # Try-except-else (else executes if no exception)
    try {
        result = 10 / 2;
    } except ZeroDivisionError {
        print("division by zero");
    } else {
        print(f"success: {result}");
    }

    # Try-except-finally (finally always executes)
    try {
        x = 5 / 1;
    } except Exception {
        print("error");
    } finally {
        print("cleanup");
    }

    # Try-except-else-finally
    try {
        data = [1, 2, 3];
        print(data[1]);
    } except IndexError as ie {
        print(f"index error: {ie}");
    } else {
        print("access successful");
    }  finally {
        print("done");
    }

    # Try-finally (without except)
    try {
        print("operation");
    } finally {
        print("always runs");
    }

    # Nested try statements
    try {
        try {
            x = 5 / 0;
        } except ValueError {
            print("inner ValueError");
        }
    } except Exception as e {
        print(f"outer caught: {e}");
    }
}
