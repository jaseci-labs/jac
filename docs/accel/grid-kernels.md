---
description: Grid kernels - functions launched with k.launch(grid, block, ...) over blocks of threads on an NVIDIA accelerator - the thread's place, barriers, shared memory, warp operations, and the atomics and fence every kernel has.
keywords: grid kernel, grid, thread block, launch, begin_launch, thread_idx, block_idx, block_dim, grid_dim, global_idx, barrier, shared, shared memory, lane_id, WARP_SIZE, warp, warp_shuffle, warp_shuffle_xor, warp_shuffle_up, warp_shuffle_down, warp_all, warp_any, atomic_add, atomic_min, atomic_max, fence, atomics in a kernel
---
# Grid kernels

A grid kernel is the form hand-tuned GPU kernels are written in.
`k.launch(grid, block, a, b, ...)` launches `f` over a grid of blocks of
threads, and every thread of every block runs `f(a, b, ...)` once. `f` takes no
index: a thread finds where it is with `accel`'s intrinsics, meets the other
threads of its block at barriers, and shares the block's memory with them.

A grid kernel runs on an NVIDIA accelerator alone. A
[kernel run for each index](kernels.md) (`k.run`) is the form that runs on
every [device](devices.md).

This program sums 1000 numbers in blocks of 256, each block by a tree in its
shared memory. It needs a machine with an NVIDIA accelerator and its driver; it
compiles everywhere:

```jac
import from accel { tensor, kernel, cuda, shared, thread_idx, block_idx, global_idx, barrier }

def block_sum(x: tensor[f32, _], out: tensor[f32, _], n: int) {
    s = shared[f32, 256]();
    t = thread_idx(0);
    i = global_idx(0);
    s[t] = x[i] if i < n else f32(0);
    barrier();
    step = 128;
    while step > 0 {
        if t < step {
            s[t] += s[t + step];
        }
        barrier();
        step //= 2;
    }
    if t == 0 {
        out[block_idx(0)] = s[0];
    }
}

with entry {
    gpu = cuda(0);
    x = tensor[f32, _](shape=1000, fill=1.0, on=gpu);
    out = tensor[f32, _](shape=4, on=gpu);
    kernel(block_sum).launch(4, 256, x, out, 1000);
    print(out.tolist());
}
```

With an accelerator it prints the four blocks' sums; without one, `cuda(0)`
raises `RuntimeError`:

```text
[256.0, 256.0, 256.0, 232.0]
```

## Launching

| Call | Does |
|---|---|
| `k.launch(grid, block, a, b, ...)` | runs `f(a, b, ...)` once in every thread of every block, and returns when every thread has |
| `k.begin_launch(grid, block, a, b, ...)` | `launch`, not waited for: it gives a `Launch` (see [Streams, events and copies](streams.md)) |

`grid` is how many blocks there are, and `block` how many threads each has.
Each is an int, or a tuple of up to three ints for the x, y and z axes; an axis
left out is 1. Anything else is `E1053`.

`launch` passes every one of the function's parameters: none is an index. The
arguments are checked against them where the call is written, their count
(`E1235`) and each one's type (`E1053`), as `run`'s are. A function whose first
parameter is not the `int` index cannot be `run` (`E1418`): it is a grid
kernel's.

Both launches take `stream=` and `print_buffer=` after the kernel's own
arguments, as `run` does (see [Kernels](kernels.md)). What a grid's threads
`print` is printed when the launch is done (see
[Printing from a kernel](kernel-printing.md)).

A launch returns when the kernel is done, and raises what it recorded, as `run`
does: an index outside a tensor's dimension is `IndexError`, and so on (see
[Kernels](kernels.md)).

## Where a grid kernel runs

A grid kernel runs on an accelerator alone. Its barriers and shared memory need
the threads of a block to run together, which the processor's kernels do not.
So:

- `launch` with tensors on the processor, or with no tensor and no `stream=`,
  raises `RuntimeError`,
- the compiler makes no processor code for a kernel that is only ever launched,
- a kernel that is `run` uses none of a grid kernel's intrinsics (`E1540`: a
  kernel run for each index lacks a grid's intrinsics).

An extent that is not positive, or more than the device runs (more than 1024
threads in a block, say), raises `ValueError` before anything is launched.

```jac
import from accel { tensor, kernel, global_idx }

def ones(y: tensor[f32, _]) {
    y[global_idx(0)] = 1.0;
}

with entry {
    y = tensor[f32, _](shape=64);
    try {
        kernel(ones).launch(2, 32, y);
    } except RuntimeError as e {
        print("RuntimeError:", e);
    }
    try {
        kernel(ones).launch((2, 0), 32, y);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
RuntimeError: ones is launched as a grid, which runs on an accelerator, and its tensors are on the processor: a grid's threads meet at barriers and share memory, which the processor's kernels do not
ValueError: a launch's grid extents are positive, and it was given (2, 0)
```

## The intrinsics

The intrinsics are imported from `accel`. They are a kernel's place's alone:
ordinary code that calls one is `E1540` ("a kernel's intrinsics, which a native
space does not provide"; see
[What code needs from the place it runs](requirements.md)).

A function is a kernel because the program names it in `kernel(f)`, and the
functions a kernel calls run in its place too, so a helper may call the
intrinsics. A function that calls one but that no kernel reaches is ordinary
code, and is `E1540` there.

### A thread's place

| Intrinsic | Gives |
|---|---|
| `thread_idx(axis)` | the thread's place in its block |
| `block_idx(axis)` | the block's place in the grid |
| `block_dim(axis)` | the block's extent: how many threads it has along the axis |
| `grid_dim(axis)` | the grid's extent: how many blocks it has along the axis |
| `global_idx(axis)` | `block_idx(axis) * block_dim(axis) + thread_idx(axis)` |

`axis` is the literal 0, 1 or 2, for x, y and z (`E1415` for anything else).
Each gives an `int`.

```jac
import from accel { tensor, kernel, cuda, global_idx }

def coords(out: tensor[int, _, _], rows: int, cols: int) {
    x = global_idx(0);
    y = global_idx(1);
    if y < rows and x < cols {
        out[y, x] = x * 100 + y;
    }
}

with entry {
    c = tensor[int, _, _](shape=(5, 7), on=cuda(0));
    kernel(coords).launch((1, 2), (8, 4), c, 5, 7);
    print(c[4].tolist());
}
```

On an accelerator, one block of 8 by 4 threads covers the first four rows and
the second the fifth; it prints row 4:

```text
[4, 104, 204, 304, 404, 504, 604]
```

### Barriers

`barrier()` holds each thread of the block until every thread of the block has
reached it. So every thread of the block must reach it alike: not inside an
`if` that some threads of a block take and others do not.

### Shared memory

`shared[T, N]()` is `N` elements of type `T` of the block's shared memory: the
same array for all the threads of a block, a `tensor[T, N]` read and written
with the usual checks (`IndexError`). `N` is an int literal (`E1419`).

- Its contents are undefined until a thread writes them.
- It is bound to a local, once (`E5090` for a second binding, or for one used
  other than as a local's value), and each such local is one array.

### Warps

The threads of a block run in warps of `WARP_SIZE` (32) threads, each a lane.

| Intrinsic | Gives |
|---|---|
| `lane_id()` | the thread's lane in its warp, 0 to 31 |
| `warp_shuffle(v, lane)` | `v` of lane `lane` |
| `warp_shuffle_xor(v, mask)` | `v` of lane `lane_id() ^ mask` |
| `warp_shuffle_up(v, d)` | `v` of lane `lane_id() - d`, or the lane's own `v` where it has none below |
| `warp_shuffle_down(v, d)` | `v` of lane `lane_id() + d`, or the lane's own `v` where it has none above |
| `warp_all(b)` | whether `b` holds on every lane of the warp |
| `warp_any(b)` | whether `b` holds on any lane of the warp |

A shuffled `v` is an `i32` or an `f32` (`E1053`), and a lane is taken modulo 32.
Every lane of the warp runs them: like a barrier, they are not for a branch
that some lanes of a warp take and others do not.

This kernel sums each warp's 32 values by shuffles across it, with one result a
warp:

```jac
import from accel { tensor, kernel, cuda, global_idx, lane_id, WARP_SIZE, warp_shuffle_xor }

def warp_sum(x: tensor[i32, _], out: tensor[i32, _]) {
    i = global_idx(0);
    v = x[i];
    m = WARP_SIZE // 2;
    while m > 0 {
        v += warp_shuffle_xor(v, m);
        m //= 2;
    }
    if lane_id() == 0 {
        out[i // WARP_SIZE] = v;
    }
}

with entry {
    gpu = cuda(0);
    x = tensor[i32, _]([k % 10 for k in range(128)], on=gpu);
    out = tensor[i32, _](shape=4, on=gpu);
    kernel(warp_sum).launch(2, 64, x, out);
    print(out.tolist());
}
```

On an accelerator, two blocks of 64 threads are four warps, and it prints their
sums:

```text
[136, 140, 144, 148]
```

## Atomics and fence

These two kinds of intrinsic are any kernel's: a grid kernel's, and a `run`
kernel's too, on the processor as on an accelerator.

| Intrinsic | Does |
|---|---|
| `atomic_add(t, i, v)` | adds `v` to item `i` of tensor `t` in one indivisible step, and gives what the item held before |
| `atomic_min(t, i, v)` | stores `v` at item `i` where it is less than what the item holds, in one step, and gives what the item held |
| `atomic_max(t, i, v)` | the same, where `v` is greater |
| `fence()` | orders what the thread wrote before it before what it writes after it, for every thread and for the processor |

- `t` is a tensor of one dimension, of `i32`, `u32`, `int`, `u64` or `f32`, and
  for `atomic_min` and `atomic_max` also `float` (`E1053` for another).
- The atomics are relaxed, as CUDA's `atomicAdd` is: one item's updates are
  indivisible, and order nothing else. `fence()` orders.
- A float's `atomic_min` and `atomic_max` are a compare-and-swap loop on every
  device. They take `v` only where it is strictly less (or greater), as `min()`
  and `max()` do, so a NaN is never taken.
- There is no atomic add of a `float` (`f64`): the PTX is for compute capability
  5.0, which has no such instruction (6.0 does, and the Maxwell GPUs below it
  are still run by current drivers). PTX has no atomics of 8- or 16-bit ints.
  Both are `E1053`.

```jac
import from accel { tensor, kernel, atomic_add, atomic_min, atomic_max, fence }

def histogram(i: int, data: tensor[i32, _], bins: tensor[int, _], firsts: tensor[int, _]) {
    was = atomic_add(bins, int(data[i]) % 4, 1);
    if was == 0 {
        atomic_add(firsts, 0, 1);
    }
    fence();
}

def ends(i: int, x: tensor[f32, _], lo_hi: tensor[f32, _]) {
    atomic_min(lo_hi, 0, x[i]);
    atomic_max(lo_hi, 1, x[i]);
}

with entry {
    data = tensor[i32, _]([k * 7 for k in range(3000)]);
    bins = tensor[int, _](shape=4);
    firsts = tensor[int, _](shape=1);
    kernel(histogram).run(len(data), data, bins, firsts);
    print(bins.tolist(), firsts.tolist());
    x = tensor[f32, _]([float((k * 37) % 101 - 50) for k in range(3000)] + [float("nan")]);
    lo_hi = tensor[f32, _]([float("inf"), float("-inf")]);
    kernel(ends).run(len(x), x, lo_hi);
    print(lo_hi.tolist());
}
```

```output
[750, 750, 750, 750] [4]
[-50.0, 50.0]
```

Exactly one index of each bin found it at 0, so `firsts` counts the bins. The
NaN at the end of `x` is never taken.

## What is rejected

```jac
# expect: E1540 x2, E1415, E1419, E1053 x3, E5090, E1235, E1418
import from accel { tensor, kernel, thread_idx, block_idx, shared, warp_shuffle, atomic_add }

def ordinary -> int {
    return thread_idx(0);
}

def mapped(i: int, y: tensor[f32, _]) {
    y[i] = f32(block_idx(0));
}

def grid(y: tensor[f32, _], d: tensor[f64, _], k: int) {
    y[0] = f32(thread_idx(k));
    s = shared[f32, k]();
    y[1] = f32(warp_shuffle(k, 0));
    atomic_add(d, 0, 1.0);
    u = shared[f32, 8]();
    u = shared[f32, 8]();
}

with entry {
    y = tensor[f32, _](shape=4);
    d = tensor[f64, _](shape=4);
    print(ordinary());
    kernel(mapped).run(4, y);
    kernel(grid).launch(1, 32, y, d);
    kernel(grid).run(4, y, d, 3);
    kernel(grid).launch((1, 2, 3, 4), 32, y, d, 3);
}
```

| Code | Line | Why |
|---|---|---|
| `E1540` | `thread_idx(0)` in `ordinary` | ordinary code lacks a kernel's intrinsics |
| `E1540` | `block_idx(0)` in `mapped` | a kernel run for each index lacks a grid's intrinsics |
| `E1415` | `thread_idx(k)` | an axis is the literal 0, 1 or 2 |
| `E1419` | `shared[f32, k]()` | shared memory's size is an int literal |
| `E1053` | `warp_shuffle(k, 0)` | a shuffled value is an `i32` or an `f32`; `k` is an `int` |
| `E1053` | `atomic_add(d, 0, 1.0)` | no atomic add of an `f64` at compute capability 5.0 |
| `E5090` | the second `u = shared[...]` | shared memory is bound to a local once |
| `E1235` | `launch(1, 32, y, d)` | `grid` takes three arguments after the grid and the block |
| `E1418` | `kernel(grid).run(...)` | a grid kernel takes no index |
| `E1053` | `launch((1, 2, 3, 4), ...)` | a grid has up to three extents |

## Diagnostics

| Code | Reported when |
|---|---|
| `E1415` | an intrinsic's axis is not the literal 0, 1 or 2 |
| `E1419` | `shared[T, N]()` is not given an element type and an int literal |
| `E1053` | a grid or block is not an int or a tuple of up to three ints; an argument is not of its parameter's type; a shuffled value is not an `i32` or `f32`; an atomic's tensor is not of one dimension of a type the device updates so |
| `E1235` | a launch has the wrong number of arguments |
| `E1418` | `run()` or `begin()` of a function whose first parameter is not the `int` index |
| `E1540` | a grid intrinsic outside a grid kernel, or an atomic or `fence()` outside a kernel |
| `E5090` | shared memory bound to a local a second time, or used other than as a local's value |

## Differences from CUDA

- An axis is an argument, `thread_idx(0)`, where CUDA has `threadIdx.x`.
- `global_idx(axis)` is the `blockIdx.x * blockDim.x + threadIdx.x` CUDA code
  writes by hand.
- Shared memory is a local, `s = shared[f32, 256]()`, where CUDA declares a
  `__shared__` array. Its size is a literal: there is no dynamic shared memory.
- The atomics take a tensor and an item's index, `atomic_add(t, i, v)`, where
  CUDA takes an address, `atomicAdd(&t[i], v)`. They give what the item held,
  as CUDA's do.
- A tensor's items are checked in a grid kernel too: an index outside its
  dimension is recorded and raised by the launch, where CUDA reads or writes
  past the array.
