---
description: A flow for over a range whose body writes a tensor is a kernel without the name - how it is launched, the rule that each index writes its own items, loops that step by a vector's width, and loops over tiles.
keywords: parallel loop over tensors, flow for over tensors, tiles, tile, stepped flow for
---
# Parallel loops over tensors

A `flow for` over a `range` whose body writes a [tensor](tensors.md)'s items is
a [kernel](kernels.md) without the name. Its body is compiled as one, taking
the loop's index and each local of the function it names, and is launched for
each index on the [device](devices.md) the tensors live on: on the processor's
threads, or on an accelerator. A `flow for` over lists and ranges that writes no
tensor is the ordinary parallel loop, in [Parallel loops: flow for](../language/flow-for.md).

```jac
import from accel { tensor }

def saxpy(a: f32, x: tensor[f32, _], y: tensor[f32, _]) {
    flow for i in range(len(y)) {
        y[i] = a * x[i] + y[i];
    }
}

with entry {
    x = tensor[f32, _]([1.0, 2.0, 3.0, 4.0]);
    y = tensor[f32, _](shape=4, fill=0.5);
    saxpy(2.0, x, y);
    print(y.tolist());
}
```

```output
[2.5, 4.5, 6.5, 8.5]
```

This is `kernel(saxpy).run(4, 2.0, x, y)` of a kernel whose first parameter is
the index, written where it is used. It works in module code as in a function.

A `flow for` whose body writes no tensor is the ordinary parallel loop, run on
the program's threads; its rules are with the `flow for` statement (see
`jac docs "flow for"`). A tensor is not shared between threads, so such a loop
does not read one (`E1308`).

## The rule: each index writes its own items

The indices run in no promised order, and at once. The compiler holds the
body to what makes the loop leave what a loop in order would:

- A tensor the body writes is written, and read, only at an index that starts
  with the loop's: `y[i]`, `m[i, j]`, `m[i]` (`E1313`). `y[i + 1]` and `y[0]`
  are another index's.
- A tensor the body only reads may be read anywhere: `x[i - 1]` and `x[i + 1]`
  are fine where `x` is not written.
- The body binds no local of the function around it (`E1308`): each index's
  result goes into the tensor, not into a variable the indices would share.
- The body needs nothing a kernel's place lacks (`E1540`; see
  [What code needs from the place it runs](requirements.md)). The diagnostic
  names the body `<function>.flow`.
- The loop's variable is the body's own: a variable of the same name outside
  the loop keeps its value.

What the indices keep between them (a count, a sum, a least or a greatest) goes
into a tensor's item through `accel`'s atomics, as in any kernel: `atomic_add(t,
j, v)`, `atomic_min` and `atomic_max` update item `j` of `t` in one indivisible
step, from any index ([Grid kernels](grid-kernels.md), "Atomics and fence").
`clipped` below counts the items it changes. An atomic's tensor is not one the
body writes for the rule above, and the body still writes a tensor's items with
an assignment or a store: a loop whose body only updates tensors atomically is
the ordinary parallel loop, which reads no tensor (`E1308`).

```jac
import from accel { tensor, atomic_add }

def smooth(x: tensor[f32, _], out: tensor[f32, _]) {
    n = len(x);
    flow for i in range(1, n - 1) {
        out[i] = (x[i - 1] + x[i] + x[i + 1]) / 3.0;
    }
}

def clipped(x: tensor[f32, _], most: f32) -> int {
    hits = tensor[int, _](shape=1);
    flow for i in range(len(x)) {
        if x[i] > most {
            x[i] = most;
            atomic_add(hits, 0, 1);
        }
    }
    return hits[0];
}

def filled(y: tensor[f32, _]) -> int {
    i = 100;
    flow for i in range(len(y)) {
        y[i] = f32(i);
    }
    return i;
}

with entry {
    x = tensor[f32, _]([0.0, 3.0, 6.0, 3.0, 0.0]);
    out = tensor[f32, _](shape=5);
    smooth(x, out);
    print(out.tolist());
    print(filled(out), out.tolist());
    print(clipped(x, 2.5), x.tolist());
}
```

```output
[0.0, 3.0, 4.0, 3.0, 0.0]
100 [0.0, 1.0, 2.0, 3.0, 4.0]
3 [0.0, 2.5, 2.5, 2.5, 0.0]
```

## The range

The loop is over `range(n)`, `range(start, n)` or `range(start, n, step)`.
`start` and `step` are compile-time ints (`E0033` for a run-time one), and the
step is above 0 (`E1313`); `n` is any int. The body runs for each index `start +
k * step` below `n`.

## What the body takes

The body reads the locals of the function it names, as a kernel's launch passes
its arguments: numbers, tensors and values held in place (structs, arrays,
vectors, 128-bit ints). Each value but a tensor is a copy, each index's own: a
change one index makes to a captured struct is its own, and the function's
local is unchanged.

A tensor's `shape` is a tuple, which a kernel does not hold (`E1540`). Read the
dimension into a local before the loop:

```jac
import from accel { tensor }

def numbered(m: tensor[i32, _, _]) {
    cols = m.shape[1];
    flow for i in range(len(m)) {
        for j in range(cols) {
            m[i, j] = i32(i * 10 + j);
        }
    }
}

with entry {
    m = tensor[i32, 3, 2]();
    numbered(m);
    print(m.tolist());
}
```

```output
[0, 1, 10, 11, 20, 21]
```

A check that fails in the body is recorded and raised when the loop is done, as
a kernel's is (see [Kernels](kernels.md)), and the message names the body
`<function>.flow`.

## Stepping by a vector's width

A loop whose range steps hands its body a vector's worth of indices:
`range(start, n, W)` is launched for each index `start + k * W` below `n`, and
the body reads and writes the `W` elements from there with a tensor's
[vector loads and stores](vector-memory.md).

```jac
import from accel { tensor }

def saxpy8(a: f32, x: tensor[f32, _], y: tensor[f32, _]) {
    flow for i in range(0, len(y), 8) {
        y.store(i, a * x.vector(i, 8) + y.vector(i, 8));
    }
}

def saxpy4(a: f32, x: tensor[f32, _], y: tensor[f32, _]) {
    n = len(y);
    flow for i in range(0, n, 4) {
        live = simd[int, 4](0, 1, 2, 3) < n - i;
        y.store_masked(i, a * x.vector_masked(i, 4, live) + y.vector_masked(i, 4, live), live);
    }
}

with entry {
    x = tensor[f32, _]([float(k) for k in range(16)]);
    y = tensor[f32, _](shape=16, fill=1.0);
    saxpy8(2.0, x, y);
    print(y.tolist());
    z = tensor[f32, _](shape=10, fill=1.0);
    saxpy4(2.0, tensor[f32, _]([float(k) for k in range(10)]), z);
    print(z.tolist());
    try {
        saxpy8(1.0, tensor[f32, _](shape=12), tensor[f32, _](shape=12));
    } except IndexError as e {
        print("IndexError:", e);
    }
}
```

```output
[1.0, 3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0, 19.0, 21.0, 23.0, 25.0, 27.0, 29.0, 31.0]
[1.0, 3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0, 19.0]
IndexError: tensor index out of range in kernel saxpy8.flow
```

`saxpy8` needs a length that is a multiple of 8: each access is checked as
anywhere, so a vector past the end raises `IndexError`. `saxpy4` takes any
length: its mask covers the tail, and a masked access neither touches nor checks
the lanes it leaves out.

A written tensor is written and read as an index's own elements:

- a vector of it starts at the loop's index (`vector`, `store`,
  `vector_masked`, `store_masked`, `compress`), and
- along a dimension the loop's index runs on, it is no wider than the step
  (`E1313`).

## Loops over tiles

`flow for (i, j) in tiles(rows, cols, TH, TW)` runs its body once for each
`TH` by `TW` tile of a `rows` by `cols` extent. `(i, j)` is the tile's first
item: `(0, 0)`, `(0, TW)`, ..., `(TH, 0)`, .... `TH` and `TW` are compile-time
ints above 0 (`E0033`, `E1313`). It is launched as a kernel, on the processor's
threads or an accelerator, as a ranged loop is, and its body must write a
tensor (`E1313`).

A tensor the body writes is written and read at its tile's items alone:

- its first two indices are `i` and `j`, each plus a compile-time int below the
  tile's size, or plus a variable the body binds only as a counted loop's over
  `range(K)`, `K` a compile-time int at most the tile's size,
- a vector along its columns is no wider than what is left of the tile's
  columns (`E1313`).

Where the sizes do not divide the extent, the tiles at its edge reach past it,
as a step does: `IndexError`, unless a mask guards the access.

```jac
import from accel { tensor, tiles }

def matmul(a: tensor[f32, _, _], b: tensor[f32, _, _], c: tensor[f32, _, _]) {
    inner = a.shape[1];
    flow for (i, j) in tiles(c.shape[0], c.shape[1], 4, 4) {
        for r in range(4) {
            for q in range(4) {
                acc = f32(0.0);
                for k in range(inner) {
                    acc += a[i + r, k] * b[k, j + q];
                }
                c[i + r, j + q] = acc;
            }
        }
    }
}

with entry {
    a = tensor[f32, 8, 8]([[float(r + c) for c in range(8)] for r in range(8)]);
    e = tensor[f32, 8, 8]([[1.0 if r == c else 0.0 for c in range(8)] for r in range(8)]);
    c = tensor[f32, 8, 8]();
    matmul(a, e, c);
    print(c.tolist() == a.tolist(), c[7, 6]);
    print(tiles(5, 7, 2, 4));
}
```

```output
True 13.0
[(0, 0), (0, 4), (2, 0), (2, 4), (4, 0), (4, 4)]
```

`accel.tiles` called anywhere but as a `flow for`'s range is the list of the
tiles' first items, in row-major order, the tiles at the edge included.

## What is rejected

```jac
# expect: E1313 x6, E1308, E1540, E0033 x2
import from accel { tensor, tiles }

def wrong(y: tensor[f32, _], names: list[str], s: int) {
    total = f32(0.0);
    flow for i in range(len(y)) {
        y[i + 1] = y[i];
    }
    flow for i in range(len(y)) {
        y[i] = y[0];
    }
    flow for i in range(len(y)) {
        total = y[i];
        y[i] = 0.0;
    }
    flow for i in range(len(y)) {
        y[i] = f32(len(names));
    }
    flow for i in range(s, len(y)) {
        y[i] = 1.0;
    }
    flow for i in range(0, len(y), 4) {
        y.store(i + 2, y.vector(i, 2));
    }
}

def tiled(x: tensor[f32, _, _], y: tensor[f32, _, _], t: int) {
    flow for (i, j) in tiles(4, 8, 4, 4) {
        y[i + 4, j] = x[i, j];
    }
    flow for (i, j) in tiles(4, 16, 4, 4) {
        y.store(i, j + 2, x.vector(i, j, 8));
    }
    flow for (i, j) in tiles(4, 8, t, 4) {
        y[i, j] = x[i, j];
    }
    flow for (i, j) in tiles(4, 8, 4, 4) {
        print(i, j);
    }
}
```

| Code | Line | Why |
|---|---|---|
| `E1313` | `y[i + 1] = y[i]` | an item of the written tensor at another index |
| `E1313` | `y[i] = y[0]` | the written tensor read at another index |
| `E1308` | `total = y[i]` | the body binds a local of the function |
| `E1540` | `len(names)` | a list needs counted references, which a kernel lacks |
| `E0033` | `range(s, len(y))` | the range's start is a compile-time int |
| `E1313` | `y.store(i + 2, ...)` | a vector of the written tensor starts at the loop's index |
| `E1313` | `y[i + 4, j]` | an item outside the loop's tile |
| `E1313` | `y.store(i, j + 2, x.vector(i, j, 8))` | 8 elements from column 2 of a tile 4 wide |
| `E0033` | `tiles(4, 8, t, 4)` | a tile's sizes are compile-time ints |
| `E1313` | `print(i, j)` | a loop over tiles writes a tensor |

## Diagnostics

| Code | Reported when |
|---|---|
| `E1313` | the body reaches a tensor it writes at another index's or tile's items; a vector of it is wider than the step, or does not start at the index; the step is not above 0; a loop over tiles writes no tensor |
| `E1308` | the body binds a local of the function around it |
| `E1540` | the body needs what a kernel's place lacks |
| `E0033` | the range's start or step, or a tile's size, is not a compile-time int |
