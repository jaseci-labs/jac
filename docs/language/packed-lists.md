---
description: How a list of structs, narrow numbers, 128-bit ints, arrays or vectors holds its elements packed in place, what indexing, loops and lending do with such elements, and what stays the same as any list.
keywords: packed list, packed lists, list of structs
---
# Packed lists

A list of values holds them packed, in place, each at its own size. A
`list[P]` of a [struct](structs.md) holds the structs' bytes one after
another, as a C array of `P` does, and a list of a narrow number holds each
at its width. A list of anything else holds one 64-bit word for each item.

| Element type | Bytes an element |
|---|---|
| `i8`, `u8`, `bool` | 1 |
| `i16`, `u16`, `f16`, `bf16` | 2 |
| `i32`, `u32`, `f32` | 4 |
| `i128`, `u128` | 16 |
| A struct | The struct's size, as C lays it out |
| An [array or a vector](../accel/vectors.md) | Its bytes |
| `int`, `float`, `str`, an object, anything else | 8: a word |

Nothing is declared to get this: the element type decides. A packed list is
a `list`, with every operation a list has.

```jac
struct P {
    has x: float = 0.0,
        y: f32 = 0.0;

    def shift(d: float) {
        self.x += d;
    }
}

def poke(p: &mut P) {
    p.x = 99.0;
}

def main {
    ps: list[P] = [P(x=1.0), P(x=2.0)];
    ps[1].x = 5.0;
    ps[0].shift(1.0);
    q = ps[1];
    q.x = 0.0;
    print(ps, q);
    poke(&mut ps[0]);
    for p in ps {
        p.x = 0.0;
    }
    print(ps);
    for m in &mut ps {
        m.y = f32(2.0);
    }
    print(ps);
}

with entry {
    main();
}
```

```output
[P(x=2.0, y=0.0), P(x=5.0, y=0.0)] P(x=0.0, y=0.0)
[P(x=99.0, y=0.0), P(x=5.0, y=0.0)]
[P(x=99.0, y=2.0), P(x=5.0, y=2.0)]
```

## The storage is a C array

The elements lie one after another, so a packed list's storage is what C
code expects of an array of the element type. `__list_data_ptr(xs)` gives
its address as a raw `ptr`. The address is good only while the list is
alive and is not grown: a list is released after its last use, so keep
using the list for as long as the pointer is used.

```jac
struct P {
    has x: float = 0.0,
        y: f32 = 0.0;
}

def main {
    fs: list[f32] = [f32(0.1), 1.5, 2.25];
    ps: list[P] = [P(x=1.0), P(x=2.0, y=3.0)];
    pf = ptr[f32](__list_data_ptr(fs));
    pp = ptr[P](__list_data_ptr(ps));
    print(int(pf + 1) - int(pf), int(pp + 1) - int(pp));
    pp[0].x = 42.0;
    print(pf[1], pp[1].y, ps[0], len(fs));
}

with entry {
    main();
}
```

```output
4 16
1.5 3.0 P(x=42.0, y=0.0) 3
```

## Elements are places

- **`ps[i].x = v` writes into the list's element**, and so does what a
  method changes: `ps[0].shift(1.0)`.
- **`q = ps[i]` is a copy.** Changing `q` leaves the list as it is.
- **`&mut ps[i]` lends the element itself** to a `&mut P` parameter.
- **`for p in ps` makes `p` each element's copy**: assigning to its fields
  changes nothing in the list.
- **`for p in &ps` and `for p in &mut ps` make `p` each element itself.**
  Through `&mut`, a field write changes the list. After the loop, `p` is a
  copy of the last element it was.
- **A list of numbers lends none of its elements mutably**, since each is
  copied out: `for v in &mut fs` over a `list[f32]` is an error (E1330).
  Index it instead: `fs[i] = ...`.
- **An element of a list of arrays or vectors is written in place too**:
  `xs[i][j] = 1.0`.

Lending an element (`&mut ps[0]`) lends the list's storage. A callee that
grows the same list through another reference to it (a global, an object's
field) goes on writing the storage the list had.

## Every list operation works

Every operation of a list works on a packed one, as on Python's list of the
same values: indexing, slicing, `+`, `*`, `in`, `==`, `len`, `append`,
`insert`, `extend`, `del`, `sort`, `sorted`, `list()`, `min`, `max`, `sum`,
unpacking, comprehensions, `repr`, `copy` and `deepcopy`. `bytes(xs)` of
a `list[u8]` is its bytes.

A key function (`sorted(ps, key=f)`, `min`, `max`, `sort`) is given each
element as its own copy.

```jac
struct P {
    has x: float = 0.0;
}

def by_x(p: P) -> float {
    p.x = -p.x;
    return p.x;
}

def main {
    ps: list[P] = [P(x=3.0), P(x=1.0)];
    ps.append(P(x=2.0));
    print(sorted(ps, key=by_x), ps);
    print(ps[0:1], ps + ps[2:], P(x=1.0) in ps, len(ps));
    fs: list[f32] = [f32(0.1), 1.5, 2.25];
    print(fs, max(fs), sum(fs), [f * 2 for f in fs]);
}

with entry {
    main();
}
```

```output
[P(x=3.0), P(x=2.0), P(x=1.0)] [P(x=3.0), P(x=1.0), P(x=2.0)]
[P(x=3.0)] [P(x=3.0), P(x=1.0), P(x=2.0), P(x=2.0)] True 3
[0.1, 1.5, 2.25] 2.25 3.85 [0.2, 3.0, 4.5]
```

`by_x` negates the copy it is given, so the list is unchanged after
`sorted`.

## As an any

Converted to an `any` or a `list[any]`, a packed list is the same list, its
elements read out as copies. A value stored through the `list[any]` is
checked against the element type: an `int` stored into a `list[i8]` or
`list[u8]` is range-checked and raises `OverflowError` where it does not
fit, and an array of another length stored into a list of arrays raises
`ValueError`. An `any`'s array is the list of its elements.

```jac
with entry {
    bs: list[u8] = [1, 2, 255];
    anys: list[any] = bs;
    anys[0] = 7;
    try {
        anys[1] = 300;
    } except OverflowError as e {
        print("OverflowError:", e);
    }
    print(bs, anys is bs);
}
```

```output
OverflowError: integer overflow
[7, 2, 255] True
```

A shared generic body's `list[T]` packs as its type argument's list does
(see [How generic code is compiled](generics-compiling.md)).

## Elements holding references

A struct holding references is packed as any struct is, and counted as every
place of one is. Under the `managed` and `rc`
[memory profiles](memory.md) the list holds a count of each reference in
each element. The count is taken as an element is stored or copied in (an
`append`, a slice, `+`, `*`, `copy`) and given up as one is overwritten or
removed (`del`, `pop`, `remove`, `clear`, the list going). `managed`
collects cycles through its elements.

`copy` copies the structs, which still refer to what the originals do.
`deepcopy` copies what each element refers to as well.

```jac
import copy;

struct Named {
    has name: str = "",
        tags: list[str] = [];
}

with entry {
    ns: list[Named] = [Named(name="a")];
    shallow = ns.copy();
    shallow[0].name = "b";
    shallow[0].tags.append("t");
    deep = copy.deepcopy(ns);
    deep[0].tags.append("u");
    print(ns, shallow, deep);
}
```

```output
[Named(name='a', tags=['t'])] [Named(name='b', tags=['t'])] [Named(name='a', tags=['t', 'u'])]
```

A [tensor](../accel/tensors.md)'s element is plain data, bytes on a device:
a tensor of a struct holding a reference is refused (E1152).

## The list owns its elements

A packed list owns its elements by holding them. `list[own P]`, or
`list[own f32]` of a narrow number, is refused (E1521): `own` marks the
owner of a reference, and these elements are values. `list[P]` is the list
that owns its structs. See [Ownership](ownership.md).

## What is rejected

```jac
# expect: E1521, E1330
struct P {
    has x: float = 0.0;
}

with entry {
    owned: list[own P] = [];
    fs = [f32(1.0), f32(2.0)];
    for v in &mut fs {
        print(v);
    }
}
```

| Code | Meaning |
|---|---|
| E1521 | A packed list's element type is marked `own`. |
| E1330 | A `&mut` loop over a list of numbers, whose elements are copied out. |
| E1152 | A tensor of a struct that holds a reference. |

## Differences from Python

In Python a list holds references, so `p = ps[0]; p.x = 1` changes the
list's element and `for p in ps: p.x = 0` changes every one. Here a list of
structs holds values: `q = ps[0]` and `for p in ps` copy, and the list
changes only through `ps[i]`, `&mut ps[i]` or `for p in &mut ps`. A list of
`obj`s behaves as Python's does.
