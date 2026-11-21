---
description: The fixed-size array type array[T, N], a value held in place, and the other values a kernel holds in place - plain structs and 128-bit ints - including a tensor over an array of the kernel's own.
keywords: array, fixed-size array, values held in place, stack tensor
---
# Arrays and values held in place

An `array[T, N]` is `N` values of type `T`, held in place as C holds an array:
no heap, no reference. It is a value in every function, and one of the values a
[kernel](kernels.md) holds in place, besides numbers and
[vectors](vectors.md):

- `array[T, N]`
- a `struct` of plain data ([Structs](../language/structs.md))
- `i128` and `u128` ([128-bit ints](../language/numbers-128.md))

```jac
import from accel { tensor, kernel }

struct V3 {
    has x: f32 = 0.0,
        y: f32 = 0.0,
        z: f32 = 0.0;
}

def add(a: V3, b: V3) -> V3 {
    return V3(x=a.x + b.x, y=a.y + b.y, z=a.z + b.z);
}

def mulhi(a: u64, b: u64) -> u64 {
    return u64((u128(a) * u128(b)) >> 64);
}

def blur(i: int, x: tensor[f32, _], out: tensor[f32, _], hi: tensor[u64, _]) {
    w = array[f32, 3](0.25, 0.5, 0.25);
    s = f32(0.0);
    for k in range(len(w)) {
        s += w[k] * x[i + k];
    }
    v = add(V3(x=s), V3(x=1.0));
    out[i] = v.x;
    hi[i] = mulhi(u64(i + 1) << 40, u64(1) << 40);
}

with entry {
    x = tensor[f32, _]([1.0, 2.0, 4.0, 8.0, 16.0]);
    out = tensor[f32, _](shape=3);
    hi = tensor[u64, _](shape=3);
    kernel(blur).run(3, x, out, hi);
    print(out.tolist(), hi.tolist());
    print(add(V3(x=1.0), V3(y=2.0)), mulhi(u64(1) << 63, u64(4)));
}
```

```output
[3.25, 5.5, 10.0] [65536, 131072, 196608]
V3(x=1.0, y=2.0, z=0.0) 2
```

The same functions run in the kernel and in ordinary code.

## The array type

`array[T, N]`:

- `T` is a number type, a struct of plain data, or another array (`E1420`).
- `N` is a compile-time int above 0 (`E1421`): a literal, a `comptime` name, or
  arithmetic on them, as a tensor's dimension is. A run-time value is `E0033`.

| Call | Gives |
|---|---|
| `array[f32, 4]()` | four zeros. Every number in it is 0, a struct's fields too |
| `array[f32, 4](x)` | `x` in every element |
| `array[f32, 4](a, b, c, d)` | each value in its place. Another count is `E1235` |

`a[i]` reads an element. `a[i] = v`, `a[i][j] = v` and `a[i].x += v` write one
in place. `len(a)` is `N`, and `for i in range(len(a))` is the loop over one
that works everywhere.

A literal index outside the array is a compile error (`E1412`). Any other index
is checked when the program runs (`IndexError`), and a negative one is out of
range, as in a tensor.

```jac
struct V2 {
    has x: f32 = 0.0,
        y: f32 = 0.0;
}

with entry {
    zeros = array[f32, 4]();
    ones = array[f32, 4](1.5);
    each = array[i32, 3](1, 2, 3);
    each[1] = 20;
    m = array[array[int, 2], 2](array[int, 2](1, 2));
    m[1][1] = 9;
    vs = array[V2, 2](V2(x=1.0), V2(y=2.0));
    vs[1].x += 2.0;
    print(zeros, ones, each, len(each));
    print(m, vs);
    for bad in [3, -1] {
        try {
            print(each[bad]);
        } except IndexError as e {
            print("IndexError:", e);
        }
    }
}
```

```output
[0.0, 0.0, 0.0, 0.0] [1.5, 1.5, 1.5, 1.5] [1, 20, 3] 3
[[1, 2], [1, 9]] [V2(x=1.0, y=0.0), V2(x=2.0, y=2.0)]
IndexError: array index out of range
IndexError: array index out of range
```

## A value, copied where it goes

An array, a struct and a 128-bit int are each a value, in any function, as a
field of a struct or an obj, and as a global. Assigning one, passing it and
returning it copies it, so a change to the copy leaves the original as it was.
An element or a field is written in place: `a[i] = v`, `m[i][j] += 1`,
`ps[k].x = 0.0`. Writing an element of a temporary copy, as in `f()[0] = v`,
would change nothing, and is `E1504`.

In ordinary code an array also:

- iterates: `for x in a` gives its elements in order,
- compares: `a == b` and `a != b` of two arrays of one type, element by element.
  Any other comparison is `E1110`,
- prints as a list of its elements does, by `str`, `repr` and f-strings:
  `[0.25, 0.5, 0.25]`,
- boxes into an `any` as such a list, and `x as array[f32, 3]` makes an array of
  it again. A list of another length is `ValueError`, and an int an element
  cannot hold is `OverflowError`.

```jac
def twice(a: array[int, 2]) -> array[int, 2] {
    a[0] *= 2;
    a[1] *= 2;
    return a;
}

with entry {
    a = array[int, 2](1, 2);
    b = a;
    b[0] = 99;
    print(a, b, twice(a), a);
    total = 0;
    for x in a {
        total += x;
    }
    print(total, a == array[int, 2](1, 2), a != b, f"{a}");
    boxed: any = a;
    back = boxed as array[int, 2];
    print(boxed, back);
    try {
        short = boxed as array[int, 3];
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
[1, 2] [99, 2] [2, 4] [1, 2]
3 True True [1, 2]
[1, 2] [1, 2]
ValueError: expected 3 items, found 2
```

## In containers, frames and closures

- A list holds arrays, vectors and 128-bit ints packed (see
  [Packed lists](../language/packed-lists.md)).
- A set or a dict holds each array, vector or 128-bit int as a box of a copy of
  its own, as it holds a struct. `d[k]` is the entry's place: `d[k][j] = v`
  writes the entry. What is read out is a copy: a variable, a loop's target,
  `list(d.values())`, `d.copy()`, `{**d}`, an `any`.
- A key or a member is hashed and compared by its elements, and a 128-bit int
  as the int it holds. An array holding a NaN equals nothing, so it is never
  found.
- An array arriving from an `any` is converted to the element type, of the
  array's length.
- An iterator holds no array yet: `iter([array[f32, 2]()])` is `E5090`.

As a struct is, each of these values is held by a generator's or an async
function's frame across its yields and awaits, by the cell of a variable a
nested function captures, by a tuple (as an `any` holds it, read back as a
copy), and by a function value's parameters and result. Each is a copy where it
goes.

```jac
def steps(a: array[int, 2]) -> Iterator[int] {
    for i in range(len(a)) {
        yield a[i];
        a[i] += 100;
        yield a[i];
    }
}

with entry {
    a = array[int, 2](1, 2);
    print(list(steps(a)), a);
    d = {"k": a};
    d["k"][1] = 20;
    got = d["k"];
    got[0] = -1;
    print(d, got, a);
    t = (a, 5);
    b = t[0];
    b[0] = 99;
    print(t, b);
    nan = float("nan");
    seen = {array[float, 2](nan, 1.0): 1};
    print(array[float, 2](nan, 1.0) in seen);
}
```

```output
[1, 101, 2, 102] [1, 2]
{'k': [1, 20]} [-1, 20] [1, 2]
([1, 2], 5) [99, 2]
False
```

## In a kernel

A kernel holds these values in place, on the processor and on an accelerator:

- **Arrays**, of numbers, of plain structs, and of arrays.
- **Plain structs**: a `struct` whose fields are numbers of 64 bits or fewer and
  such structs, each default a literal (or `P()` of literals). A kernel holds
  one in place, as ordinary code holds it, so a function over structs runs in
  ordinary code and in kernels alike. So does a plain struct's method: one that
  changes `self` changes the place it is called on, a kernel's local or
  parameter or a field of one. A struct with an array or a 128-bit field is not
  held by a kernel yet (`E5090`).
- **128-bit ints**, with their arithmetic. A kernel converts none to or from a
  float (`E1540`): no CUDA device has an instruction for it.

A kernel holds no `obj`: an `obj` is a counted reference made on a heap, which a
device lacks (`E1540`).

A launch takes structs, nested ones too, arrays and 128-bit ints as arguments.
Each launch passes the kernel a copy of the value it is given, the kernel's own
to change. A `flow for` over tensors does the same with the values it captures
(see [Parallel loops over tensors](parallel-loops.md)). Arrays of structs are a
kernel's too, and so are tensors of them (see [Tensors](tensors.md)).

```jac
import from accel { tensor, kernel }

struct Clamp {
    has lo: f32 = 0.0,
        hi: f32 = 1.0;

    def apply(v: f32) -> f32 {
        return min(max(v, self.lo), self.hi);
    }

    def widen(d: f32) {
        self.lo -= d;
        self.hi += d;
    }
}

def clamped(i: int, c: Clamp, w: array[f32, 2], big: u128, y: tensor[f32, _]) {
    c.widen(1.0);
    y[i] = c.apply(y[i]) + w[i % 2] + f32(u64(big >> 100));
}

with entry {
    y = tensor[f32, _]([-5.0, 0.5, 2.5, 9.0]);
    c = Clamp(lo=0.0, hi=2.0);
    kernel(clamped).run(4, c, array[f32, 2](0.0, 100.0), u128(3) << 100, y);
    print(y.tolist(), c.lo, c.hi);
}
```

```output
[2.0, 103.5, 5.5, 106.0] 0.0 2.0
```

## A tensor over an array

In a kernel, `tensor[f32, 4, 4](view=a)` of an array local `a` is a tensor over
the array's memory. Its dimensions are all known, and it has as many elements as
the array, of the array's element type (`E1235` otherwise). Its items,
`t.vector(...)` and `t.store(...)` read and write the array in place, and it is
passed to another kernel function as any tensor is. A local is bound to one
once.

It is a kernel's alone: run in ordinary code, it raises `RuntimeError`.

```jac
import from accel { tensor, kernel }

def row_sums(t: tensor[f32, 4, 4], out: tensor[f32, _]) {
    for r in range(4) {
        out[r] = t.vector(r, 0, 4).sum();
    }
}

def stacked(i: int, out: tensor[f32, _]) {
    a = array[f32, 16]();
    t = tensor[f32, 4, 4](view=a);
    for r in range(4) {
        for c in range(4) {
            t[r, c] = f32(r * 4 + c) * 0.5;
        }
    }
    a[15] = 100.0;
    row_sums(t, out);
    out[4] = a[6];
}

with entry {
    out = tensor[f32, _](shape=5);
    kernel(stacked).run(1, out);
    print(out.tolist());
    try {
        stacked(0, out);
    } except RuntimeError as e {
        print("RuntimeError:", e);
    }
}
```

```output
[3.0, 11.0, 19.0, 119.5, 3.0]
RuntimeError: a tensor over an array is a kernel's: it runs where a kernel calls it
```

## In a cpython or JavaScript space

A cpython or JavaScript space holds an array as a list of its elements of its
own, and the same value: copied where native code copies one, an element read
and written at an index of the array's alone (`IndexError` for a negative one),
compared and hashed by its elements, printed as a list, boxed into an `any` as a
list and made again of one (`ValueError` for another length, `OverflowError` for
a sized int out of its element type's range).

Such a space holds a 128-bit int as its host's int, a Python int or a JavaScript
BigInt, checked against its type's range as natively.

It has no vectors and no narrow floats, nor arrays of them (`E1540`; see
[What code needs from the place it runs](requirements.md)).

## What is rejected

```jac
# expect: E1235, E1412, E1420, E1421, E0033, E1504, E1110, E5090
def pair -> array[f32, 2] {
    return array[f32, 2](1.0, 2.0);
}

with entry {
    a = array[f32, 4]();
    b = array[f32, 3](1.0, 2.0);
    c = a[4];
    s = array[simd[f32, 4], 2]();
    z = array[f32, 0]();
    n = 3;
    r = array[f32, n]();
    pair()[0] = 3.0;
    lt = a < a;
    im = iter([array[f32, 2]()]);
}
```

| Code | Line | Why |
|---|---|---|
| `E1235` | `array[f32, 3](1.0, 2.0)` | an array is made of no value, one value, or as many as it holds |
| `E1412` | `a[4]` | a literal index outside the array |
| `E1420` | `array[simd[f32, 4], 2]` | an array holds numbers, structs of plain data or arrays |
| `E1421` | `array[f32, 0]` | an array holds at least one element |
| `E0033` | `array[f32, n]` | the length is a compile-time int |
| `E1504` | `pair()[0] = 3.0` | the call's result is a temporary copy |
| `E1110` | `a < a` | arrays compare with `==` and `!=` alone |
| `E5090` | `iter(...)` | an iterator holds no array yet |
