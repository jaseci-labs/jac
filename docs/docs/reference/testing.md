# Testing Reference

Complete reference for writing and running tests in Jac.

---

## Test Syntax

### Basic Test

```jac
test test_name {
    # Test body
    assert condition;
}
```

### Test with Setup

```jac
test test_with_setup {
    # Setup
    data = prepare_data();
    obj = MyObject(data);

    # Test
    result = obj.process();

    # Assert
    assert result == expected;
}
```

---

## Assertions

### Basic Assert

```jac
assert condition;
assert condition, "Error message";
```

### Equality

```jac
assert a == b;           # Equal
assert a != b;           # Not equal
assert a is b;           # Same object
assert a is not b;       # Different objects
```

### Comparisons

```jac
assert a > b;            # Greater than
assert a >= b;           # Greater or equal
assert a < b;            # Less than
assert a <= b;           # Less or equal
```

### Boolean

```jac
assert True;
assert not False;
assert bool(value);
```

### Membership

```jac
assert item in collection;
assert item not in collection;
assert key in dictionary;
```

### Type Checking

```jac
assert isinstance(obj, MyClass);
assert type(obj) == MyClass;
```

### None Checking

```jac
assert value is None;
assert value is not None;
```

### With Messages

```jac
assert result > 0, f"Expected positive, got {result}";
assert len(items) == 3, "Should have 3 items";
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
jac test main.jac -t test_name
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
jac test main.jac -f "test_user"

# Max failures
jac test -d tests/ -m 3

# Combined
jac test main.jac -t test_add -v
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

test test_calculator_add {
    calc = Calculator();
    assert calc.add(5) == 5;
    assert calc.add(3) == 8;
    assert calc.value == 8;
}

test test_calculator_reset {
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

test test_walker_increments {
    counter = root ++> Counter();
    root spawn Incrementer();
    assert counter[0].count == 1;
}

test test_walker_custom_amount {
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

test test_find_adults {
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

test test_graph_connections {
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

test test_divide_normal {
    assert divide(10, 2) == 5;
}

test test_divide_by_zero {
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
test test_user_valid {
    user = User(name="Alice", email="alice@example.com");
    assert user.is_valid();
}

test test_user_invalid_email {
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

## Best Practices

### 1. Descriptive Names

```jac
# Good
test test_user_creation_with_valid_email { }
test test_walker_visits_all_connected_nodes { }

# Avoid
test test1 { }
test my_test { }
```

### 2. One Focus Per Test

```jac
# Good - focused tests
test test_add_positive_numbers {
    assert add(2, 3) == 5;
}

test test_add_negative_numbers {
    assert add(-2, -3) == -5;
}

# Avoid - too broad
test test_all_math_operations {
    assert add(2, 3) == 5;
    assert subtract(5, 3) == 2;
    assert multiply(2, 3) == 6;
}
```

### 3. Isolate Tests

```jac
# Good - creates fresh state
test test_counter_increment {
    counter = root ++> Counter();
    root spawn Incrementer();
    assert counter[0].count == 1;
}

# Each test should be independent
test test_counter_starts_at_zero {
    counter = Counter();
    assert counter.count == 0;
}
```

### 4. Test Edge Cases

```jac
test test_empty_list {
    result = process([]);
    assert result == [];
}

test test_single_item {
    result = process([1]);
    assert len(result) == 1;
}

test test_large_list {
    result = process(list(range(1000)));
    assert len(result) == 1000;
}
```

### 5. Clear Assertions

```jac
# Good - clear what failed
test test_calculation {
    result = calculate(input);
    assert result == expected, f"Expected {expected}, got {result}";
}

# Avoid - unclear failures
test test_calculation {
    assert calculate(input) == expected;
}
```

---

## Related Resources

- [Testing Tutorial](../tutorials/language/testing.md)
- [CLI Reference](cli/index.md)
