---
description: Printing from a kernel for debugging - what a kernel prints, the launch's print buffer the records go to, when and in what order the host prints them, and the records dropped past its end.
keywords: kernel print, print_buffer, print buffer, printing from a kernel
---
# Printing from a kernel

A [kernel](kernels.md) may call `print` to debug it. Each call appends a record
to its launch's print buffer, and when the launch is done the program prints
the records with its own `print`, so they go where its `print` goes. Kernels on
the processor print through the same buffer as kernels on an accelerator, so
both behave alike.

```jac
import from accel { tensor, kernel }

def tell(i: int, y: tensor[f32, _], flag: bool) {
    if i == 5 {
        print("item", i, "is", y[i], "and", flag, f16(0.1), u64(1) << 63, 1.0 / 3);
        print(y[i] * 2, y[i] / 3, sep=", ", end=" (two values)\n");
    }
}

with entry {
    y = tensor[f32, _]([float(k) - 7.5 for k in range(8)]);
    kernel(tell).run(8, y, True);
}
```

```output
item 5 is -2.5 and True 0.1 9223372036854775808 0.3333333333333333
-5.0, -0.8333333 (two values)
```

## What a kernel prints

`print(...)` in a kernel, or in a function a kernel calls, takes:

- ints and floats of 64 bits or fewer, and bools,
- str literals,
- `sep=` and `end=`, each a str literal.

Each value is shown as ordinary code shows its type: `0.1` of an `f32`, an
`f16` or a `bf16`, `True` of a bool, `9223372036854775808` of a `u64`. An
element of a small float format (`f8e4m3fn` and the others) reads as an `f32`,
and is shown as one.

What a device lacks is `E1540`: an f-string needs allocation, and a str held in
a variable needs counted references. A value a kernel does not print yet is
`E5090`, naming the argument: a tensor, a vector, an array, a struct, a 128-bit
int.

```jac
# expect: E1540, E5090 x2
import from accel { tensor, kernel }

def noisy(i: int, y: tensor[f32, _], w: i128) {
    print(f"at {i}");
    print(y);
    print(w);
}

with entry {
    kernel(noisy).run(2, tensor[f32, _](shape=2), i128(1));
}
```

```text
main.jac:4:11: error[E1540]: an f-string needs allocation, which a kernel run for each index does not provide (in noisy)
main.jac:5:11: error[E5090]: jac does not support a kernel printing tensor[f32, _] ('y'): it prints numbers of 64 bits or fewer, bools and str literals yet
main.jac:6:11: error[E5090]: jac does not support a kernel printing i128 ('w'): it prints numbers of 64 bits or fewer, bools and str literals yet
```

## The print buffer

Each launch has a print buffer of its own. A call appends a record to it: a
word naming the call and a word for each value, at the place an atomic bump of
the buffer's cursor gives it. The text is the host's, kept with the program's
kernels: a str literal is never on the device.

`print_buffer=n`, after a launch's arguments, sets the buffer's size in bytes:
`k.run(count, ..., print_buffer=4096)`, and the same for `begin`, `launch` and
`begin_launch`. It is 64 KiB (65536) unless given, and 0 to 34359738360 bytes
(`ValueError` otherwise, before anything is launched).

A record past the buffer's end is counted and dropped, and after the records
it kept, one line says how many were:

```jac
import from accel { tensor, kernel }

def check(i: int, y: tensor[f32, _]) {
    if y[i] < 0 {
        print("negative");
    }
}

with entry {
    y = tensor[f32, _]([float(k % 9) - 7.5 for k in range(100)]);
    kernel(check).run(len(y), y, print_buffer=32);
    try {
        kernel(check).run(len(y), y, print_buffer=-8);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
negative
negative
negative
negative
check: 85 prints dropped past the 32 bytes of its launch's print buffer
ValueError: a launch's print buffer is of 0 to 34359738360 bytes, and it was given -8
```

A record of `print("negative")` is one word, 8 bytes, so 32 bytes hold four of
the 89 calls. A record of `print("negative at", i, ":", y[i])` is three words,
24 bytes: the default buffer holds 2730 of them.

## When and in what order

The host prints a launch's records when the launch is done: when `run` or
`launch` returns, and for a begun launch at its `synchronize()`, or its
stream's or an event's (see [Streams, events and copies](streams.md)). They are
printed before the launch raises what the kernel recorded, so a kernel's last
words before a fault are seen.

The records are printed in the order of the bumps that placed them. Between
the threads of a launch that order is unspecified: on the processor a run of
1024 indices or more is split into chunks on several threads, and on an
accelerator every thread runs at once. Print from one index, or sort what was
printed, where the order matters.

```jac
import from accel { tensor, kernel }

def failing(i: int, y: tensor[f32, _]) {
    print("at", i);
    y[i + 1] = 0.0;
}

with entry {
    y = tensor[f32, _](shape=1);
    l = kernel(failing).begin(1, y);
    print("begun");
    try {
        l.synchronize();
    } except IndexError as e {
        print("IndexError:", e);
    }
}
```

```output
begun
at 0
IndexError: tensor index out of range in kernel failing
```

On the processor `begin` ran the kernel before it returned, and its record was
still printed at `synchronize()`.
