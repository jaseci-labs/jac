# Syntax & Basics

Jac is a **native superset of Python** - all valid Python code is valid Jac code. Jac adds modern syntax features, mandatory typing, and new paradigms while compiling to standard Python bytecode.

## Key Differences from Python

| Feature | Python | Jac |
|---------|--------|-----|
| Type annotations | Optional | **Required** |
| Code blocks | Indentation | `{ }` braces |
| Statement terminator | Newline | `;` semicolon |
| Comments | `#` single, `"""` multi | `#` single, `#* *#` multi |
| Object definition | `class` | `obj` (also `node`, `edge`, `walker`) |
| Access control | Convention (`_prefix`) | Keywords (`:pub`, `:priv`, `:protect`) |

---

## Variables & Types

Jac requires explicit type annotations for all variables.

### Basic Types

```jac
with entry {
    # Primitives
    name: str = "Alice";
    age: int = 25;
    height: float = 5.8;
    active: bool = True;

    # Collections
    items: list[str] = ["a", "b", "c"];
    scores: dict[str, int] = {"math": 95, "science": 88};
    coords: tuple[int, int] = (10, 20);
    unique: set[int] = {1, 2, 3};

    # Optional types
    maybe_value: int | None = None;
}
```

### Global Variables

```jac
glob VERSION: str = "1.0.0";
glob MAX_ITEMS: int = 100;

def get_version() -> str {
    :g: VERSION;  # Access global
    return VERSION;
}
```

---

## Functions

### Basic Functions

```jac
def greet(name: str) -> str {
    return f"Hello, {name}!";
}

def add(a: int, b: int) -> int {
    return a + b;
}

with entry {
    print(greet("World"));
    print(add(2, 3));
}
```

### Default Parameters

```jac
def greet(name: str, greeting: str = "Hello") -> str {
    return f"{greeting}, {name}!";
}
```

### Multiple Return Values

```jac
def divide_with_remainder(a: int, b: int) -> tuple[int, int] {
    return (a // b, a % b);
}

with entry {
    (quotient, remainder) = divide_with_remainder(10, 3);
    print(f"{quotient} remainder {remainder}");
}
```

### Async Functions

```jac
async def fetch_data(url: str) -> str {
    # Async operations
    return "data";
}
```

### Lambda Expressions

Jac supports lambda expressions with explicit type annotations.

```jac
# Without parameters
callback = lambda -> None { print("Hello"); };

# With single parameter
double = lambda x: int -> int { return x * 2; };

# With multiple parameters
add = lambda x: int, y: int -> int { return x + y; };
```

**Common Use Cases:**

```jac
with entry {
    numbers: list[int] = [1, 2, 3, 4, 5];

    # Map operation
    doubled = [x * 2 for x in numbers];

    # Filter with lambda
    evens = list(filter(lambda x: int -> bool { return x % 2 == 0; }, numbers));

    # Sort with key
    items: list[str] = ["banana", "apple", "cherry"];
    items.sort(key=lambda s: str -> int { return len(s); });
}
```

**In Client-Side Code (JSX):**

When using lambdas in client-side `cl { }` blocks for event handlers:

```jac
cl {
    def:pub app() -> any {
        has count: int = 0;

        return <div>
            {# No parameters #}
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>

            {# With event parameter #}
            <input onChange={lambda e: any -> None { console.log(e.target.value); }} />
        </div>;
    }
}
```

**Multi-statement Lambdas:**

```jac
process = lambda x: int -> int {
    doubled = x * 2;
    result = doubled + 1;
    return result;
};
```

---

## Control Flow

### Conditionals

```jac
with entry {
    x: int = 10;

    if x < 5 {
        print("small");
    } elif x < 15 {
        print("medium");
    } else {
        print("large");
    }
}
```

### Pattern Matching

```jac
with entry {
    value: int = 2;

    match value {
        case 1:
            print("one");
        case 2:
            print("two");
        case _:
            print("other");
    }
}
```

### For Loops

```jac
with entry {
    # Iterate over collection
    items: list[str] = ["a", "b", "c"];
    for item in items {
        print(item);
    }

    # Range-based loop (Jac-specific syntax)
    for i = 0 to i < 5 by i += 1 {
        print(i);
    }
}
```

### While Loops

```jac
with entry {
    count: int = 0;
    while count < 3 {
        print(count);
        count += 1;
    }
}
```

---

## Objects (Classes)

### Basic Object Definition

```jac
obj Person {
    has name: str;
    has age: int;

    def greet() -> str {
        return f"Hello, I'm {self.name}";
    }
}

with entry {
    p = Person(name="Alice", age=30);
    print(p.greet());
}
```

### Access Modifiers

```jac
obj Account {
    has :pub name: str;           # Public (default)
    has :priv balance: float;     # Private
    has :protect id: str;         # Protected

    def :pub get_balance() -> float {
        return self.balance;
    }
}
```

### Inheritance

```jac
obj Animal {
    has name: str = "Animal";

    def speak() -> str {
        return "...";
    }
}

obj Dog(Animal) {
    def speak() -> str {
        return "Woof!";
    }
}

with entry {
    d = Dog(name="Rex");
    print(d.speak());  # Woof!
}
```

---

## Imports

### Import Patterns

```jac
# Absolute import
import os;
import json;

# Import with alias
import datetime as dt;

# From-import (specific items)
import from math { sqrt, pi };

# From-import with alias
import from collections { defaultdict as dd };

# Include all (wildcard) - use sparingly
include utils;
```

### Jac-Python Interoperability

```jac
# Import Python modules
import requests;
import numpy as np;

# Import from Jac files (no extension needed)
import from mymodule { MyClass, my_function };
```

---

## Entry Points

### Main Entry Point

```jac
# Runs when file is executed directly
with entry {
    print("Hello, World!");
}
```

### Conditional Entry (like Python's `if __name__ == "__main__"`)

```jac
with entry:__main__ {
    print("Only runs when this file is the main module");
}
```

---

## Operators

### Arithmetic

```jac
with entry {
    a: int = 10;
    b: int = 3;

    print(a + b);   # Addition: 13
    print(a - b);   # Subtraction: 7
    print(a * b);   # Multiplication: 30
    print(a / b);   # Division: 3.333...
    print(a // b);  # Integer division: 3
    print(a % b);   # Modulo: 1
    print(a ** b);  # Power: 1000
}
```

### Comparison

```jac
with entry {
    print(5 == 5);   # Equal: True
    print(5 != 3);   # Not equal: True
    print(5 > 3);    # Greater than: True
    print(5 < 3);    # Less than: False
    print(5 >= 5);   # Greater or equal: True
    print(5 <= 3);   # Less or equal: False
}
```

### Logical

```jac
with entry {
    print(True and False);  # False
    print(True or False);   # True
    print(not True);        # False
}
```

### Pipe Operator (Jac-specific)

```jac
def double(x: int) -> int { return x * 2; }
def add_one(x: int) -> int { return x + 1; }

with entry {
    # Pipe left-to-right
    result = 5 |> double |> add_one;
    print(result);  # 11

    # Pipe to print
    "Hello" |> print;
}
```

---

## Collections

### Lists

```jac
with entry {
    fruits: list[str] = ["apple", "banana", "cherry"];

    # Access
    print(fruits[0]);     # apple
    print(fruits[-1]);    # cherry

    # Slice
    print(fruits[0:2]);   # ["apple", "banana"]

    # Modify
    fruits.append("date");
    fruits.remove("banana");
}
```

### Dictionaries

```jac
with entry {
    person: dict[str, any] = {
        "name": "Alice",
        "age": 30,
        "city": "NYC"
    };

    # Access
    print(person["name"]);

    # Modify
    person["email"] = "alice@example.com";

    # Iterate
    for key in person.keys() {
        print(f"{key}: {person[key]}");
    }
}
```

### List Comprehensions

```jac
with entry {
    # Basic comprehension
    squares: list[int] = [x ** 2 for x in range(5)];

    # With filter
    evens: list[int] = [x for x in range(10) if x % 2 == 0];

    print(squares);  # [0, 1, 4, 9, 16]
    print(evens);    # [0, 2, 4, 6, 8]
}
```

---

## Error Handling

```jac
with entry {
    try {
        result = 10 / 0;
    } except ZeroDivisionError as e {
        print(f"Error: {e}");
    } finally {
        print("Cleanup");
    }
}
```

---

## Comments

```jac
# Single-line comment

#*
    Multi-line
    comment block
*#

"""Docstrings work like Python"""
```

---

## Learn More

| Topic | Resource |
|-------|----------|
| Python Superset Details | [Jac as Python Superset](../../learn/superset_python.md) |
| Variables & Types | [Chapter 2: Variables & Types](../../jac_book/chapter_2.md) |
| Functions & Control Flow | [Chapter 3: Functions & Control](../../jac_book/chapter_3.md) |
| Import System | [Import Basics](../../learn/imports/basics.md) |
| Complete Reference | [Syntax Quick Reference](../../learn/syntax_quick_reference.md) |
| Full Specification | [Jac Language Reference](../../learn/jac_ref.md) |
