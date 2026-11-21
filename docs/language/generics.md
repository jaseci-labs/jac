---
description: Type parameters on functions and methods: what a call infers, what a type parameter provides under its bound, generic methods, and what is rejected.
keywords: generics, generic, generic function, generic method, type parameter, type argument, type arguments, bound
grammar: type_params, type_param
---
# Generics

A function or method with type parameters in brackets after its name is
generic: `def first[T](xs: list[T]) -> T`. A type parameter stands for a type
that each use gives, written or found from the arguments. Generic code is
checked once, where it is declared, against what its parameters' bounds
provide. The same brackets hold compile-time value parameters
(`[comptime N: int]`), described on
[Compile-time parameters](comptime-parameters.md) (`jac docs value
parameter`), and give classes type parameters, described on
[Generic classes](generics-classes.md) (`jac docs generic class`).

## Syntax

```ebnf
type_params ::= type_param ("," type_param)* ","?

type_param ::= "comptime"? NAME (":" pipe)? ("=" pipe)?
```

The brackets go after the name of a function, a method, an archetype or a
type alias:

| Declaration | Example |
|---|---|
| Function | `def pair[K, V](k: K, v: V) -> tuple[K, V] {` |
| Method | `def pick[T](xs: list[T]) -> T {` in an archetype |
| Archetype | `obj Box[T] {`, `struct Duo[T] {`; see [Generic classes](generics-classes.md) |
| Value parameter | `def scaled[comptime N: int](x: int) -> int {`; see [Compile-time parameters](comptime-parameters.md) |

A type parameter is one of:

| Form | Is |
|---|---|
| `T` | A type parameter, any type |
| `T: Named` | A type parameter bounded by the class `Named` |
| `T: Shape`, `T: Shape & Named` | A type parameter bounded by one or several [interfaces](interfaces.md) (several joined by `&`) |

A type parameter is compile-time already, so the word `comptime` marks only
value parameters: before a type parameter it is E1479 (see
[Compile-time parameters](comptime-parameters.md)). A default for a type
parameter (`[T = int]`) is not built yet (E5090). A
[`where` clause](interfaces-where.md) after the signature states a condition
the parameters must meet at each use.

## Generic functions

```jac
def first[T](xs: list[T]) -> T {
    return xs[0];
}

def pair[K, V](k: K, v: V) -> tuple[K, V] {
    return (k, v);
}

def empty[T] -> list[T] {
    return [];
}

with entry {
    n = first([3, 4]) + 1;
    s = first(["a", "b"]).upper();
    print(n, s, first[float]([2]), pair("k", 2.5));
    names = empty[str]();
    names.append("x");
    print(names);
}
```

```output
4 A 2.0 ('k', 2.5)
['x']
```

- **A call finds its type arguments from its arguments' types.**
  `first([3, 4])` is a call with `T` as `int`, so its result is an `int`
  and `+ 1` is checked as an int's.
- **A result that is a union naming `T` is that union of the call's `T`**:
  `def mid[T](xs: list[T]) -> T | float` gives an `int | float` of ints. A
  type named twice is named once, so of floats its result is a `float`.
- **A `T` that is itself a union is spread into a union that names it.**
  With `T` as `int | None`, a parameter typed `T | Unset` is an
  `int | None | Unset`, and takes `None`. So a class whose parameter has a
  sentinel default takes an optional type: `ContextVar[Scope | None]("scope",
  default=None)`.
- **A call may write them**: `first[float]([2])`. Written arguments are the
  leading ones, in order (`f[int, 4]`); the rest are found from the
  arguments or take their defaults.
- **Only the arguments are used.** A type parameter that no argument fixes
  must be written (`empty[str]()`); it is not found from the type the result
  is assigned to (E1194).
- **The first argument that gives a parameter a type fixes it**, and the
  later ones must convert to that type. For `def both[T](a: T, b: T)`,
  `both(2.5, 1)` is a call with `T` as `float` (`[2.5, 1.0]`), while
  `both(1, 2.5)` and `both(1, "x")` are E1053: `T` is not widened to a
  union.
- **Through an `Iterable[T]` parameter, `T` is what iterating the argument
  gives**: a list's items, a dict's keys, a range's or a generator's values,
  a str's characters, and a tuple's items where they share a type (`any`
  where they do not). An `Iterable`'s elements are only read, so a `T` that
  so far only `Iterable` arguments have given becomes `any` when another
  argument gives it another type, instead of E1053.
- **A type parameter may type a `*` parameter** (`*parts: list[T]`), with
  keyword-only parameters after it, and a call may spread into it.

```jac
def gathered[T, C: Iterable[T]](src: C) -> list[T] {
    return [x for x in src];
}

def running[T](src: Iterable[T], first: T) -> list[T] {
    return [first] + [v for v in src];
}

def joined[T](*parts: list[T], sep: str = ",") -> str {
    return sep.join([str(x) for p in parts for x in p]);
}

with entry {
    print(gathered({"k": 1}), gathered(range(3)), gathered("ab"), gathered((1, "x")));
    print(running([1, 2], 0.5), running(["a"], 1));
    rows = [[1, 2], [3]];
    print(joined(*rows), joined([0], *rows, sep=""));
}
```

```output
['k'] [0, 1, 2] ['a', 'b'] [1, 'x']
[0.5, 1, 2] [1, 'a']
1,2,3 0123
```

`running([1, 2], 0.5)` is a call with `T` as `any`: its `int`s stay `int`s.

## What a type parameter provides

The body is checked once, where it is declared, with each type parameter
standing for any type its bound admits. It may do with a `T` only what that
bound provides. (A body that uses `T` as a value, `T(x)` or `fields(T)`, is
also checked for each type: see
[How generic code is compiled](generics-compiling.md).)

| Parameter | Provides |
|---|---|
| `T`, unbounded | What every value has: being held, passed, returned, converted to `any`, compared with `==` and `is`, printed, hashed |
| `T: Named`, a class | That, and the class's fields and methods, called as the value's own class overrides them; a `T` converts to `Named` |
| `T: Shape`, an interface | That, and what the interface requires; see [Interfaces](interfaces.md) |
| `F: Callable[[], any]` | Calling it with that signature |

- **A use the bound does not provide is an error in the body** (E1110,
  E1030, ...), never an error for one type at one call. In a body bounded by
  interfaces, E1284 at the declaration names the bounds as well.
- **A type that does not fit a bound is an error at the call**: E1053 for a
  class bound, E1283 for an interface.
- **A `T` converts to no other type by itself.** `x as int` asserts the
  type, checked when the code runs (`TypeError` otherwise), and an
  `isinstance(x, int)` test narrows `x` to `int` inside its branch.
  `isinstance` asks the value's type as the program runs: `True` is a
  `bool` before it is an `int`, and a `T` that is `any` answers with the
  type of the value it holds.
- **A function taken as a value** is best given a parameter bounded by the
  signature it fits (`F: Callable[[], any]`): `F` is the function's own
  type, so what calling it gives keeps its type (a `str` for a `def f ->
  str`, where through a `Callable[[], any]` it is an `any`). The function
  stays itself either way: `f is g` holds for what was given.

```jac
obj Named {
    has label: str = "?";

    def tag -> str {
        return "<" + self.label + ">";
    }
}

obj Item(Named) {
    has qty: int = 1;

    override def tag -> str {
        return "[" + self.label + "]";
    }
}

def same[T](a: T, b: T) -> str {
    held: any = a;
    return f"{a} {a == b} {a is b} {len({a, b})} {held}";
}

def tags[T: Named](xs: list[T]) -> list[str] {
    return [x.tag() for x in xs];
}

def widest[T: Named](xs: list[T]) -> Named {
    best: Named = xs[0];
    for x in xs {
        if len(x.label) > len(best.label) {
            best = x;
        }
    }
    return best;
}

def as_int[T](x: T) -> int {
    if isinstance(x, int) {
        return x + 1;
    }
    return x as int;
}

def run_twice[F: Callable[[], any]](f: F) -> F {
    f();
    f();
    return f;
}

def hello {
    print("hello");
}

with entry {
    print(same(1, 1), "|", same("a", "b"));
    items = [Item(label="ab"), Item(label="abc", qty=3)];
    print(tags(items), tags([Named()]), widest(items));
    print(as_int(4));
    try {
        as_int("four");
    } except TypeError as e {
        print("TypeError:", e);
    }
    print(run_twice(hello) is hello);
}
```

```output
1 True True 1 1 | a False False 2 a
['[ab]', '[abc]'] ['<?>'] Item(label='abc', qty=3)
5
TypeError: expected int, found str
hello
hello
True
```

A closure or a nested `def` inside a generic function may use the
function's type parameters, as `both` does in `twice` below, and keeps the
`T`s it holds. A local of type `T` may be declared without a value
(`last: T;`) and assigned later, and a generic generator
(`def repeated[T](v: T, n: int) -> Iterator[T]`) yields `T`s.

## Generic methods

A method may have bracket parameters of its own, in any class: type
parameters, or [value parameters](comptime-parameters.md)
(`def sized[comptime K: int](x: int) -> int`). Each call finds them from its
arguments or writes them.

```jac
obj Rack {
    has size: int = 0;

    def pick[T](xs: list[T]) -> T {
        return xs[self.size];
    }
}

obj TopRack(Rack) {
    override def pick[T](xs: list[T]) -> T {
        return xs[-1];
    }
}

def twice[T](x: T) -> list[T] {
    def both(v: T) -> list[T] {
        return [v, v];
    }
    return both(x);
}

def adder[T: Number](k: T) -> Callable[[T], T] {
    return lambda (v: T) -> T { return v + k; };
}

with entry {
    racks: list[Rack] = [Rack(size=1), TopRack()];
    print([r.pick([7, 8, 9]) for r in racks], Rack().pick(["a"]));
    print(twice("w"), adder(2)(5), adder(0.5)(1.0));
}
```

```output
[8, 9] a
['w', 'w'] 7 1.5
```

- **A method with unbounded or class-bounded type parameters overrides and
  is overridden as any method is**, and is dispatched on the object's class.
  An override has the same number of type parameters (E2195).
- **A method whose type parameters are copied for each type (see
  [How generic code is compiled](generics-compiling.md)), or that
  has value parameters, is compiled for each call** and called as the
  receiver's type finds it, so it neither overrides a method nor is
  overridden: a subclass declaring one of the same name is E5090.

A generic function or method is not a value: `f = first` and `f =
Rack().pick` are E5090. Call it, or wrap the call in a lambda of the types
you want.

## What is rejected

| Code | When |
|---|---|
| E1194 | A type parameter no argument fixes, and the call does not write |
| E1053 | One type parameter given two types by one call; a type argument outside a class bound |
| E1283 | A type argument that does not conform to an interface bound |
| E1110, E1030, ... | A body uses what its parameters' bounds do not provide |
| E1284 | The same, in a body bounded by interfaces, reported at the declaration |
| E2195 | An override with another number of type parameters |
| E5090 | A generic function or method as a value; a default for a type parameter; an override among methods compiled for each call |

```jac
# expect: E1110 x2, E1030, E1284, E1194, E1053 x2, E1283, E5090
obj Plain {
    has n: int = 0;
}

obj Base {
    has b: int = 0;
}

def none_of[T](n: int) -> list[T] {
    return [];
}

def least[T: Ordered](a: T, b: T) -> T {
    return a if a < b else b;
}

def sum2[T: Ordered](a: T, b: T) -> T {
    return a + b;
}

def both[T](a: T, b: T) -> list[T] {
    return [a, b];
}

def plus_one[T](x: T) -> T {
    return x + 1;
}

def named[T](x: T) -> str {
    return x.name;
}

def who[T: Base](a: T) -> int {
    return a.b;
}

with entry {
    print(none_of(3));
    print(both(1, "x"));
    print(least(Plain(), Plain()));
    who(3);
    f = least;
}
```

```jac
# expect: E5090
def c[T = int](x: T) -> T {
    return x;
}
```

```jac
# expect: E2195, E5090
obj Base {
    def wrap[T](x: T) -> list[T] {
        return [x];
    }

    def low[T: Ordered](x: T) -> T {
        return x;
    }
}

obj Sub(Base) {
    override def wrap(x: int) -> list[int] {
        return [x, x];
    }

    def low[T: Ordered](x: T) -> T {
        return x;
    }
}
```

## Differences from Python and from the reference design

- **Python's `def first[T](...)` declares a type parameter for a type
  checker, and the program ignores it; here the compiler checks the body
  against the bounds and each call against the parameters.**
- **In Python a call never writes its type arguments; here `first[int](xs)`
  may**, and a parameter no argument fixes must be written.
- **In the reference design a call cannot write its type arguments** (`first[int](xs)` fails
  as it runs); here it may.

## See also

- [Generic classes](generics-classes.md): `obj Box[T]` and generic bases.
- [Compile-time parameters](comptime-parameters.md): value parameters
  (`[comptime N: int]`).
- [Interfaces](interfaces.md): bounds by interfaces and `dyn`;
  [Builtin interfaces](interfaces-builtin.md): `Ordered` and `Number`;
  [Where clauses](interfaces-where.md).
- [Compile-time evaluation](compile-time.md): `comptime if`, `comptime for`
  and compile-time values.
- [How generic code is compiled](generics-compiling.md): shared code and
  copies, and using a type parameter as a value (`T(x)`, `fields(T)`).
- [Reflection](reflection.md): a type parameter's fields and kind at
  compile time.
- [Inheritance](inheritance.md): bases, overriding and dispatch.
