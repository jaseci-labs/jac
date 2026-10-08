# Variables and Scope

**On this page:**

- [Local Variables](#1-local-variables) - Function-local bindings
- [Instance Variables (has)](#2-instance-variables-has) - Declarative object state
- [Global Variables (glob)](#3-global-variables-glob) - Module-level variables
- [Scope Rules](#4-scope-rules) - LEGB resolution, lexical rebinding, shadowing
- [Truthiness](#5-truthiness) - What counts as true in conditions

---

Jac distinguishes between local variables (within functions), instance variables (`has` declarations in objects), and global variables (`glob`). Unlike Python where you assign `self.x = value` in `__init__`, Jac uses declarative `has` statements that make your data model explicit and visible at a glance.

## 1 Local Variables

```jac
def example() {
    # Type inferred
    x = 42;
    name = "Alice";

    # Explicit type
    count: int = 0;
    items: list[str] = [];
}
```

## 2 Instance Variables (has)

The `has` keyword declares instance variables in a clean, declarative style. Unlike Python's `self.x = value` pattern scattered throughout `__init__`, `has` statements appear at the top of your class definition, making the data model immediately visible. This design improves readability for both humans and AI code generators.

!!! tip "Coming from Python"
    In Python you write `self.x = value` inside `__init__`. In Jac, `has x: Type = value;` at the top of an `obj` replaces both the `__init__` parameter and the assignment -- no `self` needed for declarations.

```jac
obj Person {
    has name: str;                    # Required
    has age: int = 0;                 # With default
    static has count: int = 0;        # Static (class-level)
}
```

**Deferred Initialization:**

Use the `postinit` field modifier when a field depends on other fields:

```jac
obj Rectangle {
    has width: float;
    has height: float;
    has area: float postinit;

    def postinit {
        self.area = self.width * self.height;
    }
}
```

> [!WARNING]
> **Strict Data Model**
> Jac enforces a declarative data model. Only attributes declared with `has` are part of the object's structure. While the runtime may currently allow dynamic assignment of undeclared attributes, this is an anti-pattern that should be avoided. Future versions of the Jac compiler will strictly forbid this behavior.

## 3 Global Variables (glob)

The `glob` keyword declares module-level variables, replacing Python's convention of bare global assignments. It is Jac's only globals keyword -- there is no `global` or `nonlocal` statement.

!!! tip "Coming from Python"
    Python uses plain global assignment (`DEBUG = True`) and the `global` keyword inside functions. Jac uses `glob` for declarations (`glob DEBUG: bool = True;`), and assignments inside functions rebind the `glob` directly -- no declaration statement needed.

```jac
glob PI: float = 3.14159;
glob config: dict = {};

with entry {
    print(PI);
}
```

## 4 Scope Rules

**Scope Resolution Order (LEGB):**

When Jac looks up a name, it searches in this order:

1. **L**ocal: Names in the current function/block
2. **E**nclosing: Names in enclosing functions (for nested functions)
3. **G**lobal: Names at module level (`glob` declarations)
4. **B**uilt-in: Pre-defined names (`print`, `len`, `range`, etc.)

```jac
glob x = "global";

def outer {
    x: str = "enclosing";   # Typed declaration = new local shadowing the glob

    def inner {
        x: str = "local";   # Typed declaration = new local shadowing outer's x
        print(x);  # "local" - found in Local scope
    }

    inner();
    print(x);  # "enclosing" - found in Enclosing scope
}
```

**Assignment binds to the nearest enclosing binding:**

A bare assignment (including augmented forms like `+=`) inside a function does not automatically create a new local. It binds to the nearest enclosing binding of that name -- a local of an enclosing function, or a module-level `glob`. A new local is created only when no such binding exists. Jac has no `global` or `nonlocal` statements; they are not needed.

```jac
glob counter: int = 0;

def increment {
    counter += 1;      # Rebinds the module-level glob directly
}

def outer {
    x = 10;            # New local (no enclosing binding named x)
    def inner {
        x += 1;        # Rebinds outer's x
    }
    inner();
    print(x);  # 11
}
```

Only `glob`-declared variables are implicitly rebindable this way. Module-level names bound by imports, function definitions, or archetype declarations are not -- assigning to such a name inside a function creates an ordinary local.

**Shadowing requires a typed declaration:**

To create a fresh local that shadows an outer binding instead of rebinding it, declare it with a type annotation before its first use in the scope:

```jac
glob counter: int = 0;

def local_count {
    counter: int = 100;   # New local; the glob is untouched
    counter += 1;         # Local becomes 101
}
```

Placing the typed declaration *after* the name has already been assigned or read in the same scope is an error (**E0064**) -- the earlier statements already bound to the outer variable.

Loop targets (`for x in ...`), `except ... as e`, and `with ... as f` always bind fresh locals; they never rebind an outer variable.

!!! tip "No UnboundLocalError gotcha"
    In Python, `counter += 1` inside a function raises `UnboundLocalError` unless you first write `global counter`. In Jac, the augmented assignment simply rebinds the `glob` -- the gotcha is gone.

**Block scope behavior:**

```jac
def example() {
    if True {
        block_var = 42;    # Created in block
    }
    # block_var is still accessible here in Jac (unlike some languages)

    for i in range(3) {
        loop_var = i;
    }
    # loop_var and i are accessible here
}
```

**Closures created in a loop:**

Because a local assigned in a loop body belongs to the function, the loop assigns the same binding on every iteration; it does not make a new one. A type annotation does not change that: `label: str = ...` in a loop body is owned by the function exactly like `label = ...`. A `lambda` or nested `def` reads the binding when it is called, not when it is created, so a closure that is kept past its iteration would see whatever the last iteration assigned. The compiler rejects that capture (**E2097**):

<!-- jac-skip -->
```jac
def build(names: list[str]) -> list[Callable[[], str]] {
    greeters: list[Callable[[], str]] = [];
    for name in names {
        label = name.upper();
        greeters.append(lambda -> str { return label; });   # E2097: all return the last label
    }
    return greeters;
}
```

Bind the value through a parameter. A parameter is a fresh binding on every call, so each closure keeps its own:

```jac
def greeter_for(label: str) -> Callable[[], str] {
    return lambda -> str { return label; };
}

def build(names: list[str]) -> list[Callable[[], str]] {
    greeters: list[Callable[[], str]] = [];
    for name in names {
        label = name.upper();
        greeters.append(greeter_for(label));
    }
    return greeters;
}
```

A closure that cannot outlive its iteration is fine: one called on the spot, a local helper `def` that is only called, the callback of `map` / `filter` / `sorted(key=...)` and the like, or one in a `return` that ends the loop. So is a closure over a binding the loop does not assign. See [E2097](../diagnostics.md#closures-created-in-a-loop) for the full list.

The check reports bindings the function owns. The `for` target and a `def` declared in the loop body belong to the loop itself and are not reported: client code gets a fresh one each iteration. Server and native code keep a single slot for them, as Python does, so a closure there that outlives its iteration sees the last target too. Pass the target through a parameter in the same way.

## 5 Truthiness

Values are evaluated as boolean in conditions. The following are **falsy** (evaluate to `False`):

| Type | Falsy Values |
|------|--------------|
| `bool` | `False` |
| `None` | `None` |
| `int` | `0` |
| `float` | `0.0` |
| `str` | `""` (empty string) |
| `list` | `[]` (empty list) |
| `tuple` | `()` (empty tuple) |
| `dict` | `{}` (empty dict) |
| `set` | `set()` (empty set) |

All other values are **truthy**.

**Examples:**

```jac
def example() {
    # Falsy values
    if not 0 { print("0 is falsy"); }
    if not "" { print("empty string is falsy"); }
    if not [] { print("empty list is falsy"); }
    if not None { print("None is falsy"); }

    # Truthy values
    if 1 { print("non-zero is truthy"); }
    if "hello" { print("non-empty string is truthy"); }
    if [1, 2] { print("non-empty list is truthy"); }

    # Common patterns
    items = [1, 2, 3];
    if items {
        print(items);
    } else {
        print("No items to process");
    }

    # Default value pattern
    user_input = "";
    name = user_input or "Anonymous";
}
```
