# Part VII: Advanced Features

This part covers error handling, testing, and advanced operators like comprehensions and pipes. These features work the same as in Python with minor syntax differences (braces instead of colons, semicolons to end statements).

## 32. Error Handling

Jac uses Python's exception model with `try/except/finally` blocks. The syntax uses braces but the semantics are identical -- catch specific exceptions, optionally capture them with `as`, and use `finally` for cleanup that always runs.

### 32.1 Try/Except/Finally

```jac
try {
    result = risky_operation();
} except ValueError as e {
    print(f"Value error: {e}");
} except KeyError {
    print("Key not found");
} except Exception as e {
    print(f"Unexpected: {e}");
} finally {
    cleanup();
}
```

### 32.2 Raising Exceptions

```jac
def validate(value: int) -> None {
    if value < 0 {
        raise ValueError("Value must be non-negative");
    }
}

def process(data: dict) -> None {
    try {
        inner_process(data);
    } except KeyError as e {
        raise ValueError("Invalid data") from e;
    }
}
```

### 32.3 Assertions

```jac
assert condition;
assert value > 0, "Value must be positive";
assert data is not None, f"Data was None for id {id}";
```

---

## 33. Testing

### 33.1 Test Blocks

```jac
test addition_works {
    result = add(2, 3);
    assert result == 5;
}

test string_operations {
    s = "hello";
    assert len(s) == 5;
    assert "ell" in s;
    assert s.upper() == "HELLO";
}
```

### 33.2 Testing Walkers

```jac
test walker_collects_data {
    # Setup graph
    root ++> DataNode(value=1);
    root ++> DataNode(value=2);
    root ++> DataNode(value=3);

    # Run walker
    result = root spawn Collector();

    # Verify
    assert len(result.reports) == 3;
    assert sum(result.reports) == 6;
}
```

### 33.3 Float Comparison

```jac
test float_comparison {
    result = 0.1 + 0.2;
    assert almostEqual(result, 0.3, places=10);
}
```

### 33.4 JacTestClient

For API testing without starting a server:

```jac
import from jaclang.testing { JacTestClient }

test api_endpoints {
    client = JacTestClient.from_file("main.jac");

    # Register and login
    client.register_user("test@example.com", "password123");
    client.login("test@example.com", "password123");

    # Test endpoint
    response = client.post("/CreateItem", {"name": "Test"});
    assert response.status_code == 200;
    assert response.json()["name"] == "Test";
}
```

### 33.5 Running Tests

```bash
# Run all tests
jac test

# Run specific test
jac test --test-name test_addition

# Stop on first failure
jac test --xit

# Verbose output
jac test --verbose
```

---

## 34. Filter and Assign Comprehensions

### 34.1 Standard Comprehensions

```jac
# List comprehension
squares = [x ** 2 for x in range(10)];

# With condition
evens = [x for x in range(20) if x % 2 == 0];

# Dict comprehension
squared_dict = {x: x ** 2 for x in range(5)};

# Set comprehension
unique_lengths = {len(s) for s in strings};

# Generator expression
gen = (x ** 2 for x in range(1000000));
```

### 34.2 Filter Comprehension Syntax

Filter collections with `?condition`:

```jac
# Filter people by age
adults = people(?age >= 18);

# Multiple conditions
qualified = employees(?salary > 50000, experience >= 5);

# On graph traversal results
friends = [-->](?status == "active");
```

### 34.3 Assign Comprehension Syntax

Modify all items with `=attr=value`:

```jac
# Set attribute on all items
people(=verified=True);

# Chained: filter then assign
people(?age >= 18)(=can_vote=True);

# Multiple assignments
items(=status="processed", processed_at=now());
```

---

## 35. Pipe Operators

### 35.1 Forward Pipe

```jac
# Traditional
result = output(filter(transform(input)));

# With pipes
result = input |> transform |> filter |> output;

# More readable data pipeline
cleaned = raw_data
    |> remove_nulls
    |> normalize
    |> validate
    |> transform;
```

### 35.2 Backward Pipe

```jac
# Right to left
result = output <| filter <| transform <| input;
```

### 35.3 Atomic Pipes (Graph Operations)

```jac
# Depth-first traversal
node spawn :> DepthFirstWalker;

# Breadth-first traversal
node spawn |> BreadthFirstWalker;
```

---
