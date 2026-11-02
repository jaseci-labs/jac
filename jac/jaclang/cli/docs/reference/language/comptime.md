# Compile-Time Evaluation

> **Related:** [Types & Values](types-and-values.md) | [Functions & Objects](functions-objects.md) | [Native Compilation](native-pathway.md) | [Diagnostics](../diagnostics.md)

**On this page:**

- [Overview](#overview) - What `comptime` means and when to reach for it
- [Bindings](#bindings) - Values the compiler computes once
- [Branches, Loops, and Assertions](#branches-loops-and-assertions) - `comptime if`, `comptime for`, `comptime assert`
- [Compile-Time Functions and Imports](#compile-time-functions-and-imports) - `comptime def` and `comptime import`
- [Comptime Parameters](#comptime-parameters) - Functions specialized per argument value
- [Archetype Value Parameters](#archetype-value-parameters) - `obj Matrix[T, comptime rows: int]` and class-body bindings
- [Records, `init`, and `Self`](#records-init-and-self) - What the evaluator does with archetypes
- [Files and Sizes](#files-and-sizes) - `embed_file`, `sizeof`, `alignof`, `set_fuel`
- [Reflection](#reflection) - The `jaclang.comptime` intrinsics
- [What Can Be Evaluated](#what-can-be-evaluated) - The interpreted subset and its limits
- [Per-Tier Behavior](#per-tier-behavior) - Python, client, and native lowering
- [Diagnostics](#diagnostics) - `E0033`, `E0108`, `E0109`

---

## Overview

`comptime` marks a value, statement, parameter, function, or import that the compiler settles while the module compiles. It is a property of values, not a macro system: an expression is comptime-known when the type checker can already compute it from literals, other comptime values, enum members, types, and the program's own declarations. There is no separate language for the compile-time part; the same Jac is interpreted by the compiler.

Reach for it when a value is derived from the program itself (a table of every enum member, the fields of an `obj`, a command's handler name), when a choice should disappear from the output for one target, or when an invariant belongs in the build rather than in a runtime check.

```jac
comptime BOARD_SIZE: int = 8;
comptime SQUARES: int = BOARD_SIZE * BOARD_SIZE;

with entry {
    comptime assert SQUARES == 64, "an eight by eight board has 64 squares";
    print(SQUARES);
}
```

## Bindings

A `comptime` binding declares a name whose initializer must be comptime-known. At module level it takes the place of `glob`; inside a body it takes the place of a local assignment. Every use of the name is treated as the computed value.

```jac
enum Level {
    LOW = 1,
    MID = 5,
    HIGH = 9
}

comptime THRESHOLDS: dict[str, int] = {"low": Level.LOW.value, "high": Level.HIGH.value};

def classify(n: int) -> str {
    comptime cutoff: int = THRESHOLDS["high"] - THRESHOLDS["low"];
    return "wide" if n > cutoff else "narrow";
}
```

An initializer that depends on a runtime value reports `E0033`; one that raises while being evaluated reports `E0108` with the reason.

## Branches, Loops, and Assertions

`comptime if` requires a comptime-known condition and keeps only the branch that was taken; the other branch is removed before any backend sees it, so it may reference names that do not exist on the current tier.

```jac
import from jaclang.comptime { codespace }

def where_am_i -> str {
    comptime if codespace.is_native {
        return "machine code";
    } else {
        return "python or javascript";
    }
}
```

`comptime for` iterates a comptime-known collection and binds its loop variable as a comptime value inside the body. Each iteration is settled separately, so a `comptime if` on the loop variable prunes per element.

```jac
comptime TAGS: list[str] = ["alpha", "beta"];

def total_len -> int {
    total = 0;
    comptime for tag in TAGS {
        total += len(tag);
    }
    return total;
}
```

`comptime assert` checks its condition during compilation and fails the build with `E0109` and the message; nothing remains at runtime. It is allowed at module level as well as inside bodies, so an invariant can sit next to the declarations it protects.

## Compile-Time Functions and Imports

A `comptime def` exists only during compilation. It can be called from any comptime site (an initializer, a condition, an assertion, another comptime def), and its result is folded into the program. A call from a runtime site is folded when the result can be written down on that tier and reports `E0033` otherwise.

```jac
comptime def stride(n: int) -> int {
    return n * 2 + 1;
}

comptime STRIDE: int = stride(4);
```

A `comptime def` may return a type. The result is a comptime value like any other, so it can seed a binding, be instantiated, or be compared to another type:

```jac
obj Narrow {
    has v: i32;
}

obj Wide {
    has v: i64;
}

comptime def cell(comptime big: bool) -> type {
    return Wide if big else Narrow;
}

comptime Cell: type = cell(True);

with entry {
    print(Cell(v=7).v);
}
```

A `comptime import` brings names in for compile-time use only; the import itself is erased from every backend. Use it for the reflection intrinsics and for compile-time values shared between modules.

```jac
comptime import from jaclang.comptime { members, name as ct_name }

enum Suit {
    HEARTS,
    SPADES
}

comptime SUIT_COUNT: int = len(members(Suit));

def helper -> int {
    return SUIT_COUNT;
}

comptime HELPER_NAME: str = ct_name(helper);
```

## Comptime Parameters

A parameter marked `comptime` must receive a comptime-known argument at every call site. Inside the body the parameter is a comptime value, so `comptime if` and `comptime for` can depend on it.

```jac
def repeat(comptime n: int, msg: str) -> str {
    out = "";
    comptime for _ in range(n) {
        out += msg;
    }
    return out;
}

with entry {
    print(repeat(3, "ab"));
}
```

On the native tier every distinct argument value produces its own specialized function; on the Python and client tiers the parameter erases to an ordinary one and the argument is still checked at compile time.

## Archetype Value Parameters

An archetype's `[]` list may carry `comptime` value parameters beside its type parameters. Instantiate the archetype by subscripting it with comptime-known values; the values become fields of the instance, so methods read them without any extra plumbing, and comptime sites see them as constants.

```jac
obj Matrix[T, comptime rows: int, comptime cols: int] {
    has data: list[T];

    comptime SIZE: int = rows * cols;

    def at(r: int, c: int) -> T {
        return self.data[r * cols + c];
    }
}

with entry {
    m = Matrix[float, 3, 4](data=[0.0] * 12);
    print(m.at(1, 2), Matrix[float, 3, 4].SIZE, m.SIZE);
}
```

`Matrix[float, 3, 4].SIZE` folds to `12` wherever it is written; the type parameter `T` keeps its ordinary meaning. Calling `Matrix(...)` without the subscript reports `E0033`, since the comptime parameters have no value. A subscripted archetype is itself a value: `comptime Small: type = Matrix[float, 2, 2];` binds a specialization that can be instantiated later.

Inside the body, `comptime NAME: T = expr;` declares a class-body binding. When the initializer depends only on literals it is a class attribute; when it depends on the comptime parameters it is evaluated per instantiation at comptime sites and read as a property on instances at runtime.

The comptime parameters erase to constructor-bound fields on every tier: keyword-only dataclass fields on the Python tier, constructor properties on the client tier, and struct fields on the native tier. The struct layout is therefore shared by all instantiations of one archetype; only the values differ.

## Records, `init`, and `Self`

The evaluator constructs archetype instances at compile time. A plain `obj` takes its fields from the call; an `obj` with an `init` runs that body with `self` bound to the fresh record, and an `obj` with a `postinit` runs it after the fields are assigned. A record that reaches a runtime site materializes as a constructor call, or, when the archetype has `init`/`postinit`, as `jaclang.comptime.record(Cls, ...)`, which restores the fields without running the constructor twice.

```jac
obj Span {
    has lo: int,
        hi: int,
        width: int postinit;

    def postinit {
        self.width = self.hi - self.lo;
    }
}

comptime S: Span = Span(lo=4, hi=10);

with entry {
    comptime assert S.width == 6, "postinit ran at compile time";
    print(S.width);
}
```

A `comptime def` declared inside an archetype is re-evaluated for each archetype it is called on: `Self` is bound to the receiving class, so a base can describe a subclass.

```jac
comptime import from jaclang.comptime { fields }

obj Base {
    has id: int = 0;

    comptime def field_names -> list[str] {
        return [f.name for f in fields(Self)];
    }
}

obj Child(Base) {
    has extra: str = "";
}

with entry {
    comptime assert Child.field_names() == ["id", "extra"], "Self is the subclass";
    print(Base.field_names(), Child.field_names());
}
```

## Files and Sizes

`embed_file(path)` reads a UTF-8 file relative to the module at compile time and returns its text; `embed_bytes(path)` returns the raw bytes. The file becomes a dependency of the module's compiled cache, so editing it recompiles the module.

`sizeof(T)` and `alignof(T)` report the native field payload size and alignment of a type: fixed-width scalars by their width, `int`/`float` as 8 bytes, `bool` as 1, and any object, string, or container as a pointer. For an archetype the fields are laid out in declaration order with natural alignment.

`set_fuel(n)` raises the evaluation budget for the comptime work that follows it, for a computation that is known to be large.

```jac
comptime import from jaclang.comptime { alignof, set_fuel, sizeof }

obj Packed {
    has a: i32,
        b: bool,
        c: f64;
}

comptime def busy -> int {
    set_fuel(100000000);
    total = 0;
    for i in range(2000) {
        total += i;
    }
    return total;
}

comptime SUM: int = busy();

with entry {
    print(sizeof(Packed), alignof(Packed), SUM);
}
```

## Reflection

The module `jaclang.comptime` exposes program facts as comptime values. Each intrinsic also has a runtime fallback, so the same call works when it reaches the Python tier unchanged.

| Intrinsic | Returns |
|-----------|---------|
| `typeof(value)` | The static type of a value |
| `fields(T)` | A list of `FieldInfo` records (`name`, `type`, `has_default`, `default`, `semstr`) for the `has` members of `T` |
| `get_field(target, field)` | The named member of a record or instance |
| `set_field(target, field, value)` | Sets the named member |
| `has_field(T, field)` | Whether `T` declares the member |
| `members(E)` | The members of an enum |
| `semstr(T)` / `semstr(T, field)` | The `sem` string attached to a declaration |
| `name(fn)` | The declared name of a function or type |
| `module_of(value)` | The dotted module that declared a function, type, or comptime record |
| `is_subtype(A, B)` | Whether `A` is a subtype of `B` |
| `codespace` | An enum with `is_python`, `is_client`, `is_native` |
| `target` | The host `os`, `arch`, and `pointer_width` |
| `embed_file(path)` / `embed_bytes(path)` | A file beside the module, read at compile time and tracked as a cache dependency |
| `sizeof(T)` / `alignof(T)` | Native payload size and alignment of a type |
| `set_fuel(n)` | Raises the evaluation budget for the current comptime work |
| `record(Cls, **fields)` / `specialize(Cls, **params)` | Runtime helpers the backends emit for materialized records and value-parameterized archetypes |

Iterating `fields(T)` is the idiom for converters that must not drift when a `has` line is added:

```jac
import from jaclang.comptime { fields, get_field }

obj Window {
    has title: str,
        width: int = 1200,
        height: int = 800;

    def to_dict -> dict[str, any] {
        out: dict[str, any] = {};
        comptime for f in fields(Window) {
            out[f.name] = get_field(self, f.name);
        }
        return out;
    }

    static def from_dict(data: dict[str, any]) -> Window {
        kw: dict[str, any] = {};
        comptime for f in fields(Window) {
            comptime if f.has_default {
                kw[f.name] = f.`type(data.get(f.name, f.`default));
            } else {
                kw[f.name] = data[f.name];
            }
        }
        return Window(**kw);
    }
}
```

## What Can Be Evaluated

The compiler interprets a bounded subset of Jac: literals, strings and f-strings, containers and comprehensions, arithmetic, comparison, boolean and unary operators, conditional expressions, `if`/`for`/`while`, `try`/`except`/`raise`, `return`, plain-data `obj` construction and member access, method and free-function calls, enum members, the common builtins (`len`, `range`, `enumerate`, `zip`, `sorted`, `min`, `max`, `sum`, `str`, `int`, `float`, `bool`, `isinstance`, and friends), and `math`.

Evaluation is fuel-limited, has no access to the file system, network, environment, or clock, and cannot call into Python packages. Bodies of ordinary functions are interpreted only when a comptime site demands them; nothing else is folded speculatively.

Not interpreted: `match`, lambdas, generators, `async`, `with`, walkers and `spawn`, and `super` calls inside a comptime-run `init`.

The evaluator works on its own typed values rather than on live Python objects, and reproduces Python's observable behavior for them: arbitrary-precision `int`, correctly rounded `float` conversion and division, `repr`/`str`/f-string and `%` formatting, `str.format`, ordering and equality across `int`/`float`/`bool`, dict insertion order and key identity (`1`, `1.0`, and `True` are one key), and the standard exception types and messages, which `try`/`except` can catch. Only allow-listed methods of `str`, `bytes`, `list`, `tuple`, `dict`, `set`, `frozenset`, `int`, `float`, and `range` are callable. A few results that Python itself cannot reproduce from one build to the next are refused instead: `hash()` of a string, bytes, type, or enum member (Python seeds those per process) and a negative number raised to a fractional power (a complex result). A set iterates in insertion order. The `target` record describes the host that runs the compiler.

## Per-Tier Behavior

- **Python**: `comptime` bindings are emitted with their computed value, `comptime if` keeps only the live branch, `comptime for` becomes a plain loop over the materialized collection, calls to comptime defs are replaced by their results, and `comptime def`, `comptime assert`, and `comptime import` disappear.
- **Client**: the same erasure, with computed values written as literals (scalars, arrays, string-keyed objects). Values that cannot be written as JavaScript literals fall back to the structural emission and are reported by the free-identifier audit if they do not resolve.
- **Native**: scalar bindings lower to constants, `comptime for` unrolls, and functions with comptime parameters are stamped once per distinct argument value. Record-producing intrinsics such as `fields()` are not yet lowered natively.

## Diagnostics

| Code | Meaning |
|------|---------|
| `E0033` | A comptime site received something that is not known at compile time; the message names the site and the reason |
| `E0108` | Compile-time evaluation raised or could not proceed; the message carries the failure |
| `E0109` | A `comptime assert` condition was false; the message carries the assertion text |

All three block code generation for the module that reports them.
