---
description: What each kind of place does with a struct it holds: an any, an optional, a tuple, a dict or set, a closure, a generator, a function value, a type parameter, C memory, and a cpython or JavaScript host.
keywords: optional struct, struct in an any, plain struct
---
# Where structs are held

A [struct](structs.md) is a value: each place that holds one holds its own.
This page says what "its own" means for each kind of place. Lists are on
their own page, [Packed lists](packed-lists.md).

| Place | How it holds a struct | Writes reach it in place |
|---|---|---|
| A variable, a parameter, a global | The struct's bytes | yes |
| A field of an `obj`, `node`, `edge`, `walker` or struct | The struct's bytes, inside the holder | yes: `o.at.x = 1.0` |
| A `list[P]` element | The struct's bytes, packed | yes: `ps[i].x = 1.0` |
| A `dict` value | A box of a copy | yes: `d[k].x = 1.0` |
| A `dict` key, a `set` member | A box of a copy | no |
| A tuple item | A box of a copy | no (E1504) |
| An `any`, a `P \| None`, a `dyn` | A box of a copy | no |
| C memory through `ptr[P]` | The struct's bytes | yes: `p[i].x = 1.0` |

## In an any

Converted to an `any`, a struct is copied into an object of its class.
`isinstance`, `getattr`, `repr` and the struct's methods that change nothing
see that object. One read back out (`p: P = x`) is copied out.

A struct in an `any` has no attribute to set, and its methods that change it
are not found there: both raise `AttributeError` when the program runs.

```jac
struct P {
    has x: float = 0.0;

    def shift(d: float) {
        self.x += d;
    }

    def doubled -> P {
        return P(x=self.x * 2.0);
    }
}

with entry {
    a = P(x=1.0);
    x: any = a;
    a.x = 7.0;
    print(x, isinstance(x, P), getattr(x, "x"), x.doubled());
    try {
        x.shift(1.0);
    } except AttributeError as e {
        print("AttributeError:", e);
    }
    back: P = x;
    back.x = 3.0;
    print(back, x, a);
}
```

```output
P(x=1.0) True 1.0 P(x=2.0)
AttributeError: 'P' object has no attribute 'shift'
P(x=3.0) P(x=1.0) P(x=7.0)
```

## Optional structs

`P | None` is an optional struct, held as an `any` holding a struct or
`None`. `d.get(k)` of a dict of structs gives one. Test it with
`is None` or `is not None`; to change the struct, copy it out to a variable
of type `P`, change that, and assign it back.

```jac
struct P {
    has x: float = 0.0;
}

def find(ps: dict[str, P], k: str) -> P | None {
    return ps.get(k);
}

with entry {
    d = {"a": P(x=1.0)};
    q = find(d, "a");
    if q is not None {
        p: P = q;
        p.x += 5.0;
        q = p;
    }
    print(q, find(d, "z"), d);
}
```

```output
P(x=6.0) None {'a': P(x=1.0)}
```

## Tuples

A tuple holds structs as an `any` does, each a copy in a box of its own,
read back as a copy. A tuple never changes, so `t[0].x = 1.0` would change a
temporary copy (E1504). `(a, b) = t` copies each item into its target. A
`for` loop over a tuple gives each item as an `any`, so `for e in t` reads
`e.x`, and `e.x = 0.0` raises `AttributeError` when the program runs, as
for any struct in an `any` (above).

## Dicts and sets

A dict holds its values, and a dict or set its keys and members, as values:
each goes in as a copy of its own.

- `d[k]` is the entry's own place: `d[k].x = 1.0` and `d[k].shift(1.0)`
  change the entry.
- What comes out is a copy: a variable (`got = d[k]`), a loop's or an
  unpacking's target, `get`, `pop`, `popitem`, `setdefault`,
  `list(d.values())`.
- A dict made from another's values holds copies of its own: `d.copy()`,
  `dict(d)`, `{**d}`, `d | e`, `update`, `dict(pairs)`,
  `dict.fromkeys(ks, p)`.
- `get(k)` of a struct value is an optional (`P | None`).

Natively each is a box of a copy, as an `any` holds one, counted under the
`managed` and `rc` [memory profiles](memory.md).

```jac
struct P {
    has x: float = 0.0;

    def shift(d: float) {
        self.x += d;
    }
}

with entry {
    p = P(x=10.0);
    d: dict[str, P] = {"k": p};
    d["k"].x = 1.0;
    d["k"].shift(1.0);
    got = d["k"];
    got.x = 50.0;
    for (k, v) in d.items() {
        v.x = 7.0;
    }
    e = d.copy();
    e["k"].x = 3.0;
    print(d, e, p);
}
```

```output
{'k': P(x=2.0)} {'k': P(x=3.0)} P(x=10.0)
```

## References inside a struct

A struct may hold references (`has name: str`, a list, an object). A copy
refers to what the original does.

Under `managed` and `rc`, every place holding a struct (a variable, a
parameter's copy, a global, a field, a list's element, a dict's entry, an
`any`) counts each reference in it. It takes the counts as a struct is
copied in and gives them up as it is overwritten or its place goes. So what
a struct refers to lives exactly as long as some place holds it, and
`managed` collects cycles through structs. Under `nogc` a struct's
references are held as an object's fields hold them. See
[Memory](memory.md).

A struct that holds no reference is plain data (see
[What crosses into a place](../accel/crossing.md)). One holding a reference is
not: no [kernel](../accel/kernels.md) holds one (E1540), no
[tensor](../accel/tensors.md) has one as its element and no `ptr` points to
one (E1152).

## Closures, generators and async functions

- **A nested function captures a struct variable as it captures any
  variable**: the variable itself, whose cell holds the struct. A change
  either one makes is the other's. A lambda made in a loop sees the
  variable's last value, as in Python.
- **A generator or async function holds its struct variables in its frame**
  across each `yield` and `await`. An async function may give a struct.

```jac
struct P {
    has x: float = 0.0;

    def shift(d: float) {
        self.x += d;
    }
}

def counted(start: P) -> list[float] {
    p = start;
    def bump(d: float) -> float {
        p.shift(d);
        return p.x;
    }
    first = bump(1.0);
    p.x += 10.0;
    return [first, bump(1.0), p.x, start.x];
}

def walk(n: int, step: P) -> Iterator[float] {
    at = P();
    for i in range(n) {
        at.x += step.x;
        yield at.x;
    }
}

with entry {
    print(counted(P(x=1.0)), list(walk(3, P(x=0.5))));
}
```

```output
[2.0, 13.0, 13.0, 1.0] [0.5, 1.0, 1.5]
```

## Function values and defaults

A function value (`Callable[[P], P]`, a lambda, a `def` named as a value)
takes and gives structs as a call does: each argument is the callee's own
copy, and its result is a value of its caller's.

- A struct's method read as a value (`m = p.scaled`) is bound to a copy of
  `p` taken as it is read. Changing `p` afterwards does not change what `m`
  computes.
- A default that is a struct is each call's own, a closure's too: a
  function that changes its defaulted parameter starts from the same
  default on the next call.

```jac
struct P {
    has x: float = 0.0;

    def scaled(k: float) -> P {
        return P(x=self.x * k);
    }
}

def bump(p: P = P(x=1.0)) -> P {
    p.x += 1.0;
    return p;
}

def apply(f: Callable[[P], P], p: P) -> P {
    return f(p);
}

def main {
    p = P(x=10.0);
    print(bump(), bump(), apply(bump, p), p);
    m = p.scaled;
    p.x = 100.0;
    print(m(2.0), p.scaled(2.0));
}

with entry {
    main();
}
```

```output
P(x=2.0) P(x=2.0) P(x=11.0) P(x=10.0)
P(x=20.0) P(x=200.0)
```

## Type parameters and generic classes

A type parameter may stand for a struct whatever its bound. A function whose
body is shared among the types its parameters stand for (each held as a
word, `def kept[T](x: T) -> T`) is copied for each struct type a call gives
it, as one bounded by an interface is copied for every type.

A generic class given a struct holds it in place (`Cell[P]`), and a generic
struct (`struct Duo[T]`) is an instance for each type. See
[Generic classes](generics-classes.md).

```jac
struct P {
    has x: float = 0.0;
}

struct Duo[T] {
    has a: T,
        b: T;
}

obj Cell[T] {
    has item: T;
}

def kept[T](x: T) -> T {
    return x;
}

with entry {
    c = Cell(item=P(x=1.0));
    c.item.x = 2.0;
    print(c, kept(P(x=3.0)), Duo(a=1, b=2), Duo[f32](a=1.5, b=2.5));
}
```

```output
Cell(item=P(x=2.0)) P(x=3.0) Duo(a=1, b=2) Duo(a=1.5, b=2.5)
```

## C memory

A plain struct is C data. `ptr[P]` and its views (`p.view(n)`) reach the
structs in C memory as C lays them out:

- `p + 1` is the next struct.
- `p[i]` is the struct there, in place: `p[i].x = 1.0` and a method that
  changes `p[i]` write C's memory.
- `p[i] = q` copies `q` in.

As a C record, a struct is reached through `p[i]`, not through `p.load()`
and `p.store()` (E1467). A struct holding a reference is no `ptr`'s item
(E1152).

```jac
import from c {
    def malloc(n: int) -> ptr;
    def free(p: ptr);
}

struct P {
    has x: float = 0.0,
        y: f32 = 0.0;

    def shift(d: float) {
        self.x += d;
    }
}

def main {
    raw = malloc(48);
    p = ptr[P](raw);
    p[0] = P(x=1.0, y=2.0);
    p[1] = P(x=3.0);
    p[2] = P();
    p[1].x = 10.0;
    p[1].shift(0.5);
    v = p.view(3);
    v[2].y = 7.0;
    print(p[0], (p + 1)[0], v[2], len(v));
    print(int(p + 1) - int(p), ptr[f32](raw)[2]);
    free(raw);
}

with entry {
    main();
}
```

```output
P(x=1.0, y=2.0) P(x=10.5, y=0.0) P(x=0.0, y=7.0) 3
16 2.0
```

The last line reads the layout: one `P` is 16 bytes, and the `f32` at byte
8 of the first is its `y`.

## Other hosts

A struct means the same on every host. A cpython or JavaScript space, whose
variables hold references, lowers a struct to a class whose instances are
records, each place holding one of its own, and copies where the language
copies:

- an assignment, an argument, a return or a store of one a place holds
  (what a call or a construction gives is its own already);
- a loop's target;
- a list's, dict's or set's element going in or coming out;
- a new list or dict made of another's elements (a slice, `+`, `*`,
  `list()`, `sorted()`, `copy()`, a merge);
- a key function's argument.

An assignment over a `&mut` parameter writes the caller's struct field by
field. What is read through an `any` (an attribute, an item, `getattr()`, a
call's result) is a copy in an `any`, as natively.

Python or JavaScript code given a struct gets a copy in an `any`: its fields
read, none set, and its methods that change it absent. One it passes back is
copied again.

## Not built yet

These are refused with E5090:

- iterators giving structs: `reversed(ps)`, a generator of them
  (`-> Iterator[P]`);
- a struct as the type of a shared generic method that subclasses override,
  which is called through its class.

## What is rejected

```jac
# expect: E1504, E1152, E1467, E5090, E1540
import from accel { tensor, kernel }

struct P {
    has x: float = 0.0;
}

struct Named {
    has name: str = "";
}

def fill(i: int, out: tensor[f32, _]) {
    n = Named();
    out[i] = 1.0;
}

def each -> Iterator[P] {
    yield P();
}

with entry {
    t = (P(), P());
    t[0].x = 1.0;
    pn = ptr[Named](0);
    print(pn[0].name);
    pc = ptr[P](0);
    print(pc.load(0, align=8));
    print(next(each()));
    kernel(fill);
}
```

| Code | Meaning |
|---|---|
| E1504 | A write to a tuple's item, which is a temporary copy. |
| E1152 | A `ptr` (or a tensor) is given a struct that holds a reference. |
| E1467 | `load()` or `store()` is used on a `ptr` to a struct; index it. |
| E5090 | An iterator of structs, which is not built yet. |
| E1540 | A kernel holds a struct with a reference in it. |
