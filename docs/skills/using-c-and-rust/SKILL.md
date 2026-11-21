---
name: using-c-and-rust
description: Use when Jac code must call C or Rust - binding a system C library (libc, libm, zlib, sqlite3) with import from <lib> { ... } declarations, compiling C source into the program as a C module (cmodule.toml), a Rust crate as a module, a project's own shared library, pointers and buffers, and building C or Rust alone with jac cc and jac cargo.
---
# Calling C and Rust

## When to use this

Use it when native Jac code calls code compiled from C, C++ or Rust. Pick the form first:

| You have | Use | jac builds it? |
|---|---|---|
| A library already on the system (`c`, `m`, `z`, `sqlite3`) | Declarations in `import from <lib> { ... }` | No: you state its interface |
| C or C++ source and headers | A C module: a directory with `cmodule.toml` | Yes, headers read by Clang |
| A Rust crate | A Rust module: a directory with `Cargo.toml` | Yes, with cargo and rustc |
| A `.so` / `.dylib` the project builds or vendors | `import from vendor.<name> { ... }` declarations | No |

Load `writing-jac` first. A Python extension or Node addon is `using-python-packages` or
`using-npm-packages`.

## Before you start

```sh
jac docs C library        # declarations, the type table, naming the library
jac docs C module         # cmodule.toml, what Jac binds from headers
jac docs Rust module      # what a crate's interface gives Jac
jac docs ptr              # pointers, views, pin, addressof
```

C's `int` is `i32`; Jac's `int` is 64-bit (`int64_t`). An `int` given to a C function's `i32`
parameter or stored in a C record's `i32` field narrows by itself, checked as it runs: one that
does not fit raises `OverflowError` there. A `float` narrows to a C `f32` the same way. A Jac
function's `i32` parameter takes no `int` but by `i32(n)`.

## Steps

1. **Bind a system library** by declaring what you call. Nothing checks a declaration against
   the library: get each type right from its C prototype.

```jac
import from c {
    def strlen(s: str) -> u64;
    def abs(x: i32) -> i32;
    def snprintf(buf: bytearray, n: int, fmt: str, *args: any) -> i32;
    def calloc(n: int, size: int) -> ptr[i32];
    def free(p: ptr[i32]) -> None;
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
}

import from m {
    def modff(x: f32, whole: &mut f32) -> f32;
}

def descending(a: ptr[i32], b: ptr[i32]) -> i32 {
    return b[0] - a[0];
}

with entry {
    n = -5;
    print(strlen("héllo"), abs(n));
    whole = f32(0.0);
    frac = modff(f32(2.75), &mut whole);
    print(whole, frac);
    buf = bytearray(32);
    k = snprintf(buf, len(buf), "%s=%d", "x", 42);
    print(buf[:k].decode());
    nums = calloc(3, 4);
    for (i, v) in enumerate([5, 30, 10]) {
        nums[i] = i32(v);
    }
    qsort(nums, 3, 4, descending);
    view = nums.view(3);
    print([view[i] for i in range(len(view))]);
    free(nums);
}
```

```output
6 5
2.0 0.75
x=42
[30, 10, 5]
```

Buffers and pointers, as above: a `bytearray` argument lets C write in place; `&mut x` lends a
variable's address for one call; memory from `calloc` is a `ptr[T]`, indexed unchecked, freed by
C's `free`; `p.view(n)` is a bounds-checked view, indexed (never iterated) with
`range(len(v))`. A Jac `list` is not a C array: copy into C memory. Where C keeps an address
after the call, use `pin(x)` (`jac docs pin`). Only a named function is a callback.

2. **Compile C source in as a C module.** A directory `stats/` beside the program:

```toml
# stats/cmodule.toml
headers = ["stats.h"]
sources = ["stats.c"]
libs = ["m"]
```

`stats/stats.h` declares `typedef struct { double mean; double stdev; } summary;`,
`summary summarize(const double *xs, int64_t n);` and `#define STATS_MAX 1024`. Jac imports the
names; the types come from the header (`const double *` is `ptr[float]`, the struct a record,
the `#define` an `int`):

<!-- example: not checked: needs the C module stats beside the program -->
```jac
import from c {
    def calloc(n: int, size: int) -> ptr[f64];
    def free(p: ptr[f64]) -> None;
}

import from stats { STATS_MAX, summarize }

with entry {
    xs = calloc(4, 8);
    for (i, v) in enumerate([2.0, 4.0, 4.0, 6.0]) {
        xs[i] = v;
    }
    s = summarize(xs, 4);
    print(STATS_MAX, s.mean, s.stdev);
    free(xs);
}
```

`jac build main.jac -o main && ./main` prints `1024 4.0 1.4142135623730951`. In a project
with an `archwire.jac`, wire a C module in (`stats ++> main { summarize }`) instead of importing
it (E1144).

3. **Link a Rust crate as a module.** A directory `adder/` with a plain `Cargo.toml`
   (`[package] name = "adder"`, `edition = "2024"`) and `src/lib.rs` exporting C-ABI items:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn add(a: i64, b: i64) -> i64 {
    a + b
}
```

`import from adder { add }` then `print(add(2, 3))` prints `5` after `jac build`. Keep
Rust values behind an opaque handle: a `pub struct` without `#[repr(C)]` is held as `ptr[T]`,
made and freed by the crate's own `extern "C"` functions. `i64` is `int`, `usize` is `u64`,
`*const c_char` is `str`.

4. **Bind a project library** you build yourself:

```sh
jac cc -shared -fPIC vendor/tally.c -o vendor/libtally.dylib   # libtally.so on Linux
```

and declare it with its dotted path: `import from vendor.tally { def tally_add(n: int) -> int; }`.
The program finds it relative to itself, so keep both where they are.

5. **Build C or Rust alone** with the toolchain jac carries (no system compiler needed):

```sh
jac cc hello.c -o hello                          # this machine
jac cc -target x86_64-linux-musl hello.c -o hello-linux
jac cargo build                                  # in a crate's directory
jac build app/Cargo.toml -o app                  # a Rust program, through jac's cache
```

## What a correct result looks like

- `jac check main.jac` prints nothing; `jac build main.jac -o main && ./main` prints the
  values above. A C module's or crate's first build compiles it; later builds reuse the cache.

## Mistakes to expect

```jac
# expect: E1053, E1195
import from c {
    def abs(x: i32) -> i32;
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
}

def magnitude(x: i32) -> i32 {
    return abs(x);
}

with entry {
    n = 5;
    print(magnitude(n));
    qsort(ptr[i32](), 0, 4, lambda (a: ptr[i32], b: ptr[i32]) -> i32 { return a[0] - b[0]; });
}
```

| Code | Means | Fix |
|---|---|---|
| E1053 `expects i32, found int` | An `int` to a Jac function's `i32` parameter: only C's parameters and fields narrow one | Declare the parameter `int`, which narrows where it reaches C, or pass `i32(n)` |
| E1053 `expects ptr[float], found list[float]` | A list passed as a C array | Copy into `calloc`'d memory, pass the pointer |
| E1195 | A lambda or bound method as a callback | A named `def` |
| E5090 `... as a C type` | A list, dict or Jac object in a declaration | Use the C types (`jac docs C library`) |
| E1021 `cannot iterate PtrView` | A view in a `for` | `for i in range(len(v))` |
| E1145 | The header or crate has no such name | Check spelling; for Rust, `pub` and `#[unsafe(no_mangle)]` |
| E5138 `it isn't extern "C"` | A Rust item C cannot call | Make it `pub extern "C"` with C types |
| E5134, E5135, E5140 | The headers, a C source, or a crate fail to compile | Read Clang's or rustc's errors printed above |
| E5149, W5021 | A library name that is no file, or absent on the target | `jac docs C library` (naming the library) |
| Crash or garbage at run time | A declaration that disagrees with C, or a bad pointer | Recheck the prototype; nothing checks it for you |

## Where to look things up

- `jac docs C library`: types, records, opaque types, callbacks, globals, variadics.
- `jac docs C module`: every `cmodule.toml` key, inline modules, C++ sources, wiring.
- `jac docs Rust module`: crate interface, calling Jac from Rust, the build and cache.
- `jac docs Rust` and `jac docs jac cc`: the toolchains on their own, cross-targets.
- `jac docs ptr`: views, `pin`, `addressof`, `load`/`store`.
