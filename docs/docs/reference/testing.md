# Testing Reference

Complete reference for writing and running tests in Jac.

---

## Test Syntax

### Basic Test

```jac
test my_feature {
    # Test body
    assert condition;
}
```

### Test with Setup

```jac
obj MyObject {
    has data: str;

    def process() -> str {
        return self.data;
    }
}

test object_processing {
    # Setup
    my_obj = MyObject(data="test");

    # Test
    result = my_obj.process();

    # Assert
    assert result == "test";
}
```

---

## Assertions

### Basic Assert

```jac
test basic_assert {
    assert condition;
    assert condition, "Error message";
}
```

### Equality

```jac
test equality_checks {
    assert a == b;           # Equal
    assert a != b;           # Not equal
    assert a is b;           # Same object
    assert a is not b;       # Different objects
}
```

### Comparisons

```jac
test comparisons {
    assert a > b;            # Greater than
    assert a >= b;           # Greater or equal
    assert a < b;            # Less than
    assert a <= b;           # Less or equal
}
```

### Boolean

```jac
test boolean_values {
    assert True;
    assert not False;
    assert bool(value);
}
```

### Membership

```jac
test membership {
    assert item in collection;
    assert item not in collection;
    assert key in dictionary;
}
```

### Type Checking

```jac
test type_checking {
    assert isinstance(obj, MyClass);
    assert type(obj) == MyClass;
}
```

### None Checking

```jac
test none_checking {
    assert value is None;
    assert value is not None;
}
```

### With Messages

```jac
test assertions_with_messages {
    assert result > 0, f"Expected positive, got {result}";
    assert len(items) == 3, "Should have 3 items";
}
```

---

## CLI Commands

### Running Tests

```bash
# Run all tests in a file
jac test main.jac

# Run tests in a directory
jac test -d tests/

# Run specific test
jac test main.jac -t my_feature
```

### CLI Options

| Option | Short | Description |
|--------|-------|-------------|
| `--test_name` | `-t` | Run specific test by name |
| `--filter` | `-f` | Filter tests by pattern |
| `--xit` | `-x` | Exit on first failure |
| `--maxfail` | `-m` | Stop after N failures |
| `--directory` | `-d` | Test directory |
| `--verbose` | `-v` | Verbose output |

### Examples

```bash
# Verbose output
jac test main.jac -v

# Stop on first failure
jac test main.jac -x

# Filter by pattern
jac test main.jac -f "user_"

# Max failures
jac test -d tests/ -m 3

# Combined
jac test main.jac -t calculator_add -v
```

---

## Test Output

### Success

```
unittest.case.FunctionTestCase (test_add) ... ok
unittest.case.FunctionTestCase (test_subtract) ... ok

----------------------------------------------------------------------
Ran 2 tests in 0.001s

OK
```

### Failure

```
unittest.case.FunctionTestCase (test_add) ... FAIL

======================================================================
FAIL: test_add
----------------------------------------------------------------------
AssertionError: Expected 5, got 4

----------------------------------------------------------------------
Ran 1 test in 0.001s

FAILED (failures=1)
```

---

## Testing Patterns

### Testing Objects

```jac
obj Calculator {
    has value: int = 0;

    def add(n: int) -> int {
        self.value += n;
        return self.value;
    }

    def reset() -> None {
        self.value = 0;
    }
}

test calculator_add {
    calc = Calculator();
    assert calc.add(5) == 5;
    assert calc.add(3) == 8;
    assert calc.value == 8;
}

test calculator_reset {
    calc = Calculator();
    calc.add(10);
    calc.reset();
    assert calc.value == 0;
}
```

### Testing Nodes and Walkers

```jac
node Counter {
    has count: int = 0;
}

walker Incrementer {
    has amount: int = 1;

    can start with `root entry {
        visit [-->];
    }

    can increment with Counter entry {
        here.count += self.amount;
    }
}

test walker_increments {
    counter = root ++> Counter();
    root spawn Incrementer();
    assert counter[0].count == 1;
}

test walker_custom_amount {
    counter = root ++> Counter();
    root spawn Incrementer(amount=5);
    assert counter[0].count == 5;
}
```

### Testing Walker Reports

```jac
node Person {
    has name: str;
    has age: int;
}

walker FindAdults {
    can check with `root entry {
        for person in [-->](`?Person) {
            if person.age >= 18 {
                report person;
            }
        }
    }
}

test find_adults {
    root ++> Person(name="Alice", age=30);
    root ++> Person(name="Bob", age=15);
    root ++> Person(name="Carol", age=25);

    result = root spawn FindAdults();

    assert len(result.reports) == 2;
    names = [p.name for p in result.reports];
    assert "Alice" in names;
    assert "Carol" in names;
    assert "Bob" not in names;
}
```

### Testing Graph Structure

```jac
node Room {
    has name: str;
}

edge Door {}

test graph_connections {
    kitchen = Room(name="Kitchen");
    living = Room(name="Living Room");
    bedroom = Room(name="Bedroom");

    root ++> kitchen;
    kitchen +>: Door() :+> living;
    living +>: Door() :+> bedroom;

    # Test connections
    assert len([root -->]) == 1;
    assert len([kitchen -->]) == 1;
    assert living in [kitchen ->:Door:->];
    assert bedroom in [living ->:Door:->];
}
```

### Testing Exceptions

```jac
def divide(a: int, b: int) -> float {
    if b == 0 {
        raise ZeroDivisionError("Cannot divide by zero");
    }
    return a / b;
}

test divide_normal {
    assert divide(10, 2) == 5;
}

test divide_by_zero {
    try {
        divide(10, 0);
        assert False, "Should have raised error";
    } except ZeroDivisionError {
        assert True;  # Expected
    }
}
```

---

## Project Organization

### Separate Test Files

```
myproject/
├── jac.toml
├── src/
│   ├── models.jac
│   └── walkers.jac
└── tests/
    ├── test_models.jac
    └── test_walkers.jac
```

```bash
# Run all tests
jac test -d tests/

# Run specific file
jac test tests/test_models.jac
```

### Tests in Same File

```jac
# models.jac

obj User {
    has name: str;
    has email: str;

    def is_valid() -> bool {
        return len(self.name) > 0 and "@" in self.email;
    }
}

# Tests at bottom
test user_valid {
    user = User(name="Alice", email="alice@example.com");
    assert user.is_valid();
}

test user_invalid_email {
    user = User(name="Alice", email="invalid");
    assert not user.is_valid();
}
```

---

## Configuration

### jac.toml

```toml
[test]
directory = "tests"
verbose = true
fail_fast = false
max_failures = 10
```

---

## JacTestClient

`JacTestClient` provides an in-process HTTP client for testing Jac API endpoints without starting a real server or opening network ports.

### Import

```python
from jaclang.runtimelib.testing import JacTestClient
```

### Creating a Client

```python
# Create from a .jac file
client = JacTestClient.from_file("app.jac")

# With a custom base path (useful for temp directories in tests)
client = JacTestClient.from_file("app.jac", base_path="/tmp/test")
```

### Authentication

```python
# Register a test user
response = client.register_user("testuser", "password123")

# Login
response = client.login("testuser", "password123")

# Manually set auth token
client.set_auth_token("eyJ...")

# Clear auth
client.clear_auth()
```

### Making Requests

```python
# GET request
response = client.get("/walker/get_users")

# POST request with JSON body
response = client.post("/walker/create_user", json={"name": "Alice"})

# PUT request
response = client.put("/walker/update_user", json={"name": "Bob"})

# Generic request
response = client.request("DELETE", "/walker/delete_user", json={"id": "123"})

# With custom headers
response = client.get("/walker/data", headers={"X-Custom": "value"})
```

### TestResponse

Responses from `JacTestClient` are `TestResponse` objects:

| Property/Method | Type | Description |
|----------------|------|-------------|
| `status_code` | `int` | HTTP status code |
| `headers` | `dict` | Response headers |
| `text` | `str` | Raw response body |
| `json()` | `dict` | Parse body as JSON |
| `ok` | `bool` | `True` if status is 2xx |
| `data` | `dict \| None` | Unwrapped data from TransportResponse envelope |

### Full Example

```python
import pytest
from jaclang.runtimelib.testing import JacTestClient

def test_task_crud(tmp_path):
    client = JacTestClient.from_file("app.jac", base_path=str(tmp_path))

    # Register and authenticate
    client.register_user("testuser", "password123")

    # Create
    resp = client.post("/walker/CreateTask", json={"title": "My Task"})
    assert resp.status_code == 200
    assert resp.ok

    # Read
    resp = client.post("/walker/GetTasks")
    data = resp.json()
    assert len(data["reports"]) == 1

    # Cleanup
    client.close()
```

### HMR Testing

Test hot module replacement behavior:

```python
def test_hmr(tmp_path):
    client = JacTestClient.from_file("app.jac", base_path=str(tmp_path))
    client.register_user("user", "pass")

    # Initial state
    resp = client.post("/walker/get_data")
    assert resp.ok

    # Simulate file change and reload
    client.reload()

    # Verify after reload
    resp = client.post("/walker/get_data")
    assert resp.ok

    client.close()
```

---

## Best Practices

### 1. Descriptive Names

```jac
# Good - the 'test' keyword already marks it as a test
test user_creation_with_valid_email { }
test walker_visits_all_connected_nodes { }

# Avoid
test t1 { }
test thing { }
```

### 2. One Focus Per Test

```jac
# Good - focused tests
test add_positive_numbers {
    assert add(2, 3) == 5;
}

test add_negative_numbers {
    assert add(-2, -3) == -5;
}

# Avoid - too broad
test all_math_operations {
    assert add(2, 3) == 5;
    assert subtract(5, 3) == 2;
    assert multiply(2, 3) == 6;
}
```

### 3. Isolate Tests

```jac
# Good - creates fresh state
test counter_increment {
    counter = root ++> Counter();
    root spawn Incrementer();
    assert counter[0].count == 1;
}

# Each test should be independent
test counter_starts_at_zero {
    counter = Counter();
    assert counter.count == 0;
}
```

### 4. Test Edge Cases

```jac
test empty_list {
    result = process([]);
    assert result == [];
}

test single_item {
    result = process([1]);
    assert len(result) == 1;
}

test large_list {
    result = process(list(range(1000)));
    assert len(result) == 1000;
}
```

### 5. Clear Assertions

```jac
# Good - clear what failed
test calculation_with_message {
    result = calculate(input);
    assert result == expected, f"Expected {expected}, got {result}";
}

# Avoid - unclear failures
test calculation_no_message {
    assert calculate(input) == expected;
}
```

---

## Related Resources

- [Testing Tutorial](../tutorials/language/testing.md)
- [CLI Reference](cli/index.md)
