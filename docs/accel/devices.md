---
description: Devices of the accel module - the processor and NVIDIA accelerators - how a program finds them, where a tensor lives, and where a kernel runs.
keywords: device, Device, accel.cpu, cuda, cuda_count, devices, JAC_CUDA, accelerator, gpu, PTX
---
# Devices

A device is where a tensor's data lives and where kernels run over it. `accel`
has two kinds:

- the processor of the machine the program runs on, `cpu()`,
- an NVIDIA accelerator, `cuda(i)`.

A tensor is made on the processor unless `on=` names another device, and a
kernel runs on the device its tensors live on. One program runs unchanged on a
machine with an accelerator and on one without.

```jac
import from accel { tensor, kernel, cpu, cuda, cuda_count, Device }

def doubled(i: int, v: tensor[f32, _]) {
    v[i] *= 2;
}

def pick -> Device {
    if cuda_count() > 0 {
        return cuda(0);
    }
    return cpu();
}

with entry {
    dev = pick();
    x = tensor[f32, _]([1.0, 2.0, 3.0], on=dev);
    kernel(doubled).run(3, x);
    print(x.tolist(), x.on is dev);
}
```

```output
[2.0, 4.0, 6.0] True
```

On a machine with an NVIDIA accelerator the tensor is in the accelerator's
memory and the kernel runs there; elsewhere both are the processor's. The
program prints the same either way.

## Finding devices

| Call | Gives |
|---|---|
| `cpu()` | the processor, as a `Device`. Every call gives the same object |
| `cuda_count()` | how many CUDA devices the machine has: 0 where it has no driver |
| `cuda(i)` | CUDA device `i` (0 without an argument). `RuntimeError` where the machine has no driver or no such device. Asked for again, the same `Device` |
| `devices()` | a list: the processor first, then each CUDA device in order of its index |
| `devices(kind)` | the devices of kind `"cpu"` or `"cuda"` alone. `ValueError` for another kind |

A `Device` has three fields a program reads:

| Field | Value |
|---|---|
| `kind` | `"cpu"` or `"cuda"` |
| `index` | which device of its kind: 0 for the processor |
| `name` | a CUDA device's model, as its driver names it; `""` for the processor |

`str(dev)` is `cpu` for the processor and `cuda:0`, `cuda:1`, ... for
accelerators. `dev.stream()` makes a stream of the device (see
[Streams, events and copies](streams.md)).

```jac
import from accel { cpu, cuda_count, devices }

with entry {
    print(cpu(), cpu().kind, cpu().index, cpu() is cpu());
    print(devices()[0] is cpu(), len(devices()) == 1 + cuda_count());
    try {
        devices("tpu");
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
cpu cpu 0 True
True True
ValueError: a device's kind is "cpu" or "cuda", and devices() was given 'tpu'
```

## The processor

On the processor a tensor's memory is the program's own, and a kernel runs as
native code on the program's threads. The indices of a `run` are split into
chunks on the threads a parallel `flow for` uses, `JAC_THREADS` of them (4
unless the environment variable is set), with one rule a `flow for` does not
have: no chunk is smaller than 1024 indices, below which starting a thread costs
more than the work. A `run` of fewer than 1024 indices is one chunk, its indices
in order. (A `flow for` of 10007 iterations at `JAC_THREADS=16` runs chunks of
626, the last of 617.)

A [grid kernel](grid-kernels.md) does not run on the processor.

## NVIDIA accelerators

NVIDIA's driver (`libcuda.so.1` on Linux, `nvcuda.dll` on Windows) is opened the
first time a program asks for a CUDA device, not when the program starts. So a
program that names `cuda` still starts and runs on a machine with no driver:
`cuda_count()` is 0 there, and `cuda(0)` raises `RuntimeError`: `this machine
has no CUDA driver`, followed on Linux and Windows by why the system could not
load its library. Only the library of the system the program was built for is
looked for; macOS has none, so nothing is.

Running a program with `JAC_CUDA=off` in its environment gives it no CUDA
devices, whatever the machine has: `cuda_count()` is 0 and `cuda(0)` raises
`RuntimeError`. Use it to run a program on the processor of a machine that has
an accelerator.

Each of the machine's `cuda_count()` devices has its own context, memory and
default stream.

A tensor on an accelerator is in the accelerator's memory. Reading or writing an
item (`t[i]`), `t.tolist()` and `t.to(dev)` copy between that memory and the
program's.

This program needs a machine with an NVIDIA accelerator and its driver; it
compiles everywhere:

```jac
import from accel { tensor, kernel, cpu, cuda, cuda_count }

def saxpy(i: int, a: f32, x: tensor[f32, _], y: tensor[f32, _]) {
    y[i] = a * x[i] + y[i];
}

with entry {
    if cuda_count() > 0 {
        gpu = cuda(0);
        x = tensor[f32, _]([1.0, 2.0, 3.0, 4.0], on=gpu);
        y = tensor[f32, _](shape=4, fill=0.5, on=gpu);
        kernel(saxpy).run(4, 2.0, x, y);
        print(gpu, y.tolist(), y.to(cpu())[0]);
    }
}
```

With an accelerator it prints the line below, and without one, nothing:

```text
cuda:0 [2.5, 4.5, 6.5, 8.5] 2.5
```

## Where a tensor lives

`t.on` is the device a tensor lives on. `tensor[...](..., on=dev)` makes one
there, and `t.to(dev)` is a copy of `t` on `dev`: contiguous, row-major, of
`t`'s items alone. A tensor's device belongs to its value, not to its type: a
function taking a `tensor[f32, _]` takes one from any device.

Copies go between any two devices. Between two accelerators a copy goes through
the program's memory. [Streams, events and copies](streams.md) has
`copy_from`, queued copies, page-locked memory and `host()`, which gives
ordinary code a device tensor's elements.

## Where a kernel runs

A kernel runs on the device the tensors among its arguments live on, and they
all live on one device: tensors on two devices raise `ValueError`. With no
tensor among its arguments, a launch runs on the processor, or on its stream's
device when it is given `stream=`.

A launch (`run`, `launch`) returns when the kernel is done, and raises what the
kernel recorded, the same way on every device (see [Kernels](kernels.md)).

One program can use the processor and every accelerator together: tensors on
each, copies between any two, and one kernel launched on each, as its tensors
say.

## One kernel, compiled for every device

Every kernel is compiled for both kinds of device when the program is built:

- for the processor, as native code,
- for CUDA devices, as PTX that the program carries. The PTX is for compute
  capability 5.0 and later. A device's driver compiles it for that device the
  first time a kernel runs there.

`k.code("cuda")` is the PTX as text, in which each kernel the program launches
is an entry. The text is there on a machine with no accelerator too. It is `""`
for a kind of device the program has no code for, and for `"cuda"` in a program
built by a jac whose LLVM has no NVPTX target: such a program's kernels run
on the processor alone.

The PTX is `.version 6.0`, `.target sm_50`. Each kernel the program launches is
two entries: `jac_kernel_<n>` for a kernel it runs with `run`, or
`jac_grid_<n>` for a [grid kernel](grid-kernels.md), which takes tensors of
any strides, and its twin `jac_kernel_<n>_dense` (`jac_grid_<n>_dense`),
for tensors that are all contiguous. A helper marked `@noinline` is a `.func`
that the entries reach by `call.uni`.

```jac
import from accel { tensor, kernel }

def saxpy(i: int, a: f32, x: tensor[f32, _], y: tensor[f32, _]) {
    y[i] = a * x[i] + y[i];
}

with entry {
    k = kernel(saxpy);
    y = tensor[f32, _](shape=4, fill=0.5);
    k.run(4, 2.0, y, y);
    ptx = k.code("cuda");
    print(ptx == "" or (".target sm_50" in ptx and ".entry jac_kernel_" in ptx));
    print(k.code("other") == "");
}
```

```output
True
True
```

`k.compile(dev)` loads the program's code on `dev` and resolves the kernel
there, so that the kernel's first launch pays for neither. Where the device's
driver cannot compile the code (a block's shared memory larger than the device
has, for one), it raises `RuntimeError` with the driver's log. For the
processor there is nothing to load, and it returns at once.

## What goes wrong

| What | Result |
|---|---|
| `cuda(i)` on a machine with no driver, with no device `i`, or under `JAC_CUDA=off` | `RuntimeError` |
| `devices("tpu")` | `ValueError` |
| a launch whose tensors live on two devices, or whose `stream=` is another device's than its tensors' | `ValueError` |
| a grid kernel launched with tensors on the processor | `RuntimeError` |
| `k.compile(dev)` where the driver cannot compile the program's code | `RuntimeError`, with the driver's log |
