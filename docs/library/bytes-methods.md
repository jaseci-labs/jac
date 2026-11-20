---
description: The methods and operators of bytes, bytearray and memoryview, and which of Python's they do not have yet.
keywords: bytes methods, bytearray methods, memoryview, bytes.decode, bytes.hex, bytes.fromhex, bytes.join, bytes.split, bytes.replace, bytes.find, bytes.translate, bytes.maketrans, bytearray.append, bytearray.extend, bytearray.pop, bytearray.decode, memoryview.cast, memoryview.tobytes, memoryview.tolist
---
# bytes, bytearray and memoryview methods

A `bytes` is an immutable sequence of ints from 0 to 255, a `bytearray` a mutable one, and a
`memoryview` a view of either without a copy. Positions and lengths count bytes. Indexing gives
an int (`b"abc"[0]` is `97`) and slicing gives the same type.

The search and split methods of `bytes` are Python's. Its text-like methods beyond those, and
all of `bytearray`'s, are not written yet: see "What is missing" below.

## Operators

| Expression | bytes | bytearray |
|---|---|---|
| `b + c`, `b * n` | A new bytes | A new bytearray |
| `b[i]`, `b[a:b:c]` | An int; a bytes | An int; a bytearray |
| `x in b` | An int from 0 to 255, or a sub-sequence | The same |
| `b == c`, `b < c` | Comparison byte by byte | The same |
| `for x in b`, `list(b)` | Each byte as an int | The same |
| `b[i] = x`, `b[a:b] = data`, `b += data`, `b *= n` | Refused: bytes is immutable | Changes it in place |

- An index out of range raises `IndexError: index out of range` for a bytes and
  `IndexError: bytearray index out of range` for a bytearray, read or stored.
- A bytearray store checks the value before the index: `buf[9] = 256` raises
  `ValueError: byte must be in range(0, 256)` even past the end, and so does a negative value.
  A failed store changes nothing.
- `n in b` with an int `n` outside 0 to 255 raises the same `ValueError`.
- A slice of a bytearray may be assigned bytes of another length: the bytes after it move and
  the buffer grows or shrinks (`a[1:3] = b"XYZW"`, `a[:] = b""`). A stepped slice takes as many
  bytes as it selects (`a[::2] = b"__"`). The source may be the bytearray itself or a slice of
  it.

## bytes

| Method | Result |
|---|---|
| `b.decode(encoding="utf-8", errors="strict")` | The str these bytes encode. The encodings and handlers are those of [`str.encode`](str-methods.md): every one of [`codecs`](codecs.md) but the CJK multibyte ones |
| `b.hex()` | Two hex digits a byte. It takes no separator |
| `bytes.fromhex(text)` | The bytes a hex string spells, in either case; spaces between bytes are skipped. `ValueError: non-hexadecimal number found in fromhex() arg at position 0`, or `fromhex() arg must contain an even number of hexadecimal digits` |
| `b.count(sub, start, end)` | How many times the bytes `sub` occur |
| `b.find(sub, start, end)`, `b.rfind(...)` | The first or last position of the bytes `sub`, or `-1` |
| `b.index(sub, start, end)`, `b.rindex(...)` | As `find`, raising `ValueError` when absent |
| `b.startswith(prefix, start, end)`, `b.endswith(suffix, start, end)` | Whether it starts or ends with a bytes, or with any of a tuple |
| `b.split(sep=None, maxsplit=-1)` | The parts between separators, as a `list[bytes]`; ASCII whitespace separates when `sep` is `None` |
| `b.splitlines(keepends=False)` | The lines, split at `\n`, `\r\n` and `\r`; with `keepends`, each with its line end |
| `b.partition(sep)`, `b.rpartition(sep)` | `(before, sep, after)` |
| `sep.join(items)` | The bytes of a list, tuple or other iterable of bytes, joined by `sep` |
| `b.replace(old, new, count=-1)` | A copy with `old` replaced by `new` |
| `b.strip(chars=None)`, `b.lstrip(...)`, `b.rstrip(...)` | A copy without leading and trailing ASCII whitespace, or without the bytes in `chars` |
| `b.lower()`, `b.upper()` | A copy with ASCII letters in another case |
| `b.isascii()`, `b.isdigit()` | Whether every byte is ASCII, or an ASCII digit |
| `b.translate(table, delete=b"")`, `bytes.maketrans(frm, to)` | A copy with the bytes in `delete` removed and the rest mapped through a 256-byte table; with `None` for the table, only the deleting. A table of another length raises `ValueError: translation table must be 256 characters long`, and `maketrans` of unequal lengths `ValueError: maketrans arguments must have same length` |

```jac
with entry {
    b = b"Hello World";
    print(b[0], b[-1], b[0:5], b + b"!", len(b), 72 in b, b"World" in b);
    print(b.find(b"o"), b.rfind(b"o"), b.count(b"l"), b.startswith((b"x", b"He")));
    print(b.split(), b.partition(b" "), b.replace(b"l", b"L", 1), b.upper());
    print(b.hex(), bytes.fromhex("6869 21"), b"-".join([b"a", b"b"]), b" x ".strip());
    print(b.decode(), b"caf\xc3\xa9".decode(), b"\xe9".decode("latin-1"));
    print(b"\xff".decode("utf-8", "replace"), b.translate(None, b"lo"));
    try {
        b"\xff".decode();
    } except UnicodeDecodeError as e {
        print(e);
    }
}
```

```output
72 100 b'Hello' b'Hello World!' 11 True True
4 7 3 True
[b'Hello', b'World'] (b'Hello', b' ', b'World') b'HeLlo World' b'HELLO WORLD'
48656c6c6f20576f726c64 b'hi!' b'a-b' b'x'
Hello World café é
� b'He Wrd'
'utf-8' codec can't decode byte 0xff in position 0: invalid start byte
```

## bytearray

| Method | Result |
|---|---|
| `a.append(x)` | Adds one byte; `ValueError` unless `0 <= x < 256` |
| `a.extend(data)` | Adds the bytes of a bytes, a bytearray or a `list[int]` |
| `a.insert(i, x)` | Inserts a byte before position `i` |
| `a.pop(i=-1)` | Removes and returns the byte at `i`; `IndexError` when empty |
| `a.remove(x)` | Removes the first byte equal to `x`; `ValueError` when absent |
| `a.reverse()`, `a.clear()` | Reverses or empties it in place |
| `a.copy()` | A new bytearray with the same bytes |
| `a.count(sub, ...)`, `a.find(sub, ...)`, `a.index(sub, ...)`, `a.startswith(...)`, `a.endswith(...)` | As for bytes |
| `a.decode(encoding="utf-8", errors="strict")`, `a.hex()` | As for bytes |

`bytes(a)` makes an immutable copy, and gives access to every bytes method. A parameter of a
bytes method that takes bytes (a separator, a prefix, a part to find) takes a bytearray too:

```jac
with entry {
    b = b"one\ntwo\r\nthree";
    print(b.splitlines(), b.splitlines(keepends=True));
    sep = bytearray(b",");
    print(b"a,b".split(sep), b"a,b".startswith(bytearray(b"a,")), b"a,b".find(sep));
}
```

```output
[b'one', b'two', b'three'] [b'one\n', b'two\r\n', b'three']
[b'a', b'b'] True 1
```

```jac
with entry {
    a = bytearray(b"abc");
    a.append(100);
    a.extend(b"ef");
    a.insert(0, 95);
    print(a, len(a), a.find(b"c"), a.decode());
    last = a.pop();
    first = a.pop(0);
    print(last, first, a);
    a[0] = 65;
    a[1:3] = b"XY";
    a += b"!";
    a.reverse();
    print(a, a[0], a[1:3], bytes(a).upper(), bytearray(2));
    try {
        a.append(256);
    } except ValueError as e {
        print(e);
    }
}
```

```output
bytearray(b'_abcdef') 7 3 _abcdef
102 95 bytearray(b'abcde')
bytearray(b'!edYXA') 33 bytearray(b'ed') b'!EDYXA' bytearray(b'\x00\x00')
byte must be in range(0, 256)
```

## memoryview

`memoryview(data)` views the bytes of a bytes or a bytearray. A view of a bytearray writes
through to it.

| Member | Result |
|---|---|
| `len(m)`, `m[i]`, `m[a:b]` | The number of items, an item, a view of part of the memory |
| `m[i] = x` | Stores an item; `TypeError` for a view of bytes, which is read-only |
| `m.tobytes()`, `bytes(m)` | A copy of the memory as bytes |
| `m.tolist()` | The items as a list |
| `m.cast(format)` | The same memory as items of another `struct` format (`"B"`, `"H"`, `"i"`, `"d"`, ...); a length that is not a multiple of the new item size raises `TypeError: memoryview: length is not a multiple of itemsize` |
| `m.format`, `m.itemsize`, `m.readonly` | The item format, its size in bytes, and whether the view is read-only |
| `m.release()` | Gives up the memory; the view has no items after |

```jac
with entry {
    data = bytearray(b"abcdef");
    m = memoryview(data);
    print(len(m), m[1], m[1:3].tobytes(), m.tolist()[:2], m.format, m.itemsize, m.readonly);
    m[0] = 88;
    print(data, memoryview(b"x").readonly);
    words = m.cast("H");
    print(len(words), words.itemsize, words[0] == 88 + 98 * 256);
}
```

```output
6 98 b'bc' [97, 98] B 1 False
bytearray(b'Xbcdef') True
3 2 True
```

## What is missing

Refused at compile time with E1030 (`bytes has no method 'title'`):

- **bytes**: `capitalize`, `center`, `expandtabs`, `isalnum`, `isalpha`, `islower`, `isspace`,
  `istitle`, `isupper`, `ljust`, `removeprefix`, `removesuffix`, `rjust`, `rsplit`,
  `swapcase`, `title`, `zfill`; and `hex(sep)` with a separator.
- **bytearray**: every method not in its table above, among them `join`, `split`, `replace`,
  `strip`, `lower`, `upper`, `partition`, `translate` and `fromhex`. Convert with `bytes(a)`
  first.
- **memoryview**: `hex`, `nbytes`, `toreadonly`, the shape attributes, iteration (`for x in m`,
  `list(m)`: use `m.tolist()`), comparison with `==`, `in`, slice assignment, and `with`.

Also not available: `%` formatting of bytes (`b"%d" % 1`) and `del a[i]` on a bytearray (use
`a.pop(i)`).

## Where to go next

- [str methods](str-methods.md) for `encode` and the encodings.
- Packing numbers into bytes: [struct](struct.md). Buffers as files: [io](io.md).
- `bytes`, `bytearray`, `memoryview` as constructors: [Builtin conversions](builtins-conversions.md).
