# Testing in Jac

Learn how to write and run tests for your Jac code.

> **Prerequisites**
>
> - Completed: [Jac Basics](basics.md)
> - Time: ~20 minutes

---

## Writing Tests

Jac uses the `test` keyword to define tests:

```jac
def add(a: int, b: int) -> int {
    return a + b;
}

test test_add {
    assert add(2, 3) == 5;
    assert add(-1, 1) == 0;
    assert add(0, 0) == 0;
}
```

**Note:** Test names are identifiers (not strings like in Python's pytest).

---

## Running Tests

```bash
# Run all tests in a file
jac test main.jac

# Run tests in a directory
jac test -d tests/

# Run a specific test
jac test main.jac -t test_add

# Verbose output
jac test main.jac -v

# Stop on first failure
jac test main.jac -x
```

### Test Output

```
unittest.case.FunctionTestCase (test_add) ... ok
unittest.case.FunctionTestCase (test_subtract) ... ok

----------------------------------------------------------------------
Ran 2 tests in 0.001s

OK
```

---

## Assertions

### Basic Assertions

```jac
test test_assertions {
    # Equality
    assert 1 + 1 == 2;
    assert "hello" == "hello";

    # Inequality
    assert 5 != 3;

    # Comparisons
    assert 5 > 3;
    assert 3 < 5;
    assert 5 >= 5;
    assert 5 <= 5;

    # Boolean
    assert True;
    assert not False;

    # Membership
    assert 3 in [1, 2, 3];
    assert "key" in {"key": "value"};
}
```

### Assertions with Messages

```jac
test test_with_messages {
    result = calculate_something();
    assert result > 0, f"Expected positive, got {result}";
}
```

---

## Testing Objects

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

---

## Testing Nodes and Walkers

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

test test_walker_increments_counter {
    # Create graph
    counter = root ++> Counter();

    # Spawn walker
    root spawn Incrementer();

    # Verify
    assert counter[0].count == 1;
}

test test_walker_with_custom_amount {
    counter = root ++> Counter();

    root spawn Incrementer(amount=5);

    assert counter[0].count == 5;
}
```

---

## Testing Walker Reports

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

---

## Testing Graph Structure

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
    assert len([living -->]) == 1;
    assert len([bedroom -->]) == 0;

    # Test connectivity
    assert living in [kitchen ->:Door:->];
    assert bedroom in [living ->:Door:->];
}
```

---

## Test Organization

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

# Run specific test file
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

# Tests at bottom of file
test test_user_valid {
    user = User(name="Alice", email="alice@example.com");
    assert user.is_valid();
}

test test_user_invalid_email {
    user = User(name="Alice", email="invalid");
    assert not user.is_valid();
}

test test_user_empty_name {
    user = User(name="", email="alice@example.com");
    assert not user.is_valid();
}
```

---

## CLI Options

| Option | Short | Description |
|--------|-------|-------------|
| `--test_name` | `-t` | Run specific test by name |
| `--filter` | `-f` | Filter tests by pattern |
| `--xit` | `-x` | Exit on first failure |
| `--maxfail` | `-m` | Stop after N failures |
| `--directory` | `-d` | Test directory |
| `--verbose` | `-v` | Verbose output |

```bash
# Examples
jac test main.jac -t test_add -v
jac test main.jac -f "test_user" -x
jac test -d tests/ -m 3
```

---

## Configuration

Set test defaults in `jac.toml`:

```toml
[test]
directory = "tests"
verbose = true
fail_fast = false
max_failures = 10
```

---

## Best Practices

### 1. Descriptive Test Names

```jac
# Good
test test_user_creation_with_valid_email { }
test test_walker_visits_all_connected_nodes { }

# Avoid
test test1 { }
test my_test { }
```

### 2. One Assertion Focus

```jac
# Good - focused tests
test test_add_positive_numbers {
    assert add(2, 3) == 5;
}

test test_add_negative_numbers {
    assert add(-2, -3) == -5;
}

# Avoid - too many unrelated assertions
test test_add {
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

test test_divide_negative {
    assert divide(-10, 2) == -5;
}
```

---

## Next Steps

- [Language Reference: Testing](../../reference/language/advanced.md) - Complete testing reference
- [AI Integration](../ai/quickstart.md) - Test AI-integrated functions
- [Production Deployment](../production/local.md) - Run as API server
