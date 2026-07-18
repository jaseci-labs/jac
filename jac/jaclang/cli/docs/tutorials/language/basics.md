# Jac Basics

This tutorial covers the core syntax and concepts you need to start writing Jac programs. If you're coming from Python, most things will look familiar -- Jac compiles to Python bytecode and shares many of Python's constructs, so your existing knowledge applies directly. The key differences are syntactic (braces instead of indentation, semicolons to end statements) and conceptual (graph-native types, the `has` keyword for fields, `with entry` for entry points).

By the end of this tutorial, you'll be comfortable writing functions, objects, control flow, imports, and simple graph operations in Jac.

> **Prerequisites**
>
> - Completed: [Installation](../../quick-guide/install.md)
> - Familiar with: Python basics
> - Time: ~30 minutes

---

## Jac and Python

Jac compiles to Python bytecode, so all Python libraries work natively and familiar Python concepts apply directly. Jac extends these with new paradigms -- graph-native types, object-spatial programming, and AI-native constructs. The main syntactic differences from Python are:

| Python | Jac |
|--------|-----|
| Indentation blocks | `{ }` braces |
| No semicolons | `;` required |
| `def func():` | `def func() { }` |
| `if x:` | `if x { }` |
| `class Foo:` | `obj Foo { }` |

---

## Variables and Types

Jac supports all the same primitive types as Python (`str`, `int`, `float`, `bool`) and the same collection types (`list`, `dict`, `set`, `tuple`). Type annotations are optional but recommended -- they enable better IDE support, catch errors during `jac check`, and make your code self-documenting.

The `with entry { }` block is Jac's equivalent of Python's `if __name__ == "__main__":` -- it defines the program's entry point and runs when you execute the file with `jac run`.

> **💡 Tip**: Run `jac run -e main.jac` to see type check errors and warnings inline after execution, without needing a separate `jac check` step.

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

Functions in Jac use `def` just like Python, with the body enclosed in braces instead of an indented block. Return type annotations use `-> Type` syntax. Jac also has a `can` keyword for event-triggered abilities on nodes and walkers (covered later in the [OSP tutorial](osp.md)), but for regular standalone functions and methods on objects, use `def`.

### Basic Functions

<div class="code-block" markdown>
def greet(name: str) -> str {
    return f"Hello, {name}!";
}

def add(a: int, b: int) -> int {
    return a + b;
}

with entry {
    message = greet("World");
    print(message);
    result = add(5, 3);
    print(result);
}
</div>

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

!!! warning "Match/case uses Python-style indentation"
    Match case bodies use `case X:` with indentation, not braces. This is the one exception to Jac's brace-based block syntax.

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

Jac uses `obj` instead of Python's `class`. Fields are declared with `has` (replacing Python's `__init__` boilerplate), and constructors are auto-generated from `has` declarations. This means you get dataclass-like convenience by default -- named fields, automatic `__init__`, and default values -- without extra decorators. Methods use `def` with implicit `self`, just like Python.

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

### Typed-Base Enums

`enum X: T { ... }` declares an enum whose members are instances of `T`. `: int` desugars to Python's `IntEnum`, `: str` to `StrEnum`, and any other base `T` to the mixin form `class X(T, Enum)`:

```jac
enum HttpStatus: int { OK = 200, NOT_FOUND = 404 }
enum Tag: str { OPEN = "open", CLOSE = "close" }

with entry {
    print(HttpStatus.OK == 200);          # True -- compare directly
    print(isinstance(Tag.OPEN, str));     # True
    print(HttpStatus.OK + 1);             # 201 -- arithmetic works
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

### Type-Only Imports

When two modules only reference each other in type annotations, a regular `import` creates a circular import at module load. Mark the import with `type` to tell the compiler it's annotation-only:

```jac
import type from billing { Invoice }

def total(inv: Invoice) -> int {
    return inv.amount;
}
```

The generated Python lowers this to `if TYPE_CHECKING: from billing import Invoice` (with `TYPE_CHECKING` imported from `typing`), so the import never runs at runtime and the cycle is broken. Keep `import type` to names you only use in `def` parameter/return types -- decorators like `dataclass` and `Pydantic.BaseModel` resolve annotations on archetype `has` fields at class-definition time and need their types as regular runtime imports.

---

## Global Variables

The `glob` keyword declares module-level variables that are accessible from any function in the file. This is Jac's equivalent of Python's module-level variables, but made explicit with a keyword so you can immediately distinguish global state from local variables when reading code.

```jac
glob config: dict[str, any] = {
    "debug": True,
    "version": "1.0.0"
};

def get_version() -> str {
    return str(config["version"]);
}

with entry {
    print(get_version());  # 1.0.0
}
```

---

## Abilities with `can`

Inside archetypes like `node`, `obj`, and `walker`, you can define **abilities** using the `can` keyword. Abilities are methods that respond to events -- they fire when a walker enters or exits a node:

```jac
node Greeter {
    has name: str;

    can greet with entry {
        print(f"Hello from {self.name}!");
    }
}
```

For regular methods that don't need event triggers, use `def` inside objects (as shown above). The distinction:

| Keyword | Use For | Example |
|---------|---------|---------|
| `def` | Regular methods on objects | `def calculate() -> int { ... }` |
| `can` | Event-triggered abilities on nodes/walkers | `can greet with entry { ... }` |

You'll learn more about `can` in the [OSP tutorial](osp.md).

---

## Access Modifiers

Jac's three access modifiers -- `:pub`, `:protect`, `:priv` -- control *source-level visibility*, and they mean different things depending on where a symbol is declared. For **top-level** functions and walkers, they govern which modules may reference the symbol:

```jac
# Exported -- visible to any module, including consuming projects
def:pub add_task(title: str) -> dict { ...; }

# Project-internal -- visible within this project (same jac.toml root)
def:protect retry(title: str) -> dict { ...; }

# Module-internal -- visible only in this module
def:priv get_tasks -> list { ...; }
```

| Modifier | Top-level visibility | Use Case |
|----------|---------------------|----------|
| `def:pub` | Any module, including a consuming project | Exported library API |
| `def:protect` | Same project (shared `jac.toml`) | Project-internal helper |
| `def:priv` | Declaring module only | Module-internal helper |
| `def` | Declaring module only (default) | Regular functions |

The *same* tags mean something different on a `has`/`def` declared **inside a class** (member encapsulation: `:protect` = subclasses too), and a *separate*, auth-only meaning when a function or walker is served as an HTTP endpoint -- there, **only `:pub` skips authentication** and everything else requires a token. See the [Access Modifiers reference](../../reference/language/access-modifiers.md) for the full three-context model.

These modifiers also apply to walkers (`walker:pub`, `walker:protect`, `walker:priv`).

---

## Preview: Nodes and Graphs

Jac's most distinctive feature is its graph-native type system. Beyond regular objects (`obj`), Jac provides `node`, `edge`, and `walker` types that live in an in-memory graph. Nodes hold data, edges define relationships between them, and walkers traverse the graph executing logic at each step. Here's a quick preview before the full [OSP tutorial](osp.md):

```jac
# A node is like an object that can live in a graph
node Task {
    has title: str;
    has done: bool = False;
}

with entry {
    # Connect nodes to the built-in root node
    root ++> Task(title="Buy groceries");
    root ++> Task(title="Write code");

    # Query connected nodes
    tasks = [root-->][?:Task];
    for t in tasks {
        print(t.title);
    }
}
```

Key differences from `obj`:

- **`node`** instances can be connected in a graph with `++>`
- **`root`** is a built-in starting node -- nodes connected to it persist across restarts
- **`[root-->]`** queries all outgoing connections from root
- **`[?:Task]`** filters by type

---

## Key Takeaways

| Concept | Python | Jac |
|---------|--------|-----|
| Blocks | Indentation | `{ }` braces |
| Statements | No semicolons | `;` required |
| Classes | `class` | `obj` |
| Methods | `def` inside class | `def` inside obj |
| Abilities | N/A | `can` with event triggers |
| Attributes | In `__init__` | `has` declarations |
| Entry point | `if __name__ == "__main__"` | `with entry { }` |
| Module variables | Global vars | `glob` keyword |
| Graph data types | N/A | `node`, `edge` |
| Public APIs | Flask routes | `def:pub` |

---

## Next Steps

- [Object-Spatial Programming](osp.md) - Learn nodes, edges, and walkers
- [Testing](../../reference/testing.md) - Write tests for your Jac code
