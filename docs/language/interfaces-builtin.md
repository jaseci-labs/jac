---
description: The interfaces of builtin values, Ordered, Number, Int and Float, what each requires and which types conform, number literals and T(x) in a body bounded by them, and T(...) of a type parameter.
keywords: Ordered, Number, Int, Float
---
# Builtin interfaces

Four interfaces describe what builtin values provide. They are known to
every program, with no import.

| Interface | Requires | Builtin types that conform |
|---|---|---|
| `Ordered` | `<` | every number type, `bool`, `str`, `bytes`; `tuple`, `list` and `any`, which compare what they hold as the program runs, as Python does (so heap, bisection and sorting code takes them) |
| `Number` | `Ordered`'s `<`, and `+`, `-`, `*`, unary `-`, `<=`, `>`, `>=`, each of its own type | every int and float type |
| `Int` | `Number`'s, and `//` and `%` | the int types (`int`, `i8` ... `u64`, ...) |
| `Float` | `Number`'s, and `/` | the float types (`float`, `f32`, `f16`, `bf16`, ...) |

Builtin types conform to no other interface. A class conforms to one of
these as to any interface: by listing it and defining the operators' methods
(`__lt__`, `__add__`, ...) with its own type as the operand.

In a body bounded by `Number`, `Int` or `Float`:

- **A number literal is a `T`** wherever a `T` is wanted: `2 * x + 1`,
  `return 0`. A float literal is a `T` only under `Float`.
- **`T(x)` converts a number** as the type's own name does (`int(x)`,
  `f32(x)`).
- **A body that uses a literal as a `T` may only be called with number
  types**: a class has no literals, and passing one is E1478. The same holds
  of a generic class whose body does (`has total: T = 0`).

`T(...)` of a type parameter that is not bounded by a number interface
calls the type it stands for, as its name would: a class is constructed, a
`str`, `bool` or `bytes` made. A type that neither converts nor constructs
(a `list[int]`, say) is E1481.

```jac
obj Version(Ordered) {
    has major: int,
        minor: int = 0;

    def __lt__(o: Version) -> bool {
        return (self.major, self.minor) < (o.major, o.minor);
    }
}

def least[T: Ordered](xs: list[T]) -> T {
    m = xs[0];
    for x in xs {
        if x < m {
            m = x;
        }
    }
    return m;
}

def dot[T: Number](a: list[T], b: list[T]) -> T {
    acc = T(0);
    for i in range(len(a)) {
        acc = a[i] * b[i] + acc;
    }
    return acc;
}

def next_odd[T: Int](x: T) -> T {
    return 2 * x + 1;
}

def halfway[T: Float](a: T, b: T) -> T {
    return (a + b) * 0.5;
}

def tripled[T: Number](x: float) -> T {
    return T(x) * 3;
}

with entry {
    print(least([3, 1, 2]), least(["b", "a"]), least([(2, "x"), (1, "y")]));
    print(least([Version(major=2), Version(major=1, minor=4)]));
    print(dot([1, 2], [3, 4]), dot([f32(0.5)], [f32(4.0)]));
    print(next_odd(4), next_odd(i8(-3)), halfway(1.0, 2.5), halfway(f32(0.5), f32(1.0)));
    print(tripled[int](2.7), tripled[f32](0.5));
}
```

```output
1 a (1, 'y')
Version(major=1, minor=4)
11 2.0
9 -5 1.75 0.75
6 1.5
```

`dyn Number` and `dyn Ordered` are refused (E1484, see
[Interfaces](interfaces.md)): a reference to a builtin number would box it
and dispatch its operators as the program runs. Generic code takes numbers
through a bounded type parameter, compiled for each number type.

## What is rejected

| Code | When |
|---|---|
| E1478 | A class is given to a body that uses a literal as a `T` |
| E1481 | `T(...)` of a type that neither converts nor constructs, with E1229 at the call that asked for that type |
| E1283 | A type that does not conform: `least(Plain(), Plain())` for a `T: Ordered` |
| E1484 | `dyn Number`, `dyn Ordered` |

```jac
# expect: E1478, E1481, E1229
obj Cents(Number) {
    has c: int;

    def __add__(o: Cents) -> Cents {
        return Cents(c=self.c + o.c);
    }

    def __sub__(o: Cents) -> Cents {
        return Cents(c=self.c - o.c);
    }

    def __mul__(o: Cents) -> Cents {
        return Cents(c=self.c * o.c);
    }

    def __neg__ -> Cents {
        return Cents(c=-self.c);
    }

    def __lt__(o: Cents) -> bool {
        return self.c < o.c;
    }

    def __le__(o: Cents) -> bool {
        return self.c <= o.c;
    }

    def __gt__(o: Cents) -> bool {
        return self.c > o.c;
    }

    def __ge__(o: Cents) -> bool {
        return self.c >= o.c;
    }
}

def plus_one[T: Number](x: T) -> T {
    return x + 1;
}

def made[T](x: int) -> T {
    return T(x);
}

with entry {
    print(plus_one(Cents(c=1)));
    print(made[list[int]](1));
}
```

## Differences from Python and from the reference design

- **Python's `numbers.Number` and `typing.SupportsIndex` are checked as the
  program runs, or by a separate type checker; here a bound by `Number` is
  checked by the compiler**, and the body is compiled for each number type
  it is called with, using that type's own arithmetic (an `i8`'s, an
  `f32`'s).
- **In Python a literal in generic code is an `int` or a `float`; here, under
  `Number`, `Int` or `Float`, it is a `T`.**

## See also

- [Interfaces](interfaces.md): what an interface is and how a class conforms.
- [Numbers](numbers.md): the int and float types.
- [Generics](generics.md): type parameters and bounds.
