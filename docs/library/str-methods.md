---
description: The methods and operators of str, with their signatures and where they differ from Python's.
keywords: str methods, string methods, str.capitalize, str.casefold, str.center, str.count, str.encode, str.endswith, str.expandtabs, str.find, str.format, str.format_map, str.index, str.isalnum, str.isalpha, str.isascii, str.isdecimal, str.isdigit, str.isidentifier, str.islower, str.isnumeric, str.isprintable, str.isspace, str.istitle, str.isupper, str.join, str.ljust, str.lower, str.lstrip, str.maketrans, str.partition, str.removeprefix, str.removesuffix, str.replace, str.rfind, str.rindex, str.rjust, str.rpartition, str.rsplit, str.rstrip, str.split, str.splitlines, str.startswith, str.strip, str.swapcase, str.title, str.translate, str.upper, str.zfill
---
# str methods

A `str` is an immutable sequence of Unicode characters. Its positions and its length count
characters (code points), as Python's do: `len("héllo")` is 5 and `"héllo"[1]` is `"é"`. Every
method of Python's `str` is here, with Python's results.

## Operators

| Expression | Result |
|---|---|
| `s + t`, `s * n` | Concatenation, repetition |
| `s[i]`, `s[a:b:c]` | The character at `i` (`IndexError: string index out of range` out of range), a slice |
| `t in s`, `t not in s` | Whether `t` occurs in `s` |
| `s == t`, `s < t`, ... | Comparison by code point |
| `for c in s` | Each character, as a one-character str |
| `s % values` | printf-style formatting: `"%d items, %.1f%%" % (3, 12.5)` |
| `f"{x:.2f}"` | An f-string; the format spec is the one `format()` and `str.format` take |

Assigning to `s[i]` is a compile error (E1191).

## Methods

`start` and `end` are optional positions, as in a slice.

| Method | Result |
|---|---|
| `s.capitalize()`, `s.casefold()`, `s.lower()`, `s.upper()`, `s.swapcase()`, `s.title()` | A copy in another case. Case mapping is Unicode's, with its special cases: `"straße".upper()` is `"STRASSE"` |
| `s.center(width, fillchar=" ")`, `s.ljust(...)`, `s.rjust(...)`, `s.zfill(width)` | `s` padded to `width` |
| `s.count(sub, start, end)` | How many times `sub` occurs, without overlap |
| `s.find(sub, start, end)`, `s.rfind(...)` | The first or last position of `sub`, or `-1` |
| `s.index(sub, start, end)`, `s.rindex(...)` | As `find`, raising `ValueError: substring not found` when `sub` is absent |
| `s.startswith(prefix, start, end)`, `s.endswith(suffix, start, end)` | Whether `s` starts or ends with a str, or with any str of a tuple |
| `s.removeprefix(prefix)`, `s.removesuffix(suffix)` | `s` without that prefix or suffix, when it has it |
| `s.strip(chars=None)`, `s.lstrip(...)`, `s.rstrip(...)` | `s` without leading and trailing whitespace, or without the characters in `chars` |
| `s.split(sep=None, maxsplit=-1)`, `s.rsplit(...)` | The parts of `s` between separators, as a `list[str]`. With no `sep`, runs of whitespace separate and empty parts are dropped |
| `s.splitlines(keepends=False)` | The lines of `s`, split at every line boundary Python splits at |
| `s.partition(sep)`, `s.rpartition(sep)` | `(before, sep, after)` around the first or last `sep`; `(s, "", "")` when it is absent |
| `sep.join(iterable)` | The strs of an iterable joined by `sep` |
| `s.replace(old, new, count=-1)` | `s` with `old` replaced by `new`, the first `count` times |
| `s.expandtabs(tabsize=8)` | `s` with tabs replaced by spaces up to the next tab stop |
| `s.encode(encoding="utf-8", errors="strict")` | The bytes of `s` in an encoding |
| `s.format(*args, **kwargs)`, `s.format_map(mapping)` | `s` with its `{}` fields replaced: `"{} {name:>4} {0[1]}"` |
| `s.translate(table)`, `str.maketrans(x, y="", z="")` | `s` with each character mapped through a table; `maketrans` builds the table |
| `s.isalnum()`, `s.isalpha()`, `s.isascii()`, `s.isdecimal()`, `s.isdigit()`, `s.isidentifier()`, `s.islower()`, `s.isnumeric()`, `s.isprintable()`, `s.isspace()`, `s.istitle()`, `s.isupper()` | Whether every character is of the class, by Unicode's character database |

```jac
with entry {
    s = "Hello, World";
    print(s.upper(), s.lower(), s.swapcase(), s.title(), "straße".upper());
    print(s.find("o"), s.rfind("o"), s.count("l"), s.startswith(("Hi", "He")), "z" in s);
    print(s.split(", "), " a  b ".split(), "a,b,c".split(",", 1), "a\nb\r\nc".splitlines());
    print(s.partition(", "), s.replace("l", "L", 2), s.strip("Hd"), s.removesuffix("World"));
    print("-".join(["a", "b"]), ", ".join(str(n) for n in range(3)), "7".zfill(3));
    print("x".center(5, "*"), "x".ljust(3) + "|", "x".rjust(3), len("héllo"), "héllo"[1]);
    print("ab1".isalnum(), "١٢".isdecimal(), "ß".isalpha(), "A b".istitle(), "".isdigit());
    print(s[::-1], s[7:], s * 2, s < "Help");
}
```

```output
HELLO, WORLD hello, world hELLO, wORLD Hello, World STRASSE
4 8 3 True False
['Hello', 'World'] ['a', 'b'] ['a', 'b,c'] ['a', 'b', 'c']
('Hello', ', ', 'World') HeLLo, World ello, Worl Hello, 
a-b 0, 1, 2 007
**x** x  |   x 5 é
True True True False False
dlroW ,olleH World Hello, WorldHello, World True
```

## Formatting

`str.format`, `format_map`, f-strings and `%` take Python's format specs: fill and alignment,
sign, `#`, zero padding, width, `,` grouping, precision and the type letters
(`d b o x X c e f g % s`). A field may index or read an attribute of its argument.

```jac
obj Point {
    has x: int = 1;
}

with entry {
    print("{:>5}|{:<5}|{:^5}|{:05d}|{:.3f}|{:,}".format("a", "b", "c", 42, 3.14159, 1234567));
    print("{0[1]} {1.x} {name}".format([1, 2], Point(), name="n"), "{k}".format_map({"k": 1}));
    print("%d %s %.2f %5d|%-5s|%x" % (1, "a", 2.5, 3, "b", 255));
    n = 255;
    print(f"{n:#x} {n:b} {n / 7:.3e} {n:+} {n!r:>6} {0.25:%}");
    try {
        print("{}".format());
    } except IndexError as e {
        print(e);
    }
}
```

```output
    a|b    |  c  |00042|3.142|1,234,567
2 1 n 1
1 a 2.50     3|b    |ff
0xff 11111111 3.643e+01 +255    255 25.000000%
Replacement index 0 out of range for positional args tuple
```

A format spec is read by CPython's rules for the value's type, and a spec the type does not take
raises CPython's `ValueError` (`Unknown format code 'd' for object of type 'str'`,
`Precision not allowed in integer format specifier`, `Cannot specify ',' with 's'.`).

- **A float rounds half to even on its exact binary value**: `format(2.5, ".0f")` is `2`,
  `format(0.125, ".2f")` is `0.12`, and `format(2.675, ".2f")` is `2.67`, because the double
  nearest 2.675 is a little below it.
- **`z` turns a negative zero into zero** after rounding: `format(-0.0, ".1f")` is `-0.0`,
  `format(-0.001, "z.2f")` is `0.00`. It is refused for an int or a str.

**printf-style `%`** takes the conversions `%s %r %a %d %i %x %X %o %e %E %f %g %G %c %%`, the
flags `-`, `+`, space, `0` and `#`, a width and a precision (`*` takes either from the
operands), `%(name)s` with a dict, and one operand that is not a tuple (`"%s" % 5`). `%c` takes
an int or a one-character str. Its errors are CPython's: `TypeError: not enough arguments for
format string`, `ValueError: unsupported format character 'z' (0x7a) at index 1`,
`TypeError: format requires a mapping`, `ValueError: incomplete format`,
`TypeError: %d format: a real number is required, not str`.

**`str.format`** numbers `{}` fields automatically, or takes `{0}`, `{name}`, `{0[1]}` and
`{0.attr}`; a spec may hold fields of its own (`"{0:{1}.{2}f}"`), and `{{` and `}}` are braces.
Its errors are CPython's: `ValueError: Single '{' encountered in format string`,
`ValueError: cannot switch from manual field specification to automatic field numbering`,
`IndexError: Replacement index 2 out of range for positional args tuple`, `KeyError: 'x'`,
`ValueError: Unknown conversion specifier q`, `ValueError: Max string recursion exceeded`.

```jac
with entry {
    print(format(2.5, ".0f"), format(0.125, ".2f"), format(2.675, ".2f"), format(-0.0, "z.1f"));
    print(
        "%*d|%-*d|%.*f" % (5, 1, 4, 2, 2, 3.14159),
        "%(n)03d" % {"n": 7},
        "%#x %c%c" % (255, 72, "i"),
    );
    print("{0:{1}.{2}f}|{{x}}".format(3.14159, 8, 2));
    try {
        print("%d %d" % (1,));
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
2 0.12 2.67 0.0
    1|2   |3.14 007 0xff Hi
    3.14|{x}
TypeError: not enough arguments for format string
```

## Encoding

`s.encode(encoding, errors)`, `bytes.decode`, `str(b, encoding, errors)` and
`bytes(s, encoding, errors)` take every encoding and error handler of
[`codecs`](codecs.md) (`jac docs codecs`), under the names and aliases CPython accepts: the
UTF family, ASCII and Latin-1, the code pages and ISO 8859 sets, the Mac and KOI8 sets, IDNA,
punycode, `unicode_escape` and the rest. The CJK multibyte encodings (`shift_jis`, `gbk`,
`big5`, `euc_kr`, ...) are not there and raise `LookupError: unknown encoding: shift_jis`, as an
unknown name does. The handlers are `strict`, `ignore`, `replace`, `backslashreplace`,
`xmlcharrefreplace`, `namereplace`, `surrogateescape` and `surrogatepass`, and any a program
registers with `codecs.register_error`. A character the encoding cannot hold raises
`UnicodeEncodeError` with CPython's message.

```jac
with entry {
    print("café".encode(), "café".encode("latin-1"), "café".encode("ascii", "replace"));
    print(
        "café €".encode("cp1252"), "hé".encode("utf-16"), "π".encode("ascii", "xmlcharrefreplace")
    );
    print(b"\x93hi\x94".decode("cp1252"), str(b"caf\xc3\xa9", "utf-8"), bytes("é", "latin-1"));
    try {
        "café".encode("ascii");
    } except UnicodeEncodeError as e {
        print(e);
    }
    try {
        "café".encode("shift_jis");
    } except LookupError as e {
        print(e);
    }
}
```

```output
b'caf\xc3\xa9' b'caf\xe9' b'caf?'
b'caf\xe9 \x80' b'\xff\xfeh\x00\xe9\x00' b'&#960;'
“hi” café b'\xe9'
'ascii' codec can't encode character '\xe9' in position 3: ordinal not in range(128)
unknown encoding: shift_jis
```

## Translating

```jac
with entry {
    table = str.maketrans("abc", "xyz", "d");
    print("abcd".translate(table), "abc".translate({97: "A", 98: None}));
}
```

```output
xyz Ac
```

## Where it differs from Python

- **`sep.join(items)` needs strs.** A `list[int]` is a compile error (E1001); convert each item
  with `str()`. Any iterable of strs is taken: a tuple, a set, a dict (its keys), a str (its
  characters), a generator. An `any` item that is not a str raises
  `TypeError: sequence item 1: expected str instance, int found` as the program runs, `1` being
  the item's position.
- **The CJK multibyte encodings are not known** to `encode` and `decode` (`LookupError`).
- Everything else follows CPython: the Unicode tables are Unicode 17.0's, and case mapping,
  character classes and line boundaries give CPython's result for every code point.

## Where to go next

- [bytes and bytearray](bytes-methods.md) for `decode` and binary data.
- `repr`, `ascii`, `format`, `chr`, `ord` in [Builtin conversions](builtins-conversions.md).
- Regular expressions: [re](re.md). Constants and templates: `string`, in
  [Standard-library modules](stdlib.md).
