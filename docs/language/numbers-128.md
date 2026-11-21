---
description: The 128-bit integer types i128 and u128, their literals, conversions, text forms and what an any holds of one.
keywords: i128, u128, Int128, UInt128, 128-bit int
---
# 128-bit ints

`i128` and `u128` are the signed and unsigned 128-bit integers. They are
values in every function, as the other sized ints are (see
[Numbers](numbers.md)): their arithmetic, comparisons,
[wrapping and saturating operators and bit operations](numbers-wrapping.md)
are the sized ints' at 128 bits, and a result past the type's range raises
`OverflowError`. `int` stays 64 bits.

| Type | Range |
|---|---|
| `i128` | -2**127 to 2**127 - 1 |
| `u128` | 0 to 2**128 - 1 |

A 128-bit int is held in place, 16 bytes, where it is stored: in a local, a
[struct](structs.md)'s field, a [packed list](packed-lists.md)'s element.

## Literals, MIN and MAX

A literal written where a 128-bit type is wanted may be of any size the type
holds: `u128(0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF)` is 2**128 - 1, and
`i128(-170141183460469231731687303715884105728)` is the least `i128`. A
literal the type does not hold is an error (E1126).

`i128.MIN`, `i128.MAX`, `u128.MIN` and `u128.MAX` are the types' ends, as
every sized type's `MIN` and `MAX` are. They are compile-time values and are
available in a [kernel](../accel/kernels.md) too.

## Arithmetic

```jac
def fact(n: int) -> u128 {
    r: u128 = 1;
    for i in range(2, n + 1) {
        r = r * u128(i);
    }
    return r;
}

with entry {
    print(fact(34));
    try {
        print(fact(35));
    } except OverflowError as e {
        print("35!:", e);
    }
    w: i128 = 1;
    w = w << 100;
    print(w, w // 3, w % 1000, -w, w > 5);
    print(w +% w, i128.MAX +| w, popcount(w), clz(w), ctz(w));
    print(i128.MIN, u128.MAX);
}
```

```output
295232799039604140847618609643520000000
35!: integer overflow
1267650600228229401496703205376 422550200076076467165567735125 376 -1267650600228229401496703205376 True
2535301200456458802993406410752 170141183460469231731687303715884105727 1 27 100
-170141183460469231731687303715884105728 340282366920938463463374607431768211455
```

The operators are the sized ints' rules at 128 bits: `//` floors and `%`
takes the divisor's sign (`i128(7) // i128(-2)` is -4, `i128(-7) % i128(2)`
is 1), `>>` keeps the sign, `~w` is `-w - 1`, and `**` is exact up to the
type's range and raises `OverflowError` past it (`i128(2) ** i128(127)`
raises, `i128(-2) ** i128(127)` is `i128.MIN`). In a
[kernel](../accel/kernels.md), a 128-bit overflow, and an `int(w)` that
does not fit, is a fault the run raises as `OverflowError` ("integer
overflow in kernel ...").

A 128-bit int mixes with a narrower sized int it holds, and with an int
literal: `w + u8(9)` and `w + 1` are `i128`s. It does not mix with an `int`
variable (E1128), and an `int` is not given where an `i128` is wanted
(E1001): write `i128(n)`.

## Conversions

| Conversion | What it does |
|---|---|
| `i128(x)`, `u128(x)` of another int | Widens it. `u128` of a negative value raises `OverflowError`. |
| `int(w)`, `u64(w)`, `i32(w)`, ... | The same value, or `OverflowError` where it does not fit. |
| `float(w)`, `f32(w)` and the other floats | The float nearest it. |
| `i128(f)`, `u128(f)` of a float | Rounds toward zero. `ValueError` for a NaN, `OverflowError` past the type's range. |
| `T.wrap(x)`, to or from a 128-bit int | The low bits of `x` at `T`'s width, read as a `T`, as for the narrower types: `u128.wrap(-1)` is `u128.MAX`, `u8.wrap(u128.MAX)` is 255. It never raises. |

```jac
with entry {
    n = 7;
    w = i128(n) << 100;
    print(int(w >> 90), u64(w >> 40), float(w), f32(w));
    print(i128(-2.5), i128(1e30));
    print(u128.wrap(-1) == u128.MAX, u8.wrap(u128.MAX), i64.wrap(w), i128.wrap(u64.MAX));
    try {
        print(int(w));
    } except OverflowError as e {
        print("int(w):", e);
    }
    try {
        print(u128(1e40));
    } except OverflowError as e {
        print("u128(1e40):", e);
    }
}
```

```output
7168 8070450532247928832 8.873554201597606e+30 8.873554e+30
-2 1000000000000000019884624838656
True 255 0 18446744073709551615
int(w): integer overflow
u128(1e40): integer overflow
```

A CUDA kernel converts none to or from a float (E1540): the device has no
instruction for it.

## Text and hashing

`str()`, `repr()`, `print`, f-strings and `format()` give a 128-bit int's
text, with every int presentation type (`x`, `b`, `o`, `,`, `_`, width and
alignment) and the float ones (`e`, `f`). `hex()`, `oct()` and `bin()` work
too. `hash()` of one is the hash of the int it equals, so
`hash(i128(5)) == hash(5)`, and a 128-bit int is a dict's key or a set's
member.

```jac
with entry {
    w = i128(1) << 100;
    print(f"{w:x} {w:,} {w:e}");
    print(hex(w), bin(i128(5)), format(w, "_d"));
    print(hash(i128(5)) == hash(5), {w: "key"}[w]);
}
```

```output
10000000000000000000000000 1,267,650,600,228,229,401,496,703,205,376 1.267651e+30
0x10000000000000000000000000 0b101 1_267_650_600_228_229_401_496_703_205_376
True key
```

## In an any

An `any` holds a 128-bit int boxed: an instance of the runtime's `Int128`
or `UInt128` class, equal to the int it holds. `x as i128` (or `as u128`)
takes it back out, and takes an ordinary `int` held in an `any` too:
`as u128` of a negative one raises `OverflowError`.

128-bit ints and `int`s in one `list[any]` compare, sort and take `in` and
`max` by value. A `list[i128]` seen as a `list[any]` is the same list: an
`int` appended through it is converted to an `i128`.

```jac
with entry {
    w = i128(1) << 100;
    box: any = w;
    print(type(box).__name__, box == w, box as i128);
    small: any = u128(3);
    print(type(small).__name__, small == 3);
    n: any = -12;
    print(n as i128);
    try {
        print(n as u128);
    } except OverflowError as e {
        print("as u128:", e);
    }
    xs: list[i128] = [i128(3), i128(1)];
    seen: list[any] = xs;
    seen.append(2);
    mixed: list[any] = [w, 5, u128(4)];
    print(sorted(xs), max(mixed), 5 in mixed);
}
```

```output
Int128 True 1267650600228229401496703205376
UInt128 True
-12
as u128: integer overflow
[1, 2, 3] 1267650600228229401496703205376 True
```

## Other hosts

On a cpython space a 128-bit int is the Python int it holds. A cpython
space and a JavaScript host both check the type's range as native code
does: a result past it raises `OverflowError`.

## What is rejected

```jac
# expect: E1126, E1128, E1001
with entry {
    n = 5;
    big = u128(340282366920938463463374607431768211456);
    w: i128 = 9;
    print(w + n);
    v: i128 = n;
}
```

| Code | Meaning |
|---|---|
| E1126 | A literal does not fit the 128-bit type it is written for. |
| E1128 | A 128-bit int is mixed with an `int` variable; convert one side. |
| E1001 | An `int` is given where a 128-bit int is wanted, or the other way round. |

## Differences from Python

In Python every int is of any size. Here only a compile-time int is (see
[Compile-time evaluation](compile-time.md)); where a program needs more than
64 bits as it runs, it says so with `i128` or `u128`, and arithmetic past 128
bits raises `OverflowError`.
