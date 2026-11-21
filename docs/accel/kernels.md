---
description: Kernels - functions launched over tensors with kernel(f).run(count, ...) - what a kernel's code may do, how its failures are reported, and the random numbers it can make.
keywords: kernel, kernel run, kernel fault, philox, philox_unit, launch arguments
---
# Kernels

A kernel is a function launched over [tensors](tensors.md). `kernel(f)` names a
function of the program as a kernel, and `k.run(count, a, b, ...)` calls
`f(i, a, b, ...)` for each index `i` below `count`, on the
[device](devices.md) the tensors live on.

```jac
import from accel { tensor, kernel }

def saxpy(i: int, a: f32, x: tensor[f32, _], y: tensor[f32, _]) {
    y[i] = a * x[i] + y[i];
}

with entry {
    x = tensor[f32, _]([1.0, 2.0, 3.0, 4.0]);
    y = tensor[f32, _](shape=4, fill=0.5);
    kernel(saxpy).run(4, 2.0, x, y);
    print(y.tolist());
}
```

```output
[2.5, 4.5, 6.5, 8.5]
```

The calls are made in no promised order, and possibly at once. So a kernel
writes only through the index it is called for: `y[i]`, not `y[i + 1]`. The
compiler does not check this for a named kernel. It does for a `flow for` over
tensors, which is a kernel without the name: see
[Parallel loops over tensors](parallel-loops.md).

## Launching

`kernel(f)` takes a function of the program by its name (`E1409`): not a
variable holding one, and not a lambda. It is compiled away to the kernel's
record; it does not call `f`.

A kernel has these methods:

| Method | Does |
|---|---|
| `k.run(count, a, b, ...)` | calls `f(i, a, b, ...)` for each `i` below `count`, and returns when every call has. A `count` of 0 or less runs nothing |
| `k.begin(count, a, b, ...)` | `run`, not waited for: see [Streams, events and copies](streams.md) |
| `k.launch(grid, block, a, b, ...)` | launches `f` over a grid of blocks of threads on an accelerator: see [Grid kernels](grid-kernels.md) |
| `k.begin_launch(grid, block, a, b, ...)` | `launch`, not waited for |
| `k.compile(dev)` | loads the program's code on `dev` ahead of the first launch: see [Devices](devices.md) |
| `k.code("cuda")` | the program's code for a kind of device, as text: see [Devices](devices.md) |

For `run` and `begin`, the function's first parameter is the `int` index it
runs for (`E1418`). The arguments are checked against the function's remaining
parameters where the call is written: their count (`E1235`) and each one's type
(`E1053`). They are passed by position.

Each launch method also takes two keyword arguments after the kernel's own:

| Argument | Meaning |
|---|---|
| `stream=s` | queue the launch on a `Stream`: see [Streams, events and copies](streams.md) |
| `print_buffer=n` | the bytes of the buffer the kernel's `print` calls write to: see [Printing from a kernel](kernel-printing.md) |

A kernel's type names its function, and is written `kernel[int, f32,
tensor[f32, _]]` in diagnostics. A local has one type, so a variable holding
`kernel(f)` cannot be rebound to `kernel(g)`, even of the same signature
(`E1452`).

## Arguments

A launch passes numbers, tensors, and values held in place: structs of plain
data (nested ones too), [arrays](arrays.md), [vectors](vectors.md) and 128-bit
ints. A tensor is passed as itself: the kernel reads and writes its memory. Each
other argument is a copy of the value the launch is given, the kernel's own to
change. An `obj`, a list, a str or any other reference is not passed (`E1540`):
see [What crosses into a place](crossing.md).

```jac
import from accel { tensor, kernel }

struct Affine {
    has a: f32 = 1.0,
        b: f64 = 0.0;
}

def affine(i: int, p: Affine, x: tensor[f32, _], y: tensor[f32, _]) {
    y[i] = p.a * x[i] + f32(p.b);
    p.a = 0.0;
}

with entry {
    x = tensor[f32, _]([0.0, 1.0, 2.0, 3.0]);
    y = tensor[f32, _](shape=4);
    p = Affine(a=2.0, b=0.5);
    kernel(affine).run(4, p, x, y);
    print(y.tolist(), p.a);
}
```

```output
[0.5, 2.5, 4.5, 6.5] 2.0
```

The kernel's `p.a = 0.0` changes its own copy: the program's `p` is unchanged,
and every index starts from the value the launch was given.

## What a kernel's code may do

A kernel, and every function it calls, is compiled apart from the rest of the
program, as typed code with no runtime. In it an `i32` is 32 bits and an `f32`
is a 32-bit float; a loop over it vectorizes.

It runs in a kernel's place, which provides nothing a device lacks (`E1540`;
see [What code needs from the place it runs](requirements.md)): no heap, no
str, no exception, and no global except a `comptime` one. What the place
provides but the kernel backend does not lower yet is `E5090`.

A kernel's code may use:

- numbers of every type, bools, vectors, arrays and structs of plain data
- the tensors it is given, their items and [views](views.md), and `len` of a
  tensor; a tensor it makes over an array of its own ([Arrays](arrays.md))
- arithmetic and comparison of numbers, `and`, `or`, `not`, a conditional
  expression
- `if`, `while`, and `for` over a `range`
- conversions by a type's name: `f32(x)`, `int(x)`, `u64(x)`. A float converted to an int
  truncates toward zero, as in ordinary code: `u64(1.5)` is 1 and `u64(-0.5)` is 0
- a sized int's least value as a negated literal: `x: i32 = -2147483648`, `y: i8 = -128`
- `abs`, and `min` and `max` of two numbers
- an int's own operations: the wrapping and saturating operators (`+%`, `*|`
  and the rest), `popcount`, `clz`, `ctz`, `rotl`, `rotr`, `bswap`, `bitrev`
  (see [Numbers](../language/numbers.md))
- a sized type's `MIN` and `MAX`
- a float's bits, as in ordinary code: `__float_bits(x)` is a `float`'s IEEE
  binary64 bits as an int, `__f32_bits(x)` an `f32`'s binary32 bits as a `u32`,
  and `__bits_float(b)` and `__bits_f32(b)` are the floats of bits
- a `comptime` global, and the items of a `comptime` global list of numbers: a
  table the compiler computed, declared `comptime T: list[int] = [...]` and read
  as `T[i]`, each index checked
- `math`'s functions: see [A kernel's math](kernel-math.md)
- `accel`'s `philox` and `philox_unit` (below), and its atomics and `fence()`
  ([Grid kernels](grid-kernels.md))
- `print`, for debugging: see [Printing from a kernel](kernel-printing.md)
- calls of functions that keep to the same

A kernel's function is an ordinary function too. Ordinary code may call it
directly, with an index, and it computes the same values.

```jac
import from accel { tensor, kernel }

comptime WEIGHTS: list[int] = [1, 3, 5, 7];

comptime GAIN: f32 = 0.5;

def half(x: f32) -> f32 {
    return x * GAIN;
}

def work(i: int, x: tensor[f32, _], y: tensor[f32, _], n: tensor[int, _]) {
    v = half(x[i]);
    k = 0;
    while k < 3 {
        v += 1.0;
        k += 1;
    }
    y[i] = abs(v) if v < 5.0 else f32(i32.MAX);
    n[i] = WEIGHTS[i % 4] + popcount(i) + len(x);
}

with entry {
    x = tensor[f32, _]([1.0, 2.0, 3.0, 4.0]);
    y = tensor[f32, _](shape=4);
    n = tensor[int, _](shape=4);
    kernel(work).run(4, x, y, n);
    print(y.tolist(), n.tolist());
    work(0, x, y, n);
    print(y[0], n[0]);
}
```

```output
[3.5, 4.0, 4.5, 2147483648.0] [5, 8, 10, 13]
3.5 5
```

What a kernel refuses:

```jac
# expect: E1540 x3, E5090 x2
import from accel { tensor, kernel }

glob scale: float = 2.0;

def bad(i: int, y: tensor[f32, _], m: tensor[f32, _, _]) {
    xs = [1, 2, 3];
    y[i] = f32(scale);
    if y[i] < 0 {
        raise ValueError("negative");
    }
    y[i] = y[i] ** 2;
    for v in array[f32, 2](1.0, 2.0) {
        y[i] += v;
    }
}

with entry {
    kernel(bad).run(4, tensor[f32, _](shape=4), tensor[f32, _, _](shape=(2, 2)));
}
```

| Code | Line | Why |
|---|---|---|
| `E1540` | `xs = [1, 2, 3]` | a list needs counted references |
| `E1540` | `f32(scale)` | a global that is not `comptime` is module state that can change |
| `E1540` | `raise` | a device has no exceptions |
| `E5090` | `y[i] ** 2` | a kernel's `**` of floats is not built yet, nor are its `//` and `%` of floats |
| `E5090` | `for v in array...` | a kernel loops over a `range` alone |

A tensor's `shape` is a tuple, which a kernel does not hold: read `t.shape[1]`
into a variable before the launch and pass it, or use `len` of a view.

## Failures

A kernel has no exceptions. What would raise in ordinary code is recorded
instead: the kernel runs on, without touching memory it should not, and `run`
raises the first such failure when the kernel is done.

| In ordinary code | Recorded in a kernel, raised by `run` |
|---|---|
| an int past its type; a float converted to an int type that cannot hold it (`u64(-1.5)`, `int(math.floor(1e300))`) | `OverflowError` |
| an index outside its dimension (a tensor's, an array's, a vector's lane, a `comptime` table's) | `IndexError` |
| a division by zero, of ints or of floats | `ZeroDivisionError` |
| a view the kernel cannot make, a NaN stored in a float format with none | `ValueError` |

After a failed run, what the kernel wrote is to be thrown away: other indices
have run, and the failing one wrote something.

```jac
import from accel { tensor, kernel }

def bad_index(i: int, v: tensor[i32, _]) {
    v[i + 1] = 0;
}

def overflow(i: int, v: tensor[i32, _]) {
    v[i] = v[i] * 100000;
}

def by_zero(i: int, v: tensor[i32, _]) {
    v[i] = 10 // v[i];
}

with entry {
    for which in range(3) {
        w = tensor[i32, _]([1, 0, 30000]);
        try {
            if which == 0 {
                kernel(bad_index).run(3, w);
            } elif which == 1 {
                kernel(overflow).run(3, w);
            } else {
                kernel(by_zero).run(3, w);
            }
        } except (IndexError, OverflowError, ZeroDivisionError) as e {
            print(type(e).__name__ + ":", e);
        }
    }
}
```

```output
IndexError: tensor index out of range in kernel bad_index
OverflowError: integer overflow in kernel overflow
ZeroDivisionError: division by zero in kernel by_zero
```

A float divided by zero is a fault too, as it raises in ordinary code. A
kernel's `math` functions and a vector's lanes follow IEEE instead: see
[A kernel's math](kernel-math.md) and [Vectors](vectors.md).

## bf16 and the small float formats

A kernel computes with `bf16` as ordinary code does: each operation in `f32`,
rounded to `bf16` in integer arithmetic, because no device a kernel is compiled
for has `bf16` arithmetic at the capability it is compiled for. For `+`, `-`,
`*` and `/` that gives the `bf16` nearest the exact result, bit for bit what
ordinary code computes. A struct with `bf16` fields crosses a launch, each field
its 16 bits. Vectors of `bf16` are not built in a kernel yet (`E5090`).

A tensor of a small float format (`f8e4m3fn`, `f8e5m2`, `f4e2m1fn`; see
[Numbers](../language/numbers.md)) is read and stored in a kernel as in ordinary
code, in every view of it: an element reads as an `f32`, and a store takes the
conversion by the format's name. A NaN stored in a format that has none is a
fault (`ValueError`). The formats have no vector methods: `t.vector(...)` of
such a tensor is `E1475`.

```jac
import from accel { tensor, kernel }

def quantize(i: int, x: tensor[f32, _], q: tensor[f8e4m3fn, _], h: tensor[bf16, _]) {
    q[i] = f8e4m3fn(x[i]);
    h[i] = bf16(x[i]) * 1.1;
    x[i] = q[i] * 2.0;
}

with entry {
    x = tensor[f32, _]([0.1, 1.7, -3.3]);
    q = tensor[f8e4m3fn, _](shape=3);
    h = tensor[bf16, _](shape=3);
    kernel(quantize).run(3, x, q, h);
    print(q.tolist(), x.tolist());
    print(h.tolist() == [float(bf16(v) * 1.1) for v in [0.1, 1.7, -3.3]]);
}
```

```output
[0.1015625, 1.75, -3.25] [0.203125, 3.5, -6.5]
True
```

## Random numbers

A kernel keeps no state between indices, so its random numbers come from a
counter-based generator, which keeps none either. `accel.philox` is Philox
4x32-10: the number for an index is a function of the index, a stream number
and a seed, so it is the same on every device and in any order.

| Function | Gives |
|---|---|
| `philox(seed, stream, index, word)` | an int from 0 to 2**32 - 1: word `word` (0 to 3) of the block the generator makes for the seed, the stream and the index |
| `philox_unit(seed, stream, index)` | an `f32` from 0 to just under 1, one of 2**24 evenly spaced, from word 0 |

Both are ordinary functions too. `philox(0, 0, 0, w)` gives the generator's
published known answers:

```jac
import from accel { tensor, kernel, philox, philox_unit }

def noise(i: int, seed: int, words: tensor[int, _], units: tensor[f32, _]) {
    words[i] = philox(seed, 7, i, i % 4);
    units[i] = philox_unit(seed, 7, i);
}

with entry {
    words = tensor[int, _](shape=3);
    units = tensor[f32, _](shape=3);
    kernel(noise).run(3, 42, words, units);
    print(words.tolist());
    print(units[0] == philox_unit(42, 7, 0), 0.0 <= units[1] < 1.0);
    print([hex(philox(0, 0, 0, w)) for w in range(4)]);
}
```

```output
[1743679276, 1611620758, 1461341424]
True True
['0x6627e8d5', '0xe169c58d', '0xbc57ac4c', '0x9b00dbd8']
```

## Diagnostics

| Code | Reported when |
|---|---|
| `E1409` | `kernel()` is given anything but a function of the program, by its name |
| `E1418` | `run()` or `begin()` of a kernel whose first parameter is not the `int` index |
| `E1235` | a launch has the wrong number of arguments, or passes the kernel's own by keyword |
| `E1053` | an argument is not of its parameter's type; `stream=` is not a `Stream`, `print_buffer=` not an int |
| `E1030` | a kernel has no such method |
| `E1452` | a local holding one kernel is bound to another |
| `E1540` | the kernel, or a function it calls, needs what a device lacks |
| `E5090` | the kernel uses what its backend does not lower yet |
| `E1475` | a vector method of a tensor of a small float format |

```jac
# expect: E1409, E1418, E1235, E1053, E1030, E1452
import from accel { tensor, kernel }

def fine(i: int, a: f32, y: tensor[f32, _]) {
    y[i] = a;
}

def twice(i: int, a: f32, y: tensor[f32, _]) {
    y[i] = a + a;
}

def no_index(y: tensor[f32, _]) {
    y[0] = 1.0;
}

with entry {
    y = tensor[f32, _](shape=4);
    f = fine;
    kernel(f);
    kernel(no_index).run(4, y);
    k = kernel(fine);
    k.run(4, 1.0);
    k.run(4, y, y);
    k.start(4);
    k = kernel(twice);
}
```
