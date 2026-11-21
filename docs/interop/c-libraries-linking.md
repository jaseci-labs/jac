---
description: How an import block names the C library it binds - by name, by file, or as a library the project provides - how each is found on Linux, macOS, Windows and WASI, and how a program links its libraries and ends through the C library.
keywords: project library, shared library, library file, run path
---
# Naming and linking a C library

An [import block of C declarations](c-libraries.md) (`jac docs C library`) binds one library,
which the words after `import from` name. This page says how that name becomes a file on each
platform, and how a program links the libraries it binds.

## Naming the library

What follows `import from` says which library the declarations bind.

| Written | Means |
|---|---|
| `import from z { ... }` | The library named `z`, by the platform's convention |
| `import from "libz.so.1" { ... }` | The library file of exactly that name |
| `import from vendor.raylib { ... }` | A library the project provides, at that path from the project's root |

### By name

An unquoted single name is `lib<name>.so` on Linux, `/usr/lib/lib<name>.dylib` on macOS and
`<name>.dll` on Windows, except for names the target's own tables give a file:

| Name | Linux | macOS | Windows |
|---|---|---|---|
| `c`, `m` | `libc.so.6`, `libm.so.6` | libSystem | `ucrtbase.dll` |
| `dl`, `pthread` | `libdl.so.2`, `libpthread.so.0` | libSystem | not available |
| `z` | linked statically from the toolchain | `/usr/lib/libz.1.dylib` | linked statically from the toolchain |
| `bz2` | linked statically from the toolchain | `/usr/lib/libbz2.1.0.dylib` | linked statically from the toolchain |
| `lzma` | linked statically from the toolchain | `/usr/lib/liblzma.5.dylib` | linked statically from the toolchain |
| `sqlite3` | linked statically from the toolchain | `/usr/lib/libsqlite3.dylib` | `winsqlite3.dll` |
| `zstd`, `ssl`, `crypto` | linked statically from the toolchain | linked statically from the toolchain | linked statically from the toolchain |

A library linked statically from the toolchain is part of the program: the parts it calls are in the executable, it needs nothing installed where it runs, and an update of the system's copy does not reach it, so a fix to one of these libraries takes a rebuild with a newer jac. On Linux that is every library of the table but the C library's own.

A library the target does not have is an error where it is imported (W5021). On
`wasm32-wasi` only `c`, `m` and `wasi_*` host modules exist.

On Windows the C library's functions that take C's 32-bit `long` are bound to their 64-bit
counterparts, so one declaration serves every platform: `labs` binds `llabs`, `strtol` binds
`strtoll`, `ftell` binds `_ftelli64`, and POSIX names such as `strdup`, `fileno` and `unlink`
bind the names the Universal CRT gives them (`_strdup`, `_fileno`, `_unlink`).

### By file

A quoted name is a library file's name, taken exactly:

- `lib<name>.so` or `lib<name>.so.<version>` for Linux: the entry the program records as needed,
  as written.
- `<name>.dylib` for macOS: an install name, which may be a path (`"/usr/lib/libz.1.dylib"`).
- `<name>.dll` for Windows: the DLL the program imports.

A quoted name that is no library file's name is refused (E5149). A file of another platform than
the build's target is refused too (E5148), so a module that binds a library whose file differs
by platform has a variant for each: `gpu.linux.jac` binding `"libcuda.so.1"` and
`gpu.windows.jac` binding `"nvcuda.dll"`. Module variants are described in
[Modules](../language/modules.md) (`jac docs variant`). A file the target's own tables name is
that library: `"libm.so.6"` is `m` on Linux.

### A library the project provides

A dotted name is a path from the project's root (the directory holding `jac.toml`), its last
part the library's own name. `import from vendor.raylib { ... }` binds:

| Platform | File |
|---|---|
| macOS | `vendor/libraylib.dylib` |
| Linux | `vendor/libraylib.so` |
| Windows | `vendor/raylib.dll` |

The program finds the library through a run path that leads from its own directory to the
library's: `@loader_path/vendor` (macOS) or `$ORIGIN/vendor` (Linux) for a program built at the
root, `@loader_path/../vendor` for one built into a directory beside `vendor/`, and
`@loader_path/../../../../vendor` for a test runner in `.jac/test/<platform>/tests/`. So it is
found wherever in the project the program is built, as long as program and library keep their
places relative to each other. Windows has no run path: it looks for the DLL beside the program
or on `PATH`.

`vendor/tally.c`, built into a library with [`jac cc`](c-and-cpp.md):

<!-- example: not checked: needs a project with a C library built beside it -->
```jac
import from vendor.tally {
    def tally_add(n: int) -> int;
}

with entry {
    tally_add(2);
    print(tally_add(40));
}
```

```sh
jac cc -shared -fPIC vendor/tally.c -o vendor/libtally.dylib   # libtally.so on Linux
jac build main.jac -o main && ./main                           # prints 42
```

A dotted name that names a [C module](c-modules.md) (a directory with a `cmodule.toml`) binds
that module instead, even when a library file of the name exists too.

## How a program links

- A library the program declares and never calls is not linked.
- A program does not start where a library it binds with `import from` is missing: the system's
  loader resolves every bound library before the program's first statement. For a library that
  may be absent, such as a GPU driver, use [`dl`](dl.md).
- Every program links its target's C library, which is how the runtime reaches the system. It
  links the way `jac cc` links a C program: the C library's startup code calls the program's
  `main` (`wmain` on Windows, whose arguments are UTF-16), with the start files, compiler runtime
  and C library stubs the toolchain carries in `lib/`.
- On Linux the C library is glibc. The program links against versioned stubs of glibc 2.29's
  interface, the newest the runtime calls, and runs on any glibc that has the symbol versions it
  references.
- Other libraries are linked against stubs jac writes from the declarations, so a build for
  another platform needs none of that platform's libraries. The system's loader binds the real
  ones when the program runs.
- On `wasm32-wasi`, C words (`int` and `ptr` in a declaration, and the pointers `str`, `bytes`
  and callbacks pass as) are 32 bits wide; `i64` and `u64` are 64 bits on every target.
- A program ends through the C library's `exit`, however it ends: its entry code finishing,
  `sys.exit`, or an uncaught exception. So what C's stdio buffered is written, and the handlers
  registered with C's `atexit` run, after the program's own output:

```jac
import sys;

import from c {
    def printf(fmt: str, *args: any) -> i32;
    def atexit(f: Callable[[], None]) -> i32;
}

def bye {
    printf(" and atexit ran\n");
}

with entry {
    atexit(bye);
    printf("buffered by C, %d", 42);
    print("from print");
    sys.exit(0);
}
```

```output
from print
buffered by C, 42 and atexit ran
```

## What is rejected

```jac
# expect: E5149
import from "zlib" {
    def zlibVersion -> str;
}

with entry {
    print(zlibVersion());
}
```

| Code | Condition |
|---|---|
| E5149 | A quoted library name is not a library file's name |
| E5148 | A quoted library file is another platform's than the build's target |
| W5021 | The library does not exist on the target platform |
| E5131 | A module of the runtime outside its platform layer binds a system library; a program's own modules bind any |

`jac docs E5149` prints any of these with its message.
