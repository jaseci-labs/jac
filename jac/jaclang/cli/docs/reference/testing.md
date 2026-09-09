# Testing Reference

Jac has first-class support for testing built directly into the language. Instead of importing a test framework or following naming conventions, you write `test "description" { ... }` blocks right alongside your code. These blocks are ignored during normal execution (`jac run`) and only run when you invoke `jac test`.

Tests in Jac use the standard `assert` statement for all checks. Each test block runs in its own isolated context, so state created in one test (including graph nodes connected to `root`) doesn't leak into another. This isolation means you can test walkers, graph operations, and node behaviors without worrying about test ordering or cleanup -- each test gets a fresh graph.

!!! tip "Graph state and tests"
    If you encounter `NodeAnchor` errors when re-running tests, clear stale persisted state with `jac clean --all` before retrying. The local storage persists graph data between runs, but test isolation resets the in-memory graph for each test block.

---

## Test Syntax

### Basic Test

```jac
test "my feature" {
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

test "object processing" {
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
test "basic assert" {
    assert condition;
    assert condition, "Error message";
}
```

### Equality

```jac
test "equality checks" {
    assert a == b;           # Equal
    assert a != b;           # Not equal
    assert a is b;           # Same object
    assert a is not b;       # Different objects
}
```

### Comparisons

```jac
test "comparisons" {
    assert a > b;            # Greater than
    assert a >= b;           # Greater or equal
    assert a < b;            # Less than
    assert a <= b;           # Less or equal
}
```

### Boolean

```jac
test "boolean values" {
    assert True;
    assert not False;
    assert bool(value);
}
```

### Membership

```jac
test "membership" {
    assert item in collection;
    assert item not in collection;
    assert key in dictionary;
}
```

### Type Checking

```jac
test "type checking" {
    assert isinstance(obj, MyClass);
    assert type(obj) == MyClass;
}
```

### None Checking

```jac
test "none checking" {
    assert value is None;
    assert value is not None;
}
```

### Float Comparison

Jac has no `almostEqual` helper -- compare within a tolerance using `abs()`:

```jac
test "float comparison" {
    result = 0.1 + 0.2;
    assert abs(result - 0.3) < 1e-10;
}
```

### With Messages

```jac
test "assertions with messages" {
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

# Run with no arguments: discovery is scoped to [test] directory
# from jac.toml (falls back to the project root when unset)
jac test
```

!!! note "No-argument discovery"
    With no file and no `-d`, `jac test` reads `directory` from the `[test]`
    section of `jac.toml` and collects tests only from that directory.
    Scoping to `tests/` keeps collection from importing
    application modules whose top-level `with entry` block would otherwise run
    as a side effect of being imported. When `[test] directory` is unset, the
    whole project (from the root) is walked, as before.

### CLI Options

| Option | Short | Description |
|--------|-------|-------------|
| `--test_name` | `-t` | Run specific test by name |
| `--filter` | `-f` | Select tests by name expression (`and`/`or`/`not`, parens) |
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

!!! tip "File naming"
    Avoid naming `.jac` files with a `test_` prefix (e.g., `test_utils.jac`), as this can conflict with Python's module import system. Use descriptive names like `utils_tests.jac` or `my_app.jac` instead.

---

## Tests and Codespaces

A `test` block runs in the codespace its surrounding context compiles to, so tests exercise the same semantics as the code beside them:

| Context | Where the test runs |
|---------|---------------------|
| Server-placed module (the default) | Python runtime (unittest) |
| Native-placed module | Native code via the LLVM JIT |
| Client-placed module (inferred or pinned) | JavaScript runtime via bun |

All of them report through the same `jac test` pass/fail pipeline, and the CLI options above apply uniformly. A test in a native-placed module compiles to native code and runs with native semantics -- a failing `assert` reports the failing source location (`file:line`). See [Native Compilation -- Testing](language/native-pathway.md#testing) for native-specific details and limitations.

---

## Tests in a Workspace

In a project with several [apps](apps.md), `jac test` takes an app name the
way `jac run` does. `jac test social_graph` reads `[test]` from that app's
effective config (its `[apps.social_graph.test]` overlay over the base table)
and resolves `directory` / `directories` against the app root; a bare
`jac test` targets `[project] default-app`, or the sole app. Tests under
shared code belong to no app and run with the base `[test]` table.

The compiler stamps the app's facts onto every module it tests, so the same
laws hold in a test as in the app itself: a test in app A cannot reach app B
except through B's walkers and `def:pub` functions, and a bridged call in a
test is awaited exactly as it is in the app. A test that needs two apps
talking runs the consumer's tests with the providers colocated, which is what
`jac run <app>` does by default.

---

## Test Output

One character per test: `.` passed, `s` skipped, `F` failed, `E` errored,
`!` the worker process died while running that file.

### Success

```
..s.....

7 passed, 1 skipped in 0.42s
```

### Failure

Each failure prints as `FAILED <file>::<test name>`, followed by a traceback
trimmed to your own frames, then anything the test wrote to stdout or stderr
(captured and discarded for passing tests).

```
..F.

FAILED tests/test_math.jac::adds two numbers
  tests/test_math.jac:12 in test_adds_two_numbers
    assert add(2, 2) == 5;
E   AssertionError: assertion failed at tests/test_math.jac:12

3 passed, 1 failed in 0.38s
```

Use `-v` for one line per test instead of the progress characters.

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

### Testing Nodes and Walkers

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

test "walker increments" {
    counter = root ++> Counter();
    root spawn Incrementer();
    assert counter.count == 1;
}

test "walker custom amount" {
    counter = root ++> Counter();
    root spawn Incrementer(amount=5);
    assert counter.count == 5;
}
```

### Testing Walker Reports

```jac
node Person {
    has name: str;
    has age: int;
}

walker FindAdults {
    can check with Root entry {
        for person in [-->][?:Person] {
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

### Testing Graph Structure

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

### Testing Exceptions

```jac
def divide(a: int, b: int) -> float {
    if b == 0 {
        raise ZeroDivisionError("Cannot divide by zero");
    }
    return a / b;
}

test "divide normal" {
    assert divide(10, 2) == 5;
}

test "divide by zero" {
    with testraises(ZeroDivisionError) {
        divide(10, 0);
    }
}

test "divide by zero explains itself" {
    with testraises(ZeroDivisionError) as ei {
        divide(10, 0);
    }
    assert "Cannot divide by zero" in str(ei.value);
}

test "divide negative" {
    assert divide(-10, 2) == -5;
}
```

---

## Skipping a Test

`testskip` abandons the current test and reports it as skipped rather than
passed or failed. Use it for environment gates. (`skip` on its own is a Jac
keyword -- the walker skip statement -- hence the name.)

```jac
test "builds a shared library" {
    import shutil;
    if not shutil.which("gcc") {
        testskip("gcc not installed");
    }
    assert build_shared_lib().ok;
}
```

`testfail` is the counterpart for a branch that should be unreachable:

```jac
test "parser attaches a location to every node" {
    for node_ in parse(src).walk() {
        if node_.loc is None {
            testfail(f"{node_} has no location");
        }
    }
}
```

`testskip`, `testfail` and `testraises` are ambient -- usable in any `test`
block with no import.

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
    ├── models_test.jac
    └── walkers_test.jac
```

```bash
# Run all tests
jac test -d tests/

# Run specific file
jac test tests/models_test.jac
```

Tests under `tests/` import the modules they exercise with the **same
project-root-absolute path** they would use from the root - no `..` dots:

```jac
# tests/models_test.jac
import from src.models { User }   # resolves from the project root, any depth
```

Imports anchor to the project root (the nearest `jac.toml`), so a test file can
move between directories without rewriting its imports.

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
from jaclang.testing.testing import JacTestClient
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

```jac
import tempfile;
import from jaclang.testing.testing { JacTestClient }

test "task crud" {
    client = JacTestClient.from_file("app.jac", base_path=tempfile.mkdtemp());
    try {
        # Register and authenticate
        client.register_user("testuser", "password123");

        # Create
        resp = client.post("/walker/CreateTask", json={"title": "My Task"});
        assert resp.status_code == 200;
        assert resp.ok;

        # Read
        resp = client.post("/walker/GetTasks");
        data = resp.json();
        assert len(data["reports"]) == 1;
    } finally {
        client.close();
    }
}
```

### HMR Testing

Test hot module replacement behavior:

```jac
test "hmr" {
    client = JacTestClient.from_file("app.jac", base_path=tempfile.mkdtemp());
    try {
        client.register_user("user", "pass");

        # Initial state
        assert client.post("/walker/get_data").ok;

        # Simulate file change and reload
        client.reload();

        # Verify after reload
        assert client.post("/walker/get_data").ok;
    } finally {
        client.close();
    }
}
```

---

## Parameterized Tests

The `parametrize()` helper registers one test per parameter. It creates individual test cases from a list of inputs, so each case runs and reports independently.

### Import

```jac
import from jaclang.testing.test { parametrize }
```

### Signature

```
parametrize(base_name: str, params: Iterable, test_func: Callable, id_fn: Callable | None = None)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `base_name` | `str` | Base name for the generated tests |
| `params` | `Iterable` | List of parameter values, each passed to the test function |
| `test_func` | `Callable` | Test function to invoke with each parameter |
| `id_fn` | `Callable \| None` | Optional function to generate test IDs from each parameter |

### Usage

Define a test function that takes a single parameter, then call `parametrize()` in a `with entry` block:

```jac
import from jaclang.testing.test { parametrize }

def _test_square(pair: tuple) {
    input_val = pair[0];
    expected = pair[1];
    result = input_val ** 2;
    assert result == expected, f"Expected {expected}, got {result}";
}

with entry {
    parametrize(
        "square",
        [(2, 4), (3, 9), (0, 0), (-1, 1)],
        _test_square
    );
}
```

This registers four tests: `square_0`, `square_1`, `square_2`, `square_3`.

### Custom Test IDs

Use `id_fn` to generate descriptive test names:

```jac
import from jaclang.testing.test { parametrize }

def _test_parse(raw: str) {
    # test logic
}

with entry {
    parametrize(
        "parse values",
        ["500m", "2", "250"],
        _test_parse,
        id_fn=lambda (p: str) -> str { return f"input_{p}"; }
    );
}
```

---

## Best Practices

### 1. Descriptive Names

```jac
# Good - use readable descriptions
test "user creation with valid email" { }
test "walker visits all connected nodes" { }

# Avoid - vague or cryptic names
test "t1" { }
test "thing" { }
```

### 2. One Focus Per Test

```jac
# Good - focused tests
test "add positive numbers" {
    assert add(2, 3) == 5;
}

test "add negative numbers" {
    assert add(-2, -3) == -5;
}

# Avoid - too broad
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
    assert counter.count == 1;
}

# Each test should be independent
test "counter starts at zero" {
    counter = Counter();
    assert counter.count == 0;
}
```

### 4. Test Edge Cases

```jac
test "empty list" {
    result = process([]);
    assert result == [];
}

test "single item" {
    result = process([1]);
    assert len(result) == 1;
}

test "large list" {
    result = process(list(range(1000)));
    assert len(result) == 1000;
}
```

### 5. Clear Assertions

```jac
# Good - clear what failed
test "calculation with message" {
    result = calculate(input);
    assert result == expected, f"Expected {expected}, got {result}";
}

# Avoid - unclear failures
test "calculation no message" {
    assert calculate(input) == expected;
}
```

---

## Related Resources

- [CLI Reference](cli/index.md)
- [Native Compilation -- Testing](language/native-pathway.md#testing)
