---
description: The native sys and atexit modules: the command line, the standard streams, exit and what runs as the program ends, the facts of the platform, and what of CPython's sys is not there.
keywords: sys, sys.argv, sys.orig_argv, sys.executable, sys.exit, sys.stdout, sys.stderr, sys.stdin, sys.__stdout__, sys.__stderr__, sys.__stdin__, sys.platform, sys.maxsize, sys.byteorder, sys.getfilesystemencoding, sys.getfilesystemencodeerrors, atexit, atexit.register, atexit.unregister
---
# sys

`import sys` in a native program loads jac's own `sys`: the part of CPython's `sys` that a
compiled program has, which is the command line, the executable, the standard streams, `exit`
and the facts of the platform. What it has behaves as CPython's does; most of CPython's `sys`
describes the Python interpreter and is not there (see "Not there yet"). It is not CPython's
module: see [The library](index.md) (`jac docs library`).

```jac
import sys;

with entry {
    names = sys.argv[1:];
    if len(names) == 0 {
        print("usage: greet NAME...", file=sys.stderr);
        sys.exit(2);
    }
    for name in names {
        sys.stdout.write(f"hello, {name}\n");
    }
}
```

Built and run as `./greet ada "grace h"`, it prints `hello, ada` and `hello, grace h`; with no
arguments it prints the usage line on standard error and exits with status 2.

## What is there

| Name | What it is |
|---|---|
| `argv` | The command line, `list[str]`: `argv[0]` is the program as it was started, then its arguments |
| `orig_argv` | The command line as the process got it; with no interpreter before the program, a copy of `argv` |
| `executable` | The absolute path of the running program's file |
| `stdout`, `stderr`, `stdin` | The standard streams, each an [`io.TextIOWrapper`](io.md) over the descriptor, UTF-8, named `<stdout>`, `<stderr>` and `<stdin>` |
| `__stdout__`, `__stderr__`, `__stdin__` | The original streams, kept when the others are replaced |
| `exit(status=None)` | Raises `SystemExit(status)` |
| `platform` | `"linux"`, `"darwin"`, `"win32"` or `"wasi"` |
| `maxsize` | `9223372036854775807`: the largest `int`, as ints are 64-bit |
| `byteorder` | `"little"` on every target jac builds for |
| `getfilesystemencoding()`, `getfilesystemencodeerrors()` | `"utf-8"`, and `"surrogateescape"` (`"surrogatepass"` on Windows), as CPython's in UTF-8 mode |

## The standard streams

`print()` writes through `sys.stdout`, so assigning another object to it captures what a program
prints. The object needs only a `write(s: str)` method: an `io.StringIO`, or an `obj` of the
program's own. `sys.__stdout__` puts the original back.

```jac
import io;
import sys;

with entry {
    buf = io.StringIO();
    sys.stdout = buf;
    print("captured", 42);
    sys.stdout = sys.__stdout__;
    print(repr(buf.getvalue()));
}
```

```output
'captured 42\n'
```

Standard output and standard error reach their file as they are written, whether it is a
terminal, a pipe or a file, as CPython's do under `python -u`: neither holds text back. So what
a program prints keeps its order with what Python, Node, Rust or C code in the same process
writes to the same file, and none of it is lost when something else ends the process. Standard
error writes what it cannot encode with `backslashreplace`. A stream a program puts in their
place may hold what is written to it: `sys.stdout` and `sys.stderr` are flushed as the program
ends, after what `atexit` runs. `sys.stdin` reads
lines with `readline()` (`""` at the end of input), all of it with `read()`, or line by line with
`for line in sys.stdin`. Read standard input one way in a program: with `sys.stdin`, or with
the builtin `input()` (see [Builtin functions](builtins.md)).

## Exiting

`sys.exit(status)` raises `SystemExit`, whose `code` is the status as given. An uncaught
`SystemExit` ends the program: `None` exits with status 0, an int with that status, and any
other value is printed to standard error and the status is 1. Like any exception it can be
caught, and `finally` blocks run on the way out.

```jac
import sys;

with entry {
    statuses: list[any] = [None, 0, 3, "bye"];
    for s in statuses {
        try {
            sys.exit(s);
        } except SystemExit as e {
            print(repr(e.code), repr(str(e)));
        }
    }
}
```

```output
None ''
0 '0'
3 '3'
'bye' 'bye'
```

The program ends through the C library's `exit`, so output a C function wrote through C's
`stdio` (`printf`, `fputs`) and has not flushed is written before the process ends.

`exit` and `quit` are not builtins in Jac (`exit` is a keyword); call `sys.exit`.

### atexit

`atexit.register(func, *args, **kwargs)` registers a function to call as the program ends: when
its main module returns, on `sys.exit`, and after an exception nothing caught is reported (not
on `os._exit`), the last registered first, as CPython's
`atexit` does; `unregister(func)` removes it. An exception a function raises is printed as
`Exception ignored in atexit callback ...` and the rest still run.

```jac
import atexit;

def goodbye(name: str) {
    print("goodbye", name);
}

with entry {
    atexit.register(goodbye, "world");
    print("main ends");
}
```

```output
main ends
goodbye world
```

## The exception being handled

`sys.exception()` is the exception the innermost `except` clause now running caught, in this
function or in one that called it, and `None` where none is running. `sys.exc_info()` gives it as
`(type, exception, traceback)`, or `(None, None, None)`.

```jac
import sys;

def note -> str {
    e = sys.exception();
    return "nothing" if e is None else f"{type(e).__name__}: {e}";
}

with entry {
    try {
        raise ValueError("bad");
    } except ValueError {
        print(note());
    }
    print(note());
}
```

```text
ValueError: bad
nothing
```

It is each thread's own, and follows the clause: it is the outer clause's exception again when
an inner one ends, however that one is left; a `finally` clause that runs because an exception
is passing through sees that exception; a generator that yields inside a clause takes its own
with it, so its caller sees the caller's; and a task starts with none.

## Differences from CPython

- **`sys.stdout`, `sys.stderr` and `sys.stdin` are typed `any`**, so that any object with a
  `write` method can be assigned, and so are `sys.__stdout__` and the other originals. A method
  called on them is checked as the program runs.
- **Recursion has a fixed limit.** Running out of stack raises a catchable
  `RecursionError: maximum recursion depth exceeded`, as in CPython, but there is no
  `getrecursionlimit` or `setrecursionlimit`.
- **`sys.maxsize` is the largest `int`**, not a bound on container sizes only: `int` does not
  grow past 64 bits (see [Numbers](number-methods.md)).

## Not there yet

The names that describe the Python interpreter or its import system are not in the native
`sys`: `version`, `version_info`, `hexversion`, `implementation`, `path`, `modules`,
`meta_path`, `flags`, `float_info`, `int_info`, `excepthook`,
`getrecursionlimit`, `setrecursionlimit`, `getsizeof`, `getrefcount`, `intern`, `settrace`,
`setprofile`, `getdefaultencoding`, `stdlib_module_names`,
`builtin_module_names`, `prefix` and the rest. Naming one is refused with E1145:

```jac
# expect: E1145
import sys;

with entry {
    print(sys.version_info);
}
```

The version of the platform is in [platform](stdlib.md) (`platform.system()`,
`platform.python_version()`); the Python interpreter's own `sys` is that of CPython, reached
through [Python interop](../interop/python.md) (`jac docs interop/python`).

## Related

- [os](os.md) for the environment and the file system, [subprocess](subprocess.md) for child
  processes, [io](io.md) for `StringIO`.
- `SystemExit` and the other exceptions: [Builtin exceptions](exceptions.md).
