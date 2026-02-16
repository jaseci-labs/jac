# Part VII: Advanced Features

**In this part:**

- [Error Handling](#error-handling) - Try/except/finally, raising exceptions
- [Testing](#testing) - Test blocks, JacTestClient
- [Filter and Assign Comprehensions](#filter-and-assign-comprehensions) - List/dict comprehensions, typed filters
- [Pipe Operators](#pipe-operators) - Forward/backward pipes

---

This part covers error handling, testing, and advanced operators like comprehensions and pipes. These features work the same as in Python with minor syntax differences (braces instead of colons, semicolons to end statements).

## Error Handling

Jac uses Python's exception model with `try/except/finally` blocks. The syntax uses braces but the semantics are identical -- catch specific exceptions, optionally capture them with `as`, and use `finally` for cleanup that always runs.

### 1 Try/Except/Finally

```jac
def risky_operation() -> int {
    return 42;
}

def cleanup() -> None {
    # Cleanup logic here
}

def example() {
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
}
```

### 2 Raising Exceptions

```jac
def inner_process(data: dict) -> None {
    # Process data here
}

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

### 3 Assertions

```jac
def example() {
    condition = True;
    value = 10;
    data: object = "something";
    id = 1;

    assert condition;
    assert value > 0, "Value must be positive";
    assert data is not None, f"Data was None for id {id}";
}
```

---

## Testing

### 1 Test Blocks

```jac
test "addition works" {
    result = add(2, 3);
    assert result == 5;
}

test "string operations" {
    s = "hello";
    assert len(s) == 5;
    assert "ell" in s;
    assert s.upper() == "HELLO";
}
```

### 2 Testing Walkers

```jac
test "walker collects data" {
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

### 3 Float Comparison

```jac
test "float comparison" {
    result = 0.1 + 0.2;
    assert almostEqual(result, 0.3, places=10);
}
```

### 4 JacTestClient

For API testing without starting a server:

```jac
import from jaclang.testing { JacTestClient }

test "api endpoints" {
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

### 5 Running Tests

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

## Filter and Assign Comprehensions

### 1 Standard Comprehensions

```jac
def example() {
    # List comprehension
    squares = [x ** 2 for x in range(10)];

    # With condition
    evens = [x for x in range(20) if x % 2 == 0];

    # Dict comprehension
    squared_dict = {x: x ** 2 for x in range(5)};

    # Set comprehension
    strings = ["hello", "world", "hi"];
    unique_lengths = {len(s) for s in strings};

    # Generator expression
    gen = (x ** 2 for x in range(1000000));
}
```

### 2 Filter Comprehension Syntax

Filter collections with `?condition`:

```jac
node Person {
    has age: int,
        status: str;
}

node Employee {
    has salary: int,
        experience: int;
}

def example(people: list[Person], employees: list[Employee]) {
    # Filter people by age
    adults = people(?age >= 18);

    # Multiple conditions
    qualified = employees(?salary > 50000, experience >= 5);

    # On graph traversal results
    friends = [-->](?status == "active");
}
```

### 3 Typed Filter Comprehensions

Filter by type with filter syntax:

```jac
node Dog {
    has name: str;
}

node Cat {
    has indoor: bool;
}

node Person {
    has age: int;
}

def example(animals: list) {
    dogs = animals(?:Dog);                    # By type only
    indoor_cats = animals(?:Cat, indoor==True); # Type with condition
    people = [-->](?:Person);                 # On graph traversal
    adults = [-->](?:Person, age > 21);        # Traversal with condition
}
```

### 4 Assign Comprehension Syntax

Modify all items with `=attr=value`:

```jac
node Person {
    has age: int,
        verified: bool = False,
        can_vote: bool = False;
}

node Item {
    has status: str,
        processed_at: str;
}

def now() -> str {
    return "2024-01-01";
}

def example(people: list[Person], items: list[Item]) {
    # Set attribute on all items
    people(=verified=True);

    # Chained: filter then assign
    people(?age >= 18)(=can_vote=True);

    # Multiple assignments
    items(=status="processed", processed_at=now());
}
```

---

## Pipe Operators

### 1 Forward Pipe

```jac
def transform(x: list) -> list { return x; }
def filter(x: list) -> list { return x; }
def output(x: list) -> list { return x; }
def remove_nulls(x: list) -> list { return x; }
def normalize(x: list) -> list { return x; }
def validate(x: list) -> list { return x; }

def example() {
    input = [1, 2, 3];
    raw_data = [1, 2, 3];

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
}
```

### 2 Backward Pipe

```jac
def transform(x: list) -> list { return x; }
def filter(x: list) -> list { return x; }
def output(x: list) -> list { return x; }

def example() {
    input = [1, 2, 3];

    # Right to left
    result = output <| filter <| transform <| input;
}
```

### 3 Atomic Pipes (Graph Operations)

```jac
node Item {}

walker DepthFirstWalker {
    can visit with Item entry {
        print("depth first");
    }
}
walker BreadthFirstWalker {
    can visit with Item entry {
        print("breadth first");
    }
}

with entry {
    start = Item();

    # Depth-first traversal
    start spawn :> DepthFirstWalker();

    # Breadth-first traversal
    start spawn |> BreadthFirstWalker();
}
```

---

## Learn More

**Tutorials:**

- [Testing](../../tutorials/language/testing.md) - Write and run tests

**Related Reference:**

- [Part I: Foundation](foundation.md) - Core language features
- [Part III: OSP](osp.md) - Graph operations
