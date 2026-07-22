---
name: jac-types
description: The Jac type system - annotations, unions, optionals, inference, `as` casts, any-boundary fixes, import type, ambient typing names, generics, and common type errors. Load before writing any non-trivial typed function or when debugging a type-check failure.
---

Jac is statically typed at **annotation boundaries** and inferred inside function bodies. Every `def` parameter and every `has` field needs an explicit type; a `def` that returns a value needs an explicit return type (a `def` with no `return` infers `None` - don't write `-> None`, it warns W3037). Local variables get their type from the right-hand side. Types are unified across client and server code.

```jac
obj User {
    has name: str;                       # required - must be passed at construction
    has age: int = 0;                    # typed primitive with default
    has rows: list[dict[str, int]] = []; # nested generic container
    has manager: User | None = None;     # self-referencing optional
}


def greet(u: User) -> str {
    if u.manager is None {               # None-narrowing: guard before deref
        return "Hi " + u.name + ", no manager";
    }
    return "Hi " + u.name + ", manager is " + u.manager.name;
}


def describe(x: int | str) -> str {     # union + isinstance narrowing
    if isinstance(x, int) {
        return "number: " + str(x);
    }
    return "text: " + x;                 # narrowed to str
}


with entry {
    alice = User(name="alice", age=30);
    print(greet(User(name="bob", manager=alice)));
    print(describe(42), describe("hi"));
}
```

## The `as` cast - THE escape hatch

`value as Type` re-types a value for the checker. It is **unchecked and type-erased** - a runtime no-op, like `typing.cast`. Use it when you know more than the checker, most often to land an `any` value (walker reports, JSON, untyped Python returns) into a concrete type:

```
result = root spawn load_feed();
tweets: list[TweetView] = result.reports[0] as list[TweetView];

nums = raw as list[int];           # cast then iterate as ints
c = (a + b) as float;              # binds tighter than nothing: `a + b as T` = `(a + b) as T`, but parenthesize for clarity
```

Casts chain left-associatively (`x as A as B`). Inside `with ... as f` / `except ... as e` headers, a cast must be parenthesized - `as` means aliasing there. A wrong cast surfaces only later (type error or runtime failure) - don't use it to silence diagnostics blindly.

## `any` at boundaries - the strict rule and its three fixes

An `any` value cannot silently flow into a declared non-`any` destination (annotated assignment, `has` initializer, typed param, typed return) - that's E1001/E1002. The check recurses into containers (`list[any]` → `list[Task]` rejected). **Permissive destinations** (no error): inferred locals (`raw = py_call();` - `raw` becomes `any`), explicit `any` annotations (`raw: any = ...;` - draws a W1037 nudge but passes), `object` params, and TypeVar params - so `print(x)` just works.

The 3-step playbook for an untyped boundary (PyPI call, `json.loads`, walker report):

1. **Type the source** - add a return annotation, a `.pyi` stub next to the Python file, install a third-party lib's stub package (`jac install types-requests` - only stdlib stubs ship in the binary, so third-party `types-*` are PEP 561-resolved from `.jac/venv`), or a typed `has reports: list[T] = [];` on the walker. Best: downstream code stays clean.
2. **Accept-and-narrow** - take it into an inferred/`any` local, then `isinstance`-narrow before flowing into typed destinations.
3. **Cast at the use site** - `value as Type` when you know the runtime shape (see above).

## Ambient typing names - no import needed

`Callable`, `Protocol`, `TypeVar`, `Generic`, `Literal`, `ClassVar`, `Annotated`, `Iterable`, `Iterator`, `Mapping`, `Sequence`, `Awaitable`, `Coroutine` (and Async/Mutable variants) resolve in annotations with **no import**. Runtime values (`cast`, `overload`, `TYPE_CHECKING`, `get_type_hints`) are NOT ambient - import those explicitly. Don't-write table:

| Don't write | Use instead |
|---|---|
| `Any` | the `any` keyword |
| `Optional[X]` | `X \| None` |
| `Union[X, Y]` | `X \| Y` |
| `List[X]`, `Dict[K, V]`, `Tuple[...]`, `Set[X]` | lowercase built-ins `list[X]`, `dict[K, V]`, ... |

## `import type` - the circular-import breaker

`import type from billing { Invoice }` registers `Invoice` for annotations only - it compiles to a `typing.TYPE_CHECKING`-guarded Python import, so it never runs at module load. That breaks circular imports between modules whose types reference each other. **Caveat:** the name does not exist at runtime - do NOT use `import type` for names you construct (`Invoice(...)`), `isinstance`-check, or use in `has` field types (archetypes are dataclass-derived and resolve annotations at runtime). Those need a regular `import`.

## Type aliases, named constructors, `Self`

```jac
type UserId = int;                              # type alias
type Handler = Callable[[int], int];            # alias over ambient names

obj Counter {
    has label: str = "";

    static def named(label: str) -> Counter {   # named constructor: static def + concrete class name
        return Counter(label=label);
    }

    def bump(n: int) -> Counter {               # fluent builder: return the CONCRETE name
        print(self.label, n);
        return self;
    }
}
```

**`Self` caveat (verified):** `-> Self` parses and runs, but the current checker resolves it to Unknown - chaining `Counter.named("c").bump(1).bump(2)` then accessing fields fails E1032. For a clean `jac check`, return the concrete archetype name. (Recursive *aliases* like `type Json = ... | list[Json]` similarly draw W1051 - keep aliases non-recursive.)

## Generics - declared type params work, with two traps

`obj Result[T, E = Exception] { has value: T | None = None, error: E | None = None; }` and `def first[T](items: list[T]) -> T` compile, check, and run. Traps (verified):

- **Type-param defaults don't apply at subscripted construction**: `Result(value=42)` and `Result[int, ValueError](value=42)` work, but `Result[int](value=42)` - leaving `E` to its default - passes `jac check` and raises `TypeError` at runtime. When in doubt, construct without the subscript.
- **The checker treats `T` opaquely**: `first([1,2]) + 1` fails E1010 (no operator on `T`) - recover the concrete type with a cast: `n = first(nums) as int;`.

## Pitfalls

- **Do NOT fall back to `any` to silence a type error.** It defers the error to the next typed boundary: `len(any)` → E1053, `any + any` → E1055, assigning/returning into a concrete type → E1001/E1002. Fix the actual type (typed field, `T | None` + `is None` guard, or `as` cast at the boundary).
- **Every `def` parameter needs a type** (E0052); a value-returning `def` needs a return type (E1003); `has name;` without a type is a parse error.
- **Don't annotate `-> None`** on a no-return `def` - W3037. Write `def save(x: int) { ... }`.
- `list`, `dict`, `set` (and ambient `Iterable` etc.) without type args default to `[any]` (W1036) - add element types.
- Use **`T | None`**, not `Optional[T]`. Always check `is None` before dereferencing.
- **Lowercase `any` is the gradual type** - Jac-native, no import. `import from typing { Any }` triggers W1104; bare `Any` warns W2001. Note: even legitimate explicit `any` annotations draw W1037 ("disables type checking here") - a nudge, not a failure.
- **Event-handler params take the event type, not `any`** (`e: ChangeEvent`, `e: MouseEvent`) - see `jac-cl-components`.
- **E1030** (`Type T has no attribute X`) - e.g. `.map()` on a list; use comprehensions.
- **E1032** (`Type is Unknown, cannot access attribute`) - inference failed; add an explicit annotation, or check for an unresolved import / `Self` return.
- **E1001** (`Cannot assign X to T`) - RHS type mismatch; widen the declared type, narrow the value, or `as`-cast.
- **Non-default fields MUST come before defaulted ones** (E2004) - and parent defaults force child defaults; see `jac-has-fields`.

## See also

`jac-has-fields` (field rules) · `jac-core-cheatsheet` (`import type` syntax, reserved words) · `jac-python-interop` (typing the Python boundary) · `jac-walker-patterns` (typed reports)
