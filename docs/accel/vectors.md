---
description: The SIMD vector type simd[T, N] - N numbers side by side - how a vector is made, its lanes, lane-wise arithmetic and its checks, masks and select, reductions, and a vector as a value.
keywords: simd, vector, mask, select, lane
---
# Vectors

A `simd[T, N]` is `N` numbers of type `T` side by side, computed together.
`T` is an int type or a float type, and `N` is a power of two from 2 to 64.
The processor computes a vector in its vector registers and an accelerator lane
by lane, with the same results.

```jac
with entry {
    a = simd[f32, 4](1.5);
    b = simd[f32, 4](1.0, 2.0, 3.0, 4.0);
    print(a + b, a * 2.0, b[2], len(b));
    m = b > 2.5;
    print(m, select(m, b, 0.0), b.sum());
}
```

```output
[2.5, 3.5, 4.5, 5.5] [3.0, 3.0, 3.0, 3.0] 3.0 4
[False, False, True, True] [0.0, 0.0, 3.0, 4.0] 10.0
```

`simd`, `select`, `join` and `interleave` are builtin: nothing is imported. A
vector is a value in every function, in ordinary code and in a
[kernel](kernels.md) alike. This page has the type, its arithmetic, masks and
reductions. [Vector methods](vector-methods.md) has the math, rounding, bit
casts and the methods that move lanes, and
[Tensor elements as vectors](vector-memory.md) has loads and stores.

## The type

`simd[T, N]`:

- `T` is an int type or a float type. Anything else is `E1410`: there is no
  vector of bools to write, and comparing vectors is what gives a mask.
- `N` is a compile-time int, a power of two from 2 to 64 (`E1411`): a literal, a
  `comptime` name or parameter, arithmetic on them, or what `target()` says.

Because `N` may be a `comptime` parameter, one function is written for every
width and compiled for each width it is called with:

```jac
import from accel { tensor }
import from jaclang.comptime { target }

def dotw[comptime W: int](a: tensor[f32, _], b: tensor[f32, _], n: int) -> f32 {
    acc = simd[f32, W](0.0);
    for k in range(0, n, W) {
        acc = a.vector(k, W).fma(b.vector(k, W), acc);
    }
    return acc.sum();
}

with entry {
    a = tensor[f32, _]([float(k % 7) for k in range(64)]);
    b = tensor[f32, _]([float(k % 5) * 0.5 for k in range(64)]);
    print(dotw[4](a, b, 64), dotw[16](a, b, 64));
    print(dotw[target().vector_bits // 32](a, b, 64));
}
```

```output
183.0 183.0
183.0
```

Each width adds its lanes in its own order, each step rounded, so a float sum
like this one can differ in its last bits from one width to another (here the
products are whole, and every width gives 183.0). At one width it is the same
on every device. An int sum is the same at every width.

`target().vector_bits` is the width in bits of the vector registers of the
processor the program is built for, so `target().vector_bits // 32` is how many
`f32` lanes one register holds. The processor's code is for any x86-64 or
aarch64 processor, where that is 128. `jac build --cpu` names a newer
processor, and `vector_bits` is then that one's width. A vector wider than the
registers is computed a register at a time. `target()` is with the compile-time
values: see `jac docs vector_bits`.

A width that is not a power of two is reported in the copy of the function that
asks for it (`E1411`), together with the call that made the copy (`E1229`):

```jac
# expect: E1411, E1229
import from accel { tensor }

def filled[comptime W: int](out: tensor[f32, _]) {
    out.store(0, simd[f32, W](1.0));
}

with entry {
    t = tensor[f32, _](shape=8);
    filled[4](t);
    filled[6](t);
}
```

## Making a vector

| Call | Gives |
|---|---|
| `simd[f32, 4](x)` | `x` in every lane |
| `simd[f32, 4](a, b, c, d)` | each number in its lane |
| `simd[i32, 4](v)`, `v` a vector of 4 lanes | each lane converted |

A literal is of the lane's type, as it is for an `f32` variable.

A conversion of a vector converts each lane as a number converts, but never
fails:

- a float made an int goes toward zero, and stops at the int type's least and
  greatest; a NaN is 0,
- an int narrowed wraps,
- a float narrowed rounds.

```jac
with entry {
    f = simd[f32, 4](1.9, -1.9, 3e10, -3e10);
    print(simd[i32, 4](f));
    print(simd[i8, 4](simd[i32, 4](300, -300, 128, 255)));
    nan = simd[f32, 4](0.0) / simd[f32, 4](0.0);
    print(simd[i32, 4](nan));
}
```

```output
[1, -1, 2147483647, -2147483648]
[44, -44, -128, -1]
[0, 0, 0, 0]
```

## Lanes

`v[i]` is lane `i`, a number of the lane's type, and `v[i] = x` sets a lane in
place. `len(v)` is `N`. A literal lane outside the vector is a compile error
(`E1412`); any other index is checked when the program runs (`IndexError:
vector index out of range`).

## Arithmetic

`+`, `-`, `*` and `/` work lane by lane. The operands are two vectors of one
type, or a vector and a number of its element type, which stands in every lane.
Any other pair is `E1128`: vectors of two lengths, or of two element types.

Of int vectors, `//`, `%`, `&`, `|`, `^`, `<<`, `>>`, unary `-` and `~` work
lane by lane too (`//` floors and `%` takes the divisor's sign, as an int's
do: `-7 // -3` is 2 and `-7 % -3` is -1), and so do the wrapping and saturating operators: `+%`, `-%`,
`*%` and unary `-%` wrap each lane, and `+|`, `-|`, `*|` stop each lane at its
type's least and greatest (see [Numbers](../language/numbers.md)).

```jac
with entry {
    i = simd[i32, 4](7, -7, 100, 0);
    print(i + 1, i // 2, i % 3, i << 1, -i, ~i);
    print(i / 2);
    s = simd[i8, 4](100, -100, 127, -128);
    print(s +% 100, s +| 100, s *| 2, -%s);
}
```

```output
[8, -6, 101, 1] [3, -4, 50, 0] [1, 2, 1, 0] [14, -14, 200, 0] [-7, 7, -100, 0] [-8, 6, -101, -1]
[3.5, -3.5, 50.0, 0.0]
[-56, 0, -29, -28] [127, 0, 127, -28] [127, -128, 127, -128] [-100, 100, -127, -128]
```

### Checks

Int lanes are checked as an int is.

| What | Raises |
|---|---|
| a lane that overflows in `+`, `-`, `*`, unary `-`, `v.abs()`, or `//` of the least int by -1 | `OverflowError` |
| a shift that loses a lane's bits, or counts past its width | `OverflowError` |
| `//` or `%` by a zero lane | `ZeroDivisionError` |
| an int vector divided with `/` by a zero lane | `ZeroDivisionError` |

An int vector divided with `/` gives a vector of `float`s, as two ints do.

A float lane divided by zero is IEEE's infinity or NaN. A lone float divided by
zero raises; a vector's lane does not.

```jac
with entry {
    i = simd[i32, 4](7, -7, 2147483647, -2147483648);
    try {
        print(i + 1);
    } except OverflowError as e {
        print("OverflowError:", e);
    }
    try {
        print(i % simd[i32, 4](1, 0, 1, 1));
    } except ZeroDivisionError as e {
        print("ZeroDivisionError:", e);
    }
    print(i +% 1);
    print(simd[f32, 4](1.0, -1.0, 0.0, 2.0) / 0.0);
}
```

```output
OverflowError: integer overflow
ZeroDivisionError: division by zero
[8, -6, -2147483648, -2147483647]
[inf, -inf, nan, inf]
```

In a kernel the same checks record a fault instead of raising, and the launch
raises it when the kernel is done (see [Kernels](kernels.md)).

## Masks

A comparison of vectors, or of a vector and a number, gives a mask: one bool for
each lane. Its type is `simd[bool, N]`, a type a program does not write.

- `m.all()` and `m.any()` are a bool: whether every lane is true, or any is.
- `m & n`, `m | n`, `m ^ n` and `~m` combine masks lane by lane.
- `select(m, a, b)` is a vector: `a`'s lane where `m`'s is true, and `b`'s
  elsewhere. Either of `a` and `b` may be a number.
- `m.count()` is how many lanes are true.
- `m.first()` is the index of the first true lane, and `N` when none is.
- `simd[i32, N](m)` is 1 where `m` is true and 0 elsewhere.

`==` of two vectors compares lane by lane and gives a mask, not a bool.

A vector is not a condition, and neither is a mask: `if m` is `E1053`. Write
`if m.any()` or `if m.all()`.

```jac
with entry {
    b = simd[f32, 4](10.0, 2.0, 3.0, 5.0);
    m = b > 3.0;
    print(m, m.all(), m.any(), m.count(), m.first());
    print(~m, m & (b < 6.0), (b > 100.0).first());
    print(select(m, b, 0.0), select(m, 1.0, b));
    if (b == b).all() {
        print("equal in every lane");
    }
}
```

```output
[True, False, False, True] False True 2 0
[False, True, True, False] [False, False, False, True] 4
[10.0, 0.0, 0.0, 5.0] [1.0, 2.0, 3.0, 1.0]
equal in every lane
```

## Reductions

`v.sum()`, `v.product()`, `v.min()` and `v.max()` reduce the lanes to one
number, in lane order, so a result is the same on every device.

- A float sum starts from -0.0 and adds lane 0 first. Each addition rounds, so
  the order matters, and it is fixed.
- An int vector's sum and product are exact: an intermediate that leaves the
  lane's type is no error. They raise `OverflowError` only where the lane's
  type does not hold the result.
- `min` and `max` take a lane only where it is strictly less or more, as
  `min()` and `max()` of numbers do.

```jac
with entry {
    big = simd[f32, 4](100000000.0, 1.0, -100000000.0, 1.0);
    print(big.sum());
    i = simd[i32, 4](2147483647, 1, -1, 0);
    print(i.sum(), i.min(), i.max());
    b = simd[f32, 4](10.0, 2.0, 3.0, 5.0);
    print(b.sum(), b.product(), b.min(), b.max());
}
```

```output
1.0
2147483647 -1 2147483647
20.0 300.0 2.0 10.0
```

## A vector is a value

A vector is held in place, as a struct is (see
[Structs](../language/structs.md)): as a local, a parameter, a result, a field
of a struct or an obj, a global. Assigning one, passing it and returning it
copies it.

- In ordinary code a vector computes as in a kernel: the same operations and
  the same results. A check raises (`OverflowError`, `ZeroDivisionError`,
  `IndexError`) where a kernel records a fault.
- It prints as a list of its lanes does: `[1.0, 2.0, 3.0, 4.0]`.
- It boxes into an `any` as that list, and `x as simd[f32, 4]` makes a vector of
  it again (`ValueError` for a list of another length).
- A launch passes a vector as a copy of its lanes.
- A list holds vectors packed (see
  [Packed lists](../language/packed-lists.md)). A set or a dict holds each as a
  copy of its own, as it holds an [array](arrays.md): `d[k]` is the entry's
  place, and what is read out is a copy.
- A cpython or JavaScript space provides no values held in place, vectors among
  them (`E1540`).

```jac
struct Ray {
    has dir: simd[f32, 4],
        t: f32 = 0.0;
}

def scaled(v: simd[f32, 4], k: f32) -> simd[f32, 4] {
    return v * k;
}

with entry {
    r = Ray(dir=simd[f32, 4](1.0, 2.0, 3.0, 4.0));
    c = r;
    c.dir[0] = 9.0;
    print(r, c.dir, scaled(r.dir, 2.0));
    d = {"a": r.dir};
    d["a"][0] = 5.0;
    x: any = r.dir;
    print(d, x, (x as simd[f32, 4]).sum());
}
```

```output
Ray(dir=[1.0, 2.0, 3.0, 4.0], t=0.0) [9.0, 2.0, 3.0, 4.0] [2.0, 4.0, 6.0, 8.0]
{'a': [5.0, 2.0, 3.0, 4.0]} [1.0, 2.0, 3.0, 4.0] 10.0
```

## What is rejected

```jac
# expect: E1411, E1410, E1128 x2, E1412, E1053 x2, E1110, E1010
with entry {
    a = simd[f32, 4](1.0);
    odd = simd[f32, 3](1.0);
    flags = simd[bool, 4](True);
    wide = a + simd[f32, 8](1.0);
    mixed = a * simd[i32, 4](1);
    x = a[4];
    y = select(a, a, a);
    if a > 0.5 {
        print("positive");
    }
    z = a +| a;
    w = -%a;
}
```

- `E1411`, `simd[f32, 3]`: a vector's length is a power of two from 2 to 64.
- `E1410`, `simd[bool, 4]`: a vector's lanes are numbers.
- `E1128`, `a + simd[f32, 8](1.0)`: two lengths.
- `E1128`, `a * simd[i32, 4](1)`: two element types. Convert one side.
- `E1412`, `a[4]`: a literal lane outside the vector.
- `E1053`, `select(a, a, a)`: `select` chooses by a mask.
- `E1053`, `if a > 0.5`: a mask is not a condition.
- `E1110`, `a +| a`: the saturating operators are of int lanes.
- `E1010`, `-%a`: so are the wrapping ones.
