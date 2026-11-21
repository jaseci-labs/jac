---
description: What a compile-time value may be and compute (ints of any size, floats, strs, collections, structs of plain data), what the evaluator runs, how a value is read where code runs, and target(), bits() and signed() from jaclang.comptime.
keywords: compile-time value, target, vector_bits, bits, signed
---
# Compile-time values

The compiler evaluates every `comptime` expression (see
[Compile-time evaluation](compile-time.md) for where `comptime` appears).
This page says which values it can hold, what it computes and how, and how
a compile-time value becomes part of the running program.

## The values

| Kind | Examples |
|---|---|
| `int` | `42`, `2 ** 100`, `i8.MAX`, `u128.MAX`. Exact, of any size. |
| `float` | `1 / 3`, `0.5`, `float(7)` |
| `bool` | `True`, `1 == 1.0` |
| `str` | `"neo" + "jac"` |
| `None` | `None` |
| An enum member | `Color.GREEN` |
| A struct of plain data | `Layout(rows=3, scale=0.25)` |
| `list`, `tuple`, `set`, `dict` of these | `[1, 2]`, `(1, "x")`, `{1, 2}`, `{"a": 1}` |

An `obj`, or a struct that is not plain data (one holding a `str`, a list or
any other reference), is not a compile-time value (E0108, with the reason).

## Ints

Compile-time ints are exact and of any size, as Python's are: their
arithmetic never overflows, and `int()` of a float is exact too. An int of
more than 65536 bits is refused (E0108). `i8.MAX`, `u128.MAX` and the other
sized types' `MIN` and `MAX` are compile-time ints.

## Floats

Compile-time float arithmetic is Python's, computed in 64-bit floats exactly
as the program would compute it, and mixed with ints by Python's rules: `1 /
3` is a float, `2 ** -1` is 0.5, `1 == 1.0` is `True`, `7.5 // 2` is 3.0,
`-7 % 2.5` is 0.5. `float()`, `int()`, `abs()`, `min()`, `max()` and
`round()` (to an int, or to a number of digits, which may be negative:
`round(1234.5, -1)` is 1230.0) work as Python's do.

An int and a float compare exactly, as in Python, whatever the int's size:
`2 ** 53 + 1 == 2.0 ** 53` is `False`. Where code runs, the int is first
converted to a `float` (see [Numbers](numbers.md)), so the same comparison
of two variables is `True` there. `1.0 is 1` is `False`.

What would raise, or would not be a finite float, is an error when the
program compiles (E0108): a division by zero, a float overflow, a negative
number to a fractional power.

```jac
comptime THIRD = 1 / 3;
comptime HALF = 2 ** -1;
comptime BIG: u128 = int(1e30);
comptime ROUNDED = round(2.5) + round(3.5);
comptime TWO_PLACES = round(2.675, 2);
comptime MIX = min(3, 1.5) + max(2, 4) + abs(-2.5);
comptime TRUNC = int(-3.9);
comptime FLOORED = 7.5 // 2;
comptime REM = -7 % 3;
comptime TOP: u128 = u128.MAX;
comptime SUM: int = i8.MAX + u8.MAX;
comptime TENS = round(1234.5, -1);
comptime EXACT = 2 ** 53 + 1 == 2.0 ** 53;
comptime PART = "ne" in "neo" and "x" not in "neo";

with entry {
    print(THIRD, HALF, BIG, ROUNDED, TWO_PLACES);
    print(MIX, TRUNC, FLOORED, REM, TOP, SUM);
    big = 2 ** 53 + 1;
    near = 2.0 ** 53;
    print(TENS, EXACT, big == near, PART);
}
```

```output
0.3333333333333333 0.5 1000000000000000019884624838656 6 2.67
8.0 -3 3.0 2 340282366920938463463374607431768211455 382
1230.0 False True True
```

## What the evaluator computes

A compile-time expression, and a `comptime def`'s body, is ordinary Jac
limited to what the compiler evaluates:

| Evaluated | Not evaluated (E0108) |
|---|---|
| Arithmetic, comparison, `and`, `or`, `not`, bitwise operators on ints | A comprehension |
| `+` of strs, lists and tuples; `*` of a str by an int | An f-string |
| Indexing (`xs[0]`, `xs[-1]`, `d["k"]`, `s[0]`) | A slice (`xs[1:]`) |
| `in` and `not in` on a list, tuple, set or dict, and of a str in a str | A conditional expression (`a if c else b`), a chained comparison (`a < b < c`) |
| `len`, `min`, `max`, `abs`, `round`, `int`, `float` | `str()`, `sum()`, `sorted()`, `divmod()` |
| `list(...)`, `tuple(...)`, `range(...)` | Methods of strs and lists (`.upper()`, `.append()`) |
| `d.keys()`, `d.values()` | `d.items()`, `d.get()` |
| Calls of `comptime def` functions | Calls of ordinary functions |

A `comptime def`'s body runs assignments (tuple targets and augmented ones
too), `if`, `while`, `for`, `break`, `continue`, `return` and calls of
other comptime functions, itself included. To build a list, concatenate
(`out = out + [x]`).

## Structs of plain data

A [struct](structs.md) of plain data (holding no reference) is a
compile-time value:

- it is made by its class's call, its fields bound by position or by name
  and the rest their defaults, each a compile-time value of its field's
  type;
- its fields read with `p.x`: in a `comptime if`, in a type's arguments and
  anywhere a compile-time value goes;
- two are equal where their fields are.

Where code runs it is the struct its literal makes (`Layout(rows=3,
scale=0.25)`), held in place, and a field read where code runs is that
field's literal. A `comptime` parameter takes one: the function is copied
for each value.

```jac
import from accel { tensor }

struct Layout {
    has rows: int = 4,
        scale: float = 1.0;
}

comptime LAYOUT = Layout(rows=3, scale=0.25);

comptime assert LAYOUT == Layout(3, 0.25) and LAYOUT.rows == 3;

def grid -> tensor[f32, LAYOUT.rows, 2] {
    return tensor[f32, LAYOUT.rows, 2](fill=LAYOUT.scale);
}

def placed(comptime l: Layout, x: float) -> float {
    comptime if l.rows > 2 {
        return x * l.scale;
    } else {
        return x;
    }
}

with entry {
    print(grid().tolist(), placed(LAYOUT, 2.0), placed(Layout(rows=1), 2.0));
    mine = LAYOUT;
    mine.rows = 9;
    print(mine, LAYOUT);
}
```

```output
[0.25, 0.25, 0.25, 0.25, 0.25, 0.25] 0.5 2.0
Layout(rows=9, scale=0.25) Layout(rows=3, scale=0.25)
```

## Reading a compile-time value where code runs

A compile-time global or local read by code that runs is its value's
literal, of the type its declaration gives it. Without a declared type, an
int one is an `int` and a float one a `float`, so:

- **To read one as a sized int or a narrow float, declare its type**
  (`comptime W: u128 = 2 ** 100;`, `comptime F: f32 = 0.1;`) **or convert
  it by name** (`u8(A)`, `i128(W)`, `f32(H)`).
- **An undeclared global whose value an `int` does not hold is an error**
  (E1126): `comptime P = 2 ** 61 - 1;` is a global and
  `comptime M = 2 ** 100;` is not. `comptime M: u128 = 2 ** 100;` is.

```jac
comptime A = 7;
comptime W: u128 = 2 ** 100;
comptime F: f32 = 0.1;
comptime P = 2 ** 61 - 1;

with entry {
    small: u8 = u8(A);
    print(small, W + 1, F, type(F), i128(P) * i128(P));
}
```

```output
7 1267650600228229401496703205377 0.1 <class 'f32'> 5316911983139663487003542222693990401
```

## target()

`target()`, from `jaclang.comptime`, is what the build targets: a
compile-time record with these fields.

| Field | Value |
|---|---|
| `os` | `"darwin"`, `"linux"`, `"windows"` or `"wasi"` |
| `arch` | `"aarch64"`, `"x86_64"` or `"wasm32"` |
| `device` | `"cpu"` |
| `cpu` | The processor `--cpu` names (`"x86-64-v3"`, the machine's own for `native`), `""` for the platform's baseline |
| `vector_bits` | The widest vector that processor computes with in one register: 128 on the aarch64 and x86-64 baselines, 256 with AVX2 (`x86-64-v3`), 512 with AVX-512 (`x86-64-v4`), 0 on `wasm32` |

A `comptime if` on it compiles only the branch it picks, so the other
branches may name what this target does not have. The record itself is no
value of the program (E1245): `t = target()` is refused, while
`target().os` is a `str` code can read.

<!-- example: not checked: its output depends on the machine that builds it -->
```jac
import from jaclang.comptime { target }

def page_size -> int {
    comptime if target().os == "darwin" and target().arch == "aarch64" {
        return 16384;
    } else {
        return 4096;
    }
}

with entry {
    print(target().os, target().arch, target().vector_bits, page_size());
}
```

```text
darwin aarch64 128 16384
```

That is its output on an Apple-silicon Mac; built with
`--target linux-x86_64 --cpu x86-64-v3` it prints `linux x86_64 256 4096`.

## bits() and signed()

`bits(T)` and `signed(T)`, from `jaclang.comptime`, describe a number type:

- `bits(T)` is how many bits a value of it is: `bits(i8)` is 8, `bits(int)`
  and `bits(float)` 64, `bits(f32)` 32, `bits(bf16)` 16, `bits(u128)` 128.
- `signed(T)` is whether it holds negative values: `True` for every int
  type but `u8` to `u128`, and for every float type.

Each is a compile-time value, so a body bounded by `Number` picks what a
type's width needs with `comptime if` (see
[How generic code is compiled](generics-compiling.md)). A type that is not a
number's is an error (E1570).

```jac
import from jaclang.comptime { bits, signed }

def describe[T: Number](x: T) -> str {
    comptime if bits(T) == 8 {
        return "a byte";
    }
    return f"{bits(T)} bits, signed {signed(T)}";
}

with entry {
    print(describe(u8(3)), describe(i32(4)), describe(f32(1.0)), describe(u128(1)));
    print(bits(int), bits(bf16), signed(u64), signed(f16));
}
```

```output
a byte 32 bits, signed True 32 bits, signed True 128 bits, signed False
64 16 False True
```

The other compile-time helpers of `jaclang.comptime`, which read a type's
fields and members, are on [Reflection](reflection.md).

## What is rejected

```jac
# expect: E0108 x7, E1126, E1245, E1570
import from jaclang.comptime { target, bits }

obj Thing {
    has n: int = 0;
}

struct Named {
    has name: str = "";
}

comptime A = 1e308 * 10;
comptime B = (-8.0) ** 0.5;
comptime C = 2 ** 70000;
comptime D = 1 // 0;
comptime E = [i for i in range(3)];
comptime T = Thing(n=1);
comptime N = Named(name="x");
comptime M = 2 ** 100;

def f -> int {
    t = target();
    return bits(str);
}
```

| Code | Meaning |
|---|---|
| E0108 | The compiler cannot evaluate this: it would raise (division by zero, float overflow, a negative number to a fractional power), it makes an int of more than 65536 bits, the evaluator does not run it (a comprehension, an f-string, a slice, a method), or the value is no compile-time value (an `obj`, a struct holding a reference). |
| E1126 | A compile-time int does not fit the type it is read as. |
| E1245 | `target()`'s record (or a type) is used as a value of the program. |
| E1570 | `bits()` or `signed()` of a type that is not a number type. |

## Differences from Python and the reference design

- Python computes module constants when the module is imported, with
  everything the language has. Here a compile-time value is computed by
  the compiler, which runs only what the table above lists.
- A compile-time int is exact, as Python's int is, though an `int` where
  code runs is 64 bits (see [Numbers](numbers.md)).
