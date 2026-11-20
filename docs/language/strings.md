---
description: Text and bytes: the str, bytes and bytearray types, string literal forms and escapes, raw strings, adjacent literals, f-strings and format specs, and the common operations and methods.
keywords: str, string, bytes, bytearray, f-string, fstring, raw string, format spec, escape sequence, multistring
grammar: multistring, string_part, fstring, formatted_value
---
# Strings

`str` is immutable Unicode text. `bytes` is an immutable sequence of bytes and `bytearray` a
changeable one. A string literal is written in single, double or triple quotes, with an optional
prefix; several literals written side by side form one string.

## Literal forms

```ebnf
multistring ::= string_part+

string_part ::= STRING | fstring
```

| Form | Example | Meaning |
|---|---|---|
| `"..."`, `'...'` | `"it's"`, `'say "hi"'` | A string on one line. The two quote characters are equivalent. |
| `"""..."""`, `'''...'''` | | A string that may span lines; line breaks are part of it. |
| `r"..."` | `r"C:\new"` | Raw: a backslash is an ordinary character. |
| `b"..."` | `b"\x00\xff"` | `bytes`. Characters are ASCII; other bytes are written `\xNN`. |
| `rb"..."` | `rb"\d+"` | Raw bytes. |
| `f"..."` | `f"{n + 1} items"` | An f-string; see below. |

A prefix is written in lower case, with `r` before `b`: `R"..."`, `B"..."` and `br"..."` are errors
(E0162). Every form may use triple quotes. A string that
reaches the end of its line without closing is E0100.

### Escapes

In a string that is not raw:

| Escape | Character |
|---|---|
| `\n`, `\t`, `\r` | Line feed, tab, carriage return |
| `\\`, `\'`, `\"` | Backslash, quotes |
| `\a`, `\b`, `\f`, `\v` | Bell, backspace, form feed, vertical tab |
| `\0` ... `\777` | The character with that octal code (one to three digits) |
| `\xNN` | Two hex digits: a character in a `str`, a byte in `bytes` |
| `\uNNNN`, `\UNNNNNNNN` | A Unicode code point, four or eight hex digits (in a `str` only) |
| `\` at the end of a line | Nothing: the line break is left out |
| `\` and any other character | Both characters, unchanged |

`\N{name}` is not supported (E0110). Too few hex digits after `\x`, `\u` or `\U` is E0112.

```jac
with entry {
    print("tab\there", "q\"q", 'q\'q', "\x41\u00e9\U0001F600", "\101");
    print(r"C:\new\table", len(r"\n"), len("\n"));
    print("""triple "quoted"
over two lines""");
    print(b"bytes\x41", rb"\x41", len(rb"\x41"));
}
```

```output
tab	here q"q q'q Aé😀 A
C:\new\table 2 1
triple "quoted"
over two lines
b'bytesA' b'\\x41' 4
```

### Adjacent literals

String literals written one after another, with only whitespace between them, are one string.
f-strings may take part. The parts are all strings or all bytes; mixing them is E0151. Plain
literals are joined when the program compiles, into one constant: `len("x" "y" "z")` is `3`, and
the joined string is the same object each time it is evaluated. Only the parts next to an
f-string are joined as the program runs.

```jac
with entry {
    s = "one " "two " 'three';
    t = "n=" f"{1 + 1}" " done";
    b = b"ab" b"cd";
    print(s, t, b);
}
```

```output
one two three n=2 done b'abcd'
```

```jac
# expect: E0151
with entry {
    print(b"a" "b");
}
```

## f-strings

```ebnf
fstring ::= FSTRING_START (FSTRING_TEXT | formatted_value)* FSTRING_END

formatted_value ::= "{" value_or_yield CONVERSION? (":" (FSTRING_TEXT | formatted_value)*)? "}"
```

An f-string is text with replacement fields in braces. Each field's expression is evaluated, left
to right, when the f-string is; its value is formatted and placed in the text. The result is a
`str`.

- **`{expr}`** formats the value as `str(expr)` does.
- **`{expr!r}`**, **`!s`**, **`!a`** apply `repr`, `str` or `ascii` first. Any other conversion
  letter is E0143.
- **`{expr:spec}`** formats with a format spec (below). The spec may itself contain fields:
  `{x:{width}.2f}`.
- **`{{`** and **`}}`** are literal braces.
- The expression is any expression. It may contain quotes of the same kind as the f-string's and
  nested f-strings: `f"{d["k"]}"`.
- Escapes work in the text of an f-string as in any string. Triple-quoted f-strings span lines.

Not accepted: Python's `{x=}` debugging form (a syntax error), an empty field `{}` (E0005), and the
raw form `rf"..."` (E5090).

```jac
obj Point {
    has x: int = 1;

    def __str__ -> str {
        return f"P({self.x})";
    }
}

with entry {
    name = "ann";
    n = 42;
    d = {"k": 5};
    print(f"{name} is {n}, next {n + 1}");
    print(f"{name!r} {Point()} {d["k"]} {[n, n]} {None}");
    print(f"{{literal}} {f'{n}'} {"yes" if n > 1 else "no"}");
}
```

```output
ann is 42, next 43
'ann' P(1) 5 [42, 42] None
{literal} 42 yes
```

### Format specs

A spec has the form `[[fill]align][sign][#][0][width][,|_][.precision][type]`, as in Python.

| Part | Values |
|---|---|
| align | `<` left, `>` right, `^` centered, `=` padding after the sign (`format(-5, "=+6d")` is `-    5`); an optional fill character before it, any character (`"é^9"`) |
| sign | `+` a sign on positive numbers too; ` ` (space) a space before them; `-` only on negative ones (the default) |
| `z` | A negative zero, after rounding, shows as `0`: `format(-0.0, "z.2f")` is `0.00` |
| `#` | Prefix `0x`, `0b`, `0o` for the integer types below |
| `0` | Pad a number with zeros to the width, with a separator too: `format(1234567, "010,")` is `01,234,567` |
| width | Minimum number of characters |
| `,` or `_` | Thousands separator; `_` groups `b`, `o` and `x` digits by four: `format(255, "#_b")` is `0b1111_1111` |
| `.precision` | Digits after the point for `f`, `e` and `%`; significant digits for `g` and no type; on a `str`, the most characters kept (`format("hello", ".2")` is `he`) |
| type | `d` integer; `x`, `X`, `b`, `o` integer in hex, binary, octal; `c` the character of an integer code point; `f`, `F` fixed point; `e`, `E` exponent; `g`, `G` general; `n` as `g`; `%` percentage; `s` string |

- A float with no type is formatted as `g` is, but always with a digit after the point when it
  has one: `format(1e16, "")` is `1e+16`, `format(1234.5, ".3")` is `1.23e+03`.
- An `int` takes the float types too: `format(1234567, "e")` is `1.234567e+06`.
- A float is rounded half to even on its exact binary value: `format(2.5, ".0f")` is `2`,
  `format(0.375, ".2f")` is `0.38` (0.375 is exact), `format(0.125, ".2f")` is `0.12`.
- A `bool` with an empty spec is `True` or `False`; with any other spec it is its `int`:
  `format(True, ">5")` is `    1`.
- A value with no format of its own (a list, `None`, an `obj` without `__format__`) is its
  `str()` under an empty spec, and raises `TypeError: unsupported format string passed to
  list.__format__` under any other. An `obj` with `def __format__(spec: str) -> str` is given the
  spec by `format()`, by an f-string field (`""` for `{m}`, `,.2f` for `{m:,.2f}`) and by
  `str.format`.
- A spec that does not fit the value raises `ValueError` with Python's message when it is
  evaluated: `Unknown format code 'd' for object of type 'str'`, `Sign not allowed in string format
  specifier`, `Precision not allowed in integer format specifier`, `Cannot specify both ',' and
  '_'.`, `Format specifier missing precision`, `Invalid format specifier '10x10' for object of
  type 'int'`. A `c` past the last code point raises `OverflowError`.

```jac
obj Money {
    has v: float = 0.0;

    def __format__(spec: str) -> str {
        return "$" + format(self.v, spec if spec else ".2f");
    }
}

with entry {
    print(format(2.5, ".0f"), format(-0.0, "z.1f"), format(65, "c"), format(1e16, ""));
    print(format(255, "#_b"), format(True, ">5"), format([1], ""));
    m = Money(v=1234.5);
    print(f"{m}", f"{m:,.1f}", "{:.0f}".format(m));
}
```

```output
2 0.0 A 1e+16
0b1111_1111     1 [1]
$1234.50 $1,234.5 $1234
```

```jac
with entry {
    n = 42;
    pi = 3.14159;
    name = "ann";
    width = 8;
    print(f"{pi:.2f}|{n:5d}|{n:<5}|{n:^5}|{n:05d}|{n:+d}|");
    print(f"{name:*^9}|{name:>6}|{pi:{width}.2f}|");
    print(f"{n:x} {n:#x} {n:b} {n:o} {n:e} {1234567:,} {0.25:%}");
    try {
        print(f"{name:d}");
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
3.14|   42|42   | 42  |00042|+42|
***ann***|   ann|    3.14|
2a 0x2a 101010 52 4.200000e+01 1,234,567 25.000000%
ValueError: Unknown format code 'd' for object of type 'str'
```

`"...".format(...)` and the `%` operator format the same way:

```jac
with entry {
    print("{} and {}".format(1, "two"), "{a}-{b:03d}".format(a="x", b=7));
    print("%d items, %s, %.1f" % (3, "ok", 2.5));
}
```

```output
1 and two x-007
3 items, ok, 2.5
```

## `str`

A `str` is a sequence of Unicode code points. `len(s)` counts code points, not bytes; `s[i]` is a
one-character `str`. A `str` cannot be changed: assigning to `s[i]` is E1191.

Any code point is allowed, a lone surrogate (`"\ud800"`) too. Encoding one with the default error
handler raises `UnicodeEncodeError`, whose message gives its code-point index (`in position 1:
surrogates not allowed`); the `surrogatepass` handler encodes it
(`"\udfff".encode("utf-8", "surrogatepass")` is `b'\xed\xbf\xbf'`).

| Operation | Result |
|---|---|
| `s + t` | Concatenation. Both sides are strings: `"a" + 1` is E1110; write `"a" + str(1)`. |
| `s * n` | `s` repeated `n` times |
| `s[i]`, `s[-1]` | One character; `IndexError` when out of range |
| `s[a:b]`, `s[a:b:step]` | A slice; bounds past the end are clipped. See [Collections](collections.md). |
| `t in s`, `t not in s` | Substring test |
| `s == t`, `s < t` | Comparison by code points. Comparing a `str` with a number is E1110. |
| `for ch in s` | Each character in turn |
| `len(s)`, `str(v)`, `repr(v)`, `ord(ch)`, `chr(n)` | Length, conversions, code point of a character and back |

Methods worth knowing, all as in Python:

| Kind | Methods |
|---|---|
| Case | `upper`, `lower`, `capitalize`, `title` |
| Search | `find`, `index`, `count`, `startswith`, `endswith` |
| Split and join | `split`, `splitlines`, `partition`, `join` |
| Trim and pad | `strip`, `lstrip`, `rstrip`, `removeprefix`, `removesuffix`, `center`, `ljust`, `rjust`, `zfill` |
| Replace | `replace` |
| Tests | `isdigit`, `isalpha`, `isalnum`, `isspace`, `isupper`, `islower` |
| Convert | `encode`, `format` |

```jac
with entry {
    s = "Hello, World";
    print(len(s), s[0], s[-1], s[0:5], s[7:], s[::-1]);
    print("ell" in s, "z" not in s, s + "!", "ab" * 3, "a" < "b");
    print(s.upper(), s.split(", "), "-".join(["a", "b"]), s.replace("l", "L"));
    print(s.find("World"), s.startswith("He"), s.count("l"), "  pad ".strip(), "7".zfill(3));
    print(len("é"), len("é".encode()), ord("a"), chr(98));
}
```

```output
12 H d Hello World dlroW ,olleH
True True Hello, World! ababab True
HELLO, WORLD ['Hello', 'World'] a-b HeLLo, WorLd
7 True 3 pad 007
1 2 97 b
```

```jac
# expect: E1191, E1110 x2
with entry {
    s = "abc";
    s[0] = "x";
    print("a" + 1);
    print("a" == 1);
}
```

## `bytes` and `bytearray`

A `bytes` value is a sequence of integers from 0 to 255. Indexing gives an `int`; slicing gives
`bytes`. `bytearray` has the same operations and can also be changed in place.

| Operation | Result |
|---|---|
| `b[i]` | An `int` |
| `b[a:b]`, `b + c`, `b * n` | `bytes` |
| `x in b` | `x` is an `int` (one byte) or a `bytes` (a run of bytes) |
| `for x in b` | Each byte as an `int` |
| `s.encode()`, `b.decode()` | Between `str` and `bytes`, as UTF-8 by default |
| `bytes([65, 66])`, `bytes(3)` | From a list of ints; `n` zero bytes |
| `b.hex()`, `int.from_bytes(b, "big")`, `n.to_bytes(2, "big")` | Hex text; integers to and from bytes |
| `ba[i] = x`, `ba.append(x)`, `ba.extend(b)` | Change a `bytearray` in place |

```jac
with entry {
    b = b"hello";
    print(len(b), b[0], b[1:3], b + b"!", b"ell" in b, 104 in b);
    print(b.upper(), b.decode(), list(b[:2]), b.hex(), bytes([65, 66]), bytes(2));
    print("héllo".encode(), b"h\xc3\xa9llo".decode());

    ba = bytearray(b"abc");
    ba[0] = 65;
    ba.append(100);
    ba.extend(b"ef");
    print(ba, bytes(ba));
}
```

```output
5 104 b'el' b'hello!' True True
b'HELLO' hello [104, 101] 68656c6c6f b'AB' b'\x00\x00'
b'h\xc3\xa9llo' héllo
bytearray(b'Abcdef') b'Abcdef'
```

## Differences from Python

- `str` and `bytes` are keywords, so they cannot be reassigned or used as names.
- `"a" == 1` and `"a" < 1` are compile errors (E1110), not `False` and a `TypeError`.
- `f"{x=}"`, `rf"..."` and `\N{name}` are not accepted.
- An unknown escape such as `\q` is kept as written, without a warning.
