---
description: What a program can ask about types and values, as it runs (type, isinstance, getattr, hasattr, setattr, vars, dir) and as it compiles (jaclang.comptime's fields, params, kind, type_args, members, get_field, set_field, restore, args_type, apply).
keywords: reflection, introspection, jaclang.comptime, Kind, kind, type_args, params, members, get_field, set_field, restore, args_type, apply
---
# Reflection

A program can ask about types and values in two ways. **As it runs**, the
builtins `type`, `isinstance`, `getattr`, `hasattr`, `setattr`, `vars` and
`dir` look at a value, as in Python. **As it compiles**, the functions of
`jaclang.comptime` read a type's fields, a function's parameters and what a
type is made of; code written with them is unrolled for each type into
straight-line code, and nothing is looked up as the program runs.

## As the program runs

```jac
obj Point {
    has x: int = 0,
        y: int = 0;

    def norm -> int {
        return self.x + self.y;
    }
}

obj Point3(Point) {
    has z: int = 0;
}

with entry {
    p = Point(x=1, y=2);
    a: any = Point3(x=1);
    print(type(p), type(p).__name__, type(a) is Point3, type(a) == Point, a.__class__.__name__);
    print(isinstance(a, Point), issubclass(Point3, Point), callable(p.norm), callable(p));
    name = "y";
    setattr(p, name, 10);
    print(getattr(p, name), hasattr(a, "z"), hasattr(a, "w"), getattr(a, "w", -1));
    print(getattr(p, "norm")(), vars(p), [n for n in dir(p) if not n.startswith("_")]);
    q: Point = Point3(x=1, z=3);
    print(vars(q), "z" in dir(q));
    make = type(p);
    print(make(x=5));
    try {
        getattr(a, "w");
    } except AttributeError as e {
        print("AttributeError:", e);
    }
}
```

```output
<class 'Point'> Point True False Point3
True True True False
10 True False -1
11 {'x': 1, 'y': 10} ['norm', 'x', 'y']
{'x': 1, 'y': 0, 'z': 3} True
Point(x=5, y=0)
AttributeError: 'Point3' object has no attribute 'w'
```

| Expression | Gives |
|---|---|
| `type(x)` | The class of `x`, which prints as `<class 'Point'>` and may be called to construct one |
| `type(x).__name__`, `x.__class__` | The class's name; the class |
| `type(x) is C`, `type(x) == C` | Whether `x` is of exactly `C`, not a subclass |
| `isinstance(x, C)`, `issubclass(D, C)` | Whether `x`, or class `D`, is `C` or derives from it; see [Inheritance](inheritance.md) |
| `callable(x)` | Whether `x` can be called: a function, a bound method, a class, an object with `__call__` |
| `hasattr(x, name)` | Whether `x` has a field, property or method `name` |
| `getattr(x, name)`, `getattr(x, name, d)` | Its value, or `d` when it has none; without `d`, `AttributeError` |
| `setattr(x, name, v)` | Assigns it |
| `vars(x)` | A dict of the fields and their values: those of `x`'s own class, whatever type it is held as |
| `dir(x)` | The sorted names of its fields and of the methods its class defines |

What the compiler checks of these:

- **A name written as a literal is checked at compile time** on a value of
  a known class: `getattr(p, "nope")` of a `Point` is E1030, as `p.nope` is,
  and `setattr(p, "x", "s")` is checked as `p.x = "s"` is.
- **A name computed as the program runs, or a value held as an `any`, is
  looked up as the program runs**, and a missing name raises
  `AttributeError`. A class's `__getattr__` and `__setattr__` are asked for
  names it does not declare (see [Special methods](methods-special.md)).
- **An object has only its declared fields**: `setattr` cannot add one.
- **A class is a value.** Held in an `any` (`k: any = Point3`, or what
  `type(x)` gives), it has `__name__` and `__qualname__`, `is` compares it
  with a class, calling it constructs an instance (binding the `init`'s
  parameters, keywords included), `k.m(x)` calls the class's own method `m`
  on `x`, and `issubclass(k, C)` is answered as the program runs.

Two spellings are reported because the language has a direct form for them
(see `jac docs W3007`):

| Written | Write instead | Code |
|---|---|---|
| `hasattr(x, "a") and x.a ...`, where `x`'s class has `a` | `x is not None and x.a ...` | W3007 |
| `getattr(x, "a", None)`, where `x`'s class has `a` | `x?.a` | W3039 |

## As the program compiles

The functions are imported from `jaclang.comptime`:

```jac
import from jaclang.comptime { fields, params, kind, type_args, members, bits, signed, Kind }

enum Color {
    RED,
    GREEN,
}

obj Author {
    has name: str,
        verified: bool = False;
}

obj Post {
    has title: str,
        likes: int = 0,
        tags: list[str] = [],
        color: Color = Color.RED;
}

sem Post.title = "What the post is called.";

def load(q: str, limit: int = 20) -> list[Post] {
    return [Post(title=f"{q} {i}") for i in range(min(limit, 2))];
}

def describe[T] -> str {
    parts: list[str] = [];
    comptime for f in fields(T) {
        parts.append(f"{f.name}: {kind(f.type).name.lower()}");
    }
    return ", ".join(parts);
}

def same[A, B] -> bool {
    comptime if A == B {
        return True;
    } else {
        return False;
    }
}

def zero_of[T] -> str {
    comptime if kind(T) == Kind.INT {
        return "0";
    } elif kind(T) == Kind.STR {
        return "''";
    } else {
        return "None";
    }
}

with entry {
    comptime for f in fields(Post) {
        print(f.name, kind(f.type).name, f.has_default, repr(f.doc));
    }
    comptime for p in params(load) {
        print("param", p.name, kind(p.type).name, p.has_default);
    }
    comptime for t in type_args(dict[str, list[int]]) {
        print("type arg", kind(t).name);
    }
    print(describe[Author](), "|", same[int, int](), same[int, str](), zero_of[str]());
    print([m.name for m in members(Color)], bits(u8), bits(f32), signed(u16), signed(float));
}
```

```output
title STR False 'What the post is called.'
likes INT True ''
tags LIST True ''
color ENUM True ''
param q STR False
param limit INT True
type arg STR
type arg LIST
name: str, verified: bool | True False ''
['RED', 'GREEN'] 8 32 False True
```

| Function | Gives |
|---|---|
| `fields(T)` | A class's or struct's fields in declaration order, a base's first: records with `name`, `type`, `has_default`, `doc` and `postinit` (whether the class sets the field in `postinit`, so that no constructor takes it) |
| `params(f)` | A function's parameters: records with `name`, `type`, `has_default` and `doc`. `f` is a function, or a method named by its class (`params(Greeter.greet)`), whose `self` is not among them |
| `kind(T)` | What a type is: a member of the enum `Kind` |
| `type_args(T)` | The types a type is made of: a list's, set's or array's item type, a dict's key and value types, a tuple's item types, a union's members |
| `members(E)` | An enum's members, in order |
| `bits(T)`, `signed(T)` | A number type's width in bits (8 for `u8`, 64 for `int` and `float`, 32 for `f32`), and whether it holds negative values; see [Compile-time values](compile-time-values.md) |
| `sendable(T)` | Whether a value of `T` may be sent to another thread or space; see [Crossing](../accel/crossing.md) |
| `target()` | What the build targets: its `os`, `arch` and `device`; see [Compile-time values](compile-time-values.md) |

`Kind`'s members are `INT`, `FLOAT`, `STR`, `BOOL`, `BYTES`, `NONE`, `ANY`,
`LIST`, `DICT`, `SET`, `TUPLE`, `UNION`, `ENUM`, `OBJ`, `NODE`, `EDGE`,
`WALKER`, `STRUCT`, `COMPLEX`, `ARRAY` and `BYTEARRAY`. Every int type is
`INT` and every float type `FLOAT`; `tuple[int, ...]` is a `TUPLE` with one
type argument, `tuple[int, str]` one with two. An `enum X: int` is an `ENUM`.

An optional `T | None` has `T`'s kind when `T` is a `str`, `bytes`, `list`,
`dict` or a class: `kind(Tweet | None)` is `OBJ` and `kind(str | None)` is
`STR`, `None` being one more value of the type. An optional of a number, a
`bool` or a struct is a `UNION`, as `int | str` is: `kind(int | None)` is
`UNION`.

How the results are used:

- **They are compile-time values.** A list of them is iterated with
  [`comptime for`](compile-time.md), which compiles its body once per item,
  and a test on them is a `comptime if`. A record's `type` is a type: it may
  be passed on (`kind(f.type)`, `schema[f.type]()`).
- **Where code runs, what they hold that is a value is that value**: a
  record's `name` (`fields(P)[0].name`, a str), a list's length
  (`len(fields(P))`). A type, a record, or a list holding either is no value
  of the program, and using one there is E1245: `print(fields(P))`.
- **Types compare with `==`** in a `comptime if`: `same[list[int],
  list[str]]()` above is `False`.
- **A field's `doc` is its [`sem`](by-and-sem.md)**, the string `sem
  Post.title = "...";` gives it, and `''` when it has none; a parameter's
  likewise. A docstring is not a `doc`.
- **A function that reflects on its type parameter is compiled for each
  type** it is called with, and checked in each copy (see
  [Generics](generics.md)).

### Reading and filling objects

Four functions work where code runs, with a field's name known at compile
time:

| Function | Does |
|---|---|
| `get_field(x, name)` | Reads `x`'s field `name`, typed as the field is |
| `set_field(x, name, v);` | A statement that assigns `x`'s field `name` |
| `x = restore(T);` | Makes an instance of class `T` without constructing it: no `init` or `postinit` runs |
| `args_type(f)` | A record type with a field for each parameter of `f`, of its type and with its default. `f` is a function, or a method named by its class (`args_type(Greeter.greet)`) |
| `apply(f, a)` | Calls the function `f` with the arguments a record of `args_type(f)` holds |
| `apply(m, a, x)` | Calls the method `m`, named by its class, on the object `x`, with the arguments `a` holds: `x.m(...)` |

```jac
import from jaclang.comptime { fields, get_field, set_field, restore, args_type, apply }

obj Author {
    has name: str,
        verified: bool = False;

    def postinit {
        print("postinit ran");
    }
}

def show_all[T](x: T) -> str {
    parts: list[str] = [];
    comptime for f in fields(T) {
        parts.append(f"{f.name}={get_field(x, f.name)!r}");
    }
    return " ".join(parts);
}

def named(n: str) -> Author {
    o = restore(Author);
    set_field(o, "name", n);
    return o;
}

def greet(who: str, times: int = 1) -> str {
    return " ".join([f"hi {who}"] * times);
}

with entry {
    a = Author(name="ann");
    print(show_all(a));
    b = named("bo");
    print(b, show_all(b));
    args = restore(args_type(greet));
    set_field(args, "who", "cy");
    print(apply(greet, args));
    set_field(args, "times", 2);
    print(apply(greet, args));
}
```

```output
postinit ran
name='ann' verified=False
Author(name='bo', verified=False) name='bo' verified=False
hi cy
hi cy hi cy
```

- **`restore` gives a local its value**, and the compiler follows the local:
  every field without a default must be set by `set_field` on every path
  before the local is used (E1241). A field with a default that is left
  unset takes its default there, made only on the paths that leave it.
- **A record of `args_type(f)` is an `obj`** like any: `==` compares it field
  by field, and a parameter's default is used by `apply` when the record
  leaves it unset.
- **`apply` of a method takes the object it is called on** as its third
  argument, and `apply` of a function takes none (E1053 either way round).
  With `obj Greeter { has greeting: str = "hi"; def greet(who: str) -> str
  { ... } }`, `apply(Greeter.greet, args, Greeter(greeting="hello"))` is
  `Greeter(greeting="hello").greet(...)`. A `by` function's tool that is a
  method is called this way ([By and sem](by-and-sem.md)).
- `stdjac.codec`'s `encode` and `decode` are written with these functions:
  `decode` restores objects without running `init` or `postinit`.

## What is rejected

| Code | When |
|---|---|
| E1030 | `getattr`, `get_field` or `set_field` of a name the class has no member of |
| E1239 | `get_field` or `set_field` of a method's name, not a field's |
| E1240 | `set_field(...)` used as a value |
| E1241 | A restored local used before each field without a default is set |
| E1242 | `restore(T)` not assigned to a local |
| E1243 | `fields`, `type_args` or `kind` of a type they cannot take apart (`fields(int)`) |
| E1244, E1245 | A compile-time value that is not a type where a type is wanted; a type, a record or a list of them (`print(fields(P))`) used where code runs |
| E1247, E1248 | `params` of what is not a function; `params` or `args_type` of a function with `*args`, `**kwargs` or type parameters |
| E1053, E1051 | `apply` of a method with no object to call it on, or of a function with one; `apply` with fewer than two arguments or more than three |
| E1570 | `bits` or `signed` of a type that is not a number's |
| E0033 | A field's name not known at compile time |
| E5090 | A generic function taken as a value |

```jac
# expect: E1030, E1239, E1240, E1241 x2, E1242, E1243, E1570, E0033, E1245 x2
import from jaclang.comptime { fields, type_args, get_field, set_field, restore, bits }

obj P {
    has a: int,
        b: int = 7;

    def total -> int {
        return self.a + self.b;
    }
}

def no_field(p: P) -> int {
    return get_field(p, "zz");
}

def a_method(p: P) {
    set_field(p, "total", 1);
}

def as_value {
    o = restore(P);
    x = set_field(o, "a", 1);
}

def too_early -> int {
    o = restore(P);
    n = o.b;
    set_field(o, "a", 1);
    return n;
}

def not_a_local -> P {
    return restore(P);
}

def takes_apart {
    comptime for f in fields(int) {
        print(f.name);
    }
    print(bits(str));
}

def name_at_run_time(p: P, name: str) -> int {
    return get_field(p, name);
}

def type_as_value {
    print(type_args(list[int])[0]);
    print(fields(P));
}
```

## Differences from Python and from the reference design

- **In Python `type(p)` prints `<class '__main__.Point'>`; here
  `<class 'Point'>`.**
- **In Python `setattr` may add an attribute to any instance; here an
  object has exactly its declared fields.**
- **In Python `getattr(p, "nope")` fails as the program runs; here, on a
  value of a known class, it fails to compile** (E1030).
- **Python reflects on types only as the program runs.** `fields(T)` and its
  neighbours are jac's: they run as the program compiles, the way
  `dataclasses.fields` would if it were evaluated at build time.
- **In the reference design `fields(T)` is a list the program builds as it runs, of records
  with a `default` and a `semstr`; here it is a compile-time value**, read
  with `comptime for`, whose records have `has_default` and `doc`.

## See also

- [Compile-time evaluation](compile-time.md): `comptime for`, `comptime if`.
- [Generics](generics.md): type parameters that reflection is written over.
- [By and sem](by-and-sem.md): `sem` strings, read as `doc`.
- [Builtins](../library/builtins.md): `type`, `getattr` and the rest.
