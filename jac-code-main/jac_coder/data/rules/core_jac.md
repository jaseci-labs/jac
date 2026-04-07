# Core Jac Pitfalls — WRONG → RIGHT

> Jac is NOT Python. These are the mistakes LLMs consistently make.
> Read every entry. Each one will save you a broken build.

---

## 1. Semicolons are required on ALL statements

```
WRONG:
x = 5
print(x)

RIGHT:
x = 5;
print(x);
```

---

## 2. Braces for blocks, not indentation

```
WRONG:
if x > 5:
    print(x)

RIGHT:
if x > 5 {
    print(x);
}
```

---

## 3. Import syntax

```
WRONG (Python):
from os import path

WRONG (deprecated Jac v1 — NEVER use):
import:py from os { path }

RIGHT:
import from os { path }
import from typing { Any }
import from datetime { datetime }
import os;
```

The `import:py` prefix is **removed**. All imports use plain `import`. Never generate `import:py` or `include:jac`.

---

## 4. Use `obj` not `class`

`obj` auto-generates `__init__`, `__eq__`, `__repr__`. Prefer it always.

```
WRONG (Python):
class Foo:
    pass

RIGHT:
obj Foo {
    has x: int = 5;
}
```

For graph programming, use `node`, `edge`, `walker` archetypes instead of `obj`.

---

## 5. `def` for methods, `can` ONLY with `with` clause

The compiler enforces this: *"Expected 'with' after 'can' ability name (use 'def' for function-style declarations)"*

```jac
# WRONG — can without with clause
obj Foo {
    can do_stuff() -> None { ... }
}

# RIGHT — def for regular methods
obj Foo {
    has x: int = 0;
    def do_stuff() -> None { print(self.x); }
}

# RIGHT — can ONLY for walker/node event abilities
walker MyWalker {
    can process with MyNode entry {
        report here.value;
        visit [-->];
    }
}
```

---

## 6. `self` is implicit — NEVER in parameter list

`self` is available in the method body but NOT declared as a parameter.

```jac
# WRONG
obj Foo {
    has x: int = 0;
    def get_x(self) -> int { return self.x; }
}

# RIGHT
obj Foo {
    has x: int = 0;
    def get_x() -> int { return self.x; }
}
```

---

## 7. Constructor is `def init`, not `__init__`

Must call `super.init()` explicitly.

```jac
# WRONG
obj Foo {
    def __init__(self, x: int) {
        self.x = x;
    }
}

# RIGHT
obj Foo {
    has x: int;
    def init(x: int) {
        super.init();
        self.x = x;
    }
}
```

Note: If you only need default field values, skip `def init` entirely — `has` fields handle it:

```jac
obj Foo {
    has x: int = 0;
    has name: str = "";
}
```

---

## 8. Instance variables use `has`, not `self.x = ...`

```jac
# WRONG
obj Foo {
    def init() {
        self.x = 5;
    }
}

# RIGHT
obj Foo {
    has x: int = 5;
}
```

---

## 9. `enumerate()` requires parentheses for tuple unpacking

```jac
# WRONG
for i, x in enumerate(items) {
    print(i, x);
}

# RIGHT
for (i, x) in enumerate(items) {
    print(i, x);
}

# Same for dict.items()
for (k, v) in my_dict.items() {
    print(k, v);
}
```

---

## 10. Backtick escaping for keywords as identifiers

```jac
has `type: str;      # "type" is a keyword — backtick escapes it
`edge = 5;           # "edge" is a keyword

# Keywords that commonly need backtick:
# type, edge, node, obj, test, default, case, visit, spawn, entry, exit
```

**These do NOT need backtick** — they are built-in references, not identifiers:
`self`, `super`, `root`, `here`, `visitor`, `init`, `postinit`

```jac
# WRONG
`self.name = "Alice";
`root ++> node;

# RIGHT
self.name = "Alice";
root() ++> node;
```

---

## 11. `static def` for static methods

```jac
obj Foo {
    static def bar() -> int {
        return 42;
    }
}
```

---

## 12. `glob` for module-level variables

```jac
glob MAX_SIZE: int = 100;
glob config: dict = {};
```

---

## 13. `with entry` — module entry point

Replaces Python's `if __name__ == "__main__"`.

```jac
with entry {
    print("Hello, World!");
    root spawn MyWalker();
}
```

---

## 14. Type annotations required on `has` and function signatures

```jac
has x: int = 5;
has name: str = "";
has items: list[str] = [];
has mapping: dict[str, int] = {};
has data: dict | None = None;

def greet(name: str, count: int = 1) -> str {
    return f"Hello, {name}!";
}
```

---

## 15. Control flow uses braces and colons for match/case

```jac
if x > 0 { print("pos"); }
elif x == 0 { print("zero"); }
else { print("neg"); }

for item in items { print(item); }
while count < 10 { count += 1; }

match value {
    case "add":
        result = a + b;
    case _:
        result = 0;
}

try { risky(); }
except ValueError as e { print(f"Error: {e}"); }
finally { cleanup(); }
```

---

## 16. No `pass` — use empty braces or placeholder

```jac
# WRONG
if condition:
    pass

# RIGHT
if condition {}

# Or with placeholder
_unused = 0;
```

---

## 17. Tuple unpacking needs parentheses

```jac
# WRONG
x, y = func();
return a, b;

# RIGHT
(x, y) = func();
return (a, b);
```

---

## 18. Walker definition and traversal

```jac
# WRONG (no visit, no with clause)
walker MyWalker {
    visit node.children;
}

# RIGHT
walker MyWalker {
    can visit_node with SomeNode entry {
        print(here.name);
        visit [-->];           # visit all outgoing nodes
    }
}

# Spawn a walker
result = root spawn MyWalker();
```

---

## 19. Node and edge definitions

```jac
node City {
    has name: str;
    has population: int = 0;
}

edge Road {
    has distance: float = 0.0;
}

# Connect nodes
a ++> b;                              # default edge
a +>:Road(distance=100.0):+> b;      # typed edge

# Query
cities = [-->][?:City];               # all connected City nodes
filtered = [-->][?:City](?name == "NYC");  # with filter
```

---

## 20. Graph keywords: here, visitor, self, root

| Keyword | Meaning | Used In |
|---------|---------|---------|
| `here` | Current node being visited | Walker abilities |
| `visitor` | The walker visiting this node | Node abilities |
| `self` | The archetype instance itself | Any method |
| `root` | Graph root node | Anywhere |

```jac
walker Collector {
    can collect with DataNode entry {
        # here = the DataNode, self = the walker
        self.items.append(here.value);
        visit [-->];
    }
}

node DataNode {
    has value: int;
    can respond with Collector entry {
        # here = this node, visitor = the Collector walker
        print(f"Walker visiting me with {len(visitor.items)} items");
    }
}
```

---

## 21. `disengage` vs `return` in walkers

- `return` — exits current ability, walker continues to next queued node
- `disengage` — stops walker entirely, no more traversal

```jac
walker Search {
    can check with Item entry {
        if here.name == self.target {
            report here;
            disengage;    # found it, stop everything
        }
        visit [-->];      # keep searching
    }
}
```

---

## 22. `report` emits data from walkers

```jac
walker GetData {
    can fetch with Root entry {
        report {"items": [1, 2, 3]};
    }
}

# Access reported data
result = root spawn GetData();
data = result.reports[0];
```

---

## 23. Interface/implementation separation

Declaration (`.jac` file) — signatures end with `;`:

```jac
obj Calculator {
    has result: float = 0.0;
    def add(x: float) -> float;
    def reset() -> None;
}
```

Implementation (`impl/` subdirectory, `.impl.jac` file):

```jac
impl Calculator.add(x: float) -> float {
    self.result += x;
    return self.result;
}

impl Calculator.reset() -> None {
    self.result = 0.0;
}
```

**CRITICAL: A parse error in `.impl.jac` breaks the ENTIRE file.** All implementations in that file will have 0 body items. Always check syntax carefully.

---

## 24. `by llm()` for AI-powered functions

**CRITICAL: You MUST import byllm and create a glob model before using `by llm()`.**

```jac
# STEP 1: Import and create model (REQUIRED)
import from byllm.lib { Model }

glob llm: Model = Model(model_name="gpt-4o");

# STEP 2: Use by llm() on functions
# Simple — LLM infers from function name and types
def classify_sentiment(text: str) -> str by llm();

# With tools (triggers ReAct loop)
def respond(message: str, history: list[dict]) -> str by llm(
    tools=[read_file, search],
    max_react_iterations=10,
    temperature=0.2
);

# Semantic annotations — system prompt for by llm()
sem MyAgent.respond = """You are an expert assistant.
Use tools to answer thoroughly.""";
```

Without the `import from byllm.lib { Model }` and `glob llm: Model = Model(...)`, any `by llm()` call will fail.

---

## 25. Access modifiers

| Modifier | Meaning |
|----------|---------|
| `:pub` | Public — REST endpoint, importable |
| `:priv` | Private — requires auth, per-user data |
| `:protect` | Protected — module-internal only |
| *(none)* | Default — module-scoped |

```jac
walker :pub get_items { ... }       # Public API endpoint
walker :priv add_item { ... }       # Authenticated endpoint
def :protect validate(x: str) -> bool { ... }  # Internal helper
def:pub get_todos() -> list { ... } # Public function endpoint
```

---

## 26. Enum definition

```jac
enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

enum Direction { NORTH, SOUTH, EAST, WEST }

def describe(c: Color) -> str {
    return f"The color is {c.value}";
}
```

---

## 27. Test blocks

```jac
test "addition works" {
    calc = Calculator();
    calc.add(5.0);
    assert calc.get_result() == 5.0;
}
```
---

## Always provide default values for `has` fields

```
WRONG — fields without defaults crash on construction:
node Project {
    has title: str;
    has tags: list;
}

RIGHT — every field has a default:
node Project {
    has title: str = "";
    has tags: list = [];
    has count: int = 0;
    has price: float = 0.0;
    has active: bool = False;
    has meta: dict = {};
}
```

---
