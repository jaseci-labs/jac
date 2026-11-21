---
description: The tensor type of the accel module - a block of numbers or plain structs on a device whose shape is part of its type - how one is made, indexed, copied and printed.
keywords: tensor, shape, tolist, tensor of structs, row-major
---
# Tensors

A `tensor[E, d0, d1, ...]` is a block of elements of type `E` that lives on a
[device](devices.md), in row-major order. Its type states its shape. Tensors
are what [kernels](kernels.md) run over; ordinary code makes them, fills them
and reads results out of them.

```jac
import from accel { tensor }

with entry {
    a = tensor[f32, 3]([1.5, 2.5, 3.25]);
    a[1] = 7;
    a[2] += 0.5;
    print(a, a.shape, len(a), a.on);
    m = tensor[i32, _, 2](shape=(3, 2), fill=4);
    m[2, 1] = 9;
    print(m[2, 1], m.shape, m.tolist());
}
```

```output
tensor([1.5, 7.0, 3.75], shape=(3,)) (3,) 3 cpu
9 (3, 2) [4, 4, 4, 4, 4, 9]
```

`tensor` is imported from `accel`. A cpython or JavaScript space has no tensors
(`E1540`; see [What code needs from the place it runs](requirements.md)).

## The type

`tensor[E, d0, d1, ...]` takes an element type and one argument for each
dimension.

- `E` is an int type, a float type, `bool`, or a struct of plain data.
  Anything else is `E1233`; a struct that holds a reference is `E1152`.
- Each dimension is a compile-time int that is not negative (`E1234`), or `_`
  for one known only when the program runs. A compile-time int is a literal, a
  `comptime` name or parameter, or arithmetic on them: `tensor[f32, N, 2 * M]`.
  A run-time value is `E0033`.

The compiler keeps the type's arguments; they are not erased. A
`tensor[f32, 2, 3]` is not a `tensor[f32, 2, 2]` or a `tensor[f64, 2, 3]`. It
is a `tensor[f32, _, 3]`: `_` accepts any size, so a function over tensors of
any length takes `tensor[f32, _]`.

A function's `comptime` parameter that is a tensor's dimension is found from
its argument's type, the way a type parameter is:

```jac
import from accel { tensor }

comptime ROWS: int = 2;

def total[comptime N: int](t: tensor[f32, N]) -> float {
    s = 0.0;
    comptime for i in range(N) {
        s += float(t[i]);
    }
    return s;
}

def last(m: tensor[i32, _, 2]) -> i32 {
    return m[len(m) - 1, 1];
}

with entry {
    print(total(tensor[f32, 3]([1.5, 2.5, 3.25])));
    print(total(tensor[f32, ROWS * 2](fill=0.25)));
    print(last(tensor[i32, 3, 2](fill=4)));
}
```

```output
7.25
1.0
4
```

A tensor's device is its value's (`t.on`), not its type's.

## Making a tensor

| Call | Makes |
|---|---|
| `tensor[f32, 3]([1.0, 2.0, 3.0])` | a tensor holding those values |
| `tensor[f64, _, 3]([[3.0, 4.0, 0.0], [1.0, 2.0, 2.0]])` | nested lists for more dimensions. The one open dimension is what the data makes it: here 2 |
| `tensor[f32, 2, 2]()` | zeros, where the type states every dimension |
| `tensor[i32, _, 2](shape=(n, 2))` | zeros of that shape. `shape=` is an int for one dimension, a tuple for more |
| `tensor[i32, _, 2](shape=(n, 2), fill=4)` | every element 4 |

A call takes these keyword arguments besides:

| Argument | Meaning |
|---|---|
| `on=dev` | the device the tensor lives on. The processor unless given |
| `order="F"` | column-major memory in place of row-major (`"C"`, the default). The data is still given row by row. See [Views and layouts](views.md) |
| `pinned=True` | page-locked memory, on the processor. See [Streams, events and copies](streams.md) |

What the type and the call say must agree when the program runs. Data of
another count than the type's, or data for a type with more than one open
dimension and no `shape=`, raises `ValueError`:

```jac
import from accel { tensor }

with entry {
    g = tensor[f64, _, 3]([[3.0, 4.0, 0.0], [1.0, 2.0, 2.0]]);
    print(g.shape, g[1, 2]);
    try {
        tensor[f32, 4]([1.0, 2.0]);
    } except ValueError as e {
        print("ValueError:", e);
    }
    try {
        tensor[f32, _, _]([1.0, 2.0]);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
(2, 3) 2.0
ValueError: a tensor of 4 elements was given 2
ValueError: more than one dimension is open in the tensor's type (`_`), so shape= has to give them
```

## Items

`t[i, j]` reads an element and `t[i, j] = v` writes one, with as many indices
as the tensor has dimensions. An item has the element's type, and a store takes
that type alone: storing a `float` into a `tensor[f32, _]` is `E1001`, as
assigning one to an `f32` variable is (a literal takes the element's type).

Each index is checked against its dimension when the program runs, and one
outside it raises `IndexError`. An index is never negative: `t[-1]` is out of
range, not the last element.

A subscript with fewer indices than dimensions, or with a slice or `...`, is
not an item: it is a view of the tensor, sharing its memory. See
[Views and layouts](views.md).

```jac
import from accel { tensor }

with entry {
    m = tensor[i32, _, 2](shape=(3, 2), fill=4);
    for bad in [3, -1] {
        try {
            print(m[bad, 0]);
        } except IndexError as e {
            print("IndexError:", e);
        }
    }
    print(m[2].tolist());
}
```

```output
IndexError: index 3 is out of range for dimension 0 of size 3
IndexError: index -1 is out of range for dimension 0 of size 3
[4, 4]
```

## What a tensor has

| Member | Is |
|---|---|
| `t.shape` | its dimensions, a tuple of ints |
| `len(t)` | its first dimension |
| `t.tolist()` | its elements in row-major order of their indices, as one flat list: of ints for an int or `bool` tensor (a `bool` as 0 or 1), of floats for a float tensor, of copies for a tensor of structs |
| `t.on` | the device it lives on |
| `t.to(dev)` | a copy of it on `dev`, contiguous and row-major |
| `t.copy()` | a copy of it where it lives: `t.to(t.on)` |
| `t.fill(v)` | sets every element to `v` |
| `t.strides`, `t.is_contiguous` | its layout: see [Views and layouts](views.md) |
| `t.pinned` | whether its memory is page-locked |

`print(t)` and `str(t)` show the elements, flat, and the shape:
`tensor([1.5, 7.0, 3.75], shape=(3,))`. Narrow floats are shown as the floats
they are: a `tensor[bf16, _]([0.1])` prints `tensor([0.10009765625], shape=(1,))`.

A copy is its own tensor; a write to it leaves the original as it was:

```jac
import from accel { tensor, cpu }

with entry {
    a = tensor[f32, 3]([1.5, 2.5, 3.25]);
    c = a.to(cpu());
    c[0] = 0.25;
    print(a[0], c[0], c.shape);
    b = tensor[bool, 3]([1, 0, 1]);
    print(b[0], b.tolist());
    z = tensor[f32, _](shape=3);
    z.fill(1.5);
    print(z);
}
```

```output
1.5 0.25 (3,)
True [1, 0, 1]
tensor([1.5, 1.5, 1.5], shape=(3,))
```

## Element types

Every sized int and float is an element type: `i8` to `u64`, `int`, `f16`,
`bf16`, `f32`, `float`. An element keeps its type: an item of a
`tensor[f16, _]` is an `f16`, and arithmetic on it is `f16`'s. The number types
are in [Numbers](../language/numbers.md).

The small float formats (`f8e4m3fn`, `f8e5m2`, `f4e2m1fn`) are storage formats,
and a tensor is where they are stored. An element reads as an `f32`, and a
store takes the conversion by the format's name:

```jac
import from accel { tensor }

with entry {
    q = tensor[f8e4m3fn, _]([0.1, 1.7, 300.0]);
    print(q[0], q.tolist());
    q[0] = f8e4m3fn(2.3);
    print(q[0]);
}
```

```output
0.1015625 [0.1015625, 1.75, 288.0]
2.25
```

## Tensors of structs

A tensor of a struct of plain data (one holding no reference, `E1152`) holds
its elements as C holds an array of the struct: one after another, each at the
struct's size, on whatever device the tensor is on. Structs are in
[Structs](../language/structs.md).

`tensor[P, _]([P(x=1.0), P(x=2.0)])` holds those structs, and
`tensor[P, _](shape=n, fill=P())` is `n` copies of one.

An element is reached in place, as a list's is:

| Code | Does |
|---|---|
| `t[i].x = 1.0` | writes the field of the tensor's element |
| `t[i].moved(dt)` | a method that changes `self` changes the tensor's element |
| `&mut t[i]` | lends the element |
| `t[i] = p` | copies `p` in |
| `q = t[i]` | copies the element out |

`t.tolist()` is a `list[P]` of copies, printing shows each struct, and views,
copies to a device and back, and launches move the bytes as they are.

```jac
import from accel { tensor }

struct P {
    has x: f32 = 0.0,
        y: f32 = 0.0;

    def moved(dt: f32) {
        self.x += dt;
    }
}

def raised(p: &mut P) {
    p.y += 1.0;
}

with entry {
    ps = tensor[P, _]([P(x=1.0), P(x=2.0)]);
    ps[0].x = 5.0;
    ps[1].moved(0.5);
    raised(&mut ps[1]);
    q = ps[0];
    q.y = 9.0;
    print(ps);
    print(q, ps.tolist()[1]);
}
```

```output
tensor([P(x=5.0, y=0.0), P(x=2.5, y=1.0)], shape=(2,))
P(x=5.0, y=9.0) P(x=2.5, y=1.0)
```

In ordinary code "in place" means in the program's memory. So the struct
elements of a tensor on an accelerator are reached through `t.host()`
(`RuntimeError` otherwise; see [Streams, events and copies](streams.md)). A
kernel reaches them on its device: `t[i].x += dt`, `t[i].moved(dt)` and
`t[i] = s[j]` are a kernel's too.

## What is rejected

```jac
# expect: E1233, E1152, E0033, E1234, E1235, E1001 x3, E1053
import from accel { tensor }

struct Named {
    has name: str = "";
}

def first(t: tensor[f32, _]) -> f32 {
    return t[0];
}

with entry {
    words: tensor[str, 3] | None = None;
    named = tensor[Named, 2]();
    n = 4;
    sized: tensor[f32, n] | None = None;
    less: tensor[f32, 2 - 3] | None = None;
    a = tensor[f32, 3]([1.0, 2.0, 3.0]);
    m = tensor[f32, 2, 3](fill=1.0);
    print(a[0, 1]);
    count: int = a[0];
    a[1] = "x";
    b: tensor[i32, 3] = a;
    first(m);
}
```

| Code | Line | Why |
|---|---|---|
| `E1233` | `tensor[str, 3]` | a tensor holds numbers, bools or structs of plain data |
| `E1152` | `tensor[Named, 2]` | the struct's field `name` is a str, a reference |
| `E0033` | `tensor[f32, n]` | a dimension must be known at compile time |
| `E1234` | `tensor[f32, 2 - 3]` | a dimension is not negative |
| `E1235` | `a[0, 1]` | an item of a `tensor[f32, 3]` takes 1 index |
| `E1001` | `count: int = a[0]` | an item is an `f32` |
| `E1001` | `a[1] = "x"` | a store takes the element's type |
| `E1001` | `b: tensor[i32, 3] = a` | another element type is another type |
| `E1053` | `first(m)` | a `tensor[f32, 2, 3]` is not a `tensor[f32, _]`: the rank differs |

## Differences from NumPy and Python

- The shape and the element type are part of the static type. In NumPy both are
  run-time properties of an array.
- An index is never negative. In Python and NumPy `a[-1]` is the last element;
  here it raises `IndexError`.
- `t.tolist()` is flat. In NumPy `tolist()` of a two-dimensional array is a
  list of lists; here it is one list in row-major order, and `t.shape` says how
  to read it.
- An int tensor's items are checked ints: arithmetic on them raises
  `OverflowError` where NumPy's wraps.
- There is no arithmetic on whole tensors: `a + b` is `E1110`. Elements are
  computed by [kernels](kernels.md), [parallel loops](parallel-loops.md) and
  [vectors](vectors.md).
- A tensor is not iterable: `for x in t` is `E1021`. Loop over
  `range(len(t))`, or over `t.tolist()`.
