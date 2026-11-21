---
description: How the library is organized, how an import of a standard-library name resolves, and where each part is documented.
keywords: standard library, library, native standard library
---
# The library

A Jac program compiled by jac has three layers of library:

| Layer | What it is | Page |
|---|---|---|
| Builtins | Functions, constants and exception classes every module has without an import: `print`, `len`, `range`, `ValueError`, ... | [Builtin functions](builtins.md), [Builtin conversions](builtins-conversions.md), [Builtin exceptions](exceptions.md) |
| Methods of the builtin types | `"a,b".split(",")`, `xs.append(1)`, `d.get(k)`, ... | [str](str-methods.md), [bytes and bytearray](bytes-methods.md), [list](list-methods.md), [dict](dict-methods.md), [set](set-methods.md), [tuple, range and slice](tuple-methods.md), [numbers](number-methods.md) |
| The standard library | Modules a program imports by Python's names: `os`, `json`, `re`, ... | [Standard-library modules](stdlib.md) |

Beside those, a few modules are jac's own and have no Python counterpart: see
[Jac's own modules](jaclang.md).

## A native program does not run on CPython

`import os` in a natively compiled program does not load CPython's `os`. It loads a module
written in Jac, compiled and linked into the program like the program's own modules. Each such
module has the name, the functions and the behavior of the Python module it stands in for, so
code written against Python's documentation works where the native module is complete.

The standard library is held to this bar:

1. **The interface is Python's.** A native module declares the names of the Python 3.15 module
   of the same name, with its parameters. A name that cannot exist natively is left out, and a
   program that names it does not compile. No name is given a narrower meaning.
2. **The behavior is CPython's.** The same statements print the same output, raise the same
   exception types and carry the same messages.
3. **The speed is that of CPython's C implementation**, within 1.5x on bulk work.

Not every module meets the bar yet. [Standard-library modules](stdlib.md) lists each module
with its state: complete, or partial with what it has.

Three differences hold in every module, because they come from the language:

- `int` is a 64-bit integer. Arithmetic past its range raises `OverflowError`
  (`math.factorial(25)` raises; CPython returns a larger int).
- An argument of the wrong static type is a compile error where CPython raises `TypeError` as
  the program runs.
- No warnings are issued: there is no native `warnings` module, so a deprecated call runs
  silently.

## How `import X` resolves

For an absolute import (`import X`, `import X.Y`, `import from X { a }`), jac takes the
first of these that exists:

1. **A module of the project.** `X.jac` (or a package, `X/__init__.jac`) beside the importing
   file, then in each directory above it, up to the directory that holds the project's
   `jac.toml`.
2. **One of jac's own runtime modules**, in the runtime's directory `rt/`: `os`, `sys`,
   `random`, `struct`, `copy`, `posixpath`, `ntpath`, `genericpath`, and Jac's own modules
   (`atomics`, `dl`, `accel`, `jaclang.comptime`).
3. **A module of the native standard library**, in `rt/stdlib/`: `json`, `re`, `math`,
   `os.path`, ...
4. **CPython's module**, when none of the above exists and Python has a module of that
   top-level name: one of CPython's standard library (`pickle`, `typing`, `inspect`) or a
   package installed in the project. The program then embeds CPython and the module's values
   are Python objects. [Python interop](../interop/python.md) (`jac docs interop/python`)
   describes how those values behave.

Where a module has variants for a target, the most specific is taken: `X.<os>.<arch>.jac`,
then `X.<arch>.jac`, then `X.<os>.jac`, then `X.jac`. That is how `errno`, `signal` and
`os.path` differ by operating system while a program imports one name.

A program whose space runs on a CPython host is the other way around: there every Python
module is CPython's, and the native standard library is not used; `jaclang.comptime`
([Jac's own modules](jaclang.md)) is still jac's.

### A project file shadows a library module

Step 1 comes first, so a file named `json.jac` beside the program is what `import json` finds,
in that file itself too. Do not name a module of your project after a library module you
import.

### A package is native or missing, never mixed

When a package exists natively, every module of it is native or absent. `json` is native, and
it has no `tool` module, so `import json.tool` is an error rather than CPython's `json.tool`:

```jac
# expect: E5143
import json.tool;

with entry {
    print("unreachable");
}
```

The packages `urllib`, `concurrent` and `compression` have native submodules (`urllib.parse`,
`urllib.request`, `concurrent.futures`, `compression.zstd`) and no module of their own: import
the submodule. `http` has both: `import http;` for `HTTPStatus`, and `http.client`,
`http.server`, `http.cookies` and `http.cookiejar`.

### A name left out on purpose

A name of Python's module that a native module cannot have is refused with E5142. The message
says why and what to write instead:

```jac
# expect: E5142
import from collections { namedtuple }

with entry {
    print("unreachable");
}
```

```text
error[E5142]: 'collections.namedtuple' is part of Python's collections module but not of the
native one: it makes a class as the program runs, and a Jac class is declared in the program;
declare an obj with the fields, `obj Point { has x: int, y: int; }`, or use a tuple. CPython's
collections is reachable explicitly: importlib.import_module("collections")
```

A name that is not written yet is the ordinary error for a missing member, E1145
(`module 'http' has no 'HTTPMethod'`). A module found nowhere is W1100
(`cannot find module 'nosuchmod'`), which stops the build like an error.

| Code | Condition |
|---|---|
| W1100 | No module of that name: not in the project, not native, not Python's |
| E1145 | The module exists and has no member of that name |
| E5142 | Python's module has the name; the native one leaves it out on purpose |
| E5143 | Python's package has the module; the native package does not |

### Reaching CPython's module explicitly

`importlib` is CPython's, so `importlib.import_module("X")` gives CPython's module `X` even
where a native `X` exists. Its values are Python objects.

```jac
import importlib;

with entry {
    collections = importlib.import_module("collections");
    Point = collections.namedtuple("Point", ["x", "y"]);
    print(Point(1, 2));
}
```

```output
Point(x=1, y=2)
```

## Which modules stay CPython's

Some of Python's modules will not be written natively, because what they do is tied to the
Python interpreter. They resolve to CPython's by rule 4:

- Python source and bytecode tooling: `ast`, `dis`, `tokenize`, `py_compile`, `marshal`, ...
- Python's import and install machinery: `importlib`, `pkgutil`, `runpy`, `site`, `venv`, ...
- Debugging and profiling the Python VM: `pdb`, `trace`, `cProfile`, `tracemalloc`, `timeit`, ...
- Modules tied to Python's object model: `inspect`, `ctypes`, `pickle`, `shelve`,
  `multiprocessing`
- Python's test frameworks: `unittest`, `doctest` (`jac test` is the native answer)
- GUI and terminal toolkits: `tkinter`, `curses`, `readline`

Every other module of Python's standard library that is not native yet (`typing`, `enum`,
`dataclasses`, `contextlib`, ...) also resolves to CPython's today.

## How the library reaches the operating system

The runtime and the standard library reach the operating system through one platform layer,
with a module per kind of resource (memory, files, processes, time, threads, sockets, signals,
errors). Each has a POSIX form for macOS, Linux and WASI and a Windows form. Only that layer
binds the system's libraries; a runtime or library module elsewhere that declares a function
of the C library is refused (E5131). A program's own modules may bind any C library.

## Where to go next

- A function that needs no import: `jac docs print`, or [Builtin functions](builtins.md).
- A method of a builtin type: `jac docs str.split`, or the page for the type.
- A module: `jac docs json`, or the table in [Standard-library modules](stdlib.md).
- A Python package from PyPI: [Python interop](../interop/python.md).
