---
description: Compile-time value parameters ([comptime N: int]) on functions, methods and archetypes: writing and finding their arguments, defaults, the normal form of a type's value argument, and archetypes parameterized by values.
keywords: compile-time parameter, comptime parameter, value parameter, Vec[N]
grammar: type_params, type_param
---
# Compile-time parameters

A parameter in brackets written `comptime`, with an `int`, `bool` or `str`
type (`[comptime N: int]`), is a **value parameter**: it stands for a value
known at compile time, which each use gives. A function, a method or an
archetype may have them, beside or instead of
[type parameters](generics.md) (`[T]`, `[T: Shape]`), which stand for
types; see [Generics](generics.md) (`jac docs type parameter`) and
[Generic classes](generics-classes.md).

```jac
def scaled[comptime N: int](x: int) -> int {
    comptime if N > 3 {
        return x * N;
    } else {
        return -x;
    }
}

obj Vec[comptime N: int] {
    has data: list[int] = [];

    def size -> int {
        return N;
    }
}

def cat[comptime N: int, comptime M: int](a: Vec[N], b: Vec[M]) -> Vec[N + M] {
    return Vec[N + M](data=a.data + b.data);
}

with entry {
    print(scaled[4](3), scaled[2](3));
    print(cat(Vec[3](), Vec[4]()).size());
}
```

```output
12 -3
7
```

`scaled[4]` writes `N`. `cat` finds `N` and `M` from its arguments' types.

## Syntax

```ebnf
type_params ::= type_param ("," type_param)* ","?

type_param ::= "comptime"? NAME (":" pipe)? ("=" pipe)?
```

- `comptime` marks a value parameter, and only a value parameter: before a
  type parameter (`[comptime T]`) it is an error (E1479), since a type
  parameter is compile-time already, and a value parameter's type written
  without it (`[N: int]`) is too (E1480).
- `: int`, `: bool` or `: str` is the value's type.
- `= default` gives a value parameter a default, which may use the
  parameters before it (`[comptime N: int, comptime M: int = N * 2]`).

A [`where` clause](interfaces-where.md) after the signature states a
condition the value parameters must meet at each use. A parameter written
`comptime` in the parenthesized parameter list (`def f(comptime n: int)`) is
a compile-time parameter of another form; see
[Compile-time evaluation](compile-time.md).

## Writing and finding the arguments

A use writes its leading bracket arguments (`f[int, 4]`); the rest are
found from its arguments' types or take their defaults.

```jac
def grid[comptime N: int, comptime M: int = N * 2](v: int) -> int {
    return N * M + v;
}

def label[comptime S: str, comptime LOUD: bool](x: int) -> str {
    comptime if LOUD {
        return S + "!" + str(x);
    }
    return S + str(x);
}

def pair[T, comptime N: int = 2](x: T) -> list[T] {
    return [x] * N;
}

with entry {
    print(grid[2](1), grid[2, 5](1), label["hi", True](1), label["lo", False](2));
    print(pair("x"), pair[int, 3](4));
}
```

```output
9 11 hi!1 lo2
['x', 'x'] [4, 4, 4]
```

A value argument is known at compile time: a literal, a
[`comptime`](compile-time.md) global or parameter, `+ - * // %` of those, or
a `comptime def`'s call. A value known only as the program runs is E0033.
A type's value argument (`Vec[...]`) is an `int` or a `bool`.

**A value parameter is found from an argument's type** where it is the
whole value argument there (`a: Vec[N]`). Once found, the other arguments'
types are checked against it: for `paired(a: Vec[N], b: Vec[N * 2])`,
`paired(Vec[3](), Vec[5]())` is E1053 (`b` expects `Vec[6]`). Where it
appears only inside arithmetic (`a: Vec[N + 1]`, `a: Vec[2 * N]`), it is not
found: the call writes it (`tail[2](v)`), and leaving it out is E1194.

**A type's value argument is kept in a normal form** where it names a
parameter not yet known, so `Vec[N + N]` and `Vec[2 * N]` are one type:

```jac
obj Vec[comptime N: int] {
    has data: list[int] = [];

    def size -> int {
        return N;
    }
}

def twice[comptime N: int](a: Vec[N]) -> Vec[N + N] {
    return Vec[2 * N](data=a.data + a.data);
}

def paired[comptime N: int](a: Vec[N], b: Vec[N * 2]) -> int {
    return N;
}

def tail[comptime N: int](a: Vec[N + 1]) -> Vec[N] {
    return Vec[N](data=a.data[1:]);
}

with entry {
    v = twice(Vec[3](data=[1, 2, 3]));
    w: Vec[6] = v;
    print(w.size(), w);
    print(paired(Vec[3](), w), tail[5](w));
}
```

```output
6 Vec[6](data=[1, 2, 3, 1, 2, 3])
3 Vec[5](data=[2, 3, 1, 2, 3])
```

**The body is checked for each value**, so a `comptime if` or a
`comptime assert` on `N` is decided for each call's or each instance's
arguments. A `comptime assert` that fails for one is E0109, and the use that
asked for it is E1229.

A method may have value parameters of its own, on any class
(`def sized[comptime K: int](x: int) -> int`). It is compiled for each call,
so it neither overrides nor is overridden (E5090); see
[Generic methods](generics.md).

## Archetypes with value parameters

Each value of an archetype's parameters makes a class of its own, named as
written: `Vec[3]` in diagnostics, in `repr` and as `type(v).__name__`.
`Vec[3]` and `Vec[4]` are unrelated types (E1001 where one is given for the
other), and `isinstance(v, Vec[3])` tells them apart. The name alone is no
class: `isinstance(v, Vec)` is E1036. An archetype may have type parameters
beside its value parameters, and they are its instances' too. Every method is checked for
each instance's arguments, so a `comptime assert` in a method holds of each
instance that is made.

```jac
comptime W = 4;

comptime def half(n: int) -> int {
    return n // 2;
}

obj Ring[comptime N: int] {
    has items: list[int] = [];

    def cap -> int {
        comptime assert N > 0, "a ring holds something";
        return N;
    }
}

obj Fixed[T, comptime N: int] {
    has items: list[T] = [];

    def push(v: T) -> bool {
        if len(self.items) >= N {
            return False;
        }
        self.items.append(v);
        return True;
    }
}

struct Cell[comptime N: int] {
    has v: int = 0;

    def scaled -> int {
        return self.v * N;
    }
}

with entry {
    r = Ring[3]();
    print(r, isinstance(r, Ring[3]), isinstance(r, Ring[4]), type(r).__name__);
    print(Ring[W + 1]().cap(), Ring[half(10)]().cap());
    f = Fixed[str, 2]();
    print(f.push("a"), f.push("b"), f.push("c"), f);
    c = Cell[3](v=2);
    d = c;
    d.v = 5;
    print(c.scaled(), d.scaled(), d);
}
```

```output
Ring[3](items=[]) True False Ring[3]
5 5
True True False Fixed[str, 2](items=['a', 'b'])
6 15 Cell[3](v=5)
```

An archetype with value parameters:

- is an `obj` or a `struct` (a `struct`'s instances are values, copied on
  assignment as `d = c` shows; see [Structs](structs.md)), not a `node`,
  `edge` or `walker`;
- has no base, and is not a base by its name alone (`obj Sub(Vec)`);
- has no static fields;
- takes `int` and `bool` value parameters, not `str`;
- is native code's: a `cpython`, `node`, `browser` or `hermes` space does
  not build one.

Each of the rest is refused with E5090.

## What is rejected

| Code | When |
|---|---|
| E1479 | `comptime` before a type parameter |
| E1480 | A value parameter's type written without `comptime` |
| E0033 | A value argument known only as the program runs |
| E0108 | A value argument that fails as it is evaluated (`1 // 0`) |
| E1126 | A value argument outside its type's range (`2 ** 63` for an `int`) |
| E1053 | A type where a value parameter is (`scaled[int]`); an argument whose type disagrees with a value parameter found from another (`Vec[5]` where `Vec[N * 2]` is `Vec[6]`) |
| E1163 | A value where a type parameter is (`Pair[3]`) |
| E1194 | A value parameter that appears in the arguments' types only inside arithmetic, and the call does not write |
| E1001 | One instance given for another (`Vec[3]` where `Vec[4]` is wanted) |
| E1036 | An archetype with value parameters named without its arguments (`isinstance(v, Vec)`) |
| E0109 | A `comptime assert` in a body does not hold for one call's or instance's arguments |
| E1229 | The use that asked for an instance or a call whose body fails so |
| E1040 | A subscript after a method that has no parameter in brackets (`Box().cell[3]()`): its value, a function, is not subscriptable |
| E5090 | An archetype with value parameters that is not an `obj` or a `struct`, has a base or static fields, is a base by its name, has a `str` value parameter, or is built for a `cpython` or JavaScript space; an override of a method with value parameters |

```jac
# expect: E1479, E1480, E5090 x5
obj Base {
    has b: int = 0;
}

obj Sub[comptime N: int](Base) {
    has c: int = 0;
}

obj Named[comptime S: str] {
    has x: int = 0;
}

obj Counted[comptime N: int] {
    static has made: int = 0;
}

node Spot[comptime N: int] {
    has v: int = 0;
}

obj Plain(Counted) {}

def bad_type[comptime T](x: T) -> T {
    return x;
}

def bad_value[N: int](x: int) -> int {
    return x * N;
}
```

```jac
# expect: E0033, E0108, E1126, E1053 x2, E1163, E1194, E1001, E1036, E0109, E1229, E1040
obj Vec[comptime N: int] {
    has data: list[int] = [];
}

obj Grid {
    def cell[comptime N: int] -> int {
        return N;
    }
}

obj Box {
    def cell -> int {
        return 1;
    }
}

obj Pair[T] {
    has a: T;
}

def paired[comptime N: int](a: Vec[N], b: Vec[N * 2]) -> int {
    return N;
}

def tail[comptime N: int](a: Vec[N + 1]) -> Vec[N] {
    return Vec[N]();
}

obj Ring[comptime N: int] {
    has items: list[int] = [];

    def cap -> int {
        comptime assert N > 0, "a ring holds something";
        return N;
    }
}

def scaled[comptime N: int](x: int) -> int {
    return x * N;
}

with entry {
    k = int(input());
    print(scaled[k](2));
    print(scaled[1 // 0](2), scaled[2 ** 63](2), scaled[int](2));
    print(Pair[3](a=1));
    print(paired(Vec[3](), Vec[5]()), tail(Vec[3]()));
    v: Vec[4] = Vec[3]();
    print(isinstance(v, Vec));
    print(Ring[0]().cap());
    print(Box().cell[3]());
}
```

## Differences from Python

- **Python has no value parameters.** `[comptime N: int]` is jac's, and
  makes `Vec[3]` and `Vec[4]` different types, sized at compile time.

## See also

- [Generics](generics.md): type parameters on functions and methods;
  [How generic code is compiled](generics-compiling.md).
- [Generic classes](generics-classes.md): `obj Box[T]`.
- [Compile-time evaluation](compile-time.md): `comptime if`, `comptime
  assert` and compile-time values.
- [Where clauses](interfaces-where.md): conditions on the parameters.
