---
description: Where code runs, and the accel module - devices, tensors, kernels, vectors and values held in place - in one page, with where to read further.
keywords: accel, accel module, accelerator programming, data parallelism
---
# Devices, tensors and kernels

jac runs one program on the processor and on NVIDIA accelerators. Data that
lives on a device is a tensor; a function launched over tensors is a kernel;
numbers computed side by side are a vector. The `accel` module has the tensors,
the kernels and the devices. Vectors and fixed-size arrays are builtin.

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

`kernel(saxpy).run(4, 2.0, x, y)` calls `saxpy(i, 2.0, x, y)` for each `i`
below 4, on the device `x` and `y` live on. Here that is the processor, where a
tensor is made unless `on=` names another; on a machine with an NVIDIA
accelerator, `on=cuda(0)` puts the same program's data and work there.

## The model

**Places.** Code runs in a place: a space's host (native, wasm, cpython, node,
browser), a kernel, or the threads of a parallel `flow for`. A function runs in
a place when the place provides everything the function's code needs, and what
it needs is what its code does: a list needs counted references, `raise` needs
exceptions, a global that can change needs module state. A device provides
numbers, values held in place and the tensors a kernel is given, and little
else. Code that needs what its place lacks is refused where it needs it, with
`E1540`. A second question, asked of the values handed to a place, is whether
their type may cross into it: plain data crosses to a device, shared values to
other threads, sendable ones to another space.

**Devices.** The processor, `cpu()`, and each NVIDIA accelerator, `cuda(i)`.
A program finds the accelerators when it runs, and runs without them.

**Tensors.** A `tensor[f32, N, M]` is a block of numbers (or plain structs) on
one device, its shape part of its type. A view is another shape over the same
memory: a slice, a transpose, a reshape, blocks.

**Kernels.** A function launched over tensors. It is compiled apart from the
rest of the program, as typed code with no heap and no exceptions, for the
processor and for CUDA devices both. There are three ways to write one:

- `kernel(f).run(count, ...)`: `f(i, ...)` for each index `i` below `count`,
  on any device,
- a `flow for` over a range whose body writes a tensor: the same, with no name,
- `kernel(f).launch(grid, block, ...)`: a grid of blocks of threads, with
  barriers, shared memory and warps, on an accelerator alone.

A kernel has no exceptions: what would raise is recorded, and the launch
raises it when the kernel is done.

**Vectors.** `simd[f32, 8]` is 8 numbers computed at once, in the processor's
vector registers or an accelerator's lanes, with the same results. A tensor
loads and stores vectors of its elements.

**Values held in place.** Numbers, vectors, `array[T, N]`, plain structs and
128-bit ints are held where they are, with no heap, so they are a kernel's as
much as ordinary code's, and a launch passes each as a copy.

## Choosing a form

Four forms run work over many indices at once. They differ in what their code may touch, what the
compiler checks, and where they run:

| | `kernel(f).run(n, ...)` | `flow for` over a range, writing a tensor | `flow for` over lists, chunks or a range | `kernel(f).launch(grid, block, ...)` |
|---|---|---|---|---|
| What it is | A named function, its first parameter the index | A kernel with no name, written where it is used | The ordinary parallel loop | A named function every thread of a grid runs |
| Reads | Its arguments: numbers, tensors, values held in place (structs, arrays, vectors) | The function's locals of those kinds | Lists lent `&`, plain data, strs, `imm` values, shared objects; not a tensor (`E1308`) | As `run` |
| Writes | The tensors it is given; each other argument is a copy of its own | Tensors, each index its own items | Its index's element of a `&mut` list, its element or chunk, its reductions, `Atomic`s | Tensors, and its block's shared memory |
| The compiler checks | The code fits a kernel (`E1540`) and the arguments (`E1235`, `E1053`); **not** that each index writes only its own items | The code fits a kernel (`E1540`), each index writes only its own items (`E1313`), no local of the function is bound (`E1308`) | No iteration touches what another touches (`E1308`) | The code fits a kernel (`E1540`) |
| Reductions | Atomics into a tensor (`atomic_add`) | As `run` | `+=`, `*=`, `min`, `max` of an outer `int` or float | Atomics, shared memory, warp operations |
| Split, on the processor | Chunks of at least 1024 indices; fewer indices are one chunk | As `run` | Up to `JAC_THREADS` chunks, with no smallest | Does not run there |
| Runs on | The device its tensors live on: the processor or an NVIDIA accelerator | As `run` | The processor, on the program's threads | An NVIDIA accelerator only (`RuntimeError` for tensors on the processor) |

- Work over tensors written once and launched from several places, or on a
  [stream](streams.md): a named kernel with `run`. Each index writing only its own items is
  yours to keep.
- The same work written where it is used, with that rule checked: a `flow for` over tensors
  ([Parallel loops over tensors](parallel-loops.md)).
- Lists, objects or strs, or a sum, count, least or greatest kept as the loop goes: a plain
  `flow for` ([Parallel loops: flow for](../language/flow-for.md), `jac docs "flow for"`).
- Threads that cooperate, meeting at barriers and sharing memory, on an accelerator: a
  [grid kernel](grid-kernels.md).

## Pages

Where code runs:

- [What code needs from the place it runs](requirements.md): needs, places,
  `E1540` (`jac docs requirements`)
- [What crosses into a place](crossing.md): plain, shared and sendable values,
  and the `Shared` interface

Data:

- [Devices](devices.md): the processor and NVIDIA accelerators, where a tensor
  lives and a kernel runs
- [Tensors](tensors.md): the tensor type, making one, items, tensors of structs
- [Views and layouts](views.md): slices, `transpose`, `reshape`, `blocks`,
  strides
- [Arrays and values held in place](arrays.md): `array[T, N]`, plain structs
  and 128-bit ints in a kernel

Kernels:

- [Kernels](kernels.md): `kernel(f).run(...)`, what a kernel's code may do,
  faults, random numbers
- [A kernel's math](kernel-math.md): `math`'s functions in a kernel, their `f32`
  forms and accuracy
- [Parallel loops over tensors](parallel-loops.md): `flow for` as a kernel,
  stepped loops, `tiles`
- [Grid kernels](grid-kernels.md): `launch`, a thread's place, barriers, shared
  memory, warps, atomics
- [Streams, events and copies](streams.md): launches not waited for, streams,
  events, `copy_from`, page-locked memory, `host()`
- [Printing from a kernel](kernel-printing.md): `print` in a kernel and its
  buffer

Vectors:

- [Vectors](vectors.md): `simd[T, N]`, lanes, arithmetic, masks, reductions
- [Vector methods](vector-methods.md): math, rounding, bit casts, moving lanes
- [Tensor elements as vectors](vector-memory.md): loads, stores, gather,
  scatter, masked access

The number types a kernel computes with (`f32`, `bf16`, the small float formats,
`i128`, the wrapping and saturating operators) are language pages:
`jac docs numbers`. Structs are `jac docs struct`.
