---
name: jac-types
description: The Jac type system - type annotations, generics, unions, optionals, inference rules, and common type errors. Load before writing any non-trivial typed function or when debugging a type-check failure.
---

Jac is statically typed at **annotation boundaries** and inferred inside function bodies. Every `def` parameter and return, and every `has` field, needs an explicit type. Local variables inside bodies get their type from the right-hand side. Types are unified across client (`.cl.jac`) and server code - only the specific types in scope differ (JsxElement in client, node archetypes in server).

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


def log_any(value: Any) -> None {        # Any = escape hatch, no import needed
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

**`Any` where dynamic access is needed:**

```
def on_event(e: Any) -> None {
    print(e.target.value);               # can touch any attribute - no type check
}
```

## Pitfalls

- **Do NOT fall back to `Any` to silence a type error.** Jac is strict-typed by design; using `Any` suppresses the diagnostic but the value is still untyped - and every downstream operation on it fails: `len(Any)` → not Sized (E1053), `Any + Any` → no overload (E1055), `Any.attr` → Type Unknown (E1032), `Any | str` ternary → can't assign to `str` (E1001). Fix the actual type instead. Common right answers: type with the imported node/obj (`has recipes: list[Recipe] = []`), use `T | None` for optionals (`has recipe: Recipe | None = None;` + `if recipe is not None { ... }`), or cast at the boundary (`recipe_id: str = str(params["id"]) if params["id"] else "";`).
- **Every `def` parameter needs a type** (E0052). `def foo(x) -> int` is invalid - must be `def foo(x: int) -> int`.
- **Every `def` needs an explicit return type.** Even `-> None`.
- **`has name;`** without a type is a parse error. Always `has name: type;`.
- `list`, `dict`, `set` without type args default to `list[Any]` (W1036) - add args when you know the element type: `list[str]`, `dict[str, int]`.
- Use **`T | None`** for optional references. NOT `Optional[T]` (Python stdlib, not idiomatic). Always check `is None` before dereferencing.
- **`Any`** is Jac-native - no import needed. Do NOT `import from typing { Any }` (Python stdlib, missing in Vite client bundle) or `import from "@jac/runtime" { Any }` (not exported). Just write `e: Any`.
- **`any` lowercase** refers to the Python `any()` builtin - not the Any type. Using `e: any` in handlers fails **E1103** (function signature mismatch with JSX intrinsic prop type).
- **E1030** (`Type T has no attribute X`) - you called a method/field that doesn't exist on that type. Example: `items.map(...)` on `list[Item]` fails because lists don't have `.map()`; use comprehensions.
- **E1032** (`Type is Unknown, cannot access attribute`) - inference couldn't figure out a variable's type. Add an explicit annotation (`x: SomeType = ...`) so the rest of the code can narrow.
- **E1001** (`Cannot assign <Unknown> to T`) - the right-hand side's type doesn't match the declared type. Usually means you need to widen the declared type or narrow the value with an explicit cast/check.
- **Non-default fields MUST come before defaulted ones** (E2004) - see `jac-has-fields` for the full rule.
- **`T | None` narrowing doesn't propagate into JSX expressions or list comprehensions.** A guard like `if x is None { return ...; }` narrows `x` to `T` for the rest of the function - direct `x.attr` access works. But inside a JSX list comprehension or short-circuit (`{x and <... x.attr />}`), the narrowing doesn't carry, and `x.attr` fails E1099. **Workaround: after the narrowing guard, pull each used attribute into a typed local before the JSX block.** JSX then references the narrowed local, not the still-Optional `x`. Keep using `T | None` for the field - don't decompose into primitives.

```jac
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
