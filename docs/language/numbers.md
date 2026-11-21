---
description: The number types (int, float and the fixed-width ints and floats), their literals, how they convert and mix, and when arithmetic raises OverflowError.
keywords: int, float, f64, i8, u8, i16, u16, i32, u32, i64, u64, MIN, MAX, numbers, sized int, integer overflow
grammar: signed_number
---
# Numbers

A number has one of a fixed set of types, each with a fixed size. Integer
arithmetic is checked: a result its type cannot hold raises `OverflowError`
instead of wrapping or growing. Number types never mix silently where a value
could be lost: the compiler either widens the smaller type or asks for a
conversion by name.

## The types

| Type | What it holds |
|---|---|
| `int` | A signed 64-bit integer, -2**63 to 2**63 - 1. The type of an int literal. |
| `i8`, `i16`, `i32`, `i64` | Signed integers of 8, 16, 32 and 64 bits (the sized ints). |
| `u8`, `u16`, `u32`, `u64` | Unsigned integers of 8, 16, 32 and 64 bits. |
| `i128`, `u128` | 128-bit integers. See [128-bit ints](numbers-128.md). |
| `float`, `f64` | The 64-bit IEEE float (binary64). Two names for one type. The type of a float literal. |
| `f32`, `f16`, `bf16` | The narrow floats. See [Narrow floats](numbers-floats.md). |
| `f8e4m3fn`, `f8e5m2`, `f4e2m1fn` | Storage formats for tensor elements, not number types. See [Small float formats](numbers-float-formats.md). |

`int` and `i64` have the same range and are still two types: an `i64` goes
where an `int` is wanted, and an `int` becomes an `i64` only by `i64(x)`.
`bool` is described in [Types](types.md); in arithmetic `True` is 1 and
`False` is 0.

Every type name is a reserved word, so none of them names a variable, a
field or a function.

## Literals

| Form | Examples | Type |
|---|---|---|
| Decimal | `42`, `1_000_000` | `int` |
| Hexadecimal, octal, binary | `0x1F`, `0o17`, `0b101` (the prefix letter in lower case; hex digits in either) | `int` |
| Float | `0.5`, `.5`, `1e3`, `1.5e-3`, `2.5e10` | `float` |

A base prefix and an exponent's `e` are written in lower case: `0XFF` and `1E3` are errors (E0163).
Underscores between digits are ignored. A digit must follow the point, so
`1.` is not a float literal. There are no type suffixes: `5u8` is not a
literal, and a literal takes a narrower type from where it stands.

- **An int literal beside a sized int, or where a sized type is wanted,
  is of that type** and must fit it: `level: u8 = 250`, `k + 1` for a `k`
  of type `i8`. One that does not fit is an error (E1126).
- **An int literal with nothing asking for another type is an `int`**, so
  it must fit 64 signed bits. A larger one is written where a `u64`, `i128`
  or `u128` is wanted: `big: u64 = 18446744073709551615`.
- **A float literal is of the float type wanted of it**: `h: f16 = 0.5`,
  `a * 2.0` for an `a` of type `f32`.
- **An int where a float is wanted becomes that float**: `x: float = 1`.

A negative literal is the literal negated (`t: i8 = -128` fits). In a
`match` pattern and in a mapping pattern's key, a number is written with its
sign by a production of its own:

```ebnf
signed_number ::= "-"? (FLOAT | INT)
```

```jac
def sign(x: int) -> str {
    match x {
        case -1:
            return "minus one";
        case 0:
            return "zero";
        case _:
            return "other";
    }
}

with entry {
    print(0x1F, 0b101, 0o17, 1_000_000, .5, 1e3, 1.5e-3);
    big: u64 = 18446744073709551615;
    print(big, sign(-1), sign(7));
}
```

```output
31 5 15 1000000 0.5 1000.0 0.0015
18446744073709551615 minus one other
```

## Checked arithmetic

`+`, `-`, `*`, `**`, `<<`, unary `-` and `abs()` on ints are checked at
the type of the operation. A result outside that type's range raises
`OverflowError` ("integer overflow"). The check is at the type's own width:
an `i8` sum overflows past 127, a `u8` difference below 0. `//` overflows in
one case only, a signed type's least value divided by -1 (`i8(-128) // -1`,
`i64.MIN // -1`); `%` never does. Each operation is checked on its own, so
a computation whose every step stays in range gives its exact result.

An assignment whose value raises leaves its target as it was, an augmented
one too: after `x += 1` raises for `x = i64.MAX`, `x` is still `i64.MAX`.

```jac
with entry {
    x = 9223372036854775807;
    try {
        x += 1;
    } except OverflowError as e {
        print("int:", e, x == 9223372036854775807);
    }
    a: u8 = 200;
    b: u8 = 100;
    try {
        print(a + b);
    } except OverflowError as e {
        print("u8:", e);
    }
    c: i8 = -128;
    try {
        print(-c);
    } except OverflowError as e {
        print("negation:", e);
    }
    try {
        print(c // -1);
    } except OverflowError as e {
        print("floor division:", e);
    }
    print(c % -1, c // 1, ~a, a >> 2, a & b, a ^ b);
    try {
        print(1 << (x - 9223372036854775744));
    } except OverflowError as e {
        print("shift:", e);
    }
    try {
        print(a << 8);
    } except OverflowError as e {
        print("u8 shift:", e);
    }
}
```

```output
int: integer overflow True
u8: integer overflow
negation: integer overflow
floor division: integer overflow
0 -128 55 50 64 172
shift: integer overflow
u8 shift: integer overflow
```

- **A left shift is checked as the arithmetic is.** One that loses bits, or
  whose count is at or past the width, raises `OverflowError` with the
  message every overflow has (`integer overflow`), whatever the int type.
  On an `int`, a negative count raises `ValueError` ("negative shift
  count"), for `>>` too, and `>>` never overflows: it keeps the sign
  (`-8 >> 1` is -4), and a count past the width gives 0, or -1 for a
  negative value. On a sized type (`i8` to `u64`) a count outside the
  width, a negative one included, is an overflow for `>>` as well.
- **Arithmetic that is meant to wrap or to stop at the type's ends says so
  with its operator**: `a +% b` wraps and `a +| b` saturates. See
  [Wrapping and saturating arithmetic](numbers-wrapping.md), which also has
  the bit operations (`popcount`, `rotl`, ...).
- **The bitwise operators** (`&`, `|`, `^`, `~`) work on a value's bits at
  its own width and signedness, and never raise: `~u8(200)` is 55 and
  `~i8(3)` is -4.
- **Float arithmetic is IEEE's and never raises for overflow**:
  `1e308 * 10` is `inf`. Dividing by zero (`/`, `//` or `%`) raises
  `ZeroDivisionError` ("division by zero") for floats and ints alike.

Division and powers follow Python's rules:

| Expression | Result |
|---|---|
| `7 / 2` | `3.5`: `/` of two ints is a `float` |
| `7 // 2`, `-7 // 2` | `3`, `-4`: floor division rounds down |
| `7 % -2` | `-1`: the remainder has the divisor's sign |
| `2 ** 10` | `1024`, an `int` |
| `2 ** -1` | `0.5`: a negative literal exponent makes a `float` |
| `2 ** n` for an int `n` that turns out negative | raises `ValueError`: convert the base with `float()` |

## Mixing types

An operator joins its two operands to one type, and computes and checks the
result there.

| Operands | Result |
|---|---|
| Two sized ints, one of which holds every value of the other | the wider one: `u8 + i16` is an `i16`, `u32 + i64` an `i64` |
| Two sized ints, neither holding the other (`u8` and `i8`, `i16` and `u32`) | error E1128: convert one side |
| A sized int and an int literal | the sized type |
| A sized int of 32 bits or fewer, or an `i64`, and an `int` | `int` |
| A `u64`, `i128` or `u128` and an `int` variable | error E1128 |
| Any int and a `float` | `float` |
| Any int and a narrow float | that narrow float |
| Two different float types | error E1128, see [Narrow floats](numbers-floats.md) |

An unsigned type is held by a signed type only when the signed one is
strictly wider: `u8` fits `i16`, and `u64` fits no signed type but `i128`.
Comparisons (`==`, `<`, ...) join their operands the same way, so
`u8(1) == i8(1)` is E1128 too. A sized int equals the `int` of the same
value and hashes as it does, so the two meet in `in`, `max`, sorting and
dict keys: a `dict[u8, str]` is indexed by an int literal.

```jac
with entry {
    a: u8 = 200;
    b: i16 = -3;
    n = 5;
    print(a + b, a + 1, a + n, a * 2.5);
    print(a > n, a == 200.0);
}
```

```output
197 201 205 500.0
True True
```

## Conversions

A type's name called on a number converts to it: `int(x)`, `u8(x)`,
`i64(x)`, `float(x)`, `f32(x)`.

| Conversion | What it does |
|---|---|
| int type of an int | The same value. Raises `OverflowError` where it does not fit (`u8(256)`, `u8(-1)`, `int(u64.MAX)`). A literal that does not fit is refused when the program compiles (E1126). |
| int type of a float | Rounds toward zero, then checks the range: `int(3.9)` is 3, `i8(-3.9)` is -3, `u64(-0.5)` is 0. Raises `OverflowError` where the result does not fit (`u64(-1.0)`) or the float is an infinity, `ValueError` for a NaN. |
| `T.wrap(x)`, for a sized int type `T` | The low bits of the int `x` at `T`'s width, read as a `T`: `u8.wrap(300)` is 44, `i64.wrap(u64.MAX)` is -1. It never raises. |
| `float(x)`, `f64(x)` of an int | The float nearest it: `float(u64.MAX)` is `1.8446744073709552e+19`. |
| `float(x)` of a narrow float | The same value, exactly. |

The sized-int conversions take a number, not text (`u8("12")` is E1053);
`int("42")` and `float("1.5")` parse text.

Without a conversion, a number goes where another type is wanted only when
nothing can be lost:

- a sized int where a wider sized int that holds it is wanted, or where an
  `int` is wanted (for all but `u64`, `i128` and `u128`);
- any int where a `float` or a narrow float is wanted.

Everything else is an error (E1001, or E1053 for a call's argument): an
`int` where an `i8` is wanted, an `i8` where a `u8` is, a `float` where an
`int` is.

The one place a sized int is made without its name is where C takes it,
whose width is the library's: an `int` given to a C function's sized-int
parameter, or stored in a C record's sized-int field, narrows to that type,
checked as `i8(n)` checks it, and raises `OverflowError` there when it does
not fit. A `float` given where C takes an `f32` rounds to it as `f32(x)`
does. See [C libraries](../interop/c-libraries.md#types-in-a-declaration).

`x as T` does not convert. It asserts that a value already is a `T`: an
`any` holding 300 asserted `as i8` raises `OverflowError` when the program
runs (see [Types](types.md)). A float is never an int, so `3.9 as int` is an
error (E1203); use `int(3.9)`. Nor is an `int` an `i8`, or an `i16` an `i8`:
a cast from an int type to one that does not hold all of its values is the
same error. To bring an `int` into a sized type, convert it by name: `i8(n)`
checks the range and `i8.wrap(n)` wraps.

```jac
def half(x: u8) -> u8 {
    return x // 2;
}

with entry {
    n = 300;
    wide: i16 = half(250);
    print(wide, int(3.9), i8(-3.9), float(7), u64(1.8e19), u64(-0.5));
    print(u8.wrap(n), i64.wrap(u64.MAX), i8.wrap(200));
    try {
        print(u8(n));
    } except OverflowError as e {
        print("u8(300):", e);
    }
    try {
        print(int(float("nan")));
    } except ValueError as e {
        print("int(nan):", e);
    }
}
```

```output
125 3 -3 7.0 18000000000000000000 0
44 -1 -56
u8(300): integer overflow
int(nan): cannot convert float NaN to integer
```

## MIN and MAX

Each sized int type has its least and greatest values as `MIN` and `MAX`:
`i8.MIN`, `u32.MAX`, `i128.MAX`. They are compile-time values. `int` and the
float types have none; `i64.MIN` and `i64.MAX` are an `int`'s ends.

```jac
with entry {
    print(i8.MIN, i8.MAX, u8.MIN, u8.MAX);
    print(i64.MIN, i64.MAX, u64.MAX);
}
```

```output
-128 127 0 255
-9223372036854775808 9223372036854775807 18446744073709551615
```

## A number in an any

A sized int of 64 bits or fewer stored in an `any` is an int: `type()` of
it is `int`, and it equals the `int` of the same value. Assigning an `any`
to a sized type checks its range when the program runs and raises
`OverflowError` where the value does not fit.

```jac
with entry {
    a: u8 = 200;
    box: any = a;
    print(box, type(box), box == 200);
    big: any = 300;
    try {
        b: i8 = big;
        print(b);
    } except OverflowError as e {
        print("any to i8:", e);
    }
}
```

```output
200 <class 'int'> True
any to i8: integer overflow
```

## How numbers are held

Inside a function, a sized int local narrower than 64 bits is an integer of
its width, with overflow checked at that width, so a loop carrying an `i32`
count computes in 32 bits. One that a closure captures, or a generator
keeps between its yields, is checked at its width too. Between functions, in
an `obj`'s field and in an `any`, such a value is a 64-bit word. A [struct](structs.md) holds each
field at its width, and so do a [packed list](packed-lists.md)
(`list[u8]` is a byte an item), a view of C memory and a
[tensor](../accel/tensors.md).

## What is rejected

```jac
# expect: E1126 x2, E1128 x2, E1001 x2, E1203 x3
with entry {
    n = 5;
    a: u8 = 300;
    b = 12345678901234567890;
    c: u8 = 1;
    d: i8 = 1;
    print(c + d);
    e: u64 = 7;
    print(e + n);
    f: i8 = n;
    g: int = 1.5;
    print(3.9 as int);
    print(n as i8, n as u64);
}
```

| Code | Meaning |
|---|---|
| E1126 | A literal does not fit the type wanted of it (`300` in a `u8`, a literal past 2**63 - 1 as an `int`). |
| E1128 | An operator mixes two int types of which neither holds the other, or two float types. Convert one side by name. |
| E1001 | A value of one number type is given where another is wanted and no widening applies. |
| E1203 | `as` is asked to turn a float into an int, or an int type into one that does not hold all of its values. |

## Differences from Python and the reference design

- In Python an `int` grows without limit; here `int` is 64 bits and
  `2 ** 63` raises `OverflowError`. A compile-time int is exact, see
  [Compile-time evaluation](compile-time.md).
- In Python `1 << 64` is a larger int; here a left shift that loses bits
  raises `OverflowError`.
- In Python `2 ** n` with a negative `n` gives a float whatever `n`'s type;
  here an `int ** int` whose exponent is negative when the program runs
  raises `ValueError`, since its type was decided as `int`.
- Python has one int and one float type. The sized types here are separate
  types the compiler keeps apart.
- On a cpython space an `int` is Python's own, and a sized type keeps its
  range. On a JavaScript host (`node`, `browser`, `hermes`) an `int` is a
  JavaScript number, exact up to 2**53 - 1 in magnitude, and a result past
  that raises `OverflowError`.
