---
name: jac-types
description: The Jac type system - type annotations, generics, unions, optionals, inference rules, and common type errors. Load before writing any non-trivial typed function or when debugging a type-check failure.
---

Jac is statically typed at **annotation boundaries** and inferred inside function bodies. Every `def` parameter and every `has` field needs an explicit type; a `def` that returns a value needs an explicit return type (a `def` with no `return` infers `None` - don't write `-> None`, it warns W3037). Local variables inside bodies get their type from the right-hand side. Types are unified across client (`.cl.jac`) and server code - only the specific types in scope differ (JsxElement in client, node archetypes in server).

```jac
obj User {
    has name: str;                       # required - must be passed at construction
    has age: int = 0;                    # typed primitive with default
    has tags: list[str] = [];            # generic container
    has meta: dict[str, int] = {};       # two-type-param generic
    has manager: User | None = None;     # self-referencing optional
}


def score(points: list[int]) -> int {
    total = sum(points);                 # inferred int, no annotation needed
    return total;
}


def greet(u: User) -> str {
    if u.manager is None {
        return "Hi " + u.name + ", no manager";
    }
    return "Hi " + u.name + ", manager is " + u.manager.name;  # safe - None branch returned
}


def describe(x: int | str) -> str {      # union type: x is either int or str
    if isinstance(x, int) {
        return "number: " + str(x);
    }
    return "text: " + x;                 # narrowed to str by the isinstance check
}


def log_any(value: any) {                # any = the gradual type; no import needed
    print(value);
}


with entry {
    alice = User(name="alice", age=30);
    bob   = User(name="bob", manager=alice);

    print(score([1, 2, 3]));             # 6
    print(greet(bob));                   # Hi bob, manager is alice
    print(describe(42));                 # number: 42
    print(describe("hi"));               # text: hi
    log_any({"foo": "bar"});             # {'foo': 'bar'}
}
```

## Common patterns

**Optional field + None narrowing:**

```
has owner: User | None = None;
if self.owner is None { return "no owner"; }
return self.owner.name;                  # safe - compiler knows owner is User here
```

**Union type + narrowing with `isinstance`:**

```
def parse(x: int | str) -> int {
    if isinstance(x, int) { return x; }
    return int(x);
}
```

**Generic containers nested:**

```
has rows: list[dict[str, int]] = [];
has adjacency: dict[str, list[str]] = {};
```

**`any` for pass-through values - NOT for attribute access:**

`any` lets a value be stored, passed, and called without a type. It does **not**
unlock attribute access: `x.attr` on an `any` value still fails E1032. Use it for
opaque values (callback references, untyped payloads), not to silence `.attr`.

```
def run_callback(cb: any, payload: str) {   # cb: an opaque function reference
    cb(payload);                             # calling through `any` is allowed
}                                            # cb.name would fail E1032
```

## Pitfalls

- **Do NOT fall back to `any` to silence a type error.** Jac is strict-typed by design; annotating a value `any` suppresses the diagnostic but the value stays untyped - and every downstream operation on it fails: `len(...)` on it → not Sized (E1053), arithmetic → no overload (E1055), `.attr` access → Type Unknown (E1032), assigning it where a `str` is expected → E1001. Fix the actual type instead. Common right answers: type with the imported node/obj (`has recipes: list[Recipe] = []`), use `T | None` for optionals (`has recipe: Recipe | None = None;` + `if recipe is not None { ... }`), or cast at the boundary (`recipe_id: str = str(params["id"]) if params["id"] else "";`).
- **Every `def` parameter needs a type** (E0052). `def foo(x) -> int` is invalid - must be `def foo(x: int) -> int`.
- **A `def` that returns a value needs a return type** (E1003). A `def` with no `return` infers `None` - **do not** annotate it `-> None`, that triggers W3037 (`unnecessary-none-return`). Write `def save(x: int) { ... }`, not `def save(x: int) -> None { ... }`.
- **`has name;`** without a type is a parse error. Always `has name: type;`.
- `list`, `dict`, `set` without type args default to `list[Any]` (W1036) - add args when you know the element type: `list[str]`, `dict[str, int]`.
- Use **`T | None`** for optional references. NOT `Optional[T]` (Python stdlib, not idiomatic). Always check `is None` before dereferencing.
- **The gradual / escape-hatch type is lowercase `any`** - Jac-native, no import needed, type-checks cleanly. Do **NOT** `import from typing { Any }` - that triggers `W1104` (the compiler explicitly tells you to use the `any` keyword instead). Capitalized `Any` is not the keyword: a bare `x: Any` warns `W2001` ("Name 'Any' may be undefined").
- **Event-handler params take the event type, not `any`.** In a `.cl.jac` handler, `e: any` does not unlock `e.target.value` - annotate the real event type (`e: ChangeEvent`, `e: MouseEvent`, ...). See `jac-cl-components`.
- **E1030** (`Type T has no attribute X`) - you called a method/field that doesn't exist on that type. Example: `items.map(...)` on `list[Item]` fails because lists don't have `.map()`; use comprehensions.
- **E1032** (`Type is Unknown, cannot access attribute`) - inference couldn't figure out a variable's type. Add an explicit annotation (`x: SomeType = ...`) so the rest of the code can narrow.
- **E1001** (`Cannot assign <Unknown> to T`) - the right-hand side's type doesn't match the declared type. Usually means you need to widen the declared type or narrow the value with an explicit cast/check.
- **Non-default fields MUST come before defaulted ones** (E2004) - see `jac-has-fields` for the full rule.
- **`T | None` narrowing doesn't propagate into JSX expressions or list comprehensions.** A guard like `if x is None { return ...; }` narrows `x` to `T` for the rest of the function - direct `x.attr` access works. But inside a JSX list comprehension or short-circuit (`{x and <... x.attr />}`), the narrowing doesn't carry, and `x.attr` fails E1099. **Workaround: after the narrowing guard, pull each used attribute into a typed local before the JSX block.** JSX then references the narrowed local, not the still-Optional `x`. Keep using `T | None` for the field - don't decompose into primitives.

```jac
obj Recipe {                             # in a real app: `sv import`-ed from a .sv.jac
    has title: str;
    has ingredients: list[str];
}

def:pub RecipeView() -> JsxElement {
    has recipe: Recipe | None = None;

    # Early-return narrows `recipe` to Recipe for direct accesses below
    if recipe is None {
        return <div>{"loading..."}</div>;
    }
    # FRAGILE - works for direct .title, fails for .ingredients inside comprehension
    # return <div>
    #     <h1>{recipe.title}</h1>                                            # ok
    #     {[<li>{recipe.ingredients[i]}</li>                                 # ✗ E1099
    #       for i in range(len(recipe.ingredients))]}
    # </div>;

    # CORRECT - pull narrowed attrs into typed locals before JSX
    title: str = recipe.title;
    ingredients: list[str] = recipe.ingredients;
    return <div>
        <h1>{title}</h1>
        {[<li key={str(i)}>{ingredients[i]}</li> for i in range(len(ingredients))]}
    </div>;
}
```
