---
description: jac port, which translates C, C++, Rust, Python, JavaScript and TypeScript source into Jac that behaves as the source does or refuses it - what a path names, where the Jac is written, --check, what is refused and why, and how each language is read.
keywords: port, porting, transpile, transpiler, translate source, jac port, --mapping
---
# port

`jac port` translates source in another language into Jac. A port behaves as its source does,
or it is refused: port never writes Jac that is only close.

```sh
jac port tools/gcd.py            # writes tools/gcd.jac
jac port vendor/shelf            # every source under a directory
jac port --check src             # write nothing: what would port, and what is refused
jac port src/half.c -o build/jac # write under another directory
```

| Language | Files | Read by | Mapping |
|---|---|---|---|
| C | `.c`, `.h` | Clang, for every target jac builds C for | [Porting C](../interop/port-c.md) |
| C++ | `.cc`, `.cpp`, `.cxx`, `.hpp` | Clang, the same way | [Porting C++](../interop/port-cxx.md) |
| Rust | A crate, by its `src/lib.rs` | rustc, for every target jac builds Rust for | [Porting Rust](../interop/port-rust.md) |
| Python | `.py` | CPython | [Porting Python](../interop/port-python.md) |
| JavaScript, TypeScript | `.js`, `.mjs`, `.cjs`, `.ts` | TypeScript | [Porting JavaScript and TypeScript](../interop/port-javascript.md) |

Each language is read by its own compiler, the one jac ships, so port sees a source exactly as
a build of it does: its types, what every name refers to, its macros expanded. This first version
translates a core of each language (functions, numbers, control flow, records, and for Python and
JavaScript strings, lists and dicts) and refuses the rest. A language's mapping page lists what it
translates.

## A port

`gcd.py`:

```python
"""Greatest common divisors."""


def gcd(a, b):
    # Euclid's algorithm.
    while b != 0:
        a, b = b, a % b
    return a


if __name__ == "__main__":
    print(gcd(1071, 462))
```

`jac port gcd.py` writes `gcd.jac`:

```jac
"""Greatest common divisors."""

def gcd(a: any, b: any) -> any {
    # Euclid's algorithm.
    while b != 0 {
        (a, b) = (b, a % b);
    }
    return a;
}

with entry:__main__ {
    print(gcd(1071, 462));
}
```

- **The Jac is in jac's one layout**, as [`jac fmt`](fmt.md) writes it, with the source's
  comments and docstrings at the declarations and statements they belong to.
- **It is checked before it is written.** Port runs everything [`jac check`](check.md) runs on
  what it made, and writes it only when that finds nothing.
- **The same source gives the same Jac.** Nothing in a port is a guess: every fact comes from the
  source's own compiler.

## Same behavior

A port prints what its source prints, exits as it exits and raises where it raises. Where Jac
means something else than the source, port writes the Jac that keeps the source's meaning, even
when no one would write it by hand. C's `/` rounds toward zero and Jac's `//` toward negative
infinity, so `n / 2` of a signed `n` is written with a test of its sign:

```c
static int half(int n) {
    return n / 2;
}
```

```jac
def half(n: i32) -> i32 {
    return n // 2 + 1 if n % 2 != 0 and n < 0 else n // 2;
}

with entry {
    print(half(7), half(-7));
}
```

```output
3 -3
```

- **What the source leaves undefined may become defined.** A signed overflow is undefined in C,
  and the Jac raises `OverflowError`.
- **What has no such Jac is refused.** A Python default that is not a constant is made once in
  Python and at each call in Jac, and port writes no Jac for it yet (E4005).

## What a path names

- **A file** is known by its extension, and one port does not translate is E4004.
- **A directory** is every source under it that port translates. Directories whose names start
  with a dot, and `node_modules`, `build`, `target`, `dist` and `__pycache__`, are left out.
- **A C or C++ source is ported with the header of its name**: `geom.c` and `geom.h` are the
  module `geom`. It is read with the flags of the C module it is in (the `cmodule.toml` above it),
  or as `jac build geom.c` reads it.
- **A directory with a `Cargo.toml` is a Rust crate**, ported from its `src/lib.rs`.

## Where the Jac is written

Beside each source, under its name: `tools/gcd.py` becomes `tools/gcd.jac`.

| `-o` | Writes |
|---|---|
| A name ending in `.jac` | That file, for one source |
| Anything else | A directory: a file's port in it, and a directory's sources under it as they are under the directory |

- **An output that is already there is refused** (E4003), so a port someone has edited is never
  written over. Remove it to port again.
- **The source is never changed**, and neither is a `cmodule.toml`, a `Cargo.toml`, an
  `archwire.jac` or a `jac.toml`.
- **C, C++ and Rust that differ by platform** port to one module where every target agrees. A
  statement that differs is written under `comptime if` on `target()`, and a declaration that
  differs goes to the module's target variant files (`geom.windows.jac`), which
  [Modules](../language/modules.md) describes.

## What is refused

A file ports whole or not at all. Port reports every construct it refuses, each at its place in
the source with what to do instead, writes nothing for that file, and exits with status 1.

```text
$ jac port bad.py
bad.py:1:18: error[E4005]: port writes no Jac yet that keeps the meaning of a default value that is not a constant: Python makes it once, when the function is defined, and Jac at each call that leaves it out
 1 | def push(x, into=[]):
   |                  ^
    = help: Default the parameter to None and make the value in the body.

1 source refused, nothing written for it
`jac docs port` says what port translates and what it refuses.
```

| Code | Refuses |
|---|---|
| E4001 | A construct outside the language's mapping |
| E4002 | A C file whose functions a source left in C still calls |
| E4003 | An output that is already there |
| E4004 | A file that is no source port translates |
| E4005 | A construct whose Jac would mean something else |

- **A source its own compiler rejects** is reported by that compiler, under its own code
  (`error[cpython SyntaxError]`, `error[tsc TS2322]`, Clang's and rustc's own messages).
- **`jac port --check`** reports the same and writes nothing: run on a codebase, it lists what
  stands between it and a port.
- **The files of a C module port together.** A C module cannot call Jac yet, so a file is refused
  while a source that calls it stays C (E4002).

## Reading a mapping

`jac port --mapping <language>` prints a language's mapping page: `c`, `c++`, `rust`, `python`
or `javascript`. The pages under [Using other languages](../interop/index.md) are those, printed
from the tables the translations read.
