# Jac Pitfalls for AI Models

Common mistakes AI models make when generating Jac code. Each entry shows the WRONG pattern and the correct Jac syntax.

## Syntax Differences from Python

### 1. Semicolons are required on ALL statements

WRONG:

```
x = 5
print(x)
```

RIGHT:

```jac
x = 5;
print(x);
```

### 2. Braces for blocks, not indentation

WRONG:

```
if x > 5:
    print(x)
```

RIGHT:

```jac
if x > 5 {
    print(x);
}
```

### 3. Import syntax is different

WRONG:

```
from os import path
from typing import Any
```

RIGHT:

```jac
import from os { path }
import from typing { Any }
```

### 4. Class declaration uses `obj` (or `node`/`edge`/`walker`)

WRONG:

```
class Foo:
    pass
```

RIGHT:

```jac
obj Foo {
}
```

### 5. Methods use `can` keyword in archetypes

WRONG:

```
def my_method(self, x: int) -> int:
    return x + 1
```

RIGHT:

```jac
can my_method(x: int) -> int;  # in .jac declaration
```

```jac
impl Foo.my_method(x: int) -> int {  # in .impl.jac
    return x + 1;
}
```

### 6. Constructor is `def init`, not `def __init__`

WRONG:

```
def __init__(self, x: int):
    self.x = x
```

RIGHT:

```jac
obj Foo {
    has x: int;
    def init(x: int) {
        super.init();
        self.x = x;
    }
}
```

NOTE: You must explicitly call `super.init()` in the init body. Without a `def init`, the compiled class gets an empty `__init__`.

### 7. No `enumerate()` in for loops

WRONG:

```
for i, x in enumerate(items) {
    print(i, x);
}
```

RIGHT:

```jac
for i in range(len(items)) {
    print(i, items[i]);
}
```

### 8. `<>` prefix means ByRef (mutable parameter)

```jac
can modify(<>data: list) -> None;
```

This passes `data` by reference so the function can mutate it.

### 9. Instance variables use `has`, not `self`

WRONG:

```
obj Foo {
    def init(self) {
        self.x = 5;
    }
}
```

RIGHT:

```jac
obj Foo {
    has x: int = 5;
}
```

### 10. Static methods don't use `self`

WRONG:

```
obj Foo {
    can bar(self) -> int {
        return 42;
    }
}
```

For standalone functions, just define them at module level:

```jac
can bar -> int {
    return 42;
}
```

### 11. String formatting

Jac supports f-strings with the same syntax as Python:

```jac
name = "world";
print(f"Hello, {name}!");
```

### 12. Type annotations are important

Always declare types on `has` declarations:

```jac
has x: int = 5;
has name: str = "";
has items: list[str] = [];
has mapping: dict[str, int] = {};
```

### 13. Boolean literals

Use Python-style `True`/`False`/`None`:

```jac
has active: bool = True;
has data: dict | None = None;
```

### 14. List/Dict comprehensions

```jac
squares = [x ** 2 for x in range(10)];
even = {k: v for (k, v) in items.items() if v % 2 == 0};
```

### 15. Exception handling

```jac
try {
    risky_operation();
} except ValueError as e {
    print(f"Error: {e}");
} finally {
    cleanup();
}
```

## Data-Spatial Gotchas

### 16. Walker definition and visit syntax

WRONG:

```
walker MyWalker {
    visit node.children;
}
```

RIGHT:

```jac
walker MyWalker {
    can visit_node with Node entry {
        visit [-->];
    }
}
```

### 17. Edge definitions

```jac
edge MyEdge {
    has weight: float = 1.0;
}
```

### 18. Graph construction with spawn

```jac
node A {
    has value: int = 0;
}
node B {
    has label: str = "";
}

with entry {
    a = A(value=1);
    b = B(label="hello");
    a ++> b;  # Connect a to b with default edge
}
```

### 19. Node connections and traversal

```jac
# Connect nodes
a ++> b;                    # default edge
a +>:MyEdge(weight=2.0):+> b;  # typed edge

# Traverse
visit [-->];           # visit all connected nodes
visit [-->](`?B);      # visit only B-type nodes
```

### 20. Walker spawn syntax

```jac
root spawn MyWalker();
```

## File Organization

### 21. Interface/Implementation separation

- `.jac` files contain declarations - method signatures end with `;`
- `.impl.jac` files (in `impl/` subdirectory) contain implementations

Declaration file (`module.jac`):

```jac
obj Calculator {
    has result: float = 0.0;
    can add(x: float) -> float;
    can reset -> None;
}
```

Implementation file (`impl/module.impl.jac`):

```jac
impl Calculator.add(x: float) -> float {
    self.result += x;
    return self.result;
}

impl Calculator.reset -> None {
    self.result = 0.0;
}
```

### 22. A parse error in .impl.jac breaks the ENTIRE file

A single syntax error in an impl file causes all implementations in that file to produce 0 body items. Always check syntax carefully.

### 23. Must clear caches when modifying .jac files

Delete `__jac_gen__` and `__pycache__` directories when making changes to `.jac` or `.impl.jac` files to avoid stale cached bytecode.

### 24. Module entry point

Use `with entry { }` for code that runs when the module is executed:

```jac
with entry {
    print("Hello, World!");
}
```

### 25. Global variables

Use `glob` for module-level variables:

```jac
glob MAX_SIZE = 100;
glob config: dict = {};
```
