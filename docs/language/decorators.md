---
description: Decorators, compile-time calls that record facts on the declaration they precede; the facts jaclang.comptime provides (inline, noinline, cold, align, fast_math), writing your own, and what replaces a run-time wrapper, @staticmethod and @property.
keywords: decorator, decorators, @, inline, noinline, cold, align, fast_math, fast-math
grammar: decorators, decorated
---
# Decorators

A decorator is a compile-time call on the declaration it precedes, and
nothing else. `@d` before a function, a method, a nested `def` or an
archetype calls the `comptime` function `d` while the program compiles,
giving it the declaration. What `d` records is a fact of the declaration
(inline it, align it, keep it cold); what the declaration computes is what
it would compute undecorated. A decorator never wraps or replaces a
function.

```jac
import from jaclang.comptime { inline, noinline, cold, align }

@inline
def dot3(a: list[float], b: list[float]) -> float {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

@noinline
@align(64)
def spread(x: int) -> int {
    return x * 3 + 1;
}

@cold
def rare(why: str) -> str {
    return "rare: " + why;
}

with entry {
    print(dot3([1.0, 2.0, 3.0], [4.0, 5.0, 6.0]), spread(4), rare("never"));
}
```

```output
32.0 13 rare: never
```

## Syntax

```ebnf
decorators ::= ("@" atomic_chain)*

decorated ::= test_decl | ability | enum_decl | impl_def | archetype
```

A decorator is `@` and a name, optionally called with arguments
(`@align(64)`). Several stack, one per line, above the declaration.

## What a decorator call does

- **It is a call of a `comptime` function.** `@d(a, b)` before a declaration
  calls `d(decl, a, b)` as the program compiles: first the declaration (a
  function as a `Callable`, an archetype as a type), then the decorator's
  own arguments. Those arguments are compile-time values (see
  [Compile-time evaluation](compile-time.md)), positional only.
- **A declaration's decorators run top to bottom**, before any body is
  checked. A nested `def`'s decorators run when the function it is in is
  checked.
- **What a decorator records is a fact of the declaration.** The facts are
  recorded nowhere else: calling `inline(f)` in code that runs, or on a
  declaration other than the one the decorator was given, is an error
  (E1491).
- **The facts change how a function is compiled, never what it computes.**
  A host they mean nothing to (a `cpython`, `node`, `browser` or `hermes`
  space) compiles the function as it is.

## The facts

`jaclang.comptime` provides these. Each is of a function with a body, and
`align` of a [struct](structs.md) too.

| Decorator | Fact |
|---|---|
| `@inline` | The function is inlined at every call, whatever its size, in every module that calls it: in a plain build as in a `--release` one. A function on a cycle of calls (one that calls itself, directly or through others) cannot be: E1493. |
| `@noinline` | Every call of it stays a call, in a [kernel](../accel/kernels.md)'s code too. |
| `@cold` | It runs rarely: a slow path kept out of line (it is `noinline` too), so the fast path that calls it stays small. |
| `@align(n)` | Its code starts at a multiple of `n` bytes, `n` a power of two up to 4096 (E1495). Of a struct, see below. |
| `@fast_math(*flags)` | Its float operations may be computed as LLVM's fast-math flags allow. See below. |

### align of a struct

`@align(n)` before a struct aligns it to `n` as C's `alignas` does: its
size is a multiple of `n`, so a C array of it (a [packed list](packed-lists.md)'s
storage, `ptr[P]`, a [tensor](../accel/tensors.md)'s elements) and a struct
holding it lay it out as C does. `n` is at least what its fields need
(E1561).

```jac
import from jaclang.comptime { align }

@align(16)
struct Vec3 {
    has x: f32 = 0.0,
        y: f32 = 0.0,
        z: f32 = 0.0;
}

struct Tagged {
    has tag: u8 = 0,
        at: Vec3 = Vec3();
}

def main {
    vs: list[Vec3] = [Vec3(x=1.0), Vec3(z=3.0)];
    ts: list[Tagged] = [Tagged(), Tagged(tag=1)];
    pv = ptr[Vec3](__list_data_ptr(vs));
    pt = ptr[Tagged](__list_data_ptr(ts));
    print(int(pv + 1) - int(pv), int(pt + 1) - int(pt), pv[1].z);
}

with entry {
    main();
}
```

```output
16 32 3.0
```

`Vec3`'s fields are 12 bytes; aligned to 16, each element of the list takes
16. `Tagged` puts its `Vec3` at offset 16, after the `u8` and its padding.

### fast_math

`@fast_math("reassoc", "contract")` names the flags it allows, and
`@fast_math` alone allows all of them. Another name is refused (E1572).

| Flag | Allows |
|---|---|
| `"reassoc"` | A sum or product regrouped, so a loop's float sum is computed a vector at a time. |
| `"contract"` | A product and a sum fused into one operation. |
| `"nnan"`, `"ninf"` | Assuming no NaN or infinity reaches an operation. One that does gives an undefined result. |
| `"nsz"` | Ignoring the sign of a zero. |
| `"arcp"` | A division computed as a product with a reciprocal. |
| `"afn"` | Approximated math functions. |

The flags apply to the function's own code (in a kernel's code too) and to
the closures written in it (a `flow for` body, a lambda). A function it
calls computes as its own declaration says, inlined or not.

Without `fast_math`, a float operation is IEEE's, rounded as written, in
every function, so its result is the same on every device. With it, results
may differ in their last digits as the regrouping does. That is the point
of the flag.

```jac
import from jaclang.comptime { fast_math }

@fast_math("reassoc", "contract")
def total(xs: list[float]) -> float {
    s = 0.0;
    for x in xs {
        s += x;
    }
    return s;
}

with entry {
    print(total([1.0, 2.0, 3.5]));
}
```

```output
6.5
```

## Writing your own

A decorator of the program's own is a `comptime def` that composes the
facts. It is given the declaration first, then the decorator's arguments,
and may choose with `comptime if` as any compile-time code does, for
example by [`target()`](compile-time-values.md):

```jac
import from jaclang.comptime { inline, align, target }

comptime def hot(f: Callable) {
    inline(f);
    comptime if target().arch == "x86_64" {
        align(f, 32);
    }
}

comptime def aligned_to(f: Callable, n: int) {
    align(f, n);
}

@hot
def squared(x: int) -> int {
    return x * x;
}

@aligned_to(64)
def halved(x: int) -> int {
    return x // 2;
}

with entry {
    print(squared(4), halved(10));
}
```

```output
16 5
```

Each fact is recorded on the declaration the decorator was given, and only
there: `hot` may call `inline(f)` on its `f`, not on another function
(E1491).

A decorator of an archetype or of an enum is given the type. It can check
the declaration's shape as the program compiles, with a `comptime assert`
and the [reflection](reflection.md) helpers:

```jac
# expect: E0109 x2
import from jaclang.comptime { fields, members }

comptime def small(t: any) {
    comptime assert len(fields(t)) <= 2, "a small class has 2 fields at most";
}

comptime def paired(e: any) {
    comptime assert len(members(e)) == 2, "an enum of two members";
}

@small
obj Pixel {
    has r: int = 0,
        g: int = 0,
        b: int = 0;
}

@paired
enum Signal {
    STOP,
    WAIT,
    GO,
}
```

## Run-time wrappers are calls

A function that wraps another as the program runs is not a decorator: `@`
before a declaration names a `comptime` function, and anything else is
refused (E1490). Call the wrapper and bind its result where the program
needs it:

```jac
def logged(f: Callable[[int], int]) -> Callable[[int], int] {
    def wrapped(x: int) -> int {
        print("calling with", x);
        return f(x);
    }
    return wrapped;
}

def double_of(x: int) -> int {
    return x * 2;
}

glob double: Callable[[int], int] = logged(double_of);

with entry {
    print(double(21));
}
```

```output
calling with 21
42
```

The same holds for a Python library's wrappers and registrations:
`glob fib = lru_cache(maxsize=32)(fib_of);`, `app.route("/hi")(hello);`.

## @staticmethod and @property

Python's `@staticmethod` and `@property` are not Jac. A static method is
`static def` (see [Methods](methods.md)), and a property is a field with
accessors, `has area: int { getter { ... } }` (see [Fields](fields.md)).
Writing the decorator is an error: W3001 and W3043 (`@name.setter` too).

```jac
# expect: W3001, W3043
obj Box {
    has width: int = 1;

    @staticmethod
    def unit -> int {
        return 1;
    }

    @property
    def area -> int {
        return self.width * self.width;
    }
}
```

## What is rejected

```jac
# expect: E1490, E1491, E1492 x2, E1493, E1494, E1495, E1496, E1561, E1572
import from jaclang.comptime { inline, noinline, cold, align, fast_math }

def wrap(f: Callable[[int], int]) -> Callable[[int], int] {
    return f;
}

@wrap
def wrapped(x: int) -> int {
    return x;
}

@inline
comptime def twice(n: int) -> int {
    return n * 2;
}

@inline
obj Point {
    has x: int = 0;
}

@inline
def countdown(n: int) -> int {
    return 0 if n == 0 else countdown(n - 1);
}

@inline
@cold
def torn(x: int) -> int {
    return x;
}

@align(24)
def odd(x: int) -> int {
    return x;
}

@align(2)
struct Tight {
    has x: f32 = 0.0;
}

@fast_math("fast")
def blended(x: float) -> float {
    return x * 2.0 + 1.0;
}

def body -> int;

@noinline
impl body -> int {
    return 1;
}

with entry {
    inline(wrapped);
}
```

| Code | Meaning |
|---|---|
| E1490 | The decorator is not a `comptime` function (a run-time wrapper, a C function). Call a wrapper instead. |
| E1491 | A fact is recorded outside a decorator's evaluation, or on a declaration other than the one the decorator was given. |
| E1492 | A fact is applied to a declaration it is not of: a class (but `align` of a struct), a C function, a `comptime` function, an abstract method. |
| E1493 | `@inline` of a function on a cycle of calls. |
| E1494 | Two facts that disagree (`@inline` and `@cold`, two different `@align`s). |
| E1495 | An alignment that is not a power of two up to 4096. |
| E1496 | A decorator before an `impl` or a `test`. Write it before the declaration the `impl` is of. |
| E1561 | `@align(n)` of a struct with `n` less than its fields' alignment. |
| E1572 | `fast_math` given a name that is not one of its flags. |
| E0033 | A decorator's argument is not known at compile time (a `glob`). |
| E1052 | A decorator's argument is passed by keyword (`@align(n=32)`). |
| W3001, W3043 | `@staticmethod`, `@property` or `@name.setter`. |

## Differences from Python and the reference design

- In Python and in the reference design a decorator is a function called when the
  definition runs, and its result replaces the function. Here it is a
  compile-time call that records facts, and the function stays itself.
  `@functools.lru_cache` and similar run-time wrappers are written as
  calls.
- `@staticmethod` and `@property` are not Jac's spellings: use
  `static def` and a `has` with accessors.
