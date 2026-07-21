# Control Flow

**On this page:**

- [Conditionals](#1-conditional-statements), [While Loops](#2-while-loops), [For Loops](#3-for-loops) - Branching and iteration
- [Pattern Matching](#4-pattern-matching) - `match`/`case` destructuring
- [Switch Statement](#5-switch-statement) - Constant-time dispatch
- [Loop Control](#6-loop-control) - `break`, `continue`, loop `else`
- [Context Managers](#7-context-managers) - `with` statements
- [Exception Handling](#8-exception-handling) - `try`/`except`/`finally`
- [Assertions](#9-assertions) - `assert` and invariants
- [Generator Functions](#10-generator-functions) - `yield` and lazy iteration

---

Jac's control flow is familiar to Python developers with a few enhancements: braces instead of indentation, semicolons to end statements, and additional constructs like C-style for loops (`for i = 0 while i < 10 with i += 1`) and `switch` statements. Jac also supports Python's pattern matching (`match/case`) for destructuring complex data.

## 1 Conditional Statements

```jac
def example() {
    condition = True;
    other_condition = False;

    if condition {
        print("condition true");
    } elif other_condition {
        print("other condition");
    } else {
        print("else");
    }

    # Ternary expression
    result = "yes" if condition else "no";
}
```

## 2 While Loops

```jac
def example() {
    count = 0;

    while count < 3 {
        print(count);
        count += 1;
    }

    # With else clause (executes if loop completes normally)
    count = 0;
    while count < 3 {
        count += 1;
    } else {
        print("completed");
    }
}
```

## 3 For Loops

Jac supports Python-style iteration and also adds C-style for loops with explicit initialization, condition, and update expressions separated by semicolons, exactly as in C -- useful when you need precise control over loop variables. The condition may be any expression.

```jac
def example() {
    items = [1, 2, 3];

    # Iterate over collection (Python-style)
    for item in items {
        print(item);
    }

    # With index
    for (i, item) in enumerate(items) {
        print(f"{i}: {item}");
    }

    # C-style for loop: for INIT; CONDITION; UPDATE
    for i = 0 while i < 10 with i += 1 {
        print(i);
    }

    # With else clause
    for item in items {
        if item == 5 {
            break;
        }
    } else {
        print("Not found");
    }
}
```

## 4 Pattern Matching

Pattern matching lets you destructure and test complex data in a single construct. Unlike a chain of `if/elif` statements, `match` can extract values from lists, dicts, and objects while testing their structure. Use it when handling multiple data shapes or implementing state machines.

!!! warning "Common Gotcha"
    Match case bodies use **Python-style indentation**, not braces. The `case` keyword is followed by a colon, and the body is indented -- this is the one place in Jac where indentation matters.

**Basic Patterns:**

```jac
obj Point {
    has x: int = 0;
    has y: int = 0;
}

def example(value: any) {
    match value {
        case 0:
            print("zero");

        case 1 | 2 | 3:
            print("small");

        case [x, y]:
            print(f"pair: {x}, {y}");

        case {"key": v}:
            print(f"dict with key: {v}");

        case Point(x=x, y=y):
            print(f"point at {x}, {y}");

        case _:
            print("default");
    }
}
```

**Advanced Patterns:**

```jac
def example(data: any) {
    match data {
        case [1, *middle, 5]:              # Spread: capture remainder
            print(f"Middle: {middle}");

        case {"key1": 1, **rest}:          # Dict spread
            print(f"Rest: {rest}");

        case [1, 2, last as captured]:     # As: bind to name
            print(f"Captured: {captured}");

        case [1, 2] | [3, 4]:              # Or: match either
            print("Matched");
    }
}
```

**Pattern Types:**

| Pattern | Example | Description |
|---------|---------|-------------|
| Literal | `case 42:` | Match exact value |
| Capture | `case x:` | Capture into variable |
| Wildcard | `case _:` | Match anything, don't capture |
| Sequence | `case [a, b]:` | Match list/tuple structure |
| Mapping | `case {"k": v}:` | Match dict structure |
| Class | `case Point(x, y):` | Match class instance |
| Or | `case 1 \| 2:` | Match any option |
| As | `case x as name:` | Capture with alias |
| Star | `case [first, *rest]:` | Capture sequence remainder |
| Double-star | `case {**rest}:` | Capture dict remainder |

## 5 Switch Statement

```jac
def example(value: int) {
    switch value {
        case 1:
            print("one");

        case 2:
            print("two");

        default:
            print("other");
    }
}
```

Note: Like C, cases fall through to subsequent cases. Use `break` to prevent fall-through.

## 6 Loop Control

```jac
def example() {
    items = [1, 2, 3, 4, 5];

    for item in items {
        if item == 2 {
            continue;    # Skip to next iteration
        }
        if item == 4 {
            break;       # Exit loop
        }
        print(item);
    }
}
```

## 7 Context Managers

```jac
def example() {
    with open("file.txt") as f {
        content = f.read();
    }

    # Multiple context managers
    with open("in.txt") as fin, open("out.txt", "w") as fout {
        fout.write(fin.read());
    }
}
```

## 8 Exception Handling

**Basic try/except:**

```jac
def risky_operation() -> int {
    raise ValueError("error");
}

def example() {
    try {
        result = risky_operation();
    } except ValueError {
        print("Value error occurred");
    }
}
```

**Capturing the exception:**

```jac
import json;

def example(input: str) {
    try {
        data = json.loads(input);
    } except ValueError as e {
        print(f"Parse error: {e}");
    } except KeyError as e {
        print(f"Missing key: {e}");
    }
}
```

**Multiple exception types:**

```jac
def process(data: any) {
    print(data);
}

def example(data: any) {
    try {
        process(data);
    } except (TypeError, ValueError) as e {
        print(f"Type or value error: {e}");
    }
}
```

**Full try/except/else/finally:**

```jac
def example() {
    default_data = "default";
    file = None;
    data = "";

    try {
        file = open("data.txt");
        data = file.read();
    } except FileNotFoundError {
        print("File not found");
        data = default_data;
    } except PermissionError as e {
        print(f"Permission denied: {e}");
        raise;  # Re-raise the exception
    } else {
        # Executes only if no exception occurred
        print(f"Read {len(data)} bytes");
    } finally {
        # Always executes (cleanup)
        if file {
            file.close();
        }
    }
}
```

**Raising exceptions:**

```jac
def validate(input: str) {
    if not input {
        # Raise an exception
        raise ValueError("Invalid input");
    }
}

def process(item: str) {
    try {
        validate(item);
    } except ValueError as e {
        # Re-raise with more context
        raise RuntimeError(f"Failed to process: {item}") from e;
    }
}
```

**Custom exceptions:**

```jac
obj ValidationError(Exception) {
    has field: str;
    has message: str;
}

def validate(data: dict) {
    if "name" not in data {
        raise ValidationError(field="name", message="Name is required");
    }
}
```

## 9 Assertions

Assertions verify conditions during development:

```jac
def example() {
    condition = True;
    items = [1, 2, 3];
    value = 42;

    # Basic assertion
    assert condition;

    # Assertion with message
    assert len(items) > 0, "Items list cannot be empty";

    # Type checking
    assert isinstance(value, int), f"Expected int, got {type(value)}";
}

# Invariant checking in class methods
obj Account {
    has balance: float = 0.0;

    def withdraw(amount: float) {
        assert amount > 0, "Withdrawal amount must be positive";
        assert amount <= self.balance, "Insufficient funds";
        self.balance -= amount;
    }
}
```

**Note:** Assertions can be disabled in production with optimization flags. Use exceptions for validation that must always run.

## 10 Generator Functions

Generators produce values lazily using `yield`:

**Basic generator:**

```jac
def count_up(n: int) -> int {
    for i in range(n) {
        yield i;
    }
}

with entry {
    # Usage
    for num in count_up(5) {
        print(num);  # 0, 1, 2, 3, 4
    }
}
```

**Generator with state:**

```jac
def fibonacci(limit: int) -> int {
    a = 0;
    b = 1;
    while a < limit {
        yield a;
        (a, b) = (b, a + b);
    }
}
```

**yield from (delegation):**

```jac
def flatten(nested: list) -> any {
    for item in nested {
        if isinstance(item, list) {
            yield from flatten(item);  # Delegate to sub-generator
        } else {
            yield item;
        }
    }
}

with entry {
    # Usage
    nested = [[1, 2], [3, [4, 5]], 6];
    flat = list(flatten(nested));  # [1, 2, 3, 4, 5, 6]
}
```

**Generator expressions:**

```jac
def example() {
    # Generator expression (lazy)
    squares = (x ** 2 for x in range(1000000));

    # List comprehension (eager)
    squares_list = [x ** 2 for x in range(100)];
}
```

??? example "Try it: Control flow and generators"
    ```jac
    def fizzbuzz(n: int) -> str {
        if n % 15 == 0 { return "FizzBuzz"; }
        elif n % 3 == 0 { return "Fizz"; }
        elif n % 5 == 0 { return "Buzz"; }
        return str(n);
    }

    def countdown(n: int) -> Generator[int] {
        while n > 0 {
            yield n;
            n -= 1;
        }
    }

    with entry {
        results = [fizzbuzz(i) for i in range(1, 16)];
        print(results);
        print([x for x in countdown(5)]);
    }
    ```
