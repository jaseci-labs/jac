---
description: What a function needs from the place it runs (a space's host, a kernel, a parallel loop's threads), what each place provides, and the E1540 refusal where a place lacks a need.
keywords: requirements, place, where code runs, needs
---
# What code needs from the place it runs

Code runs in a place. Every place answers one question about a function the
same way: does the place provide everything the function's code needs? Where it
does not, the compiler refuses the construct that needs it, with `E1540`.

The places are:

- a native or wasm space
- a cpython space
- a node space
- a browser or hermes space
- a kernel run for each index (`k.run`, `k.begin`, a `flow for` over tensors;
  see [Kernels](kernels.md))
- a grid kernel (`k.launch`; see [Grid kernels](grid-kernels.md))
- the threads of a parallel `flow for`

A place asks a second question of the values it is handed: may a value of this
type go there? That is answered by the type alone, and is on its own page:
[What crosses into a place](crossing.md).

## What a function needs

A function needs what its code does. Each construct, each builtin and each
value's type brings needs of its own, and a function needs what the lambdas it
makes need.

| Need | What brings it |
|---|---|
| module state that can change | reading or writing a global that is not `comptime` |
| allocation | a display or a comprehension, an f-string, a closure, an `obj`'s constructor, a builtin that makes a str or a container, a generator |
| exceptions | `raise`, `try`, `assert`, `with` |
| a call no analysis follows | a call of a function value, a dynamic call or attribute (a method of an `any`, a Python or npm module's function), a function declared with no body that is no C function |
| C code | a use of C: a C function called or named, a C record made or named as a value, a C record's field, a C global (an import block's, a C module's, a Rust module's) |
| tasks | `await`, `flow` or `wait` of an expression, `async for` and `async with`, a call of an async function |
| a graph | `here`, `visitor`, `root`, an edge reference, a filter comprehension |
| changing or walking a graph | `++>`, `del -->`, `spawn` of this space's walker, `visit`, `report`, `disengage`, `skip` |
| loading a module | an `import` in a function |
| threads | a parallel `flow for`, atomics, thread-local state |
| a blocking read of stdin | `input()` |
| launching kernels | `kernel(f)` |
| the native runtime's intrinsics | the runtime's own builtins (`__sdiv`, the steps of a walk, ...) |
| the native runtime's own definitions | a function, class or global of the native runtime that a host's own runtime does not give |
| native memory | pointers, `pin`, `addressof`, the raw memory intrinsics |
| bit intrinsics | `popcount`, `clz`, `ctz`, `bswap`, `bitrev`, `rotl`, `rotr` |
| a float's bits | `__float_bits` and the other float bit intrinsics |
| values held in place | an `f32`, `f16`, `bf16` or a small float format, a vector, and an array or a struct of them |
| 128-bit ints | an `i128` or a `u128` |
| a conversion between a 128-bit int and a float | `f32(w)`, `i128(x)` and the implicit conversions |
| tensors | a tensor and its views |
| a kernel's intrinsics | `accel`'s atomics (`atomic_add`, `atomic_min`, `atomic_max`) and `fence()` |
| a grid's intrinsics | a thread's place (`thread_idx` and the rest), `barrier()`, `shared`, a warp's operations |
| changing what another thread reaches | a builtin that writes memory or state another thread reaches, `print(..., file=f)` |
| counted references | a value of a reference type: a str, a list, a dict, an `obj`, `None`, an `any`, a function value |

The diagnostic names a need by the text in the first column. Where one
construct brings several, it names the first in the table's order: reading a
global list is "module state that can change" before it is "counted
references". A grid's intrinsics bring a kernel's intrinsics too, so ordinary
code calling `thread_idx()` is refused for "a kernel's intrinsics", and a
kernel run for each index calling it for "a grid's intrinsics".

A value computed as the program compiles needs nothing: a `comptime` name, an
item of a `comptime` table, `i32.MAX`.

An `import` inside a function is not supported yet on any host (`E5090`), so
"loading a module" is a need no program has today.

## What each place provides

Each place provides every need but the ones it lacks.

| Place | Lacks |
|---|---|
| a native or wasm space | a kernel's intrinsics and a grid's intrinsics |
| a cpython space | the native runtime's intrinsics; the native runtime's own definitions, except its core's, which are Python's own builtins; C code; native memory; bit intrinsics; values held in place; tensors; launching kernels; a kernel's and a grid's intrinsics |
| a node space | what a cpython space lacks, and a float's bits, threads and a blocking read of stdin. Of the native runtime's definitions, it has those its own runtime gives |
| a browser or hermes space | what a node space lacks, and a graph and changing or walking one |
| a kernel run for each index | everything except numbers, values held in place, their bits (bit intrinsics and a float's bits), 128-bit ints, the tensors it is given (which it writes), a kernel's intrinsics, and the runtime's code that keeps to the same. It converts no 128-bit int to or from a float: no CUDA device has an instruction for it |
| a grid kernel | the same as a kernel run for each index, except that it has a grid's intrinsics |
| a parallel `flow for`'s threads | changing what another thread reaches, a call no analysis follows, C code, changing or walking a graph, tasks, loading a module, a blocking read of stdin, a kernel's and a grid's intrinsics |

A cpython or JavaScript space imports a module of the native runtime that its
host has no module of its own for (`accel`, `atomics`) as its declarations
alone. What the program uses of it is refused where it is used (`E1540`). A
module Python has is Python's in a cpython space.

## Callees run where their caller runs

A function's callees run in its place:

- every function a kernel calls is held to the kernel's device,
- every function a `flow for`'s body may run is held to its threads,
- every function of a space is held to the space's host.

So one function may be fine in one place and refused in another. `tally` below
makes a list. Ordinary code in a native space runs it. The kernel `scale` cannot
call it, because a device has no heap and counts no references:

```jac
# expect: E1540
import from accel { tensor, kernel }

def tally(x: f32) -> f32 {
    seen = [x];
    return x * f32(len(seen));
}

def scale(i: int, y: tensor[f32, _]) {
    y[i] = tally(y[i]);
}

with entry {
    print(tally(2.0));
    kernel(scale).run(4, tensor[f32, _](shape=4));
}
```

The error is reported where the need is, not at the launch. It names the need,
the place, and the calls that reach the construct (`in scale -> tally`):

```text
main.jac:5:5: error[E1540]: 'seen' (list[f32]) needs counted references, which a kernel run for each index does not provide (in scale -> tally)
```

A function that needs nothing a device lacks runs in every place. `smooth`
computes with numbers alone, so ordinary code, a named kernel and a `flow for`
over a tensor all call it and give the same values:

```jac
import from accel { tensor, kernel }

def smooth(x: f32) -> f32 {
    return x * 0.5 + 0.25;
}

def on_device(i: int, y: tensor[f32, _]) {
    y[i] = smooth(y[i]);
}

def over_tensor(y: tensor[f32, _]) {
    flow for i in range(len(y)) {
        y[i] = smooth(y[i]);
    }
}

with entry {
    xs: list[f32] = [0.0, 1.0, 2.0, 3.0];
    print([smooth(x) for x in xs]);
    y = tensor[f32, _]([0.0, 1.0, 2.0, 3.0]);
    kernel(on_device).run(4, y);
    print(y.tolist());
    z = tensor[f32, _]([0.0, 1.0, 2.0, 3.0]);
    over_tensor(z);
    print(z.tolist());
}
```

```output
[0.25, 0.75, 1.25, 1.75]
[0.25, 0.75, 1.25, 1.75]
[0.25, 0.75, 1.25, 1.75]
```

What the runtime's own code needs is refused at the program's call that reaches
it. `math.gamma()` reads a table that can change, so a kernel that calls it is
refused at the call:

```jac
# expect: E1540
import math;
import from accel { tensor, kernel }

def special(i: int, out: tensor[float, _]) {
    out[i] = math.gamma(out[i]);
}

with entry {
    kernel(special).run(2, tensor[float, _](shape=2));
}
```

```text
main.jac:6:14: error[E1540]: gamma() needs module state that can change, which a kernel run for each index does not provide (in special)
```

## A native space

A native or wasm space lacks only a kernel's and a grid's intrinsics. Calling
one from ordinary code is the one way native code gets `E1540`:

```jac
# expect: E1540
import from accel { thread_idx }

with entry {
    print(thread_idx(0));
}
```

```text
main.jac:5:11: error[E1540]: thread_idx() needs a kernel's intrinsics, which a native space does not provide (in module code)
```

## A cpython or JavaScript space

The same program is checked against its space's host. This module is the entry
of a space declared `space s: cpython { entry main; }` in the project's
`archwire.jac`, checked with `jac check --space s`:

<!-- example: not checked: needs a project with an archwire.jac that declares a cpython space -->
```jac
import from accel { tensor }

with entry {
    t = tensor[f32, _](shape=4, fill=0.5);
    v = simd[f32, 4](1.0);
    h: f32 = 1.5;
    print(popcount(5));
    a = array[int, 3](1, 2, 3);
    w = i128(5) * i128(3);
    print(a, w);
}
```

```text
main.jac:4:5: error[E1540]: 't' (tensor[f32, _]) needs tensors, which a cpython space does not provide (in module code)
main.jac:5:5: error[E1540]: 'v' (simd[f32, 4]) needs values held in place (narrow floats, vectors), which a cpython space does not provide (in module code)
main.jac:6:5: error[E1540]: 'h' (f32) needs values held in place (narrow floats, vectors), which a cpython space does not provide (in module code)
main.jac:7:11: error[E1540]: popcount() needs bit intrinsics, which a cpython space does not provide (in module code)
```

The array and the 128-bit int are not refused: a cpython or JavaScript space
holds an array as a list of its own and a 128-bit int as its host's int (see
[Arrays](arrays.md)). A node space refuses the same lines and, besides,
`__float_bits()` ("a float's bits") and `input()` ("a blocking read of stdin").
A browser space also refuses `root ++> n` ("a graph"). Each of them refuses a use
of C ("C code"), where it is written: a C function called or named, a C record
made, named as a value or its field used, a C global. A C declaration that
nothing uses, and a C record's name in a type, are not refused.

## Parallel loops are not refused

A parallel `flow for` whose body may run something its threads lack is not an
error. Its chunks run one after another on the calling thread instead, with the
same results. The thread rule is with the `flow for` statement
(`jac docs "flow for"`); [Parallel loops over tensors](parallel-loops.md) covers
the loops that are launched as kernels, which are held to a kernel's place and
are refused (`E1540`).

A class conforming to `Shared` is held to what a loop's threads provide in every
method (`E1541`); see [What crosses into a place](crossing.md).

## Provided, but not built yet

Where a place provides what a construct needs but the place's backend does not
lower the construct yet, the refusal is `E5090`, "jac does not support ...
yet", not `E1540`. A kernel's `**` of floats and its vectors of `bf16` are two:

```jac
# expect: E5090
import from accel { tensor, kernel }

def squared(i: int, y: tensor[f32, _]) {
    y[i] = y[i] ** 2;
}

with entry {
    kernel(squared).run(4, tensor[f32, _](shape=4));
}
```

```text
main.jac:5:12: error[E5090]: jac does not support a kernel applying '**' to floats yet
```

## Diagnostics

| Code | Reported when |
|---|---|
| `E1540` | a construct needs what its place does not provide. The message names the construct, the need, the place and the path of calls |
| `E1541` | a method of a class conforming to `Shared` writes the object's fields, or needs what a parallel loop's threads lack |
| `E5090` | the place provides what the construct needs, but its backend does not lower the construct yet |
