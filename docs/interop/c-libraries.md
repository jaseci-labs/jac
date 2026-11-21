---
description: Binding a C library from Jac with an import block of declarations - functions, records, globals, callbacks and variadics - how the library is named and found on each platform, and how a program links.
keywords: C library, import from c, C record, opaque C type, C global, C callback, C variadic, library import, FFI
---
# C libraries

A Jac module calls a C library by declaring what it uses of it. The declarations go in the braces
of an `import from <library>` statement; nothing else is needed: no header, no wrapper, no build
step.

```jac
import from c {
    obj div_t {
        has quot: i32,
            rem: i32;
    }

    def labs(x: int) -> int;
    def strlen(s: str) -> u64;
    def div(num: i32, den: i32) -> div_t;
}

import from m {
    def sqrt(x: f64) -> f64;
    def modff(x: f32, whole: &mut f32) -> f32;
}

with entry {
    print(labs(-7), strlen("héllo"), sqrt(2.0));
    d = div(17, 5);
    print(d.quot, d.rem);
    whole = f32(0.0);
    frac = modff(f32(2.75), &mut whole);
    print(whole, frac);
}
```

```output
7 6 1.4142135623730951
3 2
2.0 0.75
```

`c` is the C library and `m` its mathematics. The block declares C functions (`def` with no
body), C records (`obj`), and C globals (`glob`). Each is a name of the importing module, used
like any other. Native code calls C: a program, or a native or wasm space of an app; code of a
cpython, node, browser or hermes space that uses a C function, record or global is refused
(E1540, "needs C code").

The declarations are the program's statement of the C interface. Nothing checks them against
the library: a declaration that disagrees with the C function it names is undefined behavior, as
a wrong prototype is in C. To have Clang read the real headers instead, make the code a
[C module](c-modules.md).

Related pages: [pointers and native memory](pointers-and-native-memory.md) for `ptr[T]`, views
and `pin`; [opening a library as the program runs](dl.md) for libraries that may be absent;
[C modules](c-modules.md) for C source compiled into the program; [C and C++](c-and-cpp.md) for
building a library with `jac cc`. The other direction, a Jac module built as a C library, is
`jac build --lib`: see [Building programs](../toolchain/build.md) (`jac docs build`).

## Types in a declaration

A parameter, a result and a record field are written in these types. Anything else is refused
(E5090).

| Jac type in the declaration | C type |
|---|---|
| `int` | A 64-bit signed integer: `int64_t`, `long long`, `long` on Linux and macOS |
| `i64`, `u64` | `int64_t`, `uint64_t` (`size_t` on 64-bit targets) |
| `i32`, `u32`, `i16`, `u16`, `i8`, `u8` | The integer of that width and sign (C's `int` is `i32`) |
| `bool` | C's one-byte `bool` |
| `float`, `f64` | `double` |
| `f32`, `f16`, `bf16` | `float`, `_Float16`, `__bf16` |
| `str` | `const char *`, NUL-terminated, UTF-8; `None` is `NULL` |
| `bytes`, `bytearray` | A pointer to the first byte; C is not told the length; `None` is `NULL` |
| `str \| bytes \| bytearray` (parameters only) | A pointer to the first byte of whichever it is given |
| `ptr` | `void *` |
| `ptr[T]` | `T *` |
| A C record declared in an import block | That `struct`, by value |
| `Callable[[P, ...], R]` | A pointer to a function of that signature; `None` is `NULL` |
| `None`, or no result type | `void` |
| `&T`, `&mut T` (parameters only) | `const T *`, `T *`: the address of the caller's variable |

A C or Rust 64-bit signed integer is an `int`, the integer Jac code computes with, and an
unsigned one is a `u64`. The sized types are described in [Numbers](../language/numbers.md)
(`jac docs numbers`). A sized result widens to `int` where one is wanted.

The other way, the width is the library's, not the program's: an `int` given to a C function's
sized-int parameter, or stored in a C record's sized-int field, narrows to that type, and a
`float` to an `f32`. The int is checked as the program runs, as `i32(n)` checks it: a value the
type cannot hold raises `OverflowError` where the call or the store is, and a compile-time int
that does not fit is refused when the program compiles (E1126). A `float` rounds as `f32(x)`
rounds it, never raising: past `f32`'s range it is an infinity, and a NaN stays a NaN. Nothing
else narrows: an `i64` given where an `i32` is declared is still E1053, and a Jac function's
`i32` parameter takes an `int` only converted by name, `i32(n)`.

```jac
import from c {
    def strtol(s: str, end: ptr[ptr[u8]], base: i32) -> int;
    def toupper(c: i32) -> i32;
    def atof(s: str) -> float;
    def abs(x: i32) -> i32;
}

with entry {
    rest = ptr[u8]();
    print(strtol("42abc", &mut rest, 10), chr(rest[0]));
    n = -5;
    total: int = abs(n) + 1;
    print(total, chr(toupper(ord("a"))), atof("2.5") * 2);
    try {
        abs(n * 1000000000);
    } except OverflowError as e {
        print("abs:", e);
    }
}
```

```output
42 a
6 A 5.0
abs: integer overflow
```

### Strings

A `str` argument reaches C as a pointer to its UTF-8 bytes, NUL-terminated, valid for the call.
A `str` result is copied into a new Jac `str` up to the first NUL; C keeps ownership of its
buffer. `None` is C's `NULL` both ways: a `None` argument passes `NULL`, and a result C returns
as `NULL` is `None`. Write `str | None` where C documents either, as the type says so to a
reader; a `str` is the same type to the compiler. A parameter declared as a union of `str`,
`bytes` and `bytearray` takes any of them, for a C function that reads bytes of a given length
through a `const char *`:

```jac
import from c {
    def getenv(name: str) -> str | None;
    def strlen(s: str | bytes | bytearray) -> int;
}

with entry {
    print(getenv("JAC_DOCS_NO_SUCH_VARIABLE"));
    print(strlen("four"), strlen(b"abc\x00zz"), strlen(bytearray(b"hello\x00")));
}
```

```output
None
4 3 5
```

Declare a result as a pointer where the address itself is wanted, and test it:

```jac
import from c {
    def strchr(s: str, c: i32) -> ptr[u8];
    def strlen(s: ptr[u8]) -> u64;
}

with entry {
    at = strchr("key=value", ord("="));
    if not at.is_null() {
        n = int(strlen(at + 1));
        print(bytes((at + 1).view(n)).decode());
    }
    print(strchr("key", ord("=")).is_null());
}
```

```output
value
True
```

`bytes` and `bytearray` arguments pass the address of their first byte. C writes into a
`bytearray` in place:

```jac
import from c {
    def snprintf(buf: bytearray, n: int, fmt: str, *args: any) -> i32;
}

with entry {
    buf = bytearray(32);
    n = snprintf(buf, len(buf), "%s=%d %.1f", "x", 42, 2.5);
    print(n, buf[:n].decode());
}
```

```output
8 x=42 2.5
```

### Variadic functions

`*args: any` as the last parameter makes the declaration variadic. Each extra argument is passed
as C's default promotions pass it: an integer as a 64-bit word, a float as a `double`, a `str`,
`bytes`, `bytearray` or pointer as an address. Any other argument is refused (E1157). A C
function takes no `**kwargs` (E1158).

C's `printf` writes through the C library's own buffer, which Jac's `print` does not share:
mixing the two can reorder a program's output. Format into a buffer with `snprintf`, as above,
or use `print`.

## Records

An `obj` with fields in an import block is a C `struct`. Its fields are laid out as C lays them
out (same sizes, alignment and padding), and it passes to and from C functions by value with the
platform's C ABI. It is constructed and read as any object is: `div_t(quot=1, rem=2)`,
`d.quot`. Fields left out are zero.

A record's fields are of the types in the table above, other records included. A record has no
bases, methods, static fields or properties (E5090), and cannot contain itself (E1150): link
records through `ptr[T]` fields.

An `obj` with no body is an **opaque type**: C knows its layout, the program does not. It has no
size, so it cannot be constructed or held by value (E1151). The program handles it as
`ptr[Name]`:

```jac
import from c {
    obj FILE;

    def tmpfile -> ptr[FILE];
    def fputs(s: str, f: ptr[FILE]) -> i32;
    def rewind(f: ptr[FILE]) -> None;
    def fgetc(f: ptr[FILE]) -> i32;
    def fclose(f: ptr[FILE]) -> i32;
}

with entry {
    f = tmpfile();
    if f.is_null() {
        raise OSError("no temporary file");
    }
    fputs("jac", f);
    rewind(f);
    print(chr(fgetc(f)), chr(fgetc(f)), chr(fgetc(f)), fgetc(f));
    fclose(f);
}
```

```output
j a c -1
```

## Passing addresses

A parameter declared `&T` or `&mut T` takes the address of a variable or field of the caller:
the call site writes `&x` or `&mut x`. `T` is C plain data, that is a number, a bool, a pointer
or a C record (E1152). The address is valid for the call only. `modff` and `strtol` above each
write a result through one.

A `ptr[T]` parameter takes a pointer, or `&x` / `&mut x` of a `T` variable, which is its address
for the call. `ptr[T]()` is the null pointer.

Where C keeps the address after the call returns, the storage must not move: use `pin`, or
memory from C's allocator. See [pointers and native memory](pointers-and-native-memory.md).

## Callbacks

A `Callable[[P, ...], R]` parameter or record field is a C function pointer. A named Jac
function of that signature is passed as it is, and C calls it:

```jac
import from c {
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
    def calloc(n: int, size: int) -> ptr[i32];
    def free(p: ptr[i32]) -> None;
}

def descending(a: ptr[i32], b: ptr[i32]) -> i32 {
    return b[0] - a[0];
}

with entry {
    nums = calloc(4, 4);
    nums[0] = 5;
    nums[1] = 30;
    nums[2] = 10;
    nums[3] = 20;
    qsort(nums, 4, 4, descending);
    print(nums[0], nums[1], nums[2], nums[3]);
    free(nums);
}
```

```output
30 20 10 5
```

Only a named function can be a callback; a lambda or a bound method cannot (E1195). `None`
passes `NULL`, which removes a callback where C says so. A `str`
parameter of a callback receives C's `const char *` as a `str`. A callback's signature cannot
take `bytes` or a `bytearray` (C passes no length), a C record by value, or another callback
(E5090). An exception a callback raises does not unwind through C's frames: the callback returns
to C, which runs on, and the exception is raised in the Jac code that called the C function, once
that returns.

A record field of a `Callable` type holds a function pointer, called as a method is:

```jac
import from c {
    obj Measure {
        has scale: i32,
            measure: Callable[[str], int];
    }
}

def tenfold(s: str) -> int {
    return len(s) * 10;
}

with entry {
    m = Measure(scale=2, measure=tenfold);
    print(m.measure("abc") * m.scale);
}
```

```output
60
```

## Globals

`glob name: T;` in an import block names a variable the library defines (C's `extern T name;`).
The program reads and assigns it in place: after `glob opterr: i32;` in `import from c`,
`opterr` reads getopt's flag.

`glob name: T = value;` in an import block **defines** C data in the program itself, under that
symbol name. A scalar is read and assigned as a variable is. A list literal defines a C array,
which the program reaches through `addressof(name)`, a `ptr[T]` to its first element. The array
is C's storage and not a list, so its name is a value nowhere else (E1153):

```jac
import from c {
    glob limit: i32 = 9;
    glob weights: list[f32] = [1.0, 3.0, 3.0, 5.0, 9.0];
}

with entry {
    limit += 1;
    w = addressof(weights);
    w[2] = 3.5;
    print(limit, addressof(limit)[0], w[2], w[4]);
}
```

```output
10 10 3.5 9.0
```

`addressof(x)` gives the address of a C global or of a C record value, as a `ptr[T]`. It takes
nothing else (E1154).

## Naming the library, and how a program links

What follows `import from` names the library: `z` by the platform's convention, `"libz.so.1"` as
a file, `vendor.raylib` as a library the project provides. How each is found on each platform, and
how a program links the libraries it binds, is in
[Naming and linking a C library](c-libraries-linking.md) (`jac docs project library`).

## What is rejected

Errors in the declarations:

```jac
# expect: E5090 x2, E1152, E1158, E1155, E1150
import from c {
    obj Link {
        has next: Link,
            value: i32;
    }

    glob table: list[i32] = list(range(4));
    def twice(x: int) -> int {
        return x * 2;
    }
    def total(xs: list[int]) -> int;
    def strlen(s: &str) -> u64;
    def printf(fmt: str, **kwargs: any) -> i32;
}

with entry {
    print("declared");
}
```

Errors in the uses:

```jac
# expect: E1053, E1195, E1157, E1154, E1151, E1153 x2
import from c {
    obj FILE;

    glob table: list[i32] = [1, 2, 3];
    def abs(x: i32) -> i32;
    def printf(fmt: str, *args: any) -> i32;
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
}

with entry {
    n = 5;
    print(abs(i64(n)));
    qsort(ptr[i32](), 0, 4, lambda (a: ptr[i32], b: ptr[i32]) -> i32 { return a[0] - b[0]; });
    printf("%d\n", [1, 2]);
    print(addressof(n));
    f = FILE();
    print(table[2]);
    table = [4, 5, 6];
}
```

| Code | Condition |
|---|---|
| E5090 | A type C cannot take (a list, a dict, a Jac object), a function with a body, a base or method on a record |
| E1150 | A C record contains itself by value |
| E1151 | An opaque C type is constructed or held by value |
| E1152 | A borrow parameter, or `pin()`, of something that is not C plain data |
| E1053 | An argument of another type than the parameter's, an `i64` where an `i32` is declared among them |
| E1153 | A C array's name used as a list: indexed, assigned or passed, where only `addressof()` of it is a value |
| E1154 | `addressof()` of something that is neither a C record nor a C global |
| E1155 | A C array defined by anything but a list literal |
| E1157 | A variadic argument that is no C scalar, pointer, `str`, `bytes` or `bytearray` |
| E1158 | A C function declared with `**kwargs` |
| E1195 | A lambda or bound method passed as a callback |

`jac docs E1150` prints any of these with its message. The codes of naming a library
(E5148, E5149, W5021) are in [Naming and linking a C library](c-libraries-linking.md).

## Differences from Python and from the reference design

- In Python, C is reached through `ctypes` or `cffi` objects built as the program runs. Here the
  declarations are compiled: a call is a direct C call with no marshaling layer, and a mistyped
  argument is a compile error.
- `int` is 64 bits. A C `int` is `i32`, not `int`.
