---
description: Functions as values - the Callable types and what fits them, calls through a function value and how they bind at run time, objects with __call__, and classes called as functions.
keywords: Callable, function value, first-class function, callable object
---
# Function values

A function's name, a lambda and a bound method (`counter.bump`) are values. They can be passed,
stored and returned, and their type is a `Callable`. Declaring and calling functions is in
[Functions](functions.md) (`jac docs def`).

## `Callable` types

| Type | Holds |
|---|---|
| `Callable[[int, str], bool]` | A function taking an `int` and a `str` and returning a `bool` |
| `Callable[[], None]` | A function taking nothing and returning nothing |
| `Callable[..., int]` | A function taking any arguments and returning an `int` |
| `Callable` | Any function; a call of it is checked as the program runs |

A function fits a `Callable` type when its parameters and result do:

- Its positional parameters must be the ones listed. A positional parameter with a default still
  counts: `def area(w: int, h: int = 1)` is not a `Callable[[int], int]` (E1001).
- Keyword-only parameters with defaults are left out: `def scaled(x: int, *, factor: int = 3)` is
  a `Callable[[int], int]`, and a call through it gives `factor` its default.
- A function that returns a value fits a `Callable[[...], None]`; its value is dropped. A lambda
  stored that way keeps what it captured after its maker returned.
- An `async def` does not fit a `Callable[[...], None]` (E1053 as an argument, E1001 in a
  variable); see [Async](async.md).
- An object whose class defines `__call__` fits, by its `__call__`'s parameters, defaults filling
  the rest. The function value keeps the object alive, and an `override def __call__` dispatches on
  the object's own class.

`callable(v)` tells whether a value can be called.

```jac
obj Tally {
    has base: int = 0;

    def __call__(a: int, b: int = 10) -> int {
        return self.base + a + b;
    }
}

def inc(x: int) -> int {
    return x + 1;
}

def scaled(x: int, *, factor: int = 3) -> int {
    return x * factor;
}

def apply(f: Callable[[int], int], x: int) -> int {
    return f(x);
}

with entry {
    ops: dict[str, Callable[[int], int]] = {
        "inc": inc,
        "dbl": lambda (x: int) -> int { return x * 2; },
        "scaled": scaled,
        "tally": Tally(base=100),
    };
    print([apply(f, 5) for f in ops.values()]);
    loose: Callable = inc;
    print(loose(41), callable(loose), callable(5));
}
```

```output
[6, 10, 15, 115]
42 True False
```

A call through a value typed `Callable[[...], R]` is checked against that type when the program
compiles: it takes as many positional arguments as the type lists, each of its type, and no
keyword, since a `Callable` names no parameters. A default of the function the value holds is
therefore not used, whether the value is a function's name or a bound method, and the refusal
names no parameter: `g() is missing 1 argument` (E1050), `g() takes 1 argument, found 2` (E1051).
A lambda or a nested `def` bound once to a local is called as it is written, with its own
parameter names and defaults.

```jac
# expect: E1050 x2, E1051, E1052
obj Counter {
    has n: int = 0;

    def bump(step: int = 1) -> int {
        self.n += step;
        return self.n;
    }
}

def area(w: int, h: int = 1) -> int {
    return w * h;
}

with entry {
    g = area;
    print(g(3));
    bump = Counter().bump;
    print(bump(), bump(1, 2), bump(step=2));
}
```

## Calls bound when the program runs

A call through a bare `Callable` or an `any` binds its arguments as the program runs, to the
parameters of the function the value holds, as a call by name would: positions, keywords,
`*rest`, keyword-only parameters and `**opts`, and defaults computed at that call, whatever
their type. Arguments that do not bind raise `TypeError` with Python's wording:

| Call | `TypeError` |
|---|---|
| Too many arguments | `three() takes 3 positional arguments but 4 were given` |
| Missing arguments | `three() missing 3 required positional arguments: 'a', 'b', and 'c'` |
| An unknown keyword | `three() got an unexpected keyword argument 'd'` |
| A missing keyword-only argument | `needs_key() missing 1 required keyword-only argument: 'key'` |
| A parameter given twice | `<lambda>() got multiple values for argument 'x'` |
| An argument of the wrong type | `expected int, found str` |
| A method called on an `any` (`w.ok(1, 2)`), or read off its object and held in one (`m: any = d.ok`, then `m(1, 2)`) | Counts `self`, and names `Class.method`: `Defaults.ok() takes 2 positional arguments but 3 were given` |

A missing argument is reported before any default is computed.

A method read off its object (`d.ok`) keeps the object: its arguments bind to the method's
parameters, by position or by their names, and none of them is the object.

A field that holds a function, typed `Callable` or `any`, is called as a method is: `h.f(4)`.

An `any` assigned to a local typed `Callable[[int, int], int]` is not checked at the assignment.
The call checks it: it binds the held function's own parameters, and raises `TypeError` when they
are others, or when the value is not callable at all (`expected function, found int`).

```jac
def three(a: int, b: int, c: int) -> int {
    return a * 100 + b * 10 + c;
}

def plus_one(a: int) -> int {
    return a + 1;
}

def as_pair_fn(v: any) -> int {
    f: Callable[[int, int], int] = v;
    return f(1, 2);
}

with entry {
    t: any = three;
    print(t(1, 2, 3), t(c=3, b=2, a=1));
    for v in [plus_one, 5] {
        try {
            print(as_pair_fn(v));
        } except TypeError as e {
            print("TypeError:", e);
        }
    }
    try {
        t(1, 2, d=3);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
123 123
TypeError: plus_one() takes 1 positional argument but 2 were given
TypeError: expected function, found int
TypeError: three() got an unexpected keyword argument 'd'
```

## Classes as functions

A class is a value too (see `jac docs types`). Called through an `any`, a class binds its
arguments as its constructor does: with no `init` of its own, positions fill its fields in the
order they are declared and keywords name fields; with an `init`, as that `init` binds, `/`,
`*rest`, keyword-only parameters and `**named` included, `*rest` the list and `**named` the dict
its type says. `type(self)(...)` makes a new object of the receiver's own class.

```jac
obj Greeter {
    has name: str = "x",
        base: str = "hi";
}

obj Bag {
    has items: list[any] = [],
        mode: str = "";

    def init(first: any, *rest: any, mode: str = "plain", **named: int) {
        self.items = [first] + rest;
        self.mode = mode;
        print(self.items, named, mode);
    }

    def again(*more: any) -> Bag {
        return type(self)(*more);
    }
}

with entry {
    gk: any = Greeter;
    print(gk("hey"), gk(base="yo"));
    try {
        gk(bse="yo");
    } except TypeError as e {
        print("TypeError:", e);
    }
    bk: any = Bag;
    b = bk(1, 2, mode="q", x=5);
    print(type(b.again(8, 9)).__name__);
}
```

```output
Greeter(name='hey', base='hi') Greeter(name='x', base='yo')
TypeError: Greeter() got an unexpected keyword argument 'bse'
[1, 2] {'x': 5} q
[8, 9] {} plain
Bag
```

Type parameters (`def first[T](xs: list[T]) -> T`) are in `jac docs generics`, and decorators,
which take and give function values, in `jac docs decorators`.

## Differences from Python

- A `Callable` names its parameter and result types, and a function given for it is checked when
  the program compiles; only a bare `Callable` or an `any` is bound as the program runs.
- A class called through an `any` binds positions to its fields, as its constructor does here; a
  Python dataclass does the same, a plain Python class does not.
