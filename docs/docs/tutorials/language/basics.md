# Jac Basics

Learn Jac syntax and fundamentals, especially if you're coming from Python.

> **Prerequisites**
>
> - Completed: [Hello World](../../quick-guide/hello-world.md)
> - Familiar with: Python basics
> - Time: ~30 minutes

---

## Jac is a Superset of Python

Jac supersets Python with new paradigms -- familiar Python concepts all apply. The main syntactic differences from Python are:

| Python | Jac |
|--------|-----|
| Indentation blocks | `{ }` braces |
| No semicolons | `;` required |
| `def func():` | `def func() { }` |
| `if x:` | `if x { }` |
| `class Foo:` | `obj Foo { }` |

---

## Variables and Types

### Basic Variables

```jac
with entry {
    # Type inference (like Python)
    name = "Alice";
    age = 30;
    pi = 3.14159;
    active = True;

    # Explicit type annotations (recommended)
    name: str = "Alice";
    age: int = 30;
    pi: float = 3.14159;
    active: bool = True;
}
```

### Collections

```jac
with entry {
    # Lists
    numbers: list[int] = [1, 2, 3, 4, 5];
    numbers.append(6);

    # Dictionaries
    person: dict[str, any] = {
        "name": "Alice",
        "age": 30
    };

    # Sets
    unique: set[int] = {1, 2, 3};

    # Tuples
    point: tuple[int, int] = (10, 20);
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
    message = greet("World");
    print(message);  # Hello, World!

    result = add(5, 3);
    print(result);  # 8
}
```

### Default Parameters

```jac
def greet(name: str, greeting: str = "Hello") -> str {
    return f"{greeting}, {name}!";
}

with entry {
    print(greet("Alice"));           # Hello, Alice!
    print(greet("Bob", "Hi"));       # Hi, Bob!
}
```

### Methods with `def`

Use `def` for methods inside objects:

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

with entry {
    calc = Calculator();
    calc.add(5);
    calc.add(3);
    print(calc.value);  # 8
}
```

---

## Control Flow

### If/Elif/Else

```jac
def classify_number(n: int) -> str {
    if n < 0 {
        return "negative";
    } elif n == 0 {
        return "zero";
    } else {
        return "positive";
    }
}

with entry {
    print(classify_number(-5));  # negative
    print(classify_number(0));   # zero
    print(classify_number(10));  # positive
}
```

### For Loops

```jac
with entry {
    # Iterate over list
    for item in [1, 2, 3] {
        print(item);
    }

    # Range-based loop
    for i in range(5) {
        print(i);  # 0, 1, 2, 3, 4
    }

    # Enumerate
    names = ["Alice", "Bob", "Carol"];
    for (i, name) in enumerate(names) {
        print(f"{i}: {name}");
    }
}
```

### While Loops

```jac
with entry {
    count = 0;
    while count < 5 {
        print(count);
        count += 1;
    }
}
```

### Match (Pattern Matching)

Match case bodies use Python-style indentation, not braces:

```jac
def describe(value: int) -> str {
    match value {
        case 0:
            return "zero";
        case 1 | 2 | 3:
            return "small";
        case _:
            return "medium";
    }
}

with entry {
    print(describe(0));    # zero
    print(describe(2));    # small
    print(describe(50));   # medium
}
```

---

## Objects (Classes)

### Basic Object Definition

```jac
obj Person {
    has name: str;
    has age: int;
    has email: str = "";  # default value

    def introduce() -> str {
        return f"I'm {self.name}, {self.age} years old.";
    }

    def have_birthday() -> None {
        self.age += 1;
    }
}

with entry {
    alice = Person(name="Alice", age=30);
    print(alice.introduce());  # I'm Alice, 30 years old.

    alice.have_birthday();
    print(alice.age);  # 31
}
```

### Inheritance

```jac
obj Animal {
    has name: str;

    def speak() -> str {
        return "...";
    }
}

obj Dog(Animal) {
    has breed: str = "Unknown";

    def speak() -> str {
        return "Woof!";
    }
}

obj Cat(Animal) {
    def speak() -> str {
        return "Meow!";
    }
}

with entry {
    dog = Dog(name="Buddy", breed="Labrador");
    cat = Cat(name="Whiskers");

    print(f"{dog.name} says {dog.speak()}");  # Buddy says Woof!
    print(f"{cat.name} says {cat.speak()}");  # Whiskers says Meow!
}
```

---

## Enums

```jac
enum Color {
    RED,
    GREEN,
    BLUE
}

enum Status {
    PENDING = "pending",
    ACTIVE = "active",
    COMPLETED = "completed"
}

with entry {
    color = Color.RED;
    status = Status.ACTIVE;

    if color == Color.RED {
        print("It's red!");
    }

    print(status.value);  # active
}
```

---

## Error Handling

```jac
def divide(a: float, b: float) -> float {
    if b == 0 {
        raise ValueError("Cannot divide by zero");
    }
    return a / b;
}

with entry {
    try {
        result = divide(10, 0);
    } except ValueError as e {
        print(f"Error: {e}");
    } finally {
        print("Done");
    }
}
```

---

## Importing

### Python Libraries

```jac
import math;
import json;
import os;

with entry {
    print(math.sqrt(16));  # 4.0
    print(os.getcwd());
}
```

### From Imports

```jac
import from collections { Counter, defaultdict }
import from typing { Optional, List }

with entry {
    counts = Counter(["a", "b", "a", "c", "a"]);
    print(counts["a"]);  # 3
}
```

### Jac Modules

```jac
# utils.jac
def helper() -> str {
    return "I'm a helper";
}

# main.jac
import from utils { helper }

with entry {
    print(helper());
}
```

---

## Global Variables

Use `glob` for module-level variables:

```jac
glob config: dict = {
    "debug": True,
    "version": "1.0.0"
};

def get_version() -> str {
    return config["version"];
}

with entry {
    print(get_version());  # 1.0.0
}
```

---

## Key Takeaways

| Concept | Python | Jac |
|---------|--------|-----|
| Blocks | Indentation | `{ }` braces |
| Statements | No semicolons | `;` required |
| Classes | `class` | `obj` |
| Methods | `def` inside class | `def` inside obj |
| Attributes | In `__init__` | `has` declarations |
| Entry point | `if __name__ == "__main__"` | `with entry { }` |
| Module variables | Global vars | `glob` keyword |

---

## Next Steps

- [Object-Spatial Programming](osp.md) - Learn nodes, edges, and walkers
- [Testing](testing.md) - Write tests for your Jac code
