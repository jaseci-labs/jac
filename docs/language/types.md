---
description: The builtin types, how annotations are written, unions and T | None, any, type aliases, the as cast, how the types of locals are inferred, and what jac check enforces.
keywords: types, annotation, type annotation, bool, union, optional, type, type alias, as, cast, inference, complex
grammar: type_alias, cast, cast_type
---
# Types

Every expression has a type the compiler knows before the program runs. Parameters, fields and
return values are annotated; locals are inferred. `jac check` reports every use that does not
fit, and a program that does not check does not build.

## The builtin types

| Type | Values | Notes |
|---|---|---|
| `int` | 64-bit integers | Arithmetic that overflows raises `OverflowError`. See [Numbers](numbers.md). |
| `float` | 64-bit floats | An `int` is accepted where a `float` is wanted. |
| `i8` ... `u64`, `f32`, ... | Sized numbers | See [Numbers](numbers.md). |
| `bool` | `True`, `False` | Not accepted where an `int` is declared; `int(b)` converts. |
| `complex` | `complex(re, im)` | No literal form. |
| `str` | Text | See [Strings](strings.md). |
| `bytes`, `bytearray` | Byte strings, fixed and changeable | See [Strings](strings.md). |
| `list[T]` | Ordered, changeable | See [Collections](collections.md). |
| `tuple[A, B]`, `tuple[T, ...]` | Fixed shape, or any length of one type | |
| `dict[K, V]` | Key to value, in insertion order | |
| `set[T]`, `frozenset[T]` | Unique items | |
| `None` | The one value `None` | Written as a type in a union or as a return type. |
| `any` | A value of any type, checked as the program runs | See [The `any` type](types-any.md). |
| `object` | Any value | |
| `Callable[[A, B], R]` | A function taking `A` and `B` and returning `R` | See [Functions](functions.md). |
| `Iterable[T]`, `Iterator[T]` | What a `for` loop accepts; what `yield` produces | See [Generators](generators.md). |
| `range` | What `range(...)` gives | |

Archetypes (`obj`, `class`, `struct`, `node`, `edge`, `walker`) and enums declare further types,
named by their own names; see `jac docs obj`.

The type words are keywords (see [Lexical structure](lexical-structure.md)): a program cannot
rebind `int` or `list`. Each is also the conversion or constructor of its type: `int("42")`,
`str(5)`, `float(2)`, `list("ab")`, `tuple(xs)`, `bool(0)`.

```jac
with entry {
    n: int = 3;
    ratio: float = n;
    names: list[str] = ["a", "b"];
    pair: tuple[int, str] = (1, "a");
    many: tuple[int, ...] = (1, 2, 3);
    ages: dict[str, int] = {"ann": 31};
    seen: set[int] = {1, 2};
    print(ratio, names, pair, many, ages, seen);
    print(type(n), type(names), type(None));
    print(int("42") + 1, str(5) + "!", float(2), list("ab"), bool(0));
}
```

```output
3.0 ['a', 'b'] (1, 'a') (1, 2, 3) {'ann': 31} {1, 2}
<class 'int'> <class 'list'> <class 'NoneType'>
43 5! 2.0 ['a', 'b'] False
```

## Annotations

An annotation is `: T` after a name, and `-> T` for what a function returns.

| Place | Example | Required |
|---|---|---|
| A parameter | `def area(w: int, h: int)` | Yes |
| A function's result | `-> int` | When it returns a value. With none, the function returns `None`. |
| A field | `has name: str;` | Yes |
| A global | `glob limit: int = 10;` | Unless it has a value |
| A local | `xs: list[int] = [];` | No: inferred from the first binding |

- **A container type names its element types.** `list`, `dict`, `set` or `tuple` bare is E1036:
  write `list[int]`.
- **Python's `Optional[T]` and `Union[A, B]` are not accepted** (E5090). Write `T | None` and
  `A | B`.
- **Annotations are never evaluated when the program runs**, so a type may be used before the
  declaration that defines it. `import from __future__ { annotations }` does nothing and is W3009.
- A name that declares no type is E2018 in an annotation.

```jac
# expect: E1036 x2
def first(xs: list, index: dict) -> int {
    return 0;
}
```

## Inference

A local's type is the type of its first binding, unless the binding is annotated:

| First binding | Type of the local |
|---|---|
| `n = 1` | `int` |
| `x = 2.5` | `float` |
| `xs = [1, 2]` | `list[int]` |
| `d = {"k": [1]}` | `dict[str, list[int]]` |
| `t = (1, "a")` | `tuple[int, str]` |
| `mixed = [1, "a"]` | `list[any]`: items of different types make the element type `any` |
| `r = f()` | What `f` is declared to return |
| `c = Cat()` | `Cat` |
| `sq = [x * x for x in range(3)]` | `list[int]` |

A local keeps that type: a later binding of another type is an error (E1452, E1001). The rule, and
how to declare a local that holds more than one type, is in [Variables](variables.md).

Some first bindings give no type, and need an annotation (W1051):

- `x = None;` Write `x: Cat | None = None;`.
- `d = {};` Write `d: dict[str, int] = {};`. Annotate an empty `[]` the same way.
- `xs = list();` and a bare `list`, `dict` or `set` used as a value.

```jac
# expect: W1051 x2
with entry {
    found = None;
    index = {};
}
```

## Unions

`A | B` is the type of a value that is an `A` or a `B`. `T | None` is a `T` that may be absent.

A union value is used by first finding out which member it is. A test **narrows** the type in the
code the test guards:

| Test | Narrows to |
|---|---|
| `isinstance(v, str)` | `str` where it holds; the other members in the `else` branch and after a branch that returns |
| `isinstance(v, (str, list))` | Either of the listed types |
| `v is None`, `v is not None` | `None`, or the type without `None` |
| `a is not None and a.field > 0` | The right side of `and` sees the narrowed type |
| A `match` class pattern | The class, in its case. See [Pattern matching](pattern-matching.md). |

```jac
obj Cat {
    has lives: int = 9;
}

obj Dog {
    has tricks: int = 2;
}

def count(p: Cat | Dog | None) -> int {
    if p is None {
        return 0;
    }
    if isinstance(p, Cat) {
        return p.lives;
    }
    return p.tricks;
}

def show(v: int | str) -> str {
    if isinstance(v, str) {
        return v.upper();
    }
    return str(v + 1);
}

with entry {
    print(count(Cat()), count(Dog()), count(None));
    print(show(1), show("a"));
}
```

```output
9 2 0
2 A
```

Narrow before use. An operation on a union value that has not been narrowed is checked against
the value's actual type when it runs, and raises `TypeError` or `AttributeError` when that type
does not support it.

`==` and `!=` between a `T | None` and a `T`, either side first, compare values without narrowing:
`None` is equal only to `None`, so for `maybe: str | None = None`, `maybe == "#"` and
`"#" == maybe` are `False` and `maybe == None` is `True`.

`is None` is only meaningful on a type that includes `None`: on an `int` or a `str` it is E1110.

```jac
# expect: E1110
def missing(n: int) -> bool {
    return n is None;
}
```

### `None` and classes

`None` is a value of a class's type, an `obj`, `node`, `edge` or `walker`, whether or not the type
is written with `| None`: `c: Cat = None;` is accepted. A union with a class among its members
takes `None` the same way, and `is None` narrows it:

```jac
obj Cat {
    has name: str = "tom";
}

obj Dog {
    has name: str = "rex";
}

def name_of(pet: Cat | Dog) -> str {
    if pet is None {
        return "no pet";
    }
    return pet.name;
}

with entry {
    pet: Cat | Dog = None;
    print(name_of(pet));
    pet = Dog();
    print(name_of(pet));
}
```

```output
no pet
rex
```

A number and a `struct` are never `None`, and neither is a union of them:

```jac
# expect: E1001 x3
struct Point {
    has x: int = 0;
}

with entry {
    n: int = None;
    p: Point = None;
    either: Point | int = None;
}
```

Write `| None` where a value may be absent: it says so to the reader, and it is what narrowing
and a function's missing `return` go by ([Functions](functions.md)).

## `any`

`any` is the type of a value whose type is known only when the program runs: every operation on
it is allowed by the checker and resolved by what it holds, and it is checked as it arrives at a
typed place (`TypeError` when it is not of that type). What converts and what is copied on the
way, and what operators do through it, are in [The `any` type](types-any.md) (`jac docs any`).

## Casts: `as`

```ebnf
cast ::= bitwise_or ("as" cast_type)*

cast_type ::= atomic_chain ("|" atomic_chain)*
```

`e as T` asserts that the value of `e` is a `T` and gives it that type. It never converts.

- From `any` or from a union, the assertion is checked when it runs and raises `TypeError` when the
  value is of another type.
- From a class to one of its subclasses, or from a [`dyn`](interfaces.md#dyn-references) to a class
  conforming to its interface, it is checked the same way: `shape as Circle` raises `TypeError`
  when the value is of another class.
- Where the value can never be a `T`, the cast is an error (E1203): `3.9 as int` is refused. To
  convert, call the type: `int(3.9)`.
- A sized integer cast to a wider integer type keeps its value: `b as int` of an `i8` is the same
  number as an `int`. `as` never checks a range, so a cast to an integer type that does not hold
  every value of the one given (`n as i8` of an `int`, `a as i8` of an `i16`) is refused (E1203).
  To make a sized integer from a wider one, call the type: `i8(n)` raises `OverflowError` when `n`
  does not fit (see [Numbers](numbers.md)).
- `as` binds more tightly than the comparison operators and more loosely than arithmetic and `|`:
  `a + b as int` is `(a + b) as int`, and `x as int == 5` is `(x as int) == 5`. To continue with an
  operator that binds tighter, parenthesize: `(v as str).upper()`, `(x as int) + 1`.

The word `as` also names an alias in `import`, `with`, `except` and `match`; those uses are part
of their own statements.

```jac
def describe(v: int | str, raw: any) -> str {
    count = raw as int;
    if isinstance(v, int) {
        return str(v + count);
    }
    return (v as str).upper();
}

with entry {
    print(describe(1, 2), describe("a", 2));
    try {
        print(describe(1, "two"));
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
3 A
TypeError: expected int, found str
```

```jac
# expect: E1203 x2
with entry {
    print(3.9 as int);
    print("s" as int);
}
```

## Type aliases

```ebnf
type_alias ::= "type" access_tag (KEYWORD | NAME) ("[" type_params "]")? (":=" | "=") pipe ";"
```

`type Name = T;` at a module's top level gives a type another name. The alias and the type it
names are the same type. An alias may take type parameters.

```jac
type Pair = tuple[int, int];
type Num = int | float;
type Grid[T] = list[list[T]];

def swap(p: Pair) -> Pair {
    return (p[1], p[0]);
}

def total(xs: list[Num]) -> float {
    t = 0.0;
    for x in xs {
        t += x;
    }
    return t;
}

with entry {
    g: Grid[int] = [[1, 2], [3]];
    print(swap((1, 2)), total([1, 2.5]), g);
}
```

```output
(2, 1) 3.5 [[1, 2], [3]]
```

An alias of a class declared above it is that class, as a value too: it is called to construct
one, raised and caught, passed to `isinstance`, and is the class by `is`, in its own module and
as `module.Name` in another. This is Python's `error = OSError`, and how a library gives a class
a second name (`os.error` is `OSError`).

```jac
import os;

class Problem(Exception) {}

type error = Problem;

with entry {
    try {
        raise error("bad");
    } except Problem as e {
        print("caught", e, isinstance(e, error), error is Problem);
    }
    try {
        os.rmdir("no-such-dir");
    } except os.error as e {
        print(type(e).__name__, os.error is OSError);
    }
}
```

```output
caught bad True True
FileNotFoundError True
```

An alias written above the class it names is a type only: used as a value it is refused
(E5090).

`type Name := T;`, a distinct type, is refused today (E5090). An alias is a module-level
declaration; inside a function it is a syntax error.

## Types as values

`type(v)` gives the type of a value, which compares with the type names and has a `__name__`.
`isinstance(v, T)` takes a class, a builtin type or a tuple of them (E1179 otherwise).

A type is a value: it may be held in an `any` or passed, and keeps its identity there (`held is
int`), its `__name__` and `__qualname__`, and its call. A container type with its element types
is one too: `list[int]` held in an `any` and called makes an empty list or a list of an iterable's
items, `dict[str, list[int]]()` and `set[str]()` make empty containers, and its `__name__` is the
bare kind (`list`). A bare `list` given to a `Callable[[], list[int]]` takes that element type.

`type(x)` of a container equals a bare container type by kind (`type(pairs) == dict`) and a
parameterized one by its element types exactly: `type([1]) is list[int]` is `True` and
`type([1]) is list[str]` is `False`. In Python `type([1]) is list[int]` is `False`.

```jac
obj Cat {
    has lives: int = 9;
}

with entry {
    t = type(3);
    print(t, t == int, type("a") is str, type(Cat()).__name__);
    print(isinstance(3, (int, str)), isinstance(True, int));

    held: any = int;
    print(held is int, held.__name__, held("12") + 1);
    make: any = list[int];
    print(make([5, 6]), make(), make.__name__);
    pairs = dict[str, list[int]]();
    print(pairs, type(pairs) == dict, type([1]) is list[int], type([1]) is list[str]);
    kind: any = Cat;
    print(kind(lives=3), kind.__qualname__);
}
```

```output
<class 'int'> True True Cat
True True
True int 13
[5, 6] [] list
{} True True False
Cat(lives=3) Cat
```

## What `jac check` enforces

`jac check main.jac` runs every analysis a build runs and stops before generating code. It
checks the main module, every module it reaches, and their `test` blocks. Among what it reports:

| Code | Condition |
|---|---|
| W2001 | A name that nothing declares |
| E1001 | A value of the wrong type for an annotated local, a field or an item of a typed container |
| E1002 | A `return` value of the wrong type |
| E1452 | A local bound to a second type |
| E1053 | An argument of the wrong type |
| E1050, E1051, E1052 | A missing argument, too many, or an unknown keyword |
| E1030 | A field or method the type does not have |
| E1110 | An operator its operand types do not support |
| E1145 | A name a module does not have |
| E1004 | A function declared to return a value that may end without returning one |
| E1174 | A constant tuple index out of range |
| E1036, E2018, W1051 | A type that is incomplete, unknown, or cannot be inferred |
| E1203 | A cast that can never hold |

```jac
# expect: E1001, E1002, E1053, E1051, E1030, W2001, E1110
obj Cat {
    has lives: int = 9;
}

def twice(n: int) -> int {
    return "twice";
}

with entry {
    lives: int = "nine";
    twice("a");
    twice(1, 2);
    Cat().purr();
    unknown_fn();
    1 + "a";
}
```

## Differences from Python

- Types are checked by the compiler, and a type error stops the build. Annotations are not hints.
- A parameter and a field must be annotated. A local's type is fixed by its first binding.
- `int` is 64 bits and overflow raises; it is not arbitrary precision.
- A `bool` is not accepted where an `int` is declared, although `True + 1` is `2` and
  `isinstance(True, int)` is `True`.
- A `float` is never silently an `int`, and `as` does not convert.
- `Optional[T]` and `Union[A, B]` are written `T | None` and `A | B`; `Any` is `any`.
- A container annotation always has its element types.
