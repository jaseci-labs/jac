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

test "add" {
    assert add(2, 3) == 5;
    assert add(-1, 1) == 0;
    assert add(0, 0) == 0;
}
```

**Note:** Test names are string descriptions, giving you readable names with spaces and punctuation.

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
test "assertions" {
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
test "with messages" {
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

test "calculator add" {
    calc = Calculator();
    assert calc.add(5) == 5;
    assert calc.add(3) == 8;
    assert calc.value == 8;
}

test "calculator reset" {
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

    can start with Root entry {
        visit [-->];
    }

    can increment with Counter entry {
        here.count += self.amount;
    }
}

test "walker increments counter" {
    # Create graph
    counter = root ++> Counter();

    # Spawn walker
    root spawn Incrementer();

    # Verify
    assert counter[0].count == 1;
}

test "walker with custom amount" {
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
    can check with Root entry {
        for person in [-->](?:Person) {
            if person.age >= 18 {
                report person;
            }
        }
    }
}

test "find adults" {
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

test "graph connections" {
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
test "user valid" {
    user = User(name="Alice", email="alice@example.com");
    assert user.is_valid();
}

test "user invalid email" {
    user = User(name="Alice", email="invalid");
    assert not user.is_valid();
}

test "user empty name" {
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
# Good - readable descriptions
test "user creation with valid email" { }
test "walker visits all connected nodes" { }

# Avoid - vague or cryptic
test "t1" { }
test "thing" { }
```

### 2. One Assertion Focus

```jac
# Good - focused tests
test "add positive numbers" {
    assert add(2, 3) == 5;
}

test "add negative numbers" {
    assert add(-2, -3) == -5;
}

# Avoid - too many unrelated assertions
test "all math operations" {
    assert add(2, 3) == 5;
    assert subtract(5, 3) == 2;
    assert multiply(2, 3) == 6;
}
```

### 3. Isolate Tests

```jac
# Good - creates fresh state
test "counter increment" {
    counter = root ++> Counter();
    root spawn Incrementer();
    assert counter[0].count == 1;
}

# Each test should be independent
test "counter starts at zero" {
    counter = Counter();
    assert counter.count == 0;
}
```

### 4. Test Edge Cases

```jac
test "divide normal" {
    assert divide(10, 2) == 5;
}

test "divide by zero" {
    try {
        divide(10, 0);
        assert False, "Should have raised error";
    } except ZeroDivisionError {
        assert True;  # Expected
    }
}

test "divide negative" {
    assert divide(-10, 2) == -5;
}
```

---

## Next Steps

- [Language Reference: Testing](../../reference/language/advanced.md) - Complete testing reference
- [AI Integration](../ai/quickstart.md) - Test AI-integrated functions
- [Production Deployment](../production/local.md) - Run as API server
