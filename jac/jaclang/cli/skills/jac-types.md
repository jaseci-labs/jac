---
name: jac-types
description: Resolve Jac type annotations, inference, any boundaries, generics, and narrowing. Use for type errors or unfamiliar typing constructs.
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

`import type from billing { Invoice }` registers `Invoice` for annotations only - it compiles to a `typing.TYPE_CHECKING`-guarded Python import and to nothing at all in the client bundle, so it never runs at module load. That breaks circular imports between modules whose types reference each other.

Every import binding carries a kind and the checker enforces it, asking whether the backend that lowers *this* module leaves a runtime binding for the imported name. A TypeScript `interface` or `type` alias in a `.d.ts` (npm or sibling declaration file) has no runtime export in any codespace, so a plain `import from` of one is always `E1131`; give it its own `import type` statement beside the value imports (`import from mermaid { default as mermaid }` + `import type from mermaid { Mermaid }`). A jac `type` alias is `E1131` **only in client code**: on the server it lowers to a real runtime binding (`type UserId := int;` becomes `UserId = int`, which is what makes `UserId(raw)` a brand constructor), so a plain import of an alias from a server module is correct - do not "fix" it. A `declare class`, a `declare enum`, and every jac archetype have a runtime binding on both backends, so a plain import of those stays correct.

Going the other way, an `import type` binding is legal only in type position - annotations, `has` field types, return types, generic arguments, `as` casts, `type` alias right-hand sides. Constructing it (`Invoice(...)`), `isinstance`-checking it, reading an attribute off it, decorating with it or inheriting from it is `E1132`, on the server as much as in the client (the `TYPE_CHECKING` guard means the name is not there at run time); those need a regular `import`. **Caveat that is not diagnosed:** an archetype `has` field type still has to exist at runtime on the Python lane, because archetypes are dataclass-derived and resolve annotations through `typing.get_type_hints`. Keep those names on a regular `import`.

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

## Fixed-width numbers - `i8`..`u64`, `f32`, `f64`

Real types with one contract on every lane (server, native, client). `int` and `float` are members of the same lattice, not exceptions: `int` is the signed 64-bit machine integer and behaves exactly as `i64`, `float` is binary64 and behaves exactly as `f64` -- so `u64 -> int` needs a cast for the same reason `u64 -> i64` does. Widening is implicit only when value-preserving (`i8 -> i16 -> i32 -> i64 -> int`, `u8 -> u16 -> u32 -> u64 -> int`, `u8 -> i16`, `i8..u16 -> f32`, `i8..u32 -> f64`, `f32 -> f64 -> float`, `bool -> int-kind`, `int-kind -> float`); everything else is the checked cast `T(x)` (raises `OverflowError` out of range) or the modular `T.wrap(x)`. An in-range literal adopts the sized operand (`w: i32 = 1; w = w + 1` is fine); arithmetic traps on overflow; `wrapping_add/sub/mul/neg/shl` never trap; `T.MIN`/`T.MAX` are the bounds.

| Code | Meaning | Fix |
|---|---|---|
| **E1126** | int literal outside the target's range (`x: u8 = 300`, `u8(-1)`) | pick a wider type, or spell the modular result: `u8.wrap(300)` |
| **E1127** | implicit conversion that is not value-preserving (`int -> i32`, `i64 -> i8`, `u8 -> i8`, `f64 -> f32`, `i64 -> f32`) | cast at the boundary: `i32(n)`, or widen the destination; FFI call sites need the cast too |
| **E1128** | operands with no common fixed-width type (`u8 + i8`, `u64 < i64`, `i32 == u32`, `i64 + f32`) | cast one operand explicitly so the width and sign of the operation is chosen: `i64(x) + y` |
| **E1129** | unary minus on an unsigned operand | negate in a signed type (`-i64(x)`) or use `wrapping_neg(x)` |
| **E1130** | float literal past the target's range (`f32 = 1e60`, `f64 = 1e400`) | it would arrive as `inf`; widen the type or write a value it can hold |

`T op int` yields `int` (so `w: i32 = w + n` with `n: int` is E1127); `/` yields `float`; shifts keep the left operand's type with the count range-checked at run time.

The width is a compile-time fact, not a runtime wrapper: a sized value is a plain `int`/`float` on the server lane, a JS number (or `BigInt` at 64 bits) on the client, and its own machine width natively. `type(x)` reports `int` or `float` and `isinstance(x, i8)` is not available -- read the width off the annotation. The only cost is the range check on the operations that can overflow (`+ - * // ** << >>`, unary minus, `abs`, `T(x)`); bitwise ops, comparisons, `f64` arithmetic and implicit widening are plain machine operations. On the wire, both lanes encode a 64-bit sized value as a JSON number when it fits in 2^53 and as a JSON string otherwise, and both decoders accept either form.

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

`jac-has-fields` (field rules) · `jac-core-cheatsheet` (`import type` syntax, reserved words) · `jac-python-interop` (typing the Python boundary) · `jac-walker-patterns` (typed reports) · `jac-comptime` (`comptime` parameters, archetype value params, compile-time reflection)
