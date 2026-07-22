# Types and Values

**On this page:**

- [Builtin Types](#1-builtin-types) - The core scalar and collection types
- [Type Annotations](#2-type-annotations) - Required annotations, ambient names, `import type`, gradual typing
- [Generic Types](#3-generic-types) - Generic functions and objects
- [The `Self` Type](#4-the-self-type) - Referring to the enclosing type
- [Union Types](#5-union-types) - `A | B` unions and optionals
- [Type References](#6-type-references) - Types as first-class values
- [Literals](#7-literals) - Numeric, string, collection literals
- [F-String Format Specifications](#8-f-string-format-specifications) - Formatting mini-language

---

Jac is statically typed -- all variables, fields, and function signatures require type annotations. This enables better tooling, clearer APIs, and catches errors at compile time rather than runtime. The type system is compatible with Python's typing module.

## 1 Builtin Types

| Type | Description | Example |
|------|-------------|---------|
| `int` | Integer | `42`, `-17`, `0x1F` |
| `float` | Floating point | `3.14`, `1e-10` |
| `str` | String | `"hello"`, `'world'` |
| `bool` | Boolean | `True`, `False` |
| `bytes` | Byte sequence | `b"data"` |
| `list` | Mutable sequence | `[1, 2, 3]` |
| `tuple` | Immutable sequence | `(1, 2, 3)` |
| `set` | Unique values | `{1, 2, 3}` |
| `dict` | Key-value mapping | `{"a": 1}` |
| `any` | Any type | -- |
| `type` | Type object | -- |
| `None` | Null value | `None` |

**Fixed-width types** (for native code and C interop):

| Type | Description | C Equivalent |
|------|-------------|--------------|
| `i8`, `u8` | 8-bit signed/unsigned integer | `int8_t`, `uint8_t` |
| `i16`, `u16` | 16-bit signed/unsigned integer | `int16_t`, `uint16_t` |
| `i32`, `u32` | 32-bit signed/unsigned integer | `int32_t`, `uint32_t` |
| `i64`, `u64` | 64-bit signed/unsigned integer | `int64_t`, `uint64_t` |
| `f32` | 32-bit float | `float` |
| `f64` | 64-bit float | `double` |
| `c_void` | Opaque pointer | `void*` |

These types are used in `.na.jac` files for C library interop. The compiler automatically coerces between Jac's standard types (`int` = `i64`, `float` = `f64`) and fixed-width types at call boundaries.

## 2 Type Annotations

Type annotations are required for fields and function signatures:

```jac
obj Example {
    has name: str;
    has count: int = 0;
    has items: list[str] = [];
    has mapping: dict[str, int] = {};
}
```

### Ambient Typing Names

A curated set of annotation-only names from `typing` resolves in user code without an explicit import:

`Callable`, `Protocol`, `TypeVar`, `Generic`, `Literal`, `ClassVar`, `Annotated`, `Iterable`, `Iterator`, `AsyncIterable`, `AsyncIterator`, `Mapping`, `MutableMapping`, `Sequence`, `MutableSequence`, `Awaitable`, `Coroutine`.

```jac
def:pub apply(func: Callable[[int, int], int], x: int, y: int) -> int {
    return func(x, y);
}
```

The Python codegen still emits `from typing import Callable` to the generated module preamble, so runtime introspection (`typing.get_type_hints`, pydantic, FastAPI) keeps working. The JS codegen strips annotations from function signatures, so no `typing` import lands in the bundle.

Names skipped on purpose:

| Don't write | Use instead |
|-------------|-------------|
| `Any` | the `any` keyword |
| `Optional[X]` | `X \| None` |
| `Union[X, Y]` | `X \| Y` |
| `List[X]`, `Dict[K, V]`, `Set[X]`, `FrozenSet[X]`, `Tuple[X, ...]`, `Type[X]` | the lowercase built-ins (PEP 585) |
| `DefaultDict`, `OrderedDict`, `Counter`, `Deque` | the `collections` equivalents |

Runtime values like `cast`, `overload`, `runtime_checkable`, `TYPE_CHECKING`, `get_type_hints`, `get_args`, `get_origin`, and `no_type_check` are not ambient -- import them explicitly when needed.

### Type-Only Imports (`import type`)

Use `import type` to bring a name into scope **only for type annotations**. The import is registered with the type checker but elided from runtime by lowering to a `typing.TYPE_CHECKING` guard in the generated Python.

```jac
import type from billing { Invoice }

def total(inv: Invoice) -> int {
    return inv.amount;
}
```

Generated Python:

```python
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from billing import Invoice
```

This is the supported way to break circular imports between Jac modules whose types reference each other. Combined with `from __future__ import annotations` (always emitted), the annotation stays valid at type-check time without forcing the import to run at module load.

When **not** to use `import type`:

- The name is constructed at runtime (e.g. `Invoice(...)`), used in `isinstance`, or referenced by any decorator that resolves annotations through `typing.get_type_hints` (dataclass, Pydantic, attrs, FastAPI route signatures, SQLAlchemy declarative, msgspec). These libraries call into the module's globals at class-definition time and a `TYPE_CHECKING`-guarded import will not be there. Use a regular `import` for those.
- The name is used inside an `obj`/`node`/`edge`/`walker` `has` field type. Jac archetypes are dataclass-derived, so the same rule applies: keep them on a regular `import`.

`import type` is opt-in -- a regular `import` still binds the name at runtime exactly as before.

### The `any` Type and Gradual Typing

`any` is Jac's gradual-typing escape valve. A value typed as `any` can hold anything, and reading from it produces `any`. Jac applies a strict rule about where `any` is allowed to flow inside `.jac` files: it must not silently widen into a declared non-`any` destination.

**The rule.** A value of type `any` cannot be silently assigned to a destination with a declared non-`any`, non-`object` type. The check fires at every site where the destination has a declared type:

- annotated assignment (`x: T = src;`)
- `has`-var initializer (`has x: T = src;`)
- function argument (`f(src)` against a declared `param: T`)
- return statement (`return src` from `def f -> T`)
- yield expression in a typed generator
- edge-connection assignment

The check recurses element-wise into containers, so `list[any] -> list[Task]` is rejected the same way `any -> Task` is.

**Two destinations stay permissive:**

1. **Inferred locals.** A binding without an annotation accepts `any` and itself becomes `any`. `x = py_call();` is fine.
2. **Explicit `any` annotation.** Annotating the destination as `any` opts into permissive flow. `x: any = py_call();` is fine.

`any -> object` and `any -> T` (where `T` is a `TypeVar`) are also permissive, so `print(x)` and generic-bound calls work without ceremony.

!!! note "`.py` and `.pyi` files keep PEP 484 semantics"
    `Any` propagates freely inside Python modules. The strict rule only fires at the `.jac` consumption site. A typed `.pyi` stub for a Python utility removes the `any` return type at the boundary, so the strict rule never engages downstream.

**Migration patterns.** Three ways to clear a strict-`any` error at a boundary:

| Approach | When to use |
|----------|-------------|
| Type the source | The function has a stable signature. Add a `.pyi` stub for a Python utility, a return annotation on a `def`, or a typed [`has reports: list[T]`](walker-responses.md#typing-your-reports) declaration on a walker. The boundary becomes strongly typed and downstream `.jac` code stays clean. |
| Accept `any` at the boundary | The source is intentionally untyped. Annotate the receiving local as `any`, then narrow with `isinstance` before flowing into typed destinations. |
| Cast at the use site | You know the runtime type the checker cannot prove. Use the [`as` cast operator](operators.md#10-the-as-cast-operator) -- `value as Type` -- to re-type the value explicitly, e.g. `result.reports[0] as list[TweetView]`. The cast is unchecked, so use it only when the assumption is sound. |

```jac
import json;

def parse(text: str) -> any {
    return json.loads(text);
}

obj Task { has title: str = ""; }

with entry {
    # Inferred destination -- `raw` becomes `any`, no error.
    raw = parse('{"title": "ship"}');

    # Narrow before flowing into a declared type.
    if isinstance(raw, dict) {
        title = raw.get("title", "");
        if isinstance(title, str) {
            t = Task(title=title);
            print(t.title);
        }
    }
}
```

## 3 Generic Types

Jac supports declared generic type parameters using Python-style (PEP 695) syntax, with defaults:

```jac
# Generic function
def first[T](items: list[T]) -> T {
    return items[0];
}

# Generic objects, optionally with parameter defaults
obj Container[T] {
    has value: T;
}

obj Result[T, E = Exception] {
    has value: T | None = None,
        error: E | None = None;
}

with entry {
    c = Container(value=42);   # subscripting the class is optional here
    print(c.value);
    print(first([1, 2, 3]));
}
```

One current limitation to be aware of:

- **Type-parameter defaults don't apply at subscripted construction.** `Result(value=42)` and `Result[int, ValueError](value=42)` work, but `Result[int](value=42)` -- leaving `E` to its default -- passes `jac check` and raises a `TypeError` at runtime. When in doubt, construct without the subscript.

Type-parameter inference now flows through: the checker infers the concrete
return type, so `first([1, 2]) + 1` checks clean and `s = first(["a", "b"]); s.upper()`
resolves. If you ever need to override the checker's inference, the
[`as` cast operator](operators.md#10-the-as-cast-operator) re-types an expression: `n = first(nums) as int;`.

!!! tip "Remember the backtick"
    If you need to use the built-in function to check if any item is truthy, use `` `any ``:
    ``if `any([True, False]) { ... }``

## 4 The `Self` Type

`Self` (capital S) is a special type that, in instance-method positions, refers to the enclosing archetype. It is distinct from `self` (lowercase), which refers to the current instance. `Self` is most useful for fluent/builder methods that return the receiver:

```jac
obj NodeRef {
    has value: int = 0;

    def set_value(v: int) -> Self {  # Self as return type
        self.value = v;
        return self;
    }
}
```

For recursive type annotations on fields and parameters, name the enclosing archetype directly:

```jac
obj LinkedNode {
    has value: int = 0,
        next: LinkedNode | None = None;

    static def create(v: int) -> LinkedNode {
        return LinkedNode(value=v);
    }
}
```

See [Class Methods and Self](functions-objects.md#6-static-methods-and-class-methods) for usage details, including the planned polymorphic `Self` enhancement for `class def` factories.

## 5 Union Types

```jac
obj Example {
    has value: int | str | None;
}

def process(data: list[int] | dict[str, int]) {
    # Handle either type
}
```

## 6 Type References

Type references are used in OSP operations like filtering graph traversals by node type. The `Root` keyword refers to the root node type in entry/exit clauses, and the `[?:TypeName]` syntax filters collections or traversals by type.

```jac
def example() {
    # In edge references
    [-->][?:Person];  # Filter nodes by Person type
}
```

## 7 Literals

**Numbers:**

```jac
def example() {
    decimal = 42;
    hex = 0x2A;
    octal = 0o52;
    binary = 0b101010;
    floating = 3.14159;
    scientific = 1.5e-10;

    # Underscore separators (for readability)
    million = 1_000_000;
    hex_word = 0xFF_FF;
}
```

**Strings:**

```jac
def example() {
    regular = "hello\nworld";
    raw = r"no\escape";
    bytes_lit = b"binary data";
    x = 42;
    f_string = f"Value: {x}";
    multiline = """
        Multiple
        lines
    """;
}
```

## 8 F-String Format Specifications

F-strings support powerful formatting with the syntax `{expression:format_spec}`.

**Basic formatting:**

```jac
def example() {
    name = "Alice";
    age = 30;

    # Simple interpolation
    greeting = f"Hello, {name}!";

    # With expressions
    message = f"In 5 years: {age + 5}";
}
```

**Width and alignment:**

```jac
def example() {
    name = "Alice";
    # Width specification
    f"{name:10}";           # "Alice     " (10 chars, left-aligned)
    f"{name:>10}";          # "     Alice" (right-aligned)
    f"{name:^10}";          # "  Alice   " (centered)
    f"{name:<10}";          # "Alice     " (left-aligned, explicit)

    # Fill character
    f"{name:*>10}";         # "*****Alice" (fill with *)
    f"{name:-^10}";         # "--Alice---" (centered with -)
}
```

**Number formatting:**

```jac
def example() {
    n = 42;
    pi = 3.14159265;

    # Integer formats
    f"{n:d}";               # "42" (decimal)
    f"{n:b}";               # "101010" (binary)
    f"{n:o}";               # "52" (octal)
    f"{n:x}";               # "2a" (hex lowercase)
    f"{n:X}";               # "2A" (hex uppercase)
    f"{n:05d}";             # "00042" (zero-padded, width 5)

    # Float formats
    f"{pi:f}";              # "3.141593" (fixed-point, 6 decimals default)
    f"{pi:.2f}";            # "3.14" (2 decimal places)
    f"{pi:10.2f}";          # "      3.14" (width 10, 2 decimals)
    f"{pi:e}";              # "3.141593e+00" (scientific notation)
    f"{pi:.2e}";            # "3.14e+00" (scientific, 2 decimals)
    f"{pi:g}";              # "3.14159" (general format)

    # Percentage
    ratio = 0.756;
    f"{ratio:.1%}";         # "75.6%"

    # Thousands separator
    big = 1234567;
    f"{big:,}";             # "1,234,567"
    f"{big:_}";             # "1_234_567" (underscore separator)
}
```

**Sign and padding:**

```jac
def example() {
    x = 42;
    y = -42;

    f"{x:+}";               # "+42" (always show sign)
    f"{y:+}";               # "-42"
    f"{x:05}";              # "00042" (zero-padded)
}
```

**Conversions (`!r`, `!s`, `!a`):**

```jac
def example() {
    text = "hello\nworld";

    f"{text}";              # "hello\nworld" (default str())
    f"{text!s}";            # "hello\nworld" (explicit str())
    f"{text!r}";            # "'hello\\nworld'" (repr())
    f"{text!a}";            # "'hello\\nworld'" (ascii())
}
```

**Nested expressions:**

```jac
def example() {
    width = 10;
    pi = 3.14159;

    # Dynamic width
    f"{pi:{width}}";   # "   3.14159"

    # Expression in format
    value = "test";
    f"{value:>10}";    # "      test"
}
```

**Format specification grammar:**

```
[[fill]align][sign][#][0][width][grouping][.precision][type]

fill      : any character
align     : '<' (left) | '>' (right) | '^' (center) | '=' (pad after sign)
sign      : '+' | '-' | ' '
#         : alternate form (0x for hex, etc.)
0         : zero-pad
width     : minimum width
grouping  : ',' or '_' for thousands
precision : digits after decimal
type      : 's' 'd' 'f' 'e' 'g' 'b' 'o' 'x' 'X' '%'
```

**Collections:**

```jac
def example() {
    list_lit = [1, 2, 3];
    tuple_lit = (1, 2, 3);
    set_lit = {1, 2, 3};
    dict_lit = {"key": "value", "num": 42};
    empty_dict: dict = {};
    empty_list: list = [];
}
```

??? example "Try it: Literals and collections"
    ```jac
    with entry {
        name = "Jac";
        nums = [1, 2, 3, 4, 5];
        info = {"language": name, "version": "0.10"};
        evens = [x for x in nums if x % 2 == 0];
        print(f"{name} evens: {evens}");
        print(f"Info: {info}");
    }
    ```
