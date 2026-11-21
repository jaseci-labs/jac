---
description: The any type - what a value of unknown type allows, how it is checked when it reaches a typed place, how containers convert to and from list[any], and what operators and item assignment do through it.
keywords: any, dynamic value, unboxing
---
# The `any` type

`any` is the type of a value whose type is known only when the program runs. It is a keyword,
written in lower case; Python's `typing.Any` is this. For the other types, see
[Types](types.md) (`jac docs types`).

- Any value converts to `any`.
- Every operation on an `any` is allowed by the checker and resolved by what the value holds as
  the program runs. One the value does not support raises `TypeError` or `AttributeError`.
- An `any` given to a typed place (a typed local, a field, a parameter, a return) is checked as it
  arrives, and raises `TypeError` when it is not of that type.

Typed code is checked earlier and runs faster; use `any` at the edges, for data whose shape is not
known until it is read.

```jac
def parse(text: str) -> any {
    if text.isdigit() {
        return int(text);
    }
    return text;
}

with entry {
    v = parse("12");
    print(v + 1, type(v).__name__);

    n: int = parse("30");
    print(n + 1);
    try {
        m: int = parse("thirty");
        print(m);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
13 int
31
TypeError: expected int, found str
```

## An `any` reaching a typed place

What the `any` holds decides what arrives:

| The `any` holds | The place wants | Result |
|---|---|---|
| A value of exactly that type | `T` | The value |
| An `int` | `float` | The int as a float: `7` arrives as `7.0` |
| `None` | `T \| None` | `None` |
| Anything else | `T` | `TypeError: expected T, found U`, with `None` named `None` and a class by its name |

A typed list, dict or set given to a `list[any]`, `dict[K, any]` or `set[any]` place is the
same container, not a copy: what the callee appends or stores through the `list[any]` the
caller sees. The other way, an `any` (or a `list[any]`) given to a `list[T]`, `dict[K, V]` or
`set[T]` place is a **new** container with every item converted, even when no item changes. The
source is never changed, and when an item does not convert the `TypeError` leaves it as it was.

```jac
def bump(xs: list[any]) {
    xs.append(7);
    xs[0] = 5;
}

def as_floats(held: any) -> list[float] {
    return held;
}

def wanted(v: any) -> ValueError {
    return v;
}

with entry {
    ns = [1, 2, 3];
    bump(ns);
    print(ns);

    held: list[any] = [1, 2];
    fl = as_floats(held);
    print(fl, held, fl is held);
    try {
        as_floats([1, "a"]);
    } except TypeError as e {
        print("TypeError:", e);
    }
    nothing: any = None;
    s: str | None = nothing;
    print(s);
    try {
        wanted(3);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
[5, 2, 3, 7]
[1.0, 2.0] [1, 2] False
TypeError: expected float, found str
None
TypeError: expected ValueError, found int
```

A `tuple[int, str]` assigns to a `tuple[int, any]` item by item. `v as list[any]` asserts that an
`any` holds a list and lets typed code walk it: `for (i, w) in enumerate(v as list[any])`.

## Operators and item assignment through an `any`

- An operator with an `any` operand is computed on what it holds. An augmented assignment to a
  typed target whose right side is an `any` is computed that way and checked back into the
  target's type: `n = 10; a: any = 3; n += a; n *= a;` leaves the `int` `39`.
- An augmented assignment to an `any` changes in place exactly what Python changes in place:
  `+=` and `*=` on a list or a bytearray, `|=`, `&=`, `-=` and `^=` on a set, `|=` on a dict, and
  a class's `__iadd__` and the other `__i<op>__` hooks. Every other reference to that value sees
  the change. Anything else, a tuple's `+=` among them, makes a new value. See
  [Augmented assignment](variables-augmented.md).
- Item assignment through an `any` reaches the container it holds, nested too:
  `cont["k"]["v"] = [1]` changes the dict inside the dict. On a held `str` or `tuple` it raises
  `TypeError: 'str' object does not support item assignment`.

```jac
with entry {
    n = 10;
    a: any = 3;
    n += a;
    n *= a;
    print(n, n + 1);

    xs = [1, 2];
    held: any = xs;
    held += (3,);
    held *= 2;
    print(xs, held is xs);

    cont: any = {"k": {"v": [0]}};
    cont["k"]["v"] = [1];
    print(cont);
    word: any = "abc";
    try {
        word[0] = "x";
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
39 40
[1, 2, 3, 1, 2, 3] True
{'k': {'v': [1]}}
TypeError: 'str' object does not support item assignment
```

## Differences from Python

- An `any` is checked when it reaches a typed place; in Python an annotation checks nothing.
- A `list[any]` converted to a `list[float]` is a new list even when every item is already of that
  type; on the cpython host the same list comes back when no item changes.
