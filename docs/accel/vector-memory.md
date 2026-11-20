---
description: Reading and writing a tensor's elements as simd vectors - vector and store, gather and scatter, masked, strided and compressed access, and prefetch - and how each access is checked.
keywords: vector load, gather, scatter, vector_masked, store_masked, vector_strided, store_strided, compress, prefetch
---
# Tensor elements as vectors

A [tensor](tensors.md) hands its elements to code as
[vectors](vectors.md): `t.vector(...)` reads `N` elements at once into a
`simd[E, N]`, and `t.store(...)` writes one back. These are a tensor's methods,
in ordinary code and in a [kernel](kernels.md).

```jac
import from accel { tensor }

def dot8(a: tensor[f32, _], b: tensor[f32, _]) -> f32 {
    acc = simd[f32, 8](0.0);
    for k in range(0, len(a), 8) {
        acc += a.vector(k, 8) * b.vector(k, 8);
    }
    return acc.sum();
}

with entry {
    a = tensor[f32, _]([float(k % 7) for k in range(64)]);
    b = tensor[f32, _]([float(k % 5) * 0.5 for k in range(64)]);
    print(dot8(a, b));
    t = tensor[f32, _]([float(k) for k in range(8)]);
    t.store(4, t.vector(0, 4) * 10.0);
    print(t.tolist());
}
```

```output
183.0
[0.0, 1.0, 2.0, 3.0, 0.0, 10.0, 20.0, 30.0]
```

## The methods

In each, `i, ..., start` is an item's index, with as many ints as the tensor has
dimensions: the access runs along the last dimension from that item. `N` is a
compile-time int, the vector's length.

| Method | Does |
|---|---|
| `t.vector(i, ..., start, N)` | reads the `N` elements of the last dimension from item `(i, ..., start)` |
| `t.store(i, ..., start, v)` | writes `v`'s lanes there |
| `t.gather(idx)` | of a one-dimensional tensor: reads the element at each lane of `idx`, a vector of ints |
| `t.scatter(idx, v)` | of a one-dimensional tensor: writes each lane of `v` at the index in the same lane of `idx`. Where two lanes name one element, the later lane is written last |
| `t.vector_masked(i, ..., start, N, m)` | reads the elements of the lanes where mask `m` is true, and gives 0 in the others |
| `t.store_masked(i, ..., start, v, m)` | writes the lanes where `m` is true |
| `t.vector_strided(i, ..., start, N, step)` | reads `N` elements `step` apart |
| `t.store_strided(i, ..., start, v, step)` | writes `v`'s lanes `step` apart |
| `t.compress(i, ..., start, v, m)` | writes the lanes of `v` where `m` is true, one after another from `start`, and gives how many it wrote |
| `t.prefetch(i, ...)` | asks the processor for the item's memory ahead of its use |

`step` is a compile-time int, and may be negative (`E0033` for a run-time
value).

## Checks

Every element an access reaches is checked against its dimension, and one
outside it raises `IndexError` (in a kernel: is recorded, and raised by the
launch). So a vector that starts inside a tensor and runs past its end is an
error, not a short read.

A masked access is the exception by design: the elements of the lanes where the
mask is false are not touched and not checked. A mask therefore guards the end
of a tensor, and a loop can take any length four elements at a time:

```jac
import from accel { tensor }

with entry {
    x = tensor[f32, _]([float(k) for k in range(10)]);
    n = len(x);
    for i in range(0, n, 4) {
        live = simd[int, 4](0, 1, 2, 3) < n - i;
        v = x.vector_masked(i, 4, live);
        x.store_masked(i, v * 10.0, live);
    }
    print(x.tolist());
    try {
        print(x.vector(8, 4));
    } except IndexError as e {
        print("IndexError:", e);
    }
}
```

```output
[0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]
IndexError: tensor index out of range
```

`prefetch` is a hint, and never fails, whatever its index. An accelerator
ignores it.

## Rows, strides, gather and compress

```jac
import from accel { tensor }

with entry {
    m = tensor[f32, 2, 8]([[float(r * 8 + c) for c in range(8)] for r in range(2)]);
    print(m.vector(1, 2, 4));
    print(m.vector_strided(0, 0, 4, 2), m.vector_strided(1, 7, 4, -2));
    m.store_strided(0, 1, simd[f32, 4](-5.0), 2);
    print(m[0].tolist());
    g = tensor[f32, _]([0.5, 1.5, 2.5, 3.5, 0.0, 0.0, 0.0, 0.0]);
    at = simd[i32, 4](2, 0, 3, 1);
    got = g.gather(at);
    g.scatter(at + 4, got * 10.0);
    print(got, g.tolist());
    out = tensor[f32, _](shape=8);
    src = simd[f32, 8](3.0, -1.0, 4.0, -1.0, 5.0, -9.0, 2.0, 6.0);
    kept = out.compress(0, src, src > 0.0);
    print(kept, out.tolist());
}
```

```output
[10.0, 11.0, 12.0, 13.0]
[0.0, 2.0, 4.0, 6.0] [15.0, 13.0, 11.0, 9.0]
[0.0, -5.0, 2.0, -5.0, 4.0, -5.0, 6.0, -5.0]
[2.5, 0.5, 3.5, 1.5] [0.5, 1.5, 2.5, 3.5, 5.0, 15.0, 25.0, 35.0]
5 [3.0, 4.0, 5.0, 2.0, 6.0, 0.0, 0.0, 0.0]
```

## Views

The methods work on a [view](views.md) of any layout, and name the view's items,
not the memory under them. Where the items of the last dimension are next to
each other in memory, a load or a store is one access of the whole vector.
Where they are not (a stepped slice, a transpose), each lane reads or writes its
own element.

```jac
import from accel { tensor }

with entry {
    t = tensor[f32, _]([float(k) for k in range(16)]);
    evens = t[::2];
    print(evens.vector(0, 4), evens.vector(4, 4));
    t[1::2].store(0, simd[f32, 4](-1.0));
    print(t.tolist()[:8]);
}
```

```output
[0.0, 2.0, 4.0, 6.0] [8.0, 10.0, 12.0, 14.0]
[0.0, -1.0, 2.0, -1.0, 4.0, -1.0, 6.0, -1.0]
```

## In ordinary code

In ordinary code a vector access reads and writes a tensor on the processor. Of
a tensor on an accelerator it raises `ValueError`: an accelerator tensor's
elements are reached by a kernel, or through `t.host()` (see
[Streams, events and copies](streams.md)).

A counted loop whose body only computes with numbers and vectors, and reaches
its tensors only by their vector accesses, reads each tensor's address, shape
and strides once, before it runs, and checks where the tensor lives there. Its
accesses then cost what a kernel's do. `dot8` above is such a loop. A loop that
runs no iteration reaches nothing, so it does not raise for a tensor on an
accelerator.

## In parallel loops

A `flow for` whose range steps by `W` hands its body `W` elements at each index,
and its body reads and writes them with these methods. A tensor the body writes
is then held to the loop's own elements (`E1313`). See
[Parallel loops over tensors](parallel-loops.md).

## What is rejected

```jac
# expect: E1050, E1235, E0033 x2, E1053 x2, E1411, E1475
import from accel { tensor }

def f(m: tensor[f32, _, _], t: tensor[f32, _], q: tensor[f8e4m3fn, _], n: int) {
    a = m.vector(0, 4);
    b = m.gather(simd[i32, 4](0));
    c = t.vector(0, n);
    d = t.vector_strided(0, 4, n);
    e = t.gather(simd[f32, 4](0.0));
    t.store(0, simd[i32, 4](1));
    g = t.vector(0, 3);
    h = q.vector(0, 4);
}
```

| Code | Line | Why |
|---|---|---|
| `E1050` | `m.vector(0, 4)` | an index for each dimension: a `tensor[f32, _, _]` takes two before the length |
| `E1235` | `m.gather(...)` | `gather` and `scatter` are of a tensor of one dimension |
| `E0033` | `t.vector(0, n)` | the vector's length is a compile-time int |
| `E0033` | `t.vector_strided(0, 4, n)` | so is a strided access's step |
| `E1053` | `t.gather(simd[f32, 4](0.0))` | the indices are a vector of ints |
| `E1053` | `t.store(0, simd[i32, 4](1))` | the vector stored is of the tensor's element type |
| `E1411` | `t.vector(0, 3)` | a vector's length is a power of two from 2 to 64 |
| `E1475` | `q.vector(0, 4)` | a small float format is a storage format, with no vectors: an element reads as an `f32` |
