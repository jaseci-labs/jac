---
description: The methods and operators of int, float, complex and bool, and where numbers differ from Python's.
keywords: int methods, float methods, complex methods, bool methods, int.bit_length, int.bit_count, int.to_bytes, int.from_bytes, int.as_integer_ratio, int.conjugate, float.is_integer, float.as_integer_ratio, float.hex, float.fromhex, float.conjugate, complex.real, complex.imag, complex.conjugate
---
# int, float, complex and bool methods

The numbers of Python: `int`, `float`, `complex` and `bool`. This page covers their methods and
the operators' results; the sized types (`i32`, `u8`, `f32`, ...) and their rules are part of
the language (`jac docs i32`).

## int

An `int` is a 64-bit signed integer. Its operators give Python's results, and a result outside
`-2**63 .. 2**63 - 1` raises `OverflowError` where Python would grow the int.

| Expression | Result |
|---|---|
| `a + b`, `a - b`, `a * b` | An int |
| `a / b` | A float: `5 / 2` is `2.5` |
| `a // b`, `a % b` | Floor division and its remainder, with the sign of `b`: `-7 // 2` is `-4`, `-7 % 3` is `2` |
| `a ** b` | An int for `b >= 0`, a float for a negative `b`: `2 ** -1` is `0.5` |
| `a << n`, `a >> n`, `a & b`, `a \| b`, `a ^ b`, `~a` | Bit operations |
| `n.bit_length()` | The bits needed for `abs(n)`: `(255).bit_length()` is `8` |
| `n.bit_count()` | The number of one bits of `abs(n)` |
| `n.to_bytes(length=1, byteorder="big", signed=False)` | `n` as `length` bytes; `OverflowError` when it does not fit |
| `int.from_bytes(data, byteorder="big", signed=False)` | The int that bytes spell |
| `n.as_integer_ratio()` | `(n, 1)` |
| `n.conjugate()` | `n` |

```jac
with entry {
    print(7 // 2, -7 // 2, -7 % 3, 7 / 2, 2 ** 10, 2 ** -1, 1 << 10, 5 & 3, 5 | 3, 5 ^ 3, ~5);
    print((255).bit_length(), (7).bit_count(), (1024).to_bytes(2, "big"));
    print((-1).to_bytes(2, signed=True), (5).as_integer_ratio());
    print(int.from_bytes(b"\x01\x00", "big"), int.from_bytes(b"\xff", "little", signed=True));
    print(0xff, 0b101, 0o17, 1_000_000, 2 ** 62, 10 ** 18);
    try {
        print(2 ** 63);
    } except OverflowError as e {
        print("OverflowError:", e);
    }
    try {
        print(1 // 0);
    } except ZeroDivisionError as e {
        print("ZeroDivisionError:", e);
    }
}
```

```output
3 -4 2 3.5 1024 0.5 1024 1 7 6 -6
8 3 b'\x04\x00'
b'\xff\xff' (5, 1)
256 -1
255 5 15 1000000 4611686018427387904 1000000000000000000
OverflowError: integer overflow
ZeroDivisionError: division by zero
```

## float

A `float` is an IEEE 754 double, printed as Python prints it (the shortest text that reads back
the same). Dividing by zero raises `ZeroDivisionError`; a sum or product too large for a double
is `inf`, as in Python.

| Expression | Result |
|---|---|
| `x.is_integer()` | Whether `x` has no fractional part |
| `x.as_integer_ratio()` | The exact `(numerator, denominator)`: `(2.5).as_integer_ratio()` is `(5, 2)` |
| `x.hex()`, `float.fromhex(text)` | The exact hexadecimal form, and back |
| `x.conjugate()` | `x` |
| `int(x)`, `round(x)`, `math.floor(x)`, `math.ceil(x)` | An int: truncated, rounded half to even, rounded down, rounded up |

```jac
with entry {
    x = 2.5;
    print(x.is_integer(), (3.0).is_integer(), x.as_integer_ratio(), x.hex());
    print(float.fromhex("0x1.4p+1"), 0.1 + 0.2, 1 / 3, 1e16, 1.5e-5, 100.0, -0.0, 1e308 * 10);
    print(7.0 // 2, 7.5 % 2, int(x), round(x), round(3.5), round(2.675, 2));
    print(float("inf") > 1e308, float("nan") == float("nan"));
    try {
        print(1.0 / 0);
    } except ZeroDivisionError as e {
        print("ZeroDivisionError:", e);
    }
}
```

```output
False True (5, 2) 0x1.4000000000000p+1
2.5 0.30000000000000004 0.3333333333333333 1e+16 1.5e-05 100.0 -0.0 inf
3.0 1.5 2 2 4 2.67
True False
ZeroDivisionError: division by zero
```

## complex

A `complex` is a pair of doubles. There is no imaginary literal: make one with
`complex(real, imag)` or `complex("1+2j")`.

| Expression | Result |
|---|---|
| `z.real`, `z.imag` | Its parts, as floats |
| `z.conjugate()` | The complex conjugate |
| `abs(z)` | Its magnitude |
| `z + w`, `z - w`, `z * w`, `z / w`, `z ** w`, `-z`, `z == w` | Complex arithmetic; an int or float operand is widened |

Complex numbers have no order: `z < w` is a compile error (E1110). Functions on them are in
[`cmath`](math.md). An int or a float goes where a `complex` is declared, and is converted:
`def magnitude(z: complex) -> float` takes `magnitude(3)`. `complex(x)` of an object calls its
`__complex__`.

As in CPython: `complex(real=1.5)` and `complex(imag=-2.0)` take their parts by keyword; a
complex equal to an int or a float compares equal to it and hashes as it does, so
`complex(2, 0)` finds a dict entry stored under `2`; `repr` leaves out a zero real part unless it
is `-0.0` (`1j`, `(-0-1j)`, `(nan+infj)`). Division by zero raises
`ZeroDivisionError: division by zero`, `complex(0, 0) ** -1` raises
`ZeroDivisionError: zero to a negative or complex power`, and a power too large raises
`OverflowError: complex exponentiation`.

```jac
with entry {
    z = complex(3, 4);
    print(z, z.real, z.imag, z.conjugate(), abs(z), z + 1, z * z, z / complex(0, 1), z ** 2);
    print(complex("1-2j"), complex(1.5), z == complex(3, 4), repr(complex(0, 1)));
}
```

```output
(3+4j) 3.0 4.0 (3-4j) 5.0 (4+4j) (-7+24j) (4-3j) (-7+24j)
(1-2j) (1.5+0j) True 1j
```

## bool

`True` and `False`. `bool` is a subclass of `int` (`isinstance(True, int)`), and a bool in
arithmetic counts as `1` or `0`: `True + True` is the int `2`.

```jac
with entry {
    print(True + True, True and 5, False or "x", not 0, int(True), str(False), True == 1);
    print(bool(""), bool("0"), bool(0.0), bool([0]), bool(None), sum([True, False, True]));
}
```

```output
2 5 x True 1 False True
False True False True False 2
```

## Where they differ from Python

- **`int` does not grow past 64 bits.** `OverflowError` is raised by `+ - * ** <<`, by `abs` and
  unary minus of the smallest int, by `int()` of a float or text out of range, and by library
  functions whose result does not fit (`math.factorial(25)`).
- **`n.real`, `n.imag`, `n.numerator` and `n.denominator` are not members of `int` or `float`**
  (E1030). `complex` has `real` and `imag`.
- **There is no `1j` literal.**
- **Mixed arithmetic is typed when the program is compiled**: `min(1, 2.5)` is the float `1.0`.

## Where to go next

- `abs`, `round`, `divmod`, `pow`: [Builtin functions](builtins.md); `int`, `float`, `complex`,
  `bin`, `hex` and reading numbers from text: [Builtin conversions](builtins-conversions.md).
- [math and cmath](math.md), and `fractions`, `statistics`, `random` in
  [Standard-library modules](stdlib.md).
