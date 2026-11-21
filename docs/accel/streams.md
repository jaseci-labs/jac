---
description: Launches not waited for (begin, Launch), streams that queue a device's work in order, events that mark and time points of it, copies between tensors and devices, page-locked memory, and host mappings of a device tensor.
keywords: stream, Stream, Event, Launch, begin, synchronize, record, elapsed, copy_from, pinned, page-locked memory, host mapping, t.host
---
# Streams, events and copies

A launch waits for its kernel: `k.run(...)` and `k.launch(...)` return when the
kernel is done. This page has the work a program queues and waits for later:
launches that are begun and not waited for, the streams that order a device's
work, the events that mark points in a stream, and the copies that move a
tensor's items between devices.

```jac
import from accel { tensor, kernel, cpu }

def doubled(i: int, v: tensor[f32, _]) {
    v[i] *= 2;
}

with entry {
    s = cpu().stream();
    t = tensor[f32, _]([1.0, 2.0, 3.0]);
    start = s.record();
    began = kernel(doubled).begin(3, t, stream=s);
    kernel(doubled).run(2, t, stream=s);
    end = s.record();
    end.synchronize();
    print(s, t.tolist(), began.done(), start.elapsed(end) >= 0.0);
}
```

```output
stream of cpu [4.0, 8.0, 6.0] True True
```

On the processor all of this is done as it is queued. On an NVIDIA accelerator
the same calls queue work the device runs while the program goes on.

## Launches not waited for

`k.begin(count, ...)` is `run` not waited for, and `k.begin_launch(grid, block,
...)` is a [grid kernel's](grid-kernels.md) `launch` not waited for. Each takes
the same arguments as the launch it begins, and gives a `Launch`:

| Method | Does |
|---|---|
| `l.done()` | whether the kernel has finished, without waiting |
| `l.synchronize()` | waits for the kernel, prints what it printed, and raises what it recorded, as `run` does. Waited for once, it returns at once again |

Each launch in flight has a fault of its own, so two begun launches each raise
their own.

What a begun kernel writes is to be read after `synchronize()`. A tensor's
items, `tolist()` and `to()` are copies the driver orders after the launches
before them on the device, so they are right even before it, and wait for the
kernel.

The arguments are read when the launch is begun: a struct changed after
`begin(...)` is not seen by the kernel.

On the processor, `begin` runs the kernel before it returns: `done()` is `True`
at once. What the kernel recorded is still raised by `synchronize()`, and what
it printed is printed there:

```jac
import from accel { tensor, kernel, Launch }

def bad_index(i: int, v: tensor[i32, _]) {
    v[i + 1] = 0;
}

with entry {
    w = tensor[i32, _]([1, 2, 3]);
    l: Launch = kernel(bad_index).begin(3, w);
    print(l.done());
    try {
        l.synchronize();
    } except IndexError as e {
        print("IndexError:", e);
    }
    l.synchronize();
    print("waited once");
}
```

```output
True
IndexError: tensor index out of range in kernel bad_index
waited once
```

## Streams

A stream is an ordered queue of one device's work. `dev.stream()` makes one, a
`Stream`, and every launch takes `stream=s` after its arguments: `k.run(n, x, y,
stream=s)`, `k.begin(...)`, `k.launch(...)` and `k.begin_launch(...)`.

- What is queued on one stream runs in the order it was queued, and at once
  with what other streams run.
- A launch with no tensor among its arguments runs on its stream's device. A
  launch whose tensors live on another device than its stream's raises
  `ValueError`.
- `s.synchronize()` finishes the launches queued on the stream so far: it
  prints what they printed and raises the first fault one recorded, in the
  order they were queued. Their faults are raised once: the next
  `synchronize()` raises nothing.
- A stream holds the tensors its work uses until the work is known to be done,
  so a tensor the program drops stays alive while a kernel may use it.
- `str(s)` is `stream of cpu`, `stream of cuda:0`, ...

Streams are ordered with the device's default stream as CUDA's blocking
streams are: a waited launch, a tensor's item, `tolist()` and an ordinary copy
wait for what the streams were given before them.

On the processor a stream's work is done as it is queued, since the processor's
`begin` runs the kernel before it returns.

```jac
import from accel { tensor, kernel, cpu }

def bad_index(i: int, v: tensor[i32, _]) {
    v[i + 1] = 0;
}

def overflow(i: int, v: tensor[i32, _]) {
    v[i] = v[i] * 100000;
}

with entry {
    s = cpu().stream();
    w = tensor[i32, _]([1, 2, 30000]);
    kernel(bad_index).begin(3, w, stream=s);
    kernel(overflow).begin(3, w, stream=s);
    try {
        s.synchronize();
    } except (IndexError, OverflowError) as e {
        print(type(e).__name__ + ":", e);
    }
    s.synchronize();
    print("nothing more");
}
```

```output
IndexError: tensor index out of range in kernel bad_index
nothing more
```

The first launch queued recorded the first fault. The second one's is dropped
with it.

## Events

`s.record()` is an `Event`: a point in the stream, after everything queued on it
so far.

| Method | Does |
|---|---|
| `e.done()` | whether everything queued before it is done, without waiting |
| `e.synchronize()` | waits for that, and finishes those launches as the stream's `synchronize()` does |
| `a.elapsed(b)` | the seconds from event `a` to a later event `b` of the same device, as the device's driver times them, waiting for both. A `float` |

On an accelerator `elapsed` is good to about half a microsecond. On the
processor an event is done when it is recorded, and its time is when it was
recorded. Two events of two devices raise `ValueError`.

This program runs two kernels at once on two streams of an accelerator, and
times the first. It needs a machine with an NVIDIA accelerator and its driver;
it compiles everywhere:

```jac
import from accel { tensor, kernel, cuda }

def scale(i: int, a: f32, y: tensor[f32, _]) {
    y[i] = a * y[i];
}

with entry {
    gpu = cuda(0);
    s1 = gpu.stream();
    s2 = gpu.stream();
    x = tensor[f32, _](shape=1 << 20, fill=1.0, on=gpu);
    y = tensor[f32, _](shape=1 << 20, fill=2.0, on=gpu);
    start = s1.record();
    kernel(scale).begin(len(x), 2.0, x, stream=s1);
    kernel(scale).begin(len(y), 3.0, y, stream=s2);
    end = s1.record();
    s1.synchronize();
    s2.synchronize();
    print(start.elapsed(end), x[0], y[0]);
}
```

It prints the seconds the first kernel took, then `2.0 6.0`.

## Copies

`dst.copy_from(src)` copies a tensor's items over another's, between any two
devices.

- The two have as many items, of one element type (`ValueError` otherwise).
  Their shapes may differ: item `k` of each, in row-major order of their
  indices, is copied.
- It writes `dst`'s items alone: of a view, the view's items, never the
  elements between them.
- Between two accelerators, the copy goes through the program's memory.

`t.to(dev)` is a new tensor on `dev` holding a copy of `t`'s items (see
[Devices](devices.md)); `copy_from` writes a tensor that exists.

```jac
import from accel { tensor }

with entry {
    m = tensor[f32, 4, 6]([[float(10 * r + c) for c in range(6)] for r in range(4)]);
    rows = tensor[f32, _](shape=6);
    rows.copy_from(m[1:3, ::2]);
    print(rows.tolist());
    m[:, 2].copy_from(tensor[f32, _]([-1.0, -2.0, -3.0, -4.0]));
    print(m[0].tolist(), m[3, 2]);
    try {
        rows.copy_from(tensor[f32, _](shape=4));
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
[10.0, 12.0, 14.0, 20.0, 22.0, 24.0]
[0.0, 1.0, -1.0, 3.0, 4.0, 5.0] -4.0
ValueError: a tensor of 6 elements copied from one of 4: a copy is of as many elements of one type
```

### Copies on a stream

`dst.copy_from(src, stream=s)` and `t.to(dev, stream=s)` queue the copy on a
stream of either device (`ValueError` for a stream of a third). A copy of a
tensor that is not contiguous goes through the program's memory after the work
the stream was given, and is done before the call returns.

### Page-locked memory

`tensor[f32, _](shape=n, pinned=True)` is a tensor on the processor in
page-locked memory, which a CUDA device copies to and from directly: about four
times faster than ordinary memory, and a copy queued on a stream returns before
the copy is done. `t.pinned` says whether a tensor's memory is page-locked. It
is `False` on a machine with no accelerator to lock it for, and `pinned=True`
with `on=` an accelerator raises `ValueError`.

```jac
import from accel { tensor, cpu, cuda_count }

with entry {
    p = tensor[f32, _](shape=3, pinned=True);
    print(p.pinned == (cuda_count() > 0));
    s = cpu().stream();
    p.copy_from(tensor[f32, _]([1.0, 2.0, 3.0]), stream=s);
    s.synchronize();
    print(p.tolist());
}
```

```output
True
[1.0, 2.0, 3.0]
```

## Host mappings

Ordinary code reaches a tensor's items in the program's memory. A tensor on an
accelerator is in the accelerator's memory, so ordinary code reaches it through
a host mapping: `with t.host() as h { ... }`.

- `h` is a tensor on the processor holding a copy of `t`'s elements, read and
  written in place.
- It is copied back into `t` when the block is left, however it is left: a
  `raise` out of the block writes back too.
- `t.host("r")` copies in alone, `t.host("w")` copies back alone (`h` starts as
  zeros, so every element is to be written), and `t.host("rw")`, the default,
  both. Another mode raises `ValueError`.
- Of a view, `h` is a contiguous tensor of the view's shape, and only the view's
  items are written back.
- For a tensor on the processor, `h` is `t`'s own items (a view of them) and
  nothing is copied. So what mode `"r"` writes is written to `t`, and mode
  `"w"` starts with `t`'s items.
- Only a tensor `host()` gave is entered: `with t as h` raises `TypeError`.

Vector loads and stores in ordinary code, and the struct elements of a tensor,
are reached in the program's memory too: of a tensor on an accelerator they
need a host mapping (see [Tensor elements as vectors](vector-memory.md) and
[Tensors](tensors.md)).

```jac
import from accel { tensor, kernel }

def doubled(i: int, v: tensor[f32, _]) {
    v[i] *= 2;
}

with entry {
    t = tensor[f32, 2, 3]([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]);
    with t.host() as h {
        h[1, 2] = h[0, 0] + 40;
        kernel(doubled).run(3, h[0]);
        print(h.on, h.shape);
    }
    print(t.tolist());
    try {
        with t.host() as h {
            h[0, 0] = -1.0;
            raise KeyError("out");
        }
    } except KeyError {
        print("left by a raise:", t[0, 0]);
    }
    try {
        t.host("a");
    } except ValueError as e {
        print("ValueError:", e);
    }
    try {
        with t as h {
            print(h);
        }
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
cpu (2, 3)
[2.0, 4.0, 6.0, 4.0, 5.0, 41.0]
left by a raise: -1.0
ValueError: a host mapping's mode is "r", "w" or "rw", and it was given 'a'
TypeError: a tensor is entered as `with t.host() as h`, which maps it to the program's memory
```

## What goes wrong

| What | Result |
|---|---|
| `l.synchronize()`, `s.synchronize()` or `e.synchronize()` after a kernel recorded a fault | the fault's exception (`IndexError`, `OverflowError`, ...), once |
| a launch whose tensors live on another device than its `stream=` | `ValueError` |
| `copy_from` between tensors of other counts or element types | `ValueError` |
| a copy queued on a stream of neither of its devices | `ValueError` |
| `a.elapsed(b)` of events of two devices | `ValueError` |
| `pinned=True` with `on=` an accelerator | `ValueError` |
| `t.host(mode)` of a mode not `"r"`, `"w"` or `"rw"` | `ValueError` |
| `with t as h` | `TypeError` |
| `stream=` given anything but a `Stream` | `E1053` |
