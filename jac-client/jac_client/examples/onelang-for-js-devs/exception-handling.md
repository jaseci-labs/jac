# Exception Handling in JAC-Lang (Onelang)

This guide covers error handling patterns in JAC-Lang for developers familiar with JavaScript's try/catch syntax.

> **Full Examples**: See the complete working examples at [jac-client-examples/exception-handling](https://github.com/jaseci-labs/jac-client-examples/tree/main/exception-handling)

---

## Key Difference: try/catch vs try/except

| React/JavaScript                   | JAC-Lang (Onelang)                              |
| ---------------------------------- | ----------------------------------------------- |
| `try { } catch(e) { }`             | `try { } except Exception as e { }`             |
| `try { } catch(e) { } finally { }` | `try { } except Exception as e { } finally { }` |
| `throw new Error("msg")`           | `raise Exception("msg")`                        |

---

## Syntax Reference

### Basic Try/Except

=== "JavaScript"

    ```javascript
    try {
      riskyOperation();
    } catch (error) {
      console.log("Error:", error.message);
    }
    ```

=== "JAC-Client"

    ```jac
    try {
        riskyOperation();
    } except Exception as e {
        console.log("Error:", (e.toString()));
    }
    ```

---

### Try/Except/Finally

=== "JavaScript"

    ```javascript
    try {
      doSomething();
    } catch (error) {
      handleError(error);
    } finally {
      cleanup(); // Always runs
    }
    ```

=== "JAC-Client"

    ```jac
    try {
        doSomething();
    } except Exception as e {
        handleError(e);
    } finally {
        cleanup();  # Always runs
    }
    ```

---

### Raising/Throwing Errors

=== "JavaScript"

    ```javascript
    if (value < 0) {
      throw new Error("Value cannot be negative!");
    }
    ```

=== "JAC-Client"

    ```jac
    if value < 0 {
        raise Exception("Value cannot be negative!");
    }
    ```

---

### Re-Raising Exceptions

=== "JavaScript"

    ```javascript
    try {
      riskyOperation();
    } catch (error) {
      console.log("Logging error...");
      throw error; // Re-throw
    }
    ```

=== "JAC-Client"

    ```jac
    try {
        riskyOperation();
    } except Exception as e {
        console.log("Logging error...");
        raise e;  # Re-raise
    }
    ```

---

## Common Patterns

### Input Validation

```jac
def validateAge(age: int) -> None {
    try {
        if age < 0 {
            raise Exception("Age cannot be negative!");
        }
        if age > 150 {
            raise Exception("Age seems unrealistic!");
        }
        console.log("Valid age:", age);
    } except Exception as e {
        console.log("Validation error:", (e.toString()));
    }
}
```

### Safe JSON Parsing

```jac
def parseJson(jsonString: str) -> any {
    try {
        let data = JSON.parse(jsonString);
        return data;
    } except Exception as e {
        console.log("Invalid JSON:", (e.toString()));
        return None;
    }
}
```

### Error Recovery with Defaults

```jac
def parseNumber(value: str, defaultVal: int) -> int {
    try {
        let parsed = parseInt(value);
        if isNaN(parsed) {
            raise Exception("Not a number");
        }
        return parsed;
    } except Exception as e {
        return defaultVal;  # Use default on error
    }
}
```

### Safe Array Access

```jac
def safeGetItem(arr: list, index: int) -> any {
    try {
        if index < 0 or index >= arr.length {
            raise Exception("Index out of bounds!");
        }
        return arr[index];
    } except Exception as e {
        console.log("Error:", (e.toString()));
        return None;
    }
}
```

---

## Quick Conversion Table

| React/JavaScript         | JAC-Lang                    |
| ------------------------ | --------------------------- |
| `try { }`                | `try { }`                   |
| `catch(e) { }`           | `except Exception as e { }` |
| `finally { }`            | `finally { }`               |
| `throw new Error("msg")` | `raise Exception("msg")`    |
| `throw error`            | `raise e`                   |
| `error.message`          | `(e.toString())`            |

---

## Examples Covered

1. **Basic Try/Except** - Division by zero handling
2. **Try/Except/Finally** - Cleanup operations
3. **JSON Parse Errors** - Handling invalid JSON
4. **Array Index Errors** - Safe array access
5. **Object Key Errors** - Safe property access
6. **Input Validation** - Form validation with exceptions
7. **Nested Try/Except** - Multi-step error handling
8. **Re-Raising Exceptions** - Catch, log, and re-throw
9. **Custom Error Messages** - Descriptive error creation
10. **Safe Function Wrapper** - Wrapping risky operations
11. **Error Recovery** - Using default values on error
12. **Async-Like Error Handling** - Simulated async errors

---

## Tips

1. **Always use `Exception as e`** - JAC requires specifying the exception type
2. **Use `(e.toString())` to get error message** - Convert exception to string for display
3. **`finally` always runs** - Use for cleanup code that must execute
4. **`raise` not `throw`** - JAC uses Python-style `raise` keyword
5. **Custom messages** - Create descriptive error messages for better debugging
