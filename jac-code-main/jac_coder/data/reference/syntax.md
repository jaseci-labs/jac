# Jac Language Syntax Reference

## Variables and Types

**Builtin types:** int, float, str, bool, bytes, list, tuple, set, dict, any, type, None

**Generic types:** `list[str]`, `dict[str, int]`, `set[int]`, `tuple[str, int]`, `Type | None`

```jac
# Field declarations in archetypes
obj Example {
    has name: str;                    # Required field
    has count: int = 0;              # With default
    has items: list[str] = [];       # Generic type
    has data: dict | None = None;    # Optional
}

# Module-level global
glob config: dict = {};

# Local variables
x: int = 42;      # Annotated
name = "hello";    # Type inferred
```

Type annotations are **required** on `has` fields and function signatures.

## Functions and Methods

```jac
# Standalone function
def greet(name: str, greeting: str = "Hello") -> str {
    return f"{greeting}, {name}!";
}

# Object with methods
obj Person {
    has name: str;
    has age: int = 0;

    def postinit { print(f"Created {self.name}"); }
    def greet() -> str { return f"Hi, I'm {self.name}"; }
    def is_adult() -> bool { return self.age >= 18; }
}

# Inheritance
obj Student(Person) { has grade: str = "A"; }

# Static method
obj Utils {
    static def helper() -> int { return 42; }
}
```

## Enums

```jac
enum Color { RED = "red", GREEN = "green", BLUE = "blue" }
enum Direction { NORTH, SOUTH, EAST, WEST }

# Usage
c = Color.RED;
print(c.value);  # "red"
```

## Control Flow

```jac
# if/elif/else
if x > 0 { print("positive"); }
elif x == 0 { print("zero"); }
else { print("negative"); }

# Inline conditional
result = "yes" if condition else "no";

# Loops
for item in items { print(item); }
for (i, x) in enumerate(items) { print(i, x); }
for (k, v) in my_dict.items() { print(k, v); }
while count < 10 { count += 1; }

# Match/case (uses colons, not braces)
match value {
    case "add":
        result = a + b;
    case "sub":
        result = a - b;
    case _:
        result = 0;
}

# Exception handling
try { result = risky(); }
except ValueError as e { print(f"Error: {e}"); }
finally { cleanup(); }
```

## Comprehensions

```jac
squares = [x ** 2 for x in range(10)];
filtered = [x for x in items if x > 0];
mapping = {k: v for (k, v) in items.items() if v > 0};
```

## String Methods

All Python string methods work in Jac:

```jac
name.lower();  name.upper();  name.strip();
name.split(",");  name.replace("old", "new");
name.startswith("prefix");  name.endswith("suffix");
",".join(items);  name.find("sub");
f"Hello, {name}!";  # f-strings supported
```

## Access Modifiers

| Modifier | Meaning | Use Case |
|----------|---------|----------|
| `:pub` | Public | REST endpoint, importable component/hook |
| `:priv` | Private (auth) | Per-user endpoint, requires login |
| `:protect` | Protected | Module-internal helper |
| *(none)* | Default | Module-scoped, not exposed |

```jac
walker :pub get_tasks { ... }        # Public API
walker :priv add_task { ... }        # Authenticated
def :protect validate(x: str) -> bool { ... }
def:pub get_items() -> list { ... }  # Public function endpoint
```

## Module Entry Point

```jac
with entry {
    print("Module loaded");
    root spawn MyWalker();
}
```

## Imports

```jac
# Python standard library
import from os { path }
import from datetime { datetime }
import from pathlib { Path }
import os;
import json;

# Jac modules (relative)
import from .submodule { Helper }
import from jac_coder.nodes { Session }

# NEVER use import:py — it's deprecated
```
