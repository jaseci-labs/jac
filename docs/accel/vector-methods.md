---
description: The methods of a simd vector - fma, sqrt and abs, math functions lane by lane, rounding and clamping, bit casts, and the methods and functions that move lanes (reversed, rotated, shuffled, slice, insert, join, interleave).
keywords: fma, clamp, as_bits, as_float, as_signed, rotated, shuffled, join, interleave, vector math, vector methods
---
# Vector methods

The methods of a [vector](vectors.md), `simd[T, N]`. Each gives a new vector or
a number; none changes the vector it is called on. They work the same in
ordinary code and in a [kernel](kernels.md).

## Lane by lane: fma, sqrt, abs, min, max

| Method | Gives, in each lane |
|---|---|
| `v.fma(b, c)` | `v * b + c` rounded once. Of floats |
| `v.sqrt()` | the square root. Of floats |
| `v.abs()` | the absolute value. Of an int vector it is checked: the least int has none (`OverflowError`) |
| `v.min(w)`, `v.max(w)` | the lesser or greater of the two lanes |

`b`, `c` and `w` are vectors of `v`'s type, or numbers of its lane's type.
`v.min()` and `v.max()` with no argument are reductions: see
[Vectors](vectors.md).

`fma` is computed in software on a processor without the instruction. The
baseline x86-64 processor that jac compiles for is one, so there `fma` is
several times slower than `*` and `+`. `jac build --cpu` names a processor
that has it.

```jac
with entry {
    a = simd[f32, 4](1.5);
    b = simd[f32, 4](10.0, 2.0, 3.0, 5.0);
    print(b.fma(a, 1.0), b.sqrt());
    print((-b).abs(), b.min(a), b.max(3.0));
}
```

```output
[16.0, 4.0, 5.5, 8.5] [3.1622777, 1.4142135, 1.7320508, 2.236068]
[10.0, 2.0, 3.0, 5.0] [1.5, 1.5, 1.5, 1.5] [10.0, 3.0, 3.0, 5.0]
```

## Math

These compute `math`'s function of the same name in each lane:

`v.exp()`, `v.expm1()`, `v.log()`, `v.log1p()`, `v.log2()`, `v.log10()`,
`v.sin()`, `v.cos()`, `v.tan()`, `v.tanh()`, `v.sinh()`, `v.cosh()`,
`v.atan()`, `v.asin()`, `v.acos()`, `v.atan2(w)`, `v.pow(w)`, `v.hypot(w)`.

`w` is a vector of the same type, or a number of its lane's type.

Each lane is computed by the routine a kernel computes a number of the lane's
type with (see [A kernel's math](kernel-math.md)). So each lane is bit for bit
what the scalar call gives in a kernel, on every device and in ordinary code,
and it follows IEEE as a kernel's math does: a lane's `log(-1.0)` is a NaN, and
nothing raises.

Which methods a vector has depends on its lanes:

| Lanes | Math methods |
|---|---|
| `float` (`f64`) | all of them |
| `f32` | the ones with an `f32` form: `exp`, `expm1`, `log`, `sin`, `cos`, `tanh`, `pow`. Any other is `E1431` |
| `f16`, `bf16` | none (`E1431`) |
| an int type | none: an int vector has no such method (`E1030`) |

Where a vector has no form, convert it to floats: `simd[float, N](v)`.

```jac
import math;

with entry {
    v = simd[f32, 4](0.5, 1.0, 2.0, -1.0);
    print(v.exp(), v.log());
    print(v.exp()[0] == math.exp(f32(0.5)));
    print(simd[float, 4](v).tan());
}
```

```output
[1.6487212, 2.7182817, 7.389056, 0.36787945] [-0.6931472, 0.0, 0.6931472, nan]
True
[0.5463024898437905, 1.5574077246549023, -2.185039863261519, -1.5574077246549023]
```

```jac
# expect: E1431 x2, E1030
def lanes_math(v: simd[f32, 4], h: simd[f16, 4], n: simd[int, 4]) {
    t = v.tan();
    e = h.exp();
    m = n.exp();
}
```

## Rounding and clamping

| Method | Gives, in each lane |
|---|---|
| `v.round()` | the nearest whole number, a half going to the even one, as `round()` does |
| `v.floor()`, `v.ceil()`, `v.trunc()` | rounded down, up, or toward zero |
| `v.clamp(lo, hi)` | `v.max(lo).min(hi)` |

The rounding methods are of float vectors, and give float vectors. `clamp` is of
int vectors too; `lo` and `hi` are vectors or numbers.

```jac
with entry {
    r = simd[f32, 4](0.5, 1.5, -2.7, 100.25);
    print(r.round(), r.floor(), r.ceil(), r.trunc());
    print(r.clamp(-1.0, 2.0), simd[i32, 4](-10, 0, 4, 100).clamp(-3, 5));
}
```

```output
[0.0, 2.0, -3.0, 100.0] [0.0, 1.0, -3.0, 100.0] [1.0, 2.0, -2.0, 101.0] [0.0, 1.0, -2.0, 100.0]
[0.5, 1.5, -1.0, 2.0] [-3, 0, 4, 5]
```

## Bit casts

A bit cast gives the vector's bits seen as another type of the same lane width.
The number of lanes stays the same.

| Method | Of | Gives |
|---|---|---|
| `v.as_bits()` | floats and signed ints | unsigned ints of the lane's width |
| `v.as_float()` | 32- and 64-bit ints | floats of the lane's width |
| `v.as_signed()` | floats and unsigned ints | signed ints of the lane's width |

Any other is `E1445`. `as_float()` is not offered of 16-bit ints, because 16
bits are both `f16`'s and `bf16`'s. A cast that changes the number of lanes is
not offered.

```jac
with entry {
    b = simd[f32, 4](1.0, -2.0, 0.5, 0.0);
    print(b.as_bits(), b.as_signed());
    print(b.as_bits().as_float(), simd[f16, 2](1.0, -2.0).as_bits());
}
```

```output
[1065353216, 3221225472, 1056964608, 0] [1065353216, -1073741824, 1056964608, 0]
[1.0, -2.0, 0.5, 0.0] [15360, 49152]
```

## Moving lanes

| Method or function | Gives |
|---|---|
| `v.reversed()` | the lanes in reverse order |
| `v.rotated(k)` | lane `i` is `v`'s lane `(i + k) % N`. `k` may be negative |
| `v.shuffled(i0, ..., iN-1)` | lane `k` is `v`'s lane `ik`. It takes `N` lane numbers, one for each lane |
| `v.low()`, `v.high()` | the first half of the lanes, and the second |
| `v.even()`, `v.odd()` | lanes 0, 2, ... and lanes 1, 3, ... |
| `v.slice(start, M)` | `M` lanes from `start` |
| `v.insert(start, w)` | `v` with `w`'s lanes from `start` |
| `join(a, b)` | `a`'s lanes, then `b`'s |
| `interleave(a, b)` | `a0, b0, a1, b1, ...` |

Every count and lane number one of these takes is a compile-time int (`E0033`
for a run-time value), and a lane outside the vector is `E1412`. A result of more than 64 lanes is `E1413`.

```jac
with entry {
    w = simd[i32, 8](10, 11, 12, 13, 14, 15, 16, 17);
    print(w.reversed(), w.rotated(3));
    print(w.shuffled(7, 0, 7, 0, 1, 2, 3, 3));
    print(w.low(), w.high(), w.even(), w.odd());
    print(w.slice(2, 4), w.insert(5, simd[i32, 2](0, -1)));
    print(join(w.high(), w.low()), interleave(w.low(), w.high()));
}
```

```output
[17, 16, 15, 14, 13, 12, 11, 10] [13, 14, 15, 16, 17, 10, 11, 12]
[17, 10, 17, 10, 11, 12, 13, 13]
[10, 11, 12, 13] [14, 15, 16, 17] [10, 12, 14, 16] [11, 13, 15, 17]
[12, 13, 14, 15] [10, 11, 12, 13, 14, 0, -1, 17]
[14, 15, 16, 17, 10, 11, 12, 13] [10, 14, 11, 15, 12, 16, 13, 17]
```

## What is rejected

```jac
# expect: E1412, E1413, E1445, E1030
with entry {
    v = simd[f32, 4](1.0);
    a = v.slice(2, 4);
    b = interleave(simd[f32, 64](0.0), simd[f32, 64](0.0));
    c = simd[f16, 4](1.0).as_bits().as_float();
    n = simd[i32, 4](1);
    d = n.adds(n);
}
```

- `E1412`, `v.slice(2, 4)`: 4 lanes from lane 2 reach past the vector's 4.
- `E1413`, `interleave(...)`: the result would have 128 lanes.
- `E1445`, `.as_float()`: of 16-bit lanes.
- `E1030`, `n.adds(n)`: there are no saturating methods. The saturating
  operators `+|`, `-|` and `*|` are what a vector has.
