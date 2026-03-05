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

WRONG (Python style):

```
from os import path
from typing import Any
```

WRONG (deprecated Jac v1 syntax -- do NOT use):

```
import:py from os { path }
import:py typing;
```

RIGHT:

```jac
import from os { path }
import from typing { Any }
```

The `import:py` prefix is **removed** from modern Jac. All imports use plain `import` -- Python modules are imported the same way as Jac modules. Never generate `import:py`, `include:jac`, or any colon-tagged import variant.

### 4. Prefer `obj` over Python-style `class`

Jac supports both `obj` (dataclass-like, auto-generates `__init__`, `__eq__`, `__repr__`) and `class` (standard Python class behavior). **Prefer `obj`** unless you specifically need Python class semantics.

WRONG (Python syntax):

```
class Foo:
    pass
```

RIGHT (idiomatic Jac):

```jac
obj Foo {
    has x: int = 5;
}
```

ALSO VALID (when you need Python class behavior):

```jac
class Foo {
    def init(name: str) {
        self.name = name;
    }
}
```

For graph programming, use `node`, `edge`, and `walker` archetypes instead.

### 5. `def` for regular methods, `can` ONLY for event-driven abilities

Use `def` for regular methods in archetypes. The `can` keyword is ONLY for data-spatial abilities that respond to walker entry/exit events --the compiler enforces this with: *"Expected 'with' after 'can' ability name (use 'def' for function-style declarations)"*

WRONG:

```
def my_method(self, x: int) -> int:
    return x + 1
```

RIGHT --regular method:

```jac
obj Foo {
    has x: int = 0;
    def my_method(val: int) -> int {
        return val + 1;
    }
}
```

RIGHT --event-driven ability (uses `can` with `with` clause):

```jac
walker MyWalker {
    can process with MyNode entry {
        report here.value;
        visit [-->];
    }
}
```

For declaration/implementation separation:

```jac
# In .jac file: declare method signature
obj Foo {
    has x: int = 0;
    def my_method(val: int) -> int;
}
```

```jac
# In .impl.jac file: implement it
impl Foo.my_method(val: int) -> int {
    return val + 1;
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

### 7. `enumerate()` requires tuple unpacking with parentheses

`enumerate()` works in Jac, but you MUST wrap the loop variables in parentheses for tuple unpacking.

WRONG:

```
for i, x in enumerate(items) {
    print(i, x);
}
```

RIGHT:

```jac
for (i, x) in enumerate(items) {
    print(i, x);
}
```

### 8. Backtick escaping for keywords used as identifiers

Jac keywords are reserved. To use one as a regular identifier (e.g., a variable or field name), prefix it with a backtick:

```jac
has `type: str;   # "type" is a keyword, backtick lets you use it as a field name
`edge = 5;        # "edge" is a keyword, backtick lets you use it as a variable
```

**However, special variable references do NOT need backtick escaping.** These are built-in references used directly as intended --they are not identifiers that happen to share a keyword name:

- `self` -- current instance
- `super` -- parent class
- `root` -- root node of the graph
- `here` -- current node (in walker abilities)
- `visitor` -- visiting walker (in node/edge abilities)
- `init` -- constructor method name
- `postinit` -- post-constructor method name

WRONG:

```
`self.name = "Alice";
`root ++> node;
def `init() { }
```

RIGHT:

```jac
self.name = "Alice";
root ++> node;
def init() { }
```

Keywords that commonly need backtick escaping when used as identifiers: `type`, `edge`, `node`, `obj`, `test`, `default`, `case`, `visit`, `spawn`, `root`, `entry`, `exit`.

### 9. Mutable objects are passed by reference automatically

In Jac (like Python), mutable objects (lists, dicts) are passed by reference by default. You don't need any special syntax:

```jac
def modify(data: list) -> None {
    data.append(42);
}
```

### 10. Instance variables use `has`, not `self`

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

### 11. Static methods use `static def`

WRONG:

```
obj Foo {
    def bar(self) -> int {
        return 42;
    }
}
```

RIGHT --static method:

```jac
obj Foo {
    static def bar() -> int {
        return 42;
    }
}
```

Or as a standalone module-level function:

```jac
def bar() -> int {
    return 42;
}
```

### 12. String formatting

Jac supports f-strings with the same syntax as Python:

```jac
name = "world";
print(f"Hello, {name}!");
```

### 13. Type annotations are important

Always declare types on `has` declarations:

```jac
has x: int = 5;
has name: str = "";
has items: list[str] = [];
has mapping: dict[str, int] = {};
```

### 14. Boolean literals

Use Python-style `True`/`False`/`None`:

```jac
has active: bool = True;
has data: dict | None = None;
```

### 15. List/Dict comprehensions

```jac
squares = [x ** 2 for x in range(10)];
even = {k: v for (k, v) in items.items() if v % 2 == 0};
```

### 16. Exception handling

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

### 17. Walker definition and visit syntax

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

### 18. Edge definitions

```jac
edge MyEdge {
    has weight: float = 1.0;
}
```

### 19. Graph construction with spawn

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

### 20. Node connections and traversal

```jac
# Connect nodes
a ++> b;                    # default edge
a +>:MyEdge(weight=2.0):+> b;  # typed edge

# Traverse
visit [-->];           # visit all connected nodes
visit [-->](`?B);      # visit only B-type nodes
```

### 21. Walker spawn syntax

```jac
root spawn MyWalker();
```

## File Organization

### 22. Interface/Implementation separation

- `.jac` files contain declarations - method signatures end with `;`
- `.impl.jac` files (in `impl/` subdirectory) contain implementations

Declaration file (`module.jac`):

```jac
obj Calculator {
    has result: float = 0.0;
    def add(x: float) -> float;
    def reset() -> None;
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

### 23. A parse error in .impl.jac breaks the ENTIRE file

A single syntax error in an impl file causes all implementations in that file to produce 0 body items. Always check syntax carefully.

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
