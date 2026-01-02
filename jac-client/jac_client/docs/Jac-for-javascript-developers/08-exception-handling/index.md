# Exception Handling

JAC uses Python-style `try/except` instead of JavaScript's `try/catch`.

---

## Syntax Comparison

| JavaScript             | Jac                                 |
| ---------------------- | ----------------------------------- |
| `try { } catch(e) { }` | `try { } except Exception as e { }` |
| `throw new Error()`    | `raise Exception()`                 |
| `finally { }`          | `finally { }`                       |

---

## Basic Try/Except

```jac
def divideNumbers(a: int, b: int) -> None {
    try {
        if b == 0 {
            raise Exception("Cannot divide by zero!");
        }
        result = a / b;
        console.log("Result: " + result.toString());
    } except Exception as e {
        console.log("Error: " + e.toString());
    }
}
```

---

## Try/Except/Finally

`finally` always runs (cleanup):

```jac
def processData(shouldFail: bool) -> None {
    try {
        if shouldFail {
            raise Exception("Something went wrong!");
        }
        console.log("Success!");
    } except Exception as e {
        console.log("Error: " + e.toString());
    } finally {
        console.log("Cleanup - always runs!");
    }
}
```

---

## Generic Except

Catch any error without specifying type:

```jac
try {
    data = JSON.parse(jsonString);
} except {
    console.log("Invalid JSON!");
}
```

---

## Re-Raising Exceptions

```jac
def outerFunction() -> None {
    try {
        innerFunction();
    } except Exception as e {
        console.log("Logged: " + e.toString());
        raise e;  # Re-raise
    }
}
```

---

## Error Recovery with Defaults

```jac
def parseWithDefault(value: str, defaultVal: int) -> int {
    try {
        parsed = parseInt(value);
        if isNaN(parsed) {
            raise Exception("Not a number");
        }
        return parsed;
    } except Exception as e {
        return defaultVal;
    }
}

# Usage
result = parseWithDefault("hello", 0);  # Returns 0
```

---

## In React Components

```jac
def SafeComponent() -> any {
    [error, setError] = useState("");
    [data, setData] = useState(None);

    def handleClick() -> None {
        try {
            result = riskyOperation();
            setData(result);
        } except Exception as e {
            setError(e.toString());
        }
    }

    return (
        <div>
            <button onClick={handleClick}>Try</button>
            {error and <p style={{"color": "red"}}>{error}</p>}
            {data and <p>{data}</p>}
        </div>
    );
}
```

---

## Summary

| Pattern      | Syntax                              |
| ------------ | ----------------------------------- |
| Basic        | `try { } except Exception as e { }` |
| Generic      | `try { } except { }`                |
| With finally | `try { } except { } finally { }`    |
| Raise error  | `raise Exception("message")`        |
| Re-raise     | `raise e`                           |

---

## Next

- [Imports and Exports](../09-imports-and-exports/) - Module system
