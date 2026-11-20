---
description: What a native Jac program can call besides Jac - C libraries, C and C++ source, Rust crates, Python and npm packages - how each is reached, and the toolchains jac carries for them.
keywords: interop, interoperability, foreign code
---
# Using other languages

A native Jac program calls code written in other languages directly, in its own process, and
jac carries the compilers and runtimes for each: Clang and LLD for C and C++, cargo and rustc for
Rust, CPython 3.15 and Node 26. Nothing needs installing on the machine.

| What you have | How Jac reaches it | Page |
|---|---|---|
| A C library already built (`libz`, the C library, a project's `.so`) | Declare what you use in `import from <library> { def ...; }` | [C libraries](c-libraries.md) |
| A C library that may be absent as the program runs | Open it with the `dl` module and call its symbols | [Opening a library as the program runs](dl.md) |
| C or C++ source | A directory with a `cmodule.toml`, imported as a module; its headers give the declarations | [C modules](c-modules.md) |
| A Rust crate | A directory with a `Cargo.toml`, imported as a module; its `extern "C"` items are the interface | [Rust modules](rust-modules.md) |
| CPython's standard library, a PyPI package | `import` it as a Jac module; `jac install --pypi <name>` | [Python](python.md), [Python values](python-values.md) |
| A project's own `.py` files | Wired into a `cpython` space | [A project's own Python modules](python-modules.md) |
| An npm package, Node's built-in modules | `import from "pkg" { ... }`; `jac install --npm <name>` | [npm and Node](npm.md) |

What C memory a program handles (`ptr[T]`, views, `pin`, `addressof`) is in
[Pointers and native memory](pointers-and-native-memory.md), and the intrinsics below pointers
(loads and stores at an `int` address, thread-local cells) in
[Raw memory intrinsics](pointers-and-native-memory-intrinsics.md).

## How the languages meet

- **C, C++ and Rust compile into the program.** Their calls are direct calls with the platform's C
  ABI, and with `--release` the optimizer inlines across Jac, C and Rust. The C types a call
  takes are the same for all three: the table is in [C libraries](c-libraries.md#types-in-a-declaration).
- **Python and JavaScript run in the program's process.** The program links CPython, or Node, and
  starts it the first time it imports a module of that language. Their values are objects Jac
  code uses directly (`PyObject`, `JsObject`); each side's numbers, strings, lists and dicts cross
  as the other side's own.
- **Checking reaches into them.** A C module's headers, a crate's interface, a Python module's
  stubs and an npm package's TypeScript declarations are read at compile time, so a name or a call
  they rule out is a compile error.
- **Wires connect them.** In a project with an `archwire.jac`, C modules, crates and Jac modules are
  wired to one another by name; see [Import wiring](../language/modules-wiring.md).

## The toolchains

| Command | What it is | Page |
|---|---|---|
| `jac cc`, `jac c++` | Clang and LLD, for every target from any machine | [C and C++](c-and-cpp.md) |
| `jac cargo`, `rustc`, `rustdoc` | Rust 1.99 | [Rust](rust.md) |
| `jac python` | CPython 3.15 | [Python](python.md#the-interpreter) |
| `jac install`, `jac remove` | A project's packages, as `jac.toml` lists them and `jac.lock` pins them: PyPI's in `.jac/venv`, npm's in `eco/<tree>` | [Packages](../toolchain/packages.md) |
| `jac absorb` | Takes a `package.json` and its lock into `jac.toml` and `jac.lock` | [Packages](../toolchain/packages.md#taking-in-a-manifest-you-already-have) |
| `jac node`, `npm`, `npx` | Node 26 and its npm | [npm and Node](npm.md#jac-node-npm-and-npx) |

`jac build --lib` goes the other way: it builds a Jac module as a shared library that C (or any
language with a C FFI) calls. The library sets its globals as it is loaded, before its caller
reads one: from the initializer the loader runs on Linux and macOS, from `DllMain` on Windows, and
from `_initialize` on WASI. See [Building programs](../toolchain/build.md) (`jac docs build`).

## Platforms

| | Linux x86_64 | Linux arm64 | macOS arm64 | macOS x86_64 | Windows x86_64 | wasm32-wasi |
|---|---|---|---|---|---|---|
| C libraries | yes | yes | yes | yes | yes | `c`, `m` and WASI's host modules |
| C and C++ modules | yes | yes | yes | yes | yes | no |
| Rust modules | yes | yes | yes | yes | yes | no |
| Python | yes | yes | yes | yes | yes | no |
| npm and Node | yes | yes | yes | no | no | no |

A program that imports npm packages builds only for the platform it is built on.
