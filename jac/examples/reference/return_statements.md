Return statements in Jac provide the mechanism for functions and methods to exit and optionally return values to their callers. The return statement syntax supports both value-returning and void functions, enabling clear control flow and data passing in function-based programming.

**Basic Return Statement Syntax**

Return statements follow this pattern from the grammar:
```jac
return expression;  # Return a value
return;             # Return without a value (void)
```

**Example Implementation**

The provided example demonstrates a function that returns a computed value:
```jac
def foo -> int {
    a = 42;
    return a;
}
```

**Key aspects:**
- **Type annotation**: Function specifies return type `-> int`
- **Variable assignment**: Local variable `a` holds the return value
- **Return expression**: `return a` exits function and returns the variable's value
- **Caller usage**: `foo()` can be used in expressions like `print("Returned:", foo())`

**Return Statement Variations**

**Value Returns**
```jac
def calculate(x: int, y: int) -> int {
    result = x * y + 10;
    return result;
}
```

**Expression Returns**
```jac
def add(a: int, b: int) -> int {
    return a + b;  # Return expression directly
}
```

**Conditional Returns**
```jac
def absolute(x: int) -> int {
    if x < 0 {
        return -x;
    }
    return x;
}
```

**Void Returns**
```jac
def print_message(msg: str) {
    print(msg);
    return;  # Optional - function ends here
}
```

**Early Returns**

Return statements enable early function exit:

**Guard Clauses**
```jac
def process_data(data: list) -> bool {
    if data is None {
        return false;  # Early exit for invalid input
    }
    if len(data) == 0 {
        return false;  # Early exit for empty data
    }
    # Main processing logic
    return process(data);
}
```

**Error Conditions**
```jac
def divide(a: float, b: float) -> float {
    if b == 0.0 {
        return float('inf');  # Early return for division by zero
    }
    return a / b;
}
```

**Multiple Return Paths**

Functions can have multiple return statements:

**Branching Logic**
```jac
def grade_score(score: int) -> str {
    if score >= 90 {
        return "A";
    } elif score >= 80 {
        return "B";
    } elif score >= 70 {
        return "C";
    } else {
        return "F";
    }
}
```

**Complex Control Flow**
```jac
def search_array(arr: list, target: int) -> int {
    for i=0 to i<len(arr) by i+=1 {
        if arr[i] == target {
            return i;  # Return index when found
        }
    }
    return -1;  # Return -1 when not found
}
```

**Return Types and Type Safety**

Jac enforces return type consistency:

**Type Matching**
```jac
def get_name() -> str {
    return "John";     # Valid: string literal
    # return 42;      # Error: int doesn't match str
}
```

**Multiple Value Returns**
```jac
def get_coordinates() -> (int, int) {
    return (10, 20);   # Return tuple
}

def get_stats() -> dict {
    return {"count": 5, "average": 3.2};
}
```

**Nullable Returns**
```jac
def find_user(id: int) -> User? {
    user = database.find(id);
    if user.exists {
        return user;
    }
    return None;       # Explicit null return
}
```

**Returns in Different Contexts**

**Method Returns**
```jac
obj Calculator {
    def multiply(a: int, b: int) -> int {
        return a * b;
    }
}
```

**Ability Returns**
```jac
walker DataCollector {
    can collect_data with `node entry -> dict {
        data = here.extract_data();
        return data;
    }
}
```

**Lambda Returns**
```jac
square = lambda x: int : x * x;  # Implicit return
```

**Object-Spatial Context Returns**

Returns work within object-spatial programming:

**Walker Method Returns**
```jac
walker Analyzer {
    can analyze with `node entry -> bool {
        if here.is_valid {
            analysis = here.perform_analysis();
            return analysis.is_successful;
        }
        return false;
    }
}
```

**Node Method Returns**
```jac
node DataNode {
    can get_value with Reader entry -> int {
        if visitor.has_permission {
            return self.value;
        }
        return 0;  # Default value for unauthorized access
    }
}
```

**Return Statement Control Flow**

**Function Termination**
- Return immediately exits the function
- No code after return in the same block executes
- Function control returns to the caller

**Nested Block Returns**
```jac
def complex_function(x: int) -> str {
    if x > 0 {
        return "positive";  # Exits entire function
    }
    # This code executes only if x <= 0
    return "non-positive";
}
```

**Loop Returns**
```jac
def find_first_even(numbers: list) -> int {
    for num in numbers {
        if num % 2 == 0 {
            return num;     # Exits function and loop
        }
    }
    return -1;  # No even number found
}
```

**Performance Considerations**

**Early Returns for Efficiency**
```jac
def expensive_computation(data: list) -> bool {
    if len(data) == 0 {
        return false;      # Avoid expensive computation
    }
    # Expensive processing only if needed
    return process_data(data);
}
```

**Avoiding Unnecessary Computation**
```jac
def validate_and_process(input: str) -> str {
    if not is_valid(input) {
        return "Invalid input";  # Skip processing
    }
    return expensive_process(input);
}
```

**Best Practices**

**Clear Return Logic**
```jac
def is_prime(n: int) -> bool {
    if n < 2 {
        return false;
    }
    for i=2 to i*i<=n by i+=1 {
        if n % i == 0 {
            return false;
        }
    }
    return true;
}
```

**Single Responsibility**
```jac
def calculate_tax(income: float) -> float {
    if income <= 0 {
        return 0.0;
    }
    # Single calculation responsibility
    return income * TAX_RATE;
}
```

**Common Patterns**

**Factory Functions**
```jac
def create_user(name: str, age: int) -> User {
    user = User();
    user.name = name;
    user.age = age;
    return user;
}
```

**Transformer Functions**
```jac
def to_uppercase(text: str) -> str {
    return text.upper();
}
```

**Validator Functions**
```jac
def is_valid_email(email: str) -> bool {
    return "@" in email and "." in email;
}
```

**Error Handling with Returns**

```jac
def safe_divide(a: float, b: float) -> (float, str) {
    if b == 0.0 {
        return (0.0, "Division by zero");
    }
    return (a / b, "Success");
}
```

**Integration with Exception Handling**

```jac
def risky_operation() -> int {
    try {
        result = perform_operation();
        return result;
    } except OperationError as e {
        log_error(e);
        return -1;  # Error indicator
    }
}
```

Return statements in Jac provide essential function control flow, enabling clean separation of concerns, early optimization, and clear data flow patterns. The mandatory type annotations ensure return consistency while supporting both simple value returns and complex conditional logic, making functions reliable and type-safe components in Jac applications.
