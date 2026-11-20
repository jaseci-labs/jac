---
description: The operators for integer arithmetic that wraps or saturates instead of raising OverflowError, the wrapping shift, and the bit operations (popcount, clz, ctz, bswap, bitrev, rotl, rotr).
keywords: +%, -%, *%, +|, -|, *|, +%=, -%=, *%=, +|=, -|=, *|=, wrapping, saturating, wrapping_shl, popcount, clz, ctz, bswap, bitrev, rotl, rotr
---
# Wrapping and saturating arithmetic

Integer arithmetic is checked: `+`, `-`, `*` and `<<` raise `OverflowError`
when the result leaves the type's range (see [Numbers](numbers.md)).
Arithmetic that is meant to wrap around, or to stop at the type's ends, says
so with its operator. The bit operations on this page count, reverse and
rotate an int's bits at its own width.

## The operators

They are alternatives of the arithmetic productions, beside the checked
operators of the same rank:

```ebnf
arithmetic ::= term (("-|" | "+|" | "-%" | "+%" | "+" | "-") term)*

term ::= factor (("*|" | "*%" | "@" | "%" | "//" | "*" | "/") factor)*

factor ::= ("-%" | "+" | "~" | "-") factor | power
```

| Operator | Meaning |
|---|---|
| `a +% b`, `a -% b`, `a *% b` | Wrapping: the low bits of the exact result, in two's complement, at the operands' type. |
| `-%x` | Wrapping negation. The least signed value is its own negation: `-%i8(-128)` is -128. |
| `a +\| b`, `a -\| b`, `a *\| b` | Saturating: the type's least or greatest value where the exact result is past it. |
| `x +%= e`, `x -%= e`, `x *%= e`, `x +\|= e`, `x -\|= e`, `x *\|= e` | The augmented forms: `h *%= p` is `h = h *% p`. |

- **Each binds as the operator it modifies.** `a +% b *% c` is
  `a +% (b *% c)`, and `10 -% 3 -% 2` is `(10 -% 3) -% 2`.
- **The operands are ints of any width and signedness**, joined to one
  type as `+` joins them: the wider of two sized ints where it holds the
  other, the sized type for a literal beside it, `int` for an `int` beside
  a narrower type. The result wraps or saturates at that type.
- **Two int types of which neither holds the other do not mix** (E1128),
  and nothing but ints is taken: a float, a bool or a str is E1110, and
  `-%` of a float E1010.
- **They never raise.** There is no wrapping or saturating division.
- **A conversion that wraps is `T.wrap(x)`**: `u8.wrap(300)` is 44, the
  low 8 bits. See [Numbers](numbers.md) for the conversions.

```jac
def fnv1a(data: bytes) -> u32 {
    h: u32 = 2166136261;
    for b in data {
        h = (h ^ u32(b)) *% u32(16777619);
    }
    return h;
}

with entry {
    print(fnv1a(b"hello"));
    level: u8 = 250;
    level +|= 10;
    print(level, u8(3) -| u8(5), i8(-100) *| i8(2));
    print(i8(100) +% i8(100), u8(3) -% u8(5), i32(65536) *% i32(65536));
    print(i8(-128) *| i8(-1), -%i8(-128));
    print(9223372036854775807 +% 1, 9223372036854775807 +| 1);
    print(2 +% 3 *% 4, i8(100) +% i16(32700));
}
```

```output
1335831723
255 0 -128
-56 254 0
127 -128
-9223372036854775808 9223372036854775807
14 -32736
```

The hash above is FNV-1a: each step multiplies at 32 bits and keeps the low
32 bits of the product, which `*` would refuse with `OverflowError`.

## The wrapping shift

`a << k` is checked: it raises `OverflowError` when it loses bits or when
`k` is past the width. `wrapping_shl(x, k)` shifts by `k` modulo the width
and keeps the low bits. Its result has `x`'s type.

```jac
with entry {
    x: u8 = 0x81;
    print(wrapping_shl(x, 1), wrapping_shl(x, 9), wrapping_shl(1, 64));
    try {
        print(x << 1);
    } except OverflowError as e {
        print("checked:", e);
    }
}
```

```output
2 2 1
checked: integer overflow
```

`>>` needs no wrapping form: it never overflows.

## The bit operations

Each works on an int's bits at the int's own width and signedness, and is
one machine instruction where the target has one.

| Call | Result | Type |
|---|---|---|
| `popcount(x)` | How many bits are 1. | `int` |
| `clz(x)` | How many leading bits are 0. The width for 0. | `int` |
| `ctz(x)` | How many trailing bits are 0. The width for 0. | `int` |
| `bswap(x)` | Its bytes in reverse order. For ints of 16 bits and up: one byte has no order to reverse (E1053). | `x`'s |
| `bitrev(x)` | Its bits in reverse order. | `x`'s |
| `rotl(x, k)`, `rotr(x, k)` | Rotated left or right by `k` modulo the width. `k` is an int and may be negative. | `x`'s |

```jac
with entry {
    a: u8 = 200;
    print(popcount(a), clz(a), ctz(a), clz(0), popcount(-1), popcount(i8(-1)));
    print(bswap(u16(0x1234)), bitrev(u8(1)), ctz(i16(-32768)));
    print(rotl(a, 1), rotr(a, 1), rotl(a, 9), rotl(a, -1));
}
```

```output
3 0 3 64 64 8
13330 128 15
145 100 145 100
```

`a` is `0b11001000`: three ones, no leading zero at 8 bits, three trailing
zeros. `clz(0)` is 64 because a literal with nothing asking for another
type is an `int`.

These are builtin names, not keywords. A program's own definition of one of
these names is what the name calls in it.

An `int` also has Python's `bit_count()` and `bit_length()` methods.

## Where they run

- **The wrapping and saturating operators and `wrapping_shl` run on every
  host**: native code, WebAssembly, and a `cpython`, `node`, `browser` or
  `hermes` space. On a JavaScript host an `int` is a number, exact up to
  2**53 - 1 in magnitude.
- **The bit operations are native code's.** A `cpython`, `node`, `browser`
  or `hermes` space does not provide them, and a call of one there is
  refused (E1540).

## What is rejected

```jac
# expect: E1110 x2, E1010, E1128 x2, E1126, E1053 x2
with entry {
    print(1.5 +% 2.0);
    print(True -% 1);
    print(-%2.5);
    print(i8(1) +| u8(2));
    print(i16(1) -% u32(2));
    print(u8(1) +% 256);
    print(bswap(u8(1)));
    print(popcount(1.5));
}
```

| Code | Meaning |
|---|---|
| E1110 | A wrapping or saturating operator has an operand that is not an int. |
| E1010 | `-%` is applied to something that is not an int. |
| E1128 | The two operands are int types of which neither holds the other. |
| E1126 | A literal operand does not fit the other operand's type. |
| E1053 | A bit operation is given something it does not take: `bswap` of an 8-bit int, a float, a count that is not an int. |
| E1540 | A bit operation is called in a space whose host does not provide it. |

## Differences from Python and the reference design

- Python has no such operators: its ints never overflow. `(a + b) & 0xFF`
  in Python is `a +% b` on `u8` operands here.
- There are no `wrapping_add`, `wrapping_mul`, `saturating_sub` or similar
  functions. Those names are unknown (W2001): the operators are the one
  spelling.
