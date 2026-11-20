---
description: The narrow float types f32, f16 and bf16: their formats and arithmetic, why float types do not mix, how to convert between them, and where they are available.
keywords: f32, f16, bf16, narrow float, binary32, binary16, brain float
---
# Narrow floats

`f32`, `f16` and `bf16` are float types narrower than `float`. Each is a
type of its own, with its format's values and its format's arithmetic:
every result is rounded once, to nearest even, in that format. `float` (also
written `f64`) is described in [Numbers](numbers.md).

| Type | Format | Bits |
|---|---|---|
| `f32` | IEEE binary32 | 32 |
| `f16` | IEEE binary16 | 16 |
| `bf16` | The 16-bit brain float: binary32's sign and exponent, with 8 bits of precision | 16 |

A narrow float prints in the fewest digits that read back as the same value
of its type, so an `f32` holding the binary32 nearest 1.1 prints `1.1`.

```jac
with entry {
    a: f32 = 1.1;
    b: float = 1.1;
    print(a * a);
    print(b * b);
    print(f64(a) * b);
    h: f16 = 1.1;
    g: bf16 = 1.1;
    print(h * h, h / 3, h + 1000);
    print(g * g, g / 3, g + 1000);
}
```

```output
1.21
1.2100000000000002
1.2100000262260437
1.209 0.3665 1001.0
1.21 0.367 1000.0
```

`a * a` is binary32's product. `f64(a) * b` is a `float`: one side was
converted by name, and the conversion shows the value the `f32` really
holds. `g + 1000` is 1000.0 because `bf16`'s 8 bits of precision cannot
hold 1001.1.

## Float types do not mix

An operator takes two floats of the same type. Two different float types
(`f32` and `float`, `f32` and `f16`) are an error (E1128), and so is giving
one where another is wanted: an `f32` where a `float` is wanted or the
other way round is E1001 (E1053 for a call's argument). Convert one side by
name. Only where C takes an `f32`, a C function's parameter or a C record's
field, does a `float` round to it by itself, as `f32(x)` rounds it (see
[C libraries](../interop/c-libraries.md#types-in-a-declaration)).

| Conversion | What it does |
|---|---|
| `f32(x)`, `f16(x)`, `bf16(x)` | Rounds a number to the type, once, to nearest even. A value past the format's range is an infinity, one too small for it is zero (`f32(1e-46)` is `0.0`), and a NaN stays a NaN. None of these raises. |
| `float(x)`, `f64(x)` | Widens a narrow float, exactly. |
| `int(x)` and the sized ints | Rounds toward zero, as for a `float`. |

What does combine with a narrow float without a conversion:

- **A float literal is of the float type wanted of it.** In `a * 2.0` and
  `h: f16 = 0.5` the literal is an `f32` and an `f16`.
- **An int beside a narrow float becomes that float**: `a + 1`, `v / 2`,
  and an int given where an `f32` is wanted. An int is rounded to the
  narrow type once, not through the `float` nearest it.

```jac
def halve(v: f32) -> f32 {
    return v / 2;
}

with entry {
    a: f32 = 1.1;
    print(a * 2.0, a + 1, halve(3), halve(a));
    print(f32(16777217), f16(70000), float(a), int(a * 10.0));
    big: f32 = 16777216.0;
    print(big + 1.0, big + 2.0, f32(0.1) + f32(0.2), 0.1 + 0.2);
    print(round(a), round(a * 3, 1), sum([a, a], f32(1.0)), f32(1e-46));
}
```

```output
2.2 2.1 1.5 0.55
16777216.0 inf 1.100000023841858 11
16777216.0 16777218.0 0.3 0.30000000000000004
1 3.3 3.2 0.0
```

The builtins that compute on numbers take narrow floats and give them back:
`abs`, `min`, `max`, `sorted`, `round(x, n)` with a number of digits, and
`sum`, which adds in the narrow type and takes a start of it
(`sum(xs, f32(1.0))`). So do `//`, `%` and `**`. `round(x)` with no digits
gives an `int`, as it does of a `float`: `round(f32(1.1))` is 1.
The `math` module's functions take an `f32` where they have a binary32
form (`math.sqrt(a)` of an `f32` is an `f32`).

## In an any

Where a value's type is not known until the program runs (an `any`, a
Python value), a narrow float is the `float` equal to it. Assigning the
`any` to an `f32`, or `f32(x)`, rounds it back.

```jac
with entry {
    a: f32 = 1.1;
    x: any = a;
    back: f32 = x;
    print(x, type(x) is float, back, f32(x) == a);
}
```

```output
1.100000023841858 True 1.1 True
```

## How they are held

- **A function's own `f32` locals are binary32 floats in its code.** A loop
  carrying an `f32` sum computes in that type.
- **Between functions, in an `obj`'s field and in an `any`, an `f32` is a
  64-bit word**: the `float` equal to it.
- **A [struct](structs.md) holds one at its width**, and so do a
  [packed list](packed-lists.md) (a `list[f32]` holds 4 bytes an item), a
  view of C memory (`ptr[f32].view(n)`) and a
  [tensor](../accel/tensors.md) (`tensor[f32, _]`).
- **`f16` and `bf16` locals are held as the `float` equal to them.** The
  x86-64 baseline converts to and from those formats only by calling a
  routine, and a loop holding them in their format would make more of
  those calls. Their arithmetic is still their format's.
- **At a C boundary** they are C's `float`, `_Float16` and `__bf16`.

Wherever it is held, a float keeps its exact bits: a negative zero and a
NaN's sign survive a branch, a loop that carries it, a closure's capture and
a generator's yields.

## Where they are available

Narrow floats are native code's. A `cpython`, `node`, `browser` or `hermes`
space has the one float, and a narrow one there is refused (E1540). A
WebAssembly program has `f32` and `f16` and no `bf16` (E5090): its code
generator does not convert to the format.

## What is rejected

```jac
# expect: E1128 x2, E1001 x2, E1053, E1110
def takes_float(x: float) -> float {
    return x;
}

with entry {
    a: f32 = 1.5;
    b: float = 2.5;
    h: f16 = 0.5;
    print(a + b);
    print(a < h);
    c: f32 = b;
    d: float = a;
    takes_float(a);
    print(a & 1);
}
```

| Code | Meaning |
|---|---|
| E1128 | An operator or a comparison mixes two float types. Convert one side: `f64(a) + b` or `a + f32(b)`. |
| E1001 | A float of one type is assigned where another float type is wanted. |
| E1053 | A float of one type is passed where a parameter wants another, or a float conversion is given something that is not a number (`f32("1.5")`). |
| E1110 | A bitwise operator is applied to a float. |
| E1540 | A narrow float is used in a space whose host has only the one float. |
| E5090 | `bf16` is used in a WebAssembly program. |

## Differences from Python

Python has one float type, the 64-bit one. Here the narrow floats are
separate types and nothing promotes one to another: `a * b` of an `f32` and
a `float` is an error, so a computation's precision is what the program
wrote.
