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

**Fixed-width types** (real types on every lane, and the vocabulary of C interop):

| Type | Description | C Equivalent |
|------|-------------|--------------|
| `i8`, `u8` | 8-bit signed/unsigned integer | `int8_t`, `uint8_t` |
| `i16`, `u16` | 16-bit signed/unsigned integer | `int16_t`, `uint16_t` |
| `i32`, `u32` | 32-bit signed/unsigned integer | `int32_t`, `uint32_t` |
| `i64`, `u64` | 64-bit signed/unsigned integer | `int64_t`, `uint64_t` |
| `f32` | 32-bit float (IEEE binary32) | `float` |
| `f64` | 64-bit float (IEEE binary64) | `double` |

A C address is `ptr[T]` (a bare `ptr` is `void*`), a builtin generic rather than a scalar; see [C pointers](native-pathway.md#c-pointers-ptrt).

### Fixed-width semantics

The ten sized scalars are distinct types with one contract that the checker and every backend (server, native, client) enforce identically. `int`, `float` and `bool` are unchanged: `int` stays arbitrary-precision on the server and i64-backed natively, `float` is IEEE binary64 everywhere.

- **Implicit widening, explicit narrowing.** A conversion is implicit only when it preserves every value of the source type. `int` and `float` are ordinary members of the lattice, not exceptions: `int` is the 64-bit signed machine integer (so it behaves exactly as `i64`) and `float` is binary64 (so it behaves exactly as `f64`). The rows are `i8 -> i16 -> i32 -> i64`/`int`, `u8 -> u16 -> u32 -> u64`, unsigned into a strictly wider signed type (`u8 -> i16`, `u16 -> i32`, `u32 -> i64`), any int-kind into `f64`/`float`, exactly-representable ints into `f32` (`i8`..`u16`), `f32 -> f64`/`float`, and `bool` into any numeric type. Everything else is a checked cast `T(x)`: narrowing, a same-width sign change (`u8 <-> i8`, and `u64 -> i64`/`int`), and any float-kind into an int-kind.
- **Literals.** An int literal (including a folded unary minus) is accepted where its value is in `[T.MIN, T.MAX]` and rejected at check time otherwise (`x: u8 = 300` is `E1126`, never a silent truncation). In an operator with a sized operand, an in-range literal adopts that operand's type: `w: i32 = 1; w = w + 1` is `i32 + i32`. A float literal is accepted where the target can hold it: precision loss inside the range is accepted (`f32 = 0.1`), but a literal past the range is `E1130` rather than a silent `inf`.
- **Operators.** Operands must unify along the lattice; the result is the wider type, or `E1128` when neither side widens into the other (`u8 + i8`, `u64 < i64`, `i32 == u32` need a cast on one side). `T op int` yields `int`, so `w = w + n` with `n: int` is a narrowing error (`E1127`) while `w = w + 1` is fine. `/` on any int-kind yields `float`; `//`, `%` and `**` keep the unified sized type (`**` with a negative or non-literal exponent yields `float`). Shifts keep the left operand's type; the count may be any int-kind and must be in `[0, width)`. `>>` is arithmetic for signed types and logical for unsigned; `~` on an unsigned type is the width mask. Unary minus on an unsigned operand is `E1129`.
- **Overflow traps.** `+ - * // % ** -x abs() <<` on a sized int raise `OverflowError("integer overflow")` when the mathematical result leaves the type's range, on every lane, including `T.MIN // -1` and `-T.MIN`. Division by zero raises `ZeroDivisionError`. `f32` and `f64` never trap (`inf` and `nan` propagate); `f32` arithmetic rounds to binary32 after every operation.
- **Casts and the modular family.** `T(x)` range-checks an int-kind or bool source and truncates a float source toward zero before the range check, raising `OverflowError` out of range; a literal argument out of range is a check-time error. `T.wrap(x)` is two's-complement truncation and never traps. `wrapping_add`, `wrapping_sub`, `wrapping_mul`, `wrapping_neg` and `wrapping_shl` are ambient builtins over sized ints that never trap. `T.MIN` and `T.MAX` are the inclusive bounds of each sized int. `int(x)`, `float(x)`, `str(x)` and `bool(x)` accept sized values as before.

```jac
def checksum(data: bytes) -> u8 {
    acc: u8 = 0;
    for b in data {
        acc = wrapping_add(acc, u8(b));   # modular: never traps
    }
    return acc;
}

with entry {
    x: u8 = u8.wrap(300);                  # 44
    w: i32 = i32.MAX;
    try {
        w = w + 1;                         # OverflowError on every lane
    } except OverflowError {
        w = 0;
    }
    n: int = 300;
    y: u8 = u8(n);                         # raises OverflowError: 300 does not fit
}
```

The sized types are compile-time types with no runtime wrapper: every lane stores the value in the machine's own representation and the compiler emits the range check where the contract needs one. On the server lane a sized value is a plain `int` or `float` (`type(x) is int`), so `isinstance(x, i8)` and `type(x) is i8` are not available -- the width lives in the annotation, not in the value. On the client lane 8-, 16- and 32-bit values and `f32` are JS numbers, while `i64` and `u64` are `BigInt`. The native lane lowers each type to its own machine width.

**On the wire.** Both lanes encode 64-bit sized values the same way: a JSON number when the value fits in 2^53, and a JSON string otherwise (an ECMAScript reader cannot hold a larger integer as a number). Both decoders accept either form, so `i64`/`u64` fields round-trip between the server and the client without losing precision. Narrower widths and the float kinds are always JSON numbers. The width comes from the declared type, not from the value: an archetype field, a `def:pub` parameter or return, and anything else with an annotation encodes exactly. A value handed to the serializer through an untyped container (a bare `dict[str, any]`) carries no width, so a large `i64`/`u64` inside one crosses as a JSON number -- give the payload a typed carrier when the width has to survive the boundary.

**Cost.** The only overhead a sized type carries is the range check on the operations that can leave the range: `+ - * // ** << >>`, unary minus, `abs` and the cast `T(x)`. `& | ^ %`, every comparison, every `f64` operation and implicit widening are plain machine operations. A tight sized-integer loop runs around 3x a plain `int` loop on the server lane and around 1.6x on the client; the native lane pays nothing, because the hardware already computes the overflow flag.

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

Use `import type` to bring a name into scope **only for type annotations**. The import is registered with the type checker but elided from runtime: the Python backend lowers it to a `typing.TYPE_CHECKING` guard, and the client backend emits nothing for it at all.

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

#### Type-only exports have to be imported this way

Every import binding carries a *kind*, inherited from whatever it resolves to. The question the checker asks at an import is not "is this a type?" but **"does the backend that lowers *this* module leave a runtime binding for it?"** Where the answer is no, `import type` is not a style choice but the only correct spelling, and [`E1131`](../diagnostics.md#type-only-import-bindings) says so.

| Declaration | Runtime binding on the server | Runtime binding in the client |
|-------------|-------------------------------|-------------------------------|
| TypeScript `interface` in a `.d.ts` | -- | no |
| TypeScript `type` alias in a `.d.ts` | -- | no |
| TypeScript `declare class`, `declare enum` | -- | yes |
| TypeScript `declare const`, `declare function` | -- | yes |
| Jac `type` alias (`type Row = dict[str, int];`) | **yes** | **no** |
| Jac type parameters | no | no |
| Jac `obj`, `class`, `node`, `edge`, `walker`, `enum` | yes | yes |
| Jac `def`, `glob`, `has`, parameters | yes | yes |

A `.d.ts` `interface` or `type` alias declares no runtime export in any codespace, so a plain import of one is always E1131.

A Jac `type` alias is different, and the difference matters. The Python backend lowers `type Row = dict[str, int];` to a real module-level `TypeAliasType` object, and lowers a distinct alias `type UserId := int;` to a plain `UserId = int`, which is why `UserId(raw)` is the supported way to build a brand. Only the client backend erases aliases. So:

```jac
# server module -- fine, and `import type` here would break UserId(raw)
import from brands { UserId }
def mk(raw: int) -> UserId { return UserId(raw); }
```

```jac
# client module -- E1131 on UserId
import from brands { UserId }
```

An external module that ships no declarations at all is a value import exactly as before (`W1102`, or `E1120` under `[check] untyped-external = "error"`).

The failure this prevents is a link-time one, not a type mismatch. `mermaid` exports `Mermaid` as an interface and `mermaid` as its default value:

```jac
import from mermaid { default as mermaid, Mermaid }   # E1131 on Mermaid
```

Written that way the client backend emits `import mermaid, { Mermaid } from "mermaid";`, and the browser refuses the module with `does not provide an export named 'Mermaid'`, which takes the whole module graph down. Split the type off its own statement:

```jac
import from mermaid { default as mermaid }
import type from mermaid { Mermaid }
```

The value import survives into the bundle; the type import emits nothing.

#### A type-only binding is not a value

Because nothing binds the name at runtime, an `import type` binding is legal only in **type position**: annotations, `has` field types, return types, generic arguments, `as` casts, and `type` alias right-hand sides. Using it in **value position** -- calling it, reading an attribute off it, passing it to `isinstance` or `issubclass`, decorating with it, listing it as a base class, or assigning it -- is [`E1132`](../diagnostics.md#type-only-import-bindings).

```jac
import type from geometry { Point }

def ok(p: Point) -> Point {
    return p as Point;
}

def bad -> Point {
    return Point(1, 2);
}
```

`Point(1, 2)` is `E1132`: the annotation and the cast above it are fine, the constructor call is not. This holds on the server as well as in the client -- `import type` erases the name on both backends, so a guarded `UserId(raw)` would be a `NameError` at runtime rather than a brand. If a name is genuinely needed at runtime, import it with a plain `import from`, which requires that it actually has a runtime binding in the codespace doing the importing.

!!! note "`has` field types under Python's dataclass machinery"
    Jac archetypes are dataclass-derived on the Python backend, and libraries that resolve annotations through `typing.get_type_hints` at class-definition time (dataclass, Pydantic, attrs, FastAPI route signatures, SQLAlchemy declarative, msgspec) read the module's real globals, where a `TYPE_CHECKING`-guarded import is not present. That is a Python-runtime limitation rather than a checker rule, so it is not diagnosed: if an archetype's `has` field type or a decorator-resolved annotation has to survive to runtime, keep that name on a regular `import`.

For a name that does have a runtime export, `import type` stays opt-in -- a regular `import` binds it at runtime exactly as before.

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

### Value Parameters

An archetype's `[]` list may also carry `comptime` value parameters (`obj Matrix[T, comptime rows: int, comptime cols: int]`), instantiated as `Matrix[float, 3, 4](...)`. They erase to constructor-bound fields; see [Compile-Time Evaluation](comptime.md#archetype-value-parameters).

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
