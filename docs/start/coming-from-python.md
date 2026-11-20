---
description: What a Python programmer gets wrong in Jac - Python's forms beside Jac's with the code each old form gets, then the syntax, typing and semantics that differ, what Python has that Jac spells otherwise, and the standard library.
keywords: python differences, coming from python
---
# Coming from Python

Jac reads like Python, and most of what a Python programmer writes inside a function carries over:
expressions, operators, f-strings, comprehensions, the builtins, the methods of `str`, `list` and
`dict`, `try`, `with`, `match`, `async`. This page lists what does not. Read
[The language in one page](primer.md) (`jac docs primer`) first; this page assumes it.

Every Python spelling below that Jac does not accept is an error with a code, and `jac check`
reports it; `jac docs <code>` explains each one.

## Python's forms and Jac's

| In Python you write | In Jac you write | Code for the Python form | Why |
|---|---|---|---|
| `if x:` and an indented block | `if x { ... }` | E0001 | Blocks are braces; indentation means nothing |
| A newline ends a statement | `;` ends a statement | E0002 | |
| `x = 1` at module level | `glob x = 1;`, or code in `with entry { }` | E0005 | The top level holds declarations only |
| `if __name__ == "__main__":` | `with entry:__main__ { ... }` | | |
| `from m import a, b` | `import from m { a, b }` | E0005 | |
| `from m import *` | `include m;` | | |
| `import` inside a function | at the top level only | E5090 | Imports are resolved when the program compiles |
| `class P:` with `def __init__(self, x)` | `class P { has x: int; }`, or `obj P { has x: int; }` for a dataclass | E0001 | `has` declares fields; the constructor is generated. A `class` prints and compares as Python's plain class, an `obj` as a dataclass |
| `def __init__`, `def __post_init__` | `def init`, `def postinit` | W3004 | |
| `def area(self) -> float:` | `def area -> float { ... }` | W3005 for `def area()` | `self` is implicit; no parameters, no parentheses |
| `@staticmethod` | `static def` | W3001 | |
| `@classmethod` | `class def`, which has `cls` | E1490 | A decorator is a compile-time call |
| `@property` | `has x: T { getter { ... } }` | W3043 | |
| `super().m()` | `super.m()` | E5090 | |
| `@dataclass`, `@functools.lru_cache` | `obj`; `glob f = lru_cache(maxsize=None)(f_impl);` | E1490 | A decorator records facts at compile time and never wraps |
| `global x`, `nonlocal x` | Nothing: assign the name | E0002 | Assigning a global's name, or an enclosing function's local, rebinds it |
| `pass` | An empty block, `{}` | E2225 | `pass` is no word of Jac |
| `lambda x: x + 1` | `lambda (x: int) -> int { return x + 1; }` | E0022 | Parameters are typed and the body is a block |
| `a, b = b, a`, `return a, b`, `t = 1, 2` | `(a, b) = (b, a);`, `return (a, b);` | E0002 | A tuple always has its parentheses |
| `for k, v in d.items():` | `for (k, v) in d.items() {` | E0001 | |
| `first, *rest = xs` | `first = xs[0]; rest = xs[1:];` | E0130 | A starred target is not accepted |
| `case (a, b):` | `case [a, b]:` | E0155 | A sequence pattern is written in brackets |
| `Optional[int]`, `List[int]`, `Any` | `int \| None`, `list[int]`, `any` | E5090 (`Any`: E2018) | |
| `xs: list` | `xs: list[int]` | E1036 | A container type names its element types |
| `x = None`, assigned something later | `x: Cat \| None = None;` | W1051 | Nothing to infer the type from |
| `x = 1`, later `x = "a"` | `x: int \| str = 1;` | E1452 | A local has one type |
| `"a" == 1` (False), `1 < "a"` (TypeError) | | E1110 | Comparing unrelated types is a compile error |
| `x is 1` | `x == 1` | W3035 | `is` compares identity |
| `raise ValueError` | `raise ValueError()` | E1090 | `raise` takes an instance |
| `except:` | `except Exception { ... }` | E0002 | An `except` names its class |
| `f"{x=}"` | `f"x={x}"` | E0002 | |
| `p.new_attr = 1` | declare `new_attr` with `has` | E1030 | An object has exactly its declared fields |
| `def g(n): yield n` | `def g(n: int) -> Iterator[int] { yield n; }` | E1202 | A generator declares what it yields |
| `save(3)` for `async def save` | `await save(3);` | E1278 | A coroutine made and dropped never runs |
| A function that falls off its end | `return` a value on every path | E1004 | Only a return type that admits `None` may end without one |
| `def area(w, h): return w * h` | `def area(w: int, h: int) -> int { return w * h; }` | E0052, E1003 | Parameters are typed, and a function that returns a value declares its type |
| `list = [1]`, `def f(type: str)` | another name | E0013 | Type words and keywords are reserved |
| `{P()}` of a dataclass | define `__hash__`, or declare `P` a `class` | E1180 | An `obj` compares by fields, so it has no default hash; a `class` hashes by identity |

## Syntax

A class written as Jac writes it: fields with `has`, the constructor generated (or written as
`init`), `postinit` for what depends on the fields, a property with a getter and a setter, methods
without `self` among their parameters, and no parentheses where there are no parameters.

```jac
obj Temperature {
    has celsius: float = 0.0,
        label: str postinit;

    static has scale: str = "C";

    def postinit {
        self.label = f"{self.celsius}{Temperature.scale}";
    }

    has fahrenheit: float {
        getter {
            return self.celsius * 9.0 / 5.0 + 32.0;
        }
        setter(v: float) {
            self.celsius = (v - 32.0) * 5.0 / 9.0;
        }
    }

    static def freezing -> Temperature {
        return Temperature(0.0);
    }

    def warmer(delta: float) -> Temperature {
        return Temperature(self.celsius + delta);
    }
}

with entry {
    t = Temperature(20.0);
    t.fahrenheit = 212.0;
    print(t, t.fahrenheit, Temperature.freezing().warmer(5.0).label);
}
```

```output
Temperature(celsius=100.0, label='20.0C') 212.0 5.0C
```

The same class with Python's spellings is refused. Most are found while the file is read, so
`jac check` reports these four first and the decorators once they are fixed:

```jac
# expect: W3005 x3, E0022
obj Temperature() {
    has celsius: float = 0.0;

    def freezing() -> Temperature {
        return Temperature(0.0);
    }
}

def scale() -> str {
    return "C";
}

with entry {
    f = lambda c: c * 1.8;
}
```

`jac fmt --fix` rewrites the spellings that have one meaning (`def f()`, `__init__`,
`@staticmethod`, `@property`, ...); see [Lint rules](../toolchain/lint.md) (`jac docs lint`).

## Types

- **Annotations are checked, and a type error stops the build.** A parameter, a field and a
  function's result are annotated; a local is inferred from its first binding and keeps that type.
- **`T | None` is an optional value** and `A | B` a union. A test narrows it: `if x is not None`,
  `isinstance(x, str)`, a `match` class pattern. An attribute of a union that has not been narrowed
  is looked up as the program runs.
- **A `bool` is not an `int` where one is declared** (`f(True)` for `n: int` is E1053), and a
  `float` is never silently an `int` (E1001). `x as int` asserts a type and never converts; write
  `int(x)`.
- **`any` is the escape hatch.** Any value converts to it, and every operation on it is resolved as
  the program runs: what it does not support raises `TypeError` or `AttributeError` then, not at
  compile time. It costs speed as well: a loop that sums into an `any` runs tens of times slower
  than the same loop on an `int`. Use it at the edges, for data whose shape is unknown until read.

```jac
# expect: E1452, W1051, E1110, E1053
def double(n: int) -> int {
    return n * 2;
}

with entry {
    x = 1;
    x = "one";
    found = None;
    print("a" == 1, double(True));
}
```

More: `jac docs types`, `jac docs variables`.

## Semantics that differ

### Integers are 64 bits

`int` arithmetic past 64 bits raises `OverflowError`, where Python makes a larger int. The sized
types (`u8`, `i32`, ...) raise past their own range; `+%`, `-%`, `*%` wrap and `+|`, `-|`, `*|`
saturate. `int ** int` with a negative exponent known only as the program runs raises `ValueError`,
because the result's type was decided as `int`; write `2.0 ** n`. Library functions follow:
`math.factorial(25)` raises.

```jac
import math;

with entry {
    try {
        print(2 ** 63);
    } except OverflowError as e {
        print("OverflowError:", e);
    }
    small: u8 = 250;
    print(small +% u8(10), small +| u8(10));
    n = -1;
    try {
        print(2 ** n);
    } except ValueError as e {
        print("ValueError:", e);
    }
    print(2.0 ** n);
    try {
        print(math.factorial(25));
    } except OverflowError as e {
        print("OverflowError:", e);
    }
}
```

```output
OverflowError: integer overflow
4 255
ValueError: int ** negative int is a float; convert the base with float()
0.5
OverflowError: factorial() result too large
```

A program that needs more than 64 bits as it runs says so with `i128` or `u128`. More:
`jac docs numbers`.

### Defaults, closures, equality, scope

```jac
glob total: int = 0;

obj Point {
    has x: int = 0,
        y: int = 0;
}

def push(x: int, into: list[int] = []) -> list[int] {
    into.append(x);
    return into;
}

def add(n: int) {
    total += n;
}

with entry {
    print(push(1), push(2));
    fs: list[Callable[[], int]] = [];
    for i in range(3) {
        fs.append(lambda -> int { return i; });
    }
    j = 0;
    gs: list[Callable[[], int]] = [];
    while j < 3 {
        gs.append(lambda -> int { return j; });
        j += 1;
    }
    print([f() for f in fs], [g() for g in gs]);
    print(Point(1, 2) == Point(1, 2), Point(1, 2) is Point(1, 2), type(Point()));
    add(5);
    add(2);
    print(total);
}
```

```output
[1] [2]
[0, 1, 2] [3, 3, 3]
True False <class 'Point'>
7
```

- **A default is evaluated at each call that leaves it out**, so a `[]` default is a new list each
  time; in Python it is made once and shared.
- **Each pass of a `for` loop has its own variable**, so a closure made in the body keeps that
  pass's value; Python's closures all see the last. A variable assigned in a `while` loop is one
  variable, as in Python.
- **An `obj` compares by its fields**, like a dataclass, and has no hash unless it defines
  `__hash__` (E1180 as a dict key or set member). A `class`, Python's plain class, `node`, `edge`
  and `walker` compare by identity.
  `type(p)` prints `<class 'Point'>`, without the module.
- **There is no `global` or `nonlocal`.** Assigning a global's name in a function assigns the
  global, and a nested function assigns its enclosing function's variables (see
  [Functions](../language/functions.md)).

### Other differences

| Python | Jac |
|---|---|
| `del x` only unbinds the name | The same for a local, a list item, a dict entry or a field; but `del n` of a variable typed as a node or an edge also takes it out of the graph |
| An `except ... as e` may reuse a local's name | A clause binds a name of its own; an existing local of that name is E1453 |
| `self.__x` is mangled to `_C__x` | No name mangling |
| `*args` is a tuple | `*args` is a `list` |
| `Box[int]` and `Box[str]` are one class at run time | A generic class keeps its type arguments, and they are checked |
| An uncaught exception prints a traceback | The same, without the source lines |
| `isinstance(True, int)` is True and `True + 1` is 2 | The same; only a declared `int` refuses a `bool` |
| An object is true unless it defines `__bool__` or `__len__` | The same |

## What Python has that Jac spells otherwise

- **`pass`** is not a word: an empty block is `{}` (`def todo {}`).
- **Decorators** are compile-time calls that record facts on a declaration: `@inline` and `@cold`
  from `jaclang.comptime`, or a `comptime def` of your own. A run-time wrapper is an ordinary call:
  `glob fib = lru_cache(maxsize=None)(fib_of);`. See `jac docs decorators`.
- **`match`** has Python's patterns, with sequence patterns in brackets only and class patterns
  bound by field order; `case list(xs)` and the other container class patterns are not available.
  `switch` is a separate statement with C's fallthrough. See `jac docs match`.
- **Comprehensions** are Python's: list, dict, set and generator, with several `for` and `if`
  clauses. Unpacking in their `for` takes parentheses: `{k: v for (k, v) in pairs}`.
- **`with`** is Python's `with`, with braces: `with open(p) as f { ... }`. See
  `jac docs context-managers`.
- **`async def`, `await` and `async for`** are Python's, with declared types, and `asyncio` is
  a native module: `asyncio.run(main())` runs a coroutine. See `jac docs async` and
  `jac docs asyncio`.
- **Jac adds** what Python has no form for: `for i = 0 while i < n with i += 1`, `forever`,
  `switch`, `glob`, `impl`, `struct`, `enum` as a declaration, `comptime`, and the object-spatial
  forms (`node`, `edge`, `walker`, `visit`, `spawn`, ...).

```jac
import from functools { lru_cache }

def fib_of(n: int) -> int {
    return n if n < 2 else fib(n - 1) + fib(n - 2);
}

glob fib = lru_cache(maxsize=None)(fib_of);

def todo {}

with entry:__main__ {
    todo();
    pairs = [("a", 1), ("b", 2)];
    print(fib(80), {k: v * 10 for (k, v) in pairs}, sum(v for (_, v) in pairs));
}
```

```output
23416728348467685 {'a': 10, 'b': 20} 3
```

## The standard library

`import os` in a native program does not run CPython's `os`. jac has its own implementation of
much of the standard library (`os`, `os.path`, `sys`, `io`, `json`, `re`, `math`, `random`,
`datetime`, `decimal`, `collections`, `itertools`, `functools`, `pathlib`, `subprocess`, `argparse`,
`logging`, `threading`, `asyncio`, `socket`, `sqlite3`, `email`, ...), written in Jac and compiled
into the program. Each has the Python module's names and behavior: the same calls print the same
output and raise the same exceptions. Three differences hold in every one of them, because they come
from the language: `int` is 64 bits, an argument of the wrong type is a compile error rather than a
`TypeError`, and no warnings are issued.

A module jac does not have natively (`pickle`, `inspect`, `typing`, ...) and any package
installed with `jac install --pypi <name>` comes from CPython 3.15, which the program then
embeds; its values are Python objects. A package is native or CPython's, never a mix: a submodule
the native package lacks (`import json.tool`) is E5143, and a name left out of a native module on
purpose (`collections.namedtuple`) is E5142, whose message names the alternative.

```jac
import json;
import pickle;

with entry {
    print(json.dumps({"total": [1, 2]}));
    print(pickle.loads(pickle.dumps(("Ada", 36))));
}
```

```output
{"total": [1, 2]}
('Ada', 36)
```

More: `jac docs library`, `jac docs stdlib`, `jac docs interop/python`.

## Where to go next

- [The language in one page](primer.md) (`jac docs primer`), if you skipped it.
- [Types](../language/types.md) (`jac docs types`) and [Functions](../language/functions.md)
  (`jac docs functions`): the rules this page summarizes.
- [Object-spatial programming](../language/object-spatial.md) (`jac docs object-spatial`): the
  part of Jac Python has no counterpart for.
