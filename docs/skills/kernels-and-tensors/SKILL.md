---
name: kernels-and-tensors
description: Use when writing numeric, data-parallel or GPU code in Jac - tensors and views from the accel module, a kernel launched with kernel(f).run, a flow for over tensors, SIMD vectors, sized number types (f32, i32, u8), running on the processor or an NVIDIA accelerator, and the errors E1540, E1313, E1308, E5090.
---
# Kernels and tensors

## When to use this

Use it for array math: element-wise work, reductions, matrix rows, SIMD inner loops, and code
meant for an NVIDIA GPU. A kernel run per index runs on the processor too, unchanged.

- Load `writing-jac` first. Calling a C or Rust numeric library instead: `using-c-and-rust`.
- A `flow for` over plain values (no tensors) runs on threads: `jac docs flow for`.

## Before you start

```sh
jac docs accel            # the model in one page, and the map of the accel pages
jac docs kernel           # what a kernel's code may and may not do
jac docs requirements     # places and E1540
jac docs numbers          # the sized types: i32, u8, f32, bf16, wrapping operators
```

Decide where the code runs. A kernel and a `flow for` over tensors run on the device their
tensors live on: the processor unless a tensor is made `on=cuda(i)`. Grid kernels
(`k.launch`, shared memory, barriers, warps) run on an accelerator only; write those only when
the target has one (`jac docs grid kernel`).

Choose the form by what the work touches:

| Form | Use it for | Checked | Reductions | Runs on |
|---|---|---|---|---|
| `kernel(f).run(n, ...)` | Tensor work written once, launched from several places or on a stream | Kernel code (E1540), arguments; **not** that each index writes only its own items | Atomics into a tensor | The tensors' device; on the processor, chunks of at least 1024 indices |
| `flow for i in range(n)` writing a tensor | The same work written in place | Kernel code (E1540), own-index writes (E1313), no outer local bound (E1308) | As `run` | As `run`, chunked as `run` |
| `flow for` over `&xs`, `&mut xs`, chunks or a range, no tensor | Lists, objects, strs; sums, counts, least, greatest | Nothing shared between iterations (E1308) | `+=`, `*=`, `min`, `max` of an outer int or float | The processor's threads, up to `JAC_THREADS` chunks |
| `kernel(f).launch(grid, block, ...)` | Threads that cooperate: barriers, shared memory, warps | Kernel code (E1540) | Atomics, shared memory, warps | An NVIDIA accelerator only |

`jac docs accel` has the full table.

## Steps

1. **Hold the data in tensors** (`import from accel { tensor }`). The element type and each
   dimension are in the type; `_` is a size known at run time. Make with a list
   (`tensor[f32, _]([...])`), with `shape=` and `fill=`, and `on=` for a device.
2. **Write the per-index work** as a function whose first parameter is the `int` index and
   launch it with `kernel(f).run(count, ...)`, or write it in place as a `flow for` over a
   `range` whose body writes a tensor. Each index writes only its own items (`y[i]`, `m[i, j]`).
3. **Read what a kernel needs before the launch**: a tensor's `shape` is a tuple, which a kernel
   cannot hold; pass `m.shape[1]` as an argument, or read it into a local before a `flow for`.
4. **Use the kernel's vocabulary only**: numbers, bools, `if`, `while`, `for` over a `range`,
   conversions (`f32(x)`), `abs`/`min`/`max`, `math`, structs of plain data, `array[T, N]`,
   `comptime` globals. No list, str, dict, `raise` or ordinary global.
5. **Vectorize an inner loop** with `simd[T, N]`: `t.vector(i, N)` loads `N` elements,
   `t.store(i, v)` stores them, `v.sum()` reduces. Build and run as any program.

All of it, on whatever device the machine has:

```jac
import from accel { tensor, kernel, cpu, cuda, cuda_count, Device }

def pick -> Device {
    if cuda_count() > 0 {
        return cuda(0);
    }
    return cpu();
}

def scale_row(i: int, cols: int, factor: f32, m: tensor[f32, _, _]) {
    for j in range(cols) {
        m[i, j] = m[i, j] * factor;
    }
}

def row_sums(m: tensor[f32, _, _], out: tensor[f32, _]) {
    cols = m.shape[1];
    flow for i in range(len(m)) {
        acc = f32(0.0);
        for j in range(cols) {
            acc += m[i, j];
        }
        out[i] = acc;
    }
}

def dot8(a: tensor[f32, _], b: tensor[f32, _]) -> f32 {
    acc = simd[f32, 8](0.0);
    for i in range(0, len(a), 8) {
        acc += a.vector(i, 8) * b.vector(i, 8);
    }
    return acc.sum();
}

with entry {
    dev = pick();
    m = tensor[f32, _, _]([float(k) for k in range(12)], shape=(3, 4), on=dev);
    kernel(scale_row).run(len(m), m.shape[1], 2.0, m);
    out = tensor[f32, _](shape=3, on=dev);
    row_sums(m, out);
    print(m.tolist());
    print(out.tolist());
    col = m[..., 1];
    print(col.tolist(), m.transpose().shape);
    a = tensor[f32, _](shape=16, fill=1.0);
    b = tensor[f32, _]([float(k) for k in range(16)]);
    print(dot8(a, b));
}
```

```output
[0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0]
[12.0, 44.0, 76.0]
[2.0, 10.0, 18.0] (4, 3)
120.0
```

`m[..., 1]` and `transpose()` are views of the same memory. `dot8` needs a length that is a
multiple of 8; `jac docs vector-memory` shows masked loads for a tail.

**Sized numbers** keep their width, and overflow raises unless you ask for wrapping (`+%`) or
saturating (`+|`) arithmetic. A `flow for` over plain values runs on threads, and an object
those threads share conforms to `Shared` and holds its state in an `Atomic`:

```jac
import from atomics { Atomic }

obj Hits(Shared) {
    has n: Atomic[int] = Atomic[int]();

    def bump {
        self.n.add(1);
    }
}

with entry {
    small: u8 = 250;
    print(small +% 10, small +| 10, i32.MAX, f32(0.1));
    try {
        print(small + 10);
    } except OverflowError {
        print("OverflowError");
    }
    h = Hits();
    flow for i in range(1000) {
        h.bump();
    }
    print(h.n.load());
}
```

```output
4 255 2147483647 0.1
OverflowError
1000
```

## What a correct result looks like

- `jac check` passes; the output matches a plain loop over `tolist()` on small sizes.
- A kernel's fault (index out of range, overflow, division by zero) is raised once it is done,
  naming it: `integer overflow in kernel bump.flow` for a `flow for` in `bump`.
- Without an accelerator, `cuda_count()` is 0 and `cuda(0)` raises `RuntimeError`.
  `kernel(f).code("cuda")` still prints the PTX a device would run, for inspection.

## Mistakes to expect

```jac
# expect: E1308, E1313, E1540, E5090
import from accel { tensor, kernel }

def shift(x: tensor[f32, _], y: tensor[f32, _]) -> f32 {
    total = f32(0.0);
    flow for i in range(len(y) - 1) {
        y[i + 1] = x[i];
        total = total + x[i];
    }
    return total;
}

def bad(i: int, y: tensor[f32, _], name: str) {
    y[i] = y[i] ** 2;
}

with entry {
    x = tensor[f32, _](shape=4);
    print(shift(x, x));
    kernel(bad).run(4, x, "x");
}
```

| Code | Means | Fix |
|---|---|---|
| E1313 | A `flow for` writes a tensor at an index not starting with the loop's | Write `y[i]`; compute shifted reads from an unwritten tensor |
| E1308 | A `flow for` body binds a local of the function around it, or reads a tensor in a non-tensor loop | Write each index's result into a tensor; reduce afterwards |
| E1540 | The kernel (or a function it calls) needs a heap, str, exception or ordinary global | Use numbers, `array[T, N]`, `comptime` globals; pass sizes in |
| E5090 | Kernel code the backend does not lower yet (`**` or `%` of floats, `for` over an array) | `x * x`; loop over `range` |
| E1053 `expects i32, found int` | A sized parameter given an `int` | `i32(n)`; literals that fit need none |
| E0033 | A tensor dimension in a type is a run-time value | Use `_` and `shape=` |
| E1418, E1235 | `run` on a function whose first parameter is not the index; wrong argument count | Put `i: int` first; pass the rest by position |
| E1541 | A `Shared` class's method writes a field | Hold state in `Atomic` and change it with its methods |
| `OverflowError` at run time | A sized number past its range | `+%`, `+|`, or a wider type |

A `flow for` over tensors keeps what its indices share (a count, a sum, a least, a greatest)
with the atomics, as a named kernel does: `atomic_add(t, j, v)` into a tensor of one
dimension. Its body still writes a tensor's items of its own, `y[i] = ...`.

## Where to look things up

- `jac docs tensor`, `jac docs views`: making, indexing, slicing, `reshape`, `blocks`.
- `jac docs parallel loop over tensors`: stepped loops and `tiles`.
- `jac docs simd`, `jac docs vector-memory`: lanes, masks, gather and scatter.
- `jac docs devices`: `cpu()`, `cuda(i)`, `JAC_CUDA`, `JAC_THREADS` (threads, 4 by default).
- `jac docs grid kernel`: `launch`, `barrier`, warps (accelerator only); `jac docs Shared`.
