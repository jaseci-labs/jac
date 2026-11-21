---
description: The builtin functions that make one value from another (int, float, complex, str, bytes and the containers) and the text forms repr, ascii, format, chr, ord, bin, oct and hex, with how text is read as a number.
keywords: builtin conversions, numbers from text, repr, ascii, format, chr, ord, bin, hex, oct
---
# Builtin conversions

The builtins that make a value of one type from another, and those that give a value's text.
They are Python's, with Python's results and messages unless this page says otherwise. The
other builtins are on [Builtin functions](builtins.md) (`jac docs builtins`).

## Making values

| Call | Result | Differs from Python |
|---|---|---|
| `int(x)`, `int(text, base)` | An int from a number (truncating toward zero), a bool, a str or bytes of digits | `int()` with no argument is refused (E1050): write `0`. `OverflowError` past 64 bits |
| `float(x)` | A float from a number or a str (`"1e3"`, `"inf"`, `"nan"`) | `float()` with no argument is refused: write `0.0` |
| `complex(real=0, imag=0)`, `complex(text)` | A complex number; either part may be given by keyword (`complex(imag=-2.0)`); of an object, its `__complex__` | There is no imaginary literal: write `complex(0, 1)`, not `1j` |
| `bool(x)` | The truth of `x` | |
| `str(x)`, `str(b, encoding, errors="strict")` | The text of `x`; with an encoding, the str the bytes or bytearray `b` encode, as `b.decode(encoding, errors)` | `str()` is refused: write `""` |
| `bytes(x)`, `bytes(s, encoding, errors="strict")` | `x` zero bytes for an int, else the bytes of an iterable of ints, a bytes, a bytearray or a memoryview; `bytes()` is `b""`. With an encoding, the str `s` encoded, as `s.encode(encoding, errors)` | |
| `bytearray(x)` | As `bytes(x)`, mutable | One argument only |
| `list(it)`, `tuple(it)`, `set(it)`, `frozenset(it)` | A container of the items of any iterable | With no argument, the variable must be annotated; `tuple()` is refused: write `()` |
| `dict(...)` | A dict from a mapping (a dict, or an object with `keys()` and `[]`, such as a `defaultdict`), an iterable of pairs, keyword arguments, or a mix. An `any` is read as what it holds | |
| `range(stop)`, `range(start, stop, step=1)` | The ints from `start` up to `stop` by `step` | |
| `slice(stop)`, `slice(start, stop, step=None)` | A slice object, as `a[start:stop:step]` makes | |
| `memoryview(b)` | A view of a bytes or bytearray: see [bytes and bytearray](bytes-methods.md) | |
| `object()` | A new featureless object | |

```jac
with entry {
    print(int("ff", 16), int(-3.9), float("1e3"), complex(1, 2), bool([]), str(2.50));
    print(bytes(2), bytes([104, 105]), bytearray(b"ab"), list("ab"), tuple(range(3)));
    print(dict(a=1, b=2), dict([("k", 1)]), dict(zip("ab", [1, 2])), set([1, 1, 2]));
    empty: list[int] = list();
    print(empty, range(10, 0, -3), list(range(10, 0, -3)), slice(1, 5, 2));
    try {
        int("3.5");
    } except ValueError as e {
        print(e);
    }
}
```

```output
255 -3 1000.0 (1+2j) False 2.5
b'\x00\x00' b'hi' bytearray(b'ab') ['a', 'b'] (0, 1, 2)
{'a': 1, 'b': 2} {'k': 1} {'a': 1, 'b': 2} {1, 2}
[] range(10, 0, -3) [10, 7, 4, 1] slice(1, 5, 2)
invalid literal for int() with base 10: '3.5'
```

A `range` prints with its start always shown and its step only when it is not 1:
`print(range(3))` prints `range(0, 3)`.

## Numbers from text

`int`, `float` and `complex` read a str as CPython 3.15 does. `int` and `float` also take a
`bytes` or a `bytearray` of ASCII text (`float(b"2.5")`, `int(b"17", 8)`).

| Call | Reads | Refuses, with `ValueError` |
|---|---|---|
| `float(s)` | Whitespace around the number (ASCII or Unicode, such as U+00A0), a sign, one `_` between two digits (`"1_000.5"`, `"1e1_0"`), `".5"`, `"5."`, an exponent, `inf`, `infinity` and `nan` in any case, the decimal digits of any script (`"٣.١٤"` is `3.14`) | `"0x10"`, `"1__0"`, `"_1"`, `"1_"`, `"1._5"`, `""`, `" "`, `"1e"`, `"1e+"`, `"infinit"`, `"1 2"`: `could not convert string to float: '1__0'` |
| `int(s, base=10)` | The same whitespace, sign, `_` and digits; bases 2 to 36, and base 0, which reads a `0x`, `0o` or `0b` prefix (an `_` may follow it: `int("0x_ff", 0)` is 255) | A bad digit, an empty string, a lone sign, a misplaced `_`, a bare prefix, and in base 0 a leading zero (`"017"`; `"00"` is 0): `invalid literal for int() with base 16: '0x'`. Another base: `int() base must be >= 2 and <= 36, or 0` |
| `complex(s)` | `"1+2j"`, `"j"`, `"-J"`, a parenthesized form with whitespace inside (`"( 1-2j )"`), `_` between digits, `inf` and `nan` parts | Whitespace around the sign (`"1 + 2j"`), `"1+-2j"`, `""`, `"()"`, `"(1"`, `"1j2"`, `"0x10"`: `complex() arg is a malformed string`. A misplaced `_`: `could not convert string to complex: '1__0'` |

`float(s)` is correctly rounded: it gives the double nearest the decimal value, an exact tie
rounding to even, so `float(repr(x)) == x` for every float. Past the largest double it is `inf`,
below the smallest it is `0.0` or `-0.0`. `int(s)` past 64 bits raises `OverflowError`.

```jac
def number(text: str) {
    try {
        print(repr(text), float(text));
    } except ValueError as e {
        print(e);
    }
}

with entry {
    for text in [" 1_000.5\n", " -InF", ".5e-3", "٣.١٤", "1__0", "0x10"] {
        number(text);
    }
    print(
        int("0x_ff", 0),
        int(" -42 "),
        int("z", 36),
        int(b"17", 8),
        complex("( 1-2j )"),
        complex("-j"),
    );
    print(float("1e500"), float("-1e-500"), float("9007199254740993"));
    try {
        int("017", 0);
    } except ValueError as e {
        print(e);
    }
    try {
        complex("1 + 2j");
    } except ValueError as e {
        print(e);
    }
}
```

```output
' 1_000.5\n' 1000.5
' -InF' -inf
'.5e-3' 0.0005
'٣.١٤' 3.14
could not convert string to float: '1__0'
could not convert string to float: '0x10'
255 -42 35 15 (1-2j) -1j
inf -0.0 9007199254740992.0
invalid literal for int() with base 0: '017'
complex() arg is a malformed string
```

## Text forms

| Call | Result |
|---|---|
| `repr(x)` | The text that shows `x` as source would write it; an object's `__repr__` |
| `ascii(x)` | As `repr`, with every non-ASCII character escaped by its code point: `\xNN` below 256, `\uNNNN` below 65536, else `\UNNNNNNNN` |
| `format(x, spec="")` | `x` formatted by a format spec, as in an f-string; an object's `__format__`. The specs are described with [str formatting](str-methods.md#formatting) |
| `chr(i)` | The one-character str of code point `i`; `ValueError` outside `0..0x10FFFF` |
| `ord(c)` | The code point of a one-character str; `TypeError` for another length |
| `bin(i)`, `oct(i)`, `hex(i)` | `'0b101'`, `'0o17'`, `'0xff'`, with `-` before the prefix for a negative int |

The `repr` of a bytes value is quoted with `'`, or with `"` when it holds a `'` and no `"`:
`repr(b"a'b")` is `b"a'b"`.

```jac
with entry {
    print(repr("it's"), repr(1.0), repr([1, "x"]), ascii("naïve ☃ \U0001f600"));
    print(format(3.14159, ".2f"), format(255, "#x"), format(1234567, ","), format("a", ">4"));
    print(chr(8364), ord("a"), bin(5), oct(8), hex(-255), repr(b"a'b\x00"));
}
```

```output
"it's" 1.0 [1, 'x'] 'na\xefve \u2603 \U0001f600'
3.14 0xff 1,234,567    a
€ 97 0b101 0o10 -0xff b"a'b\x00"
```

## Where to go next

- The other builtins: [Builtin functions](builtins.md).
- Methods of the values made here: [str](str-methods.md), [bytes](bytes-methods.md),
  [numbers](number-methods.md), [tuple, range and slice](tuple-methods.md).
