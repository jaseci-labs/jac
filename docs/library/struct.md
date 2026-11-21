---
description: The native struct module, as CPython's struct, packing values into bytes by format strings, and where 64-bit ints limit it.
keywords: struct module, struct.pack, struct.unpack, struct.calcsize, struct.Struct, struct.iter_unpack, struct.pack_into, struct.unpack_from, struct.error
---
# struct

The `struct` module packs values into bytes and unpacks them by format strings, as CPython's
`struct` does: the same format characters, sizes, alignment, byte orders, errors and messages.
It is native (see [The library](index.md), `jac docs library`). It is unrelated to Jac's
`struct` declarations, which define value types: see [Structs](../language/structs.md)
(`jac docs struct`).

```jac
import struct;

with entry {
    header = struct.pack("<HIf", 7, 65536, 1.5);
    print(header, struct.calcsize("<HIf"), struct.calcsize("@HIf"));
    (kind, size, scale) = struct.unpack("<HIf", header);
    print(kind, size, scale);
    rec = struct.Struct(">i4s?");
    data = rec.pack(-2, b"abcd", True);
    print(data.hex(), rec.size, rec.unpack(data));
    print(list(struct.iter_unpack("<h", b"\x01\x00\x02\x00")));
    buf = bytearray(8);
    struct.pack_into("<i", buf, 4, 99);
    print(struct.unpack_from("<i", buf, 4));
    try {
        struct.pack("<B", 300);
    } except struct.error as e {
        print("struct.error:", e);
    }
}
```

```output
b'\x07\x00\x00\x00\x01\x00\x00\x00\xc0?' 10 12
7 65536 1.5
fffffffe6162636401 9 (-2, b'abcd', True)
[(1,), (2,)]
(99,)
struct.error: 'B' format requires 0 <= number <= 255
```

## What is there

| Name | What it does |
|---|---|
| `pack(format, *values)` | The values as `bytes` |
| `pack_into(format, buffer, offset, *values)` | Packs into a writable buffer (a `bytearray`, a writable `memoryview`, an `array.array`) at `offset` |
| `unpack(format, buffer)` | A tuple of the values; the buffer's length must be `calcsize(format)` |
| `unpack_from(format, buffer, offset=0)` | The same, from `offset` on |
| `iter_unpack(format, buffer)` | An iterator of tuples, one for each `calcsize(format)` bytes |
| `calcsize(format)` | The size in bytes |
| `Struct(format)` | A compiled format: `pack`, `pack_into`, `unpack`, `unpack_from`, `iter_unpack`, `format`, `size` |
| `error` | What a bad format or a value that does not fit raises |

A format starts with its byte order: `@` (the default) native sizes and alignment, `=` native
order with standard sizes, `<` little-endian, `>` and `!` big-endian. Every target jac builds
for is little-endian. A C `long` (`l`, `L`) is 8 bytes except on Windows and WASI, where it is
4; a pointer and a `size_t` (`P`, `n`, `N`) are 8 bytes except on WASI. The functions keep each
format they compile, as CPython keeps its `Struct` objects, so a repeated format is not
compiled again.

The values each format character takes are CPython's: `F` and `D` pack a complex of two `f32`s
or two `f64`s (an int or a float counts as a complex), and `Zf` and `Zd` are accepted for them
(`struct.calcsize("bZd")` is 24, `"=bZd"` 17); `?` packs any value by its truth and unpacks any
nonzero byte as `True`; `e`, `f` and `d` round to nearest even and keep `-0.0`, infinities and
a quiet NaN; `Np` is a Pascal string, its length byte at most 255 and N - 1; the integer codes
take an object's `__index__` and the float codes its `__float__`. A value whose `__index__`
resizes the bytearray being packed into raises
`BufferError: Existing exports of data: object cannot be re-sized`.

The unpacked values are a tuple of `any`; unpacking into names, or assigning to an annotated
name, gives them their types (`n: int = struct.unpack("<q", data)[0];`).

## Differences from CPython

- **Integers are 64-bit.** An unsigned value at or above 2\*\*63 (`Q`, `N`, `P`) does not unpack:

```jac
import struct;

with entry {
    try {
        struct.unpack("<Q", b"\xff" * 8);
    } except OverflowError as e {
        print("OverflowError:", e);
    }
}
```

```output
OverflowError: struct: 'Q' unpacked a number above what an int holds
```
