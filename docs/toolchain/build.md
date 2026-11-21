---
description: jac build for a program, what a program is (a Jac, C, C++, Rust or Python file, or a directory's manifest), every option it takes, what it writes, release builds, cross-compiling to other platforms and WebAssembly, and how the runtime and toolchain are found.
keywords: cross-compiling, cross-compile, wasm32-wasi, wasi, linux-x86_64, linux-aarch64, macos-aarch64, macos-x86_64, windows-x86_64, x86-64-v2, x86-64-v3, x86-64-v4, release build, debug map, vectorize
---
# build

`jac build` compiles a program into one native executable. The program is the main module you name and every module it imports, compiled with jac's runtime. The executable needs nothing installed where it runs.

```sh
jac build hello.jac -o hello
./hello
```

`build` has two forms. This page is the first:

| Form | Builds | Documented in |
|---|---|---|
| `jac build [<program>...] -o <out> [<option>...]` | A program: the one a Jac main module starts, or a C, C++, Rust or Python program; or several Jac programs in one executable | This page |
| `jac build [<app>...] [--profile <profile>]` | The apps of the project in this directory (one whose `archwire.jac` declares spaces), each into `dist/` | [Building apps](../apps/building.md) |

Which form runs is decided by the arguments. In a project whose `archwire.jac` declares spaces, a name with no extension or path in it is an app's; anything else names a program.

## What a program is

A program is a file, known by its extension, or a directory, known by the first manifest it holds. With none named, it is the directory the command runs in.

| Named | The program |
|---|---|
| `main.jac` | The Jac program that main module starts |
| `hello.c`, `hello.cc`, `hello.cpp` | A C or C++ program of one file, built with its language's standard library ([C and C++](../interop/c-and-cpp.md)) |
| `hello.rs` | A Rust program of one file ([Rust](../interop/rust.md)) |
| `hello.py` | A Python program of one file, built into the directory `-o` names: the program, the CPython it runs on with its standard library, and a launcher of the program's name |
| A directory whose `archwire.jac` declares spaces | The project's apps ([Building apps](../apps/building.md)). An `archwire.jac` that declares only layers and wires leaves its directory the program its other manifest names |
| A directory with a `jac.toml` | The Jac project's `main.jac` |
| A directory with a `Cargo.toml` | The Rust package |
| A directory with a `cmodule.toml` | The C module, whose sources define `main` |

A manifest named itself (`app/Cargo.toml`) is the program of its directory. `-o` and `--release` are every program's options; the others are a Jac program's.

```sh
jac build hello.c -o hello
jac build adder -o adder --release     # the Rust package in adder/
jac run hello.rs                       # build it, then run it
jac run -- input.txt                   # the program in this directory, with an argument
```

`jac run` builds a program as `build` does, in its project's `.jac/build/` unless `-o` says where, then runs it with what follows `--` and exits with its status. It takes the options of a build for this machine that is then run: `-o`, `--release`, `--cpu`, `--gui`, `--monitor`, `--memory` and `--rt`. One it does not take is named with the command that does: ``it has no option '--lib' (`jac build` and `jac check` have it)``.

What is no program is refused: a file of another extension (E5150), a directory with none of the manifests (E5151), a Jac project with no `main.jac` (E5152). A Python project (`pyproject.toml`), an npm package (`package.json`) and a JavaScript or TypeScript file are recognized and refused until their builds are made (E5090).

## What a build does

1. Loads the main module and everything it imports, with their annexes ([Projects](projects.md)).
2. Checks the whole program: syntax, names, types, ownership, the memory profile's contract. Any error stops the build, after every error of that phase is reported ([check](check.md)). A build does not check `test` blocks and does not judge lint rules; `jac check` does both.
3. Generates code, compiles each module on its own (reusing what the [build cache](cache.md) holds), and links.

On a terminal it shows the step it is at and ends with `✓ Built hello in 1.94s`. Run again with nothing changed, it does nothing and says `✓ hello is up to date`. Not on a terminal, a build that succeeds prints nothing ([Projects](projects.md#what-jac-shows-while-it-works)).

The exit status is 0 when the output was built or was up to date, and 1 otherwise.

## Options

| Option | What it does |
|---|---|
| `-o <out>` | The file to write. Required |
| `--release` | Inline more across modules: faster code, from a build that takes longer |
| `--target <platform>` | Build for another platform |
| `--cpu <processor>` | Compile for a processor newer than the platform's baseline |
| `--lib` | Build a C-ABI shared library of the main module's `:pub` functions and globals |
| `--c-archive` | Write the program's C modules as a static library; the program is not built |
| `--gui` | Build a Windows program of the GUI subsystem, which starts without a console |
| `--monitor` | Have a program using Python fire `sys.monitoring`'s events, for profilers and coverage |
| `--memory <profile>` | The memory profile: `managed`, `rc` or `nogc` |
| `--emit-ir <file>` | Also write the program's LLVM IR |
| `--verify-reuse` | Compile every module, and check each one an earlier build made against what its sources make now ([the build cache](cache.md#modules-taken-from-an-earlier-build)) |
| `--rt <dir>` | The runtime to build against |
| `--diagnostics <form>` | How diagnostics are written on stderr: `human` (the default), or `json`, one record a line ([check](check.md#diagnostics-as-json)) |
| `--profile <profile>` | For app builds only: see [Building apps](../apps/building.md) |

An option that takes a value takes it as the next argument, or, spelled with `--`, after `=` (`--rt=<dir>`); every command reads its arguments the same way ([Commands](../reference/commands.md#how-a-command-line-is-read)). A build takes one program, or several Jac programs for [one executable](#several-programs-in-one-executable). Mistakes are answered with the usage and the nearest option:

```text
jac build: it has no option '--relese' (did you mean '--release'?)

Usage: jac build [<program>...] -o <out> [<option>...]
       jac build [<app>...] [--profile <profile>]

Run `jac help build` for what it takes.
```

Leaving out `-o` is an error that suggests a name: `it needs a place to write what it builds: -o <out> (say, -o hello)`.

## What it writes

| Build | Files |
|---|---|
| A program | `<out>`. For a Windows target `.exe` is added unless `<out>` already ends in it |
| `--lib` | `<out>` as named; for Windows also the import library `<out without extension>.lib` |
| `--c-archive` | `<out>`, a static library |
| `--emit-ir <file>` | `<file>`, besides the build's own output |
| Any | A record of the build's inputs in the project's `.jac/build/`, which is how the next build knows whether it has anything to do ([cache](cache.md)) |

A program whose C modules are built as shared libraries gets those libraries beside it (`lib<name>.dylib`, `lib<name>.so`, or `<name>.dll`), and finds them there at run time.

The program keeps only what a run of it can reach; what it cannot is left out, with the libraries only that code used:

- A function nothing reachable calls or takes as a value.
- A method nothing can name of a class that is made: one that no call names and no attribute lookup by name can ask for. A program that looks attributes up by names it computes keeps every method of the classes those lookups can reach.
- The methods of a class no reachable code makes an instance of, but for a static method it calls. A call on a base class dispatches only to the classes the program makes, so a module's class the program never makes costs it nothing, whatever the class overrides. A class is made where reachable code calls it or holds it as a value.
- A module-level `glob` nothing reachable reads, when its value is a display of plain values: literals, functions, classes, other globals. Such a table is not built at start-up, and the functions only it names are left out.

A module's own code runs at the module's first use ([Modules](../language/modules.md)), so a module the program imports and never uses adds nothing. What a program that uses Python exposes to Python, and what a `--lib` build exports, count as reached.

## --release

Each module is compiled as a unit of its own, and a unit may take in a copy of a function of another unit to inline it.

A plain build compiles a module as the module and what it imports make it, whatever else the program holds. The unit is then the same in every program that uses the module, so a build finds in the [build cache](cache.md) what any other program's build compiled: the runtime and the standard library are compiled once, not once for each program, and adding a class or a module to a program compiles only what was added. Such a unit takes in:

- small functions of the modules it imports;
- a function marked `@inline`, which is inlined at every call, in every unit ([Decorators](../language/decorators.md)).

What is the whole program's is kept in a unit of the program's own, which every build of it compiles: the numbers its classes have, the test of whether a value is of a class, and how a virtual call picks its method. A module's unit reads and calls those there.

`--release` compiles the units for this one program. A unit takes in larger functions too, and a function only one other unit calls, which is compiled into that unit and inlined there whatever its size; what the program never uses is dropped before it is compiled; and each unit holds what the program unit says of the classes, so a test of a class is two comparisons with numbers. The program runs faster and the build takes longer: it shares little with another program's build, and an edit to one module recompiles more of the others.

A plain build also links less, on Linux:

- Where jac's `lib/` holds a library both as static archives and as a shared library (LLVM, which a program that compiles code links), a plain build links the shared one, and the program then runs with jac's `lib/` where it was when it was built.
- A program's Rust modules are linked once into one shared library, `libjac-rust-<hash>.so`, kept in the [build cache](cache.md) and put beside the program (a hard link, where the cache is on the same disk). The program finds it beside itself, so the two move together. Rust that calls the program's own functions (a Jac function it is given, a C module's) is linked into the program as before: such a library could not stand alone.

The link then has that much less to read and write on every build. A `--release` build links all of it in, and its program is one file that needs nothing of jac's to run.

Use a plain build while developing and `--release` for what you ship or measure.

On macOS a `--release` program is also linked without a debug map. A debug map names the object files a program was linked from by where they were on the machine that built it (the build cache, jac's `lib/`), for a debugger on that machine. Without it the program's symbols stay, it names nothing its user does not have, and the same sources build to the same bytes wherever they are built.

## --target: building for another platform

`--target <platform>` builds for a platform other than the one jac runs on. Every jac builds for all six, with no other toolchain or SDK:

| Platform | Program | C library |
|---|---|---|
| `macos-aarch64` | Mach-O, arm64, macOS 14 or later | The system's |
| `macos-x86_64` | Mach-O, x86-64, macOS 14 or later | The system's |
| `linux-aarch64` | ELF, dynamically linked | glibc: built against glibc 2.29's symbol versions, so it runs on any glibc that has every version it references |
| `linux-x86_64` | ELF, dynamically linked | The same |
| `windows-x86_64` | PE, console subsystem (`--gui` for GUI) | mingw-w64 on the Universal CRT |
| `wasm32-wasi` | A WebAssembly module (WASI preview 1) | wasi-libc |

```sh
jac build hello.jac -o hello-linux --target linux-x86_64
jac build hello.jac -o hello.exe --target windows-x86_64
jac build hello.jac -o hello.wasm --target wasm32-wasi
```

A name that is no platform is an error that lists them:

```text
jac: unknown platform 'plan9'; one of macos-aarch64, macos-x86_64, linux-aarch64, linux-x86_64, windows-x86_64, wasm32-wasi
```

An installed release carries every target's C headers and runtime. What it carries only for its own platform (the C libraries a program using Python or Node links) it fetches for another platform the first time a build needs it, and says so (`jac: fetching <what> for <platform>`). What is fetched is kept beside the build cache, in `fetched/`. It comes from the zip of that part of the toolchain its release pins, read by HTTP range requests: the zip's directory first, then the members the build needs, nearby members in one request; each member is checked against its CRC-32 as it is unpacked, and one that does not match is refused.

Windows programs are built the same way on every platform, and jac's own Windows release is built on Linux; neither has been tested on Windows yet.

### What a program does on each platform

The same program behaves the same on each, but for what the platform decides:

- **How it ends.** A program that links the C library ends through C's `exit`, whatever ends it (the end of its entry, `sys.exit(n)`, an uncaught exception): C's output buffers are flushed and the `atexit` handlers a C module registered run, before the exit status is returned.
- **Windows.** The standard streams are in binary mode from the start, as CPython puts them, so what a program writes to them reaches them byte for byte. A text file opened with `open(path, "w")` ends each line it writes with CR LF, as CPython's does there, and so does `logging.FileHandler`. The environment (`os.environ`, and `JAC_GC` and `JAC_THREADS` as a program starts) is read as UTF-8 from Windows' UTF-16 block. A `--lib` DLL's entry is `DllMain`.
- **Windows and WASI.** `fcntl`, `termios` and `tty` import, and every call of them raises `RuntimeError` (`fcntl is unavailable on this platform`).
- **WASI.** The C library is wasi-libc: `os.getcwd()` and `os.chdir()` work in its working directory, `os.listdir`, `os.putenv` and `time.sleep` work, `sys.argv` holds the arguments, and a path resolves against every directory the runtime preopens (the current directory, on jac's Node).

### wasm32-wasi

A `wasm32-wasi` build is a WASI command module, which any WASI runtime runs. jac's own Node is one, with the script `node/wasi.mjs` of jac's runtime directory (`rt/`, beside an installed release's `bin/`). It gives the program the current directory, its arguments, and the environment variables its `--env <name>=<value>` options name:

```sh
jac node ~/.jac/current/rt/node/wasi.mjs hello.wasm
```

- Its C library is wasi-libc, so functions a program imports `from c` resolve as on any target.
- A C library whose name starts with `wasi_` is a WASI host module the program imports. Any other C library is unavailable.
- C's words are 32 bits there, as wasm32's C ABI is ILP32: `int` and `ptr` in a C declaration, and the pointers that `str`, `bytes` and callbacks pass as. `i64` and `u64` are 64 bits on every target, so a C function's 64-bit integer is declared `i64`.
- With `--lib` the module is a WASI reactor: it has no entry, exports its `:pub` functions, and its globals are set by its `_initialize`.

[`jac test --target wasm32-wasi`](test.md) runs tests on jac's Node.

## --cpu: a newer processor

Without `--cpu`, a program runs on every machine of its platform: jac compiles for the platform's baseline (SSE2 on x86-64, NEON on arm64). `--cpu <processor>` compiles for more. Loops and kernels then use that processor's vector registers, and the program runs only on processors that have what that one has.

| Target architecture | `--cpu` takes |
|---|---|
| x86-64 | `x86-64` (the baseline), `x86-64-v2`, `x86-64-v3` (AVX2 and FMA), `x86-64-v4` (AVX-512), `native` |
| arm64 | `generic` (the baseline), `native` |
| wasm32 | `generic` |

`native` is the processor of the machine running the build, so it cannot be combined with a `--target` for another platform. A name the target's architecture does not have is an error that lists what it has:

```text
jac: --cpu x86-64-v3: the processors of macos-aarch64 are native, generic
```

### Which loops vectorize

On any processor, a counted loop (`for i in range(...)`) becomes a vector loop when its body computes on numbers alone and reaches its lists of numbers, `bytes`, `bytearray`s and views through locals, only by index and by `len()`. It may call the builtins that compute on numbers (`abs`, `min`, `max`, `float`, `popcount` and the like) and nothing else, and it binds, grows and shrinks none of those containers.

```jac
def axpy(out: list[float], a: list[float], b: list[float], k: float) {
    for i in range(len(out)) {
        out[i] = a[i] * k + b[i];
    }
}

def wrapping_sum(xs: list[int]) -> int {
    s = 0;
    for i in range(len(xs)) {
        s +%= xs[i];
    }
    return s;
}

with entry {
    fs = [float(i) for i in range(1000)];
    out = [0.0 for i in range(1000)];
    axpy(out, fs, fs, 2.0);
    print(out[10], wrapping_sum([i for i in range(1000)]));
}
```

```output
30.0 499500
```

Both loops above compile to vector instructions. Such a loop reads each container's length and storage once, before it runs. The index checks its bounds imply are dropped, and an index out of range still raises where the loop reaches it, after the items before it were written. A list written at a shift from where it is read gives what running the loop in order gives.

A counted loop that stays scalar keeps the first of these: when its body only indexes and measures its lists, `bytes` and views, it reads their lengths once, before the loop, and a view held in a local that its function only indexes and measures is never made as an object. A body that appends to its list reads the list's length at every pass.

What stays scalar:

| Loop | Why | What to write |
|---|---|---|
| A checked sum or map of `int` or a sized int (`s += xs[i]`) | It must raise `OverflowError` where the loop overflows | The wrapping operators (`+%=`), where wrapping is what the loop means |
| A float sum (`s += fs[i]`) | A vector loop would add in another order and change the result | |
| A container reached through a field or a global | It could change under the loop | Read it into a local first |
| A list or bytearray, in a program using Python | Python's threads may change it between iterations | |

## Several programs in one executable

Given several Jac main modules, `jac build` builds them into one executable that holds each program:

```sh
jac build tools/count.jac tools/sort.jac -o tools
./tools count notes.txt
./tools sort notes.txt
```

- **The first argument names the program to run.** It is taken off: `tools count notes.txt` runs `count.jac` with `notes.txt` as its one argument, and `sys.argv[0]` is the executable. A program is named by its file (`count.jac` is `count`), and a `main.jac` by the directory it is in. Two programs of one name are refused.
- **Each program runs as it does built alone.** Only the code of its own modules runs, in its own order, and it is its own main module (`with entry:__main__` runs, `__name__` is `"__main__"`). What the programs share, the runtime and the library modules more than one of them imports, is in the executable once: loaded, compiled and linked once for all of them.
- **With no name, or one it does not hold,** the executable says which programs it holds and exits with status 2:

  ```text
  ./tools holds the programs count, sort: its first argument names the one to run, as `./tools count`
  ```

- **What the library loads by what a program does** (`io` where one calls `open`, the codecs where one encodes) is loaded for every program of the executable when one of them needs it.
- **The programs are one project's, and none uses Python** (E5154): a program using Python carries its interpreter and standard library, and is built alone. `--lib`, `--c-archive` and `--gui` build one program.
- **It is built for Linux and macOS.** A build of several programs for Windows or WASI is refused.

## --lib: a shared library

`--lib` builds the main module as a shared library with a C ABI instead of a program. It exports the module's `:pub` functions and globals, and `jac_retain` and `jac_release` for the objects it hands out; nothing else is visible (a function or global without `:pub` is not exported).

```jac
glob:pub counter: int = 7,
         ratio: float = 0.5;

obj:pub Point {
    has x: int = 0,
        y: int = 0;
}

def:pub jadd(a: int, b: int) -> int {
    return a + b;
}

def:pub make_point(x: int, y: int) -> Point {
    return Point(x=x, y=y);
}

def:pub point_sum(p: Point) -> int {
    return p.x + p.y;
}

def:pub safe_div(a: int, b: int) -> int {
    return a // b;
}

def helper -> int {
    return 1;
}
```

`host.c`:

```c
#include <stdint.h>
#include <stdio.h>

extern int64_t counter;
extern double ratio;

int64_t jadd(int64_t a, int64_t b);
void *make_point(int64_t x, int64_t y);
int64_t point_sum(void *p);
int64_t safe_div(int64_t a, int64_t b);

int main(void) {
    void *p = make_point(3, 4);
    printf("%lld %lld %.2f\n", (long long)jadd(2, 3), (long long)counter, ratio);
    printf("%lld %lld %lld\n", (long long)point_sum(p), (long long)safe_div(9, 2), (long long)safe_div(1, 0));
    return 0;
}
```

```sh
jac build mathlib.jac --lib -o libmathlib.dylib
jac cc host.c libmathlib.dylib -Wl,-rpath,@loader_path -o host
./host
```

```text
Traceback (most recent call last):
  File "mathlib.jac", line 22, in safe_div
    return a // b;
ZeroDivisionError: division by zero
5 7 0.50
7 4 0
```

What C sees of each type:

| Jac | C |
|---|---|
| `int`, `bool`, `i64` | `int64_t` |
| `u64` | `uint64_t` |
| `i8`, `i16`, `i32`, `u8`, `u16`, `u32` | The C integer of that width and sign (`int32_t`, `uint8_t`, ...) |
| `float` | `double` |
| `f32`, `f16`, `bf16` | `float`, `_Float16`, `__bf16` |
| A `glob:pub` global | C data of its type, declared `extern` (`extern int64_t counter;`); a Windows C program declares it `__declspec(dllimport)` |
| An `obj` (or any other value) | An opaque handle, `void *`, which C only passes back |

- **A handle** stays valid while the library is loaded: what the library hands out is never freed. `jac_retain(void *)` and `jac_release(void *)` are the calls for a C program that holds and drops handles; neither is needed for a handle to stay valid.
- **An exception** an exported function raises cannot reach C. The function returns 0 (a float function 0.0) and prints the exception's traceback on stderr.
- **The library's module code** runs when the library is loaded, before any export is called: as a constructor on Linux and macOS, from `DllMain` on Windows (called by mingw-w64's `dllcrt2.o`), from `_initialize` on WASI.

Name the output as the platform names libraries (`lib<name>.dylib`, `lib<name>.so`, `<name>.dll`). Linking a C program against it:

| Platform | Link | Finds the library at run time by |
|---|---|---|
| macOS | `host.c libmathlib.dylib -Wl,-rpath,@loader_path` | The rpath: beside the program |
| Linux | `host.c libmathlib.so -Wl,-rpath,'$ORIGIN'` | The same |
| Windows | `host.c mathlib.lib`, the import library written beside `mathlib.dll` | Windows' search, which starts beside the program |

`jac check --lib` checks a module as this build makes it.

## --c-archive: the program's C modules

`--c-archive` compiles the C modules the program imports and writes them as one static library, `<out>`, for another build system to link. The Jac program itself is not built. An [inline module](../interop/c-modules.md#inline-modules) is in the library as objects, like every other: there is no program for its bitcode to be linked into. C modules that are built as shared libraries are written as those libraries, beside `<out>`.

```sh
jac build main.jac --c-archive -o libadder.a
```

## --gui, --monitor, --memory, --emit-ir, --verify-reuse

- `--gui` builds a Windows program of the GUI subsystem, which starts without a console window. It is refused for any other target, for `--lib`, and for a test runner.
- `--monitor` makes a program that uses Python fire the events of Python's `sys.monitoring` from its own Jac functions and module code, which is what Python's profilers and coverage tools listen to. The standard library's functions fire them too, as CPython's Python modules do, but for `_thread`'s, which CPython writes in C and which fire none.
- `--memory managed|rc|nogc` picks the memory profile. Without it the project's `jac.toml` decides (`[memory] profile`), and `managed` is the default. See [Memory](../language/memory.md) (`jac docs memory`). A value that is none of the three is an error.
- `--emit-ir <file>` also writes the whole program's LLVM IR as text, as generated and before optimization. A build with `--emit-ir` always runs, even when the output is up to date, and generates every module's code: it takes none as an earlier build made it, since what the cache holds of a module is its compiled code and not this. The module carries its target's `target datalayout`; a function is named `j.<module>.<function>` (`j.tries.fast`), and a kernel's copy for the processor `k.j.<module>.<function>`. The decorators of [jaclang.comptime](../language/decorators.md) show as LLVM's attributes: `@inline` as `alwaysinline`, `@noinline` as `noinline`, `@cold` as `cold noinline`, and `@align(64)` as `align 64` on what is laid out.
- `--verify-reuse` checks what the build takes from the cache: it generates every module's code, whatever an earlier build recorded of it, and fails if a module it would have taken as that build made it is not what its sources make now. It always runs, and is for a plain build: a `--release` build takes no module from the cache. See [the build cache](cache.md#modules-taken-from-an-earlier-build).

## How the runtime is found

Every program is compiled with the runtime: the directory `rt/`, Jac source that holds the builtins, the standard library and `stdjac`.

- jac uses the `rt/` beside its own executable's directory, or in the nearest directory above it that has one. For an installed release that is `<prefix>/rt` beside `<prefix>/bin/jac`.
- `--rt <dir>` names another. The directory must hold `core.jac`.
- A runtime made for a different jac is refused before anything is compiled: `the runtime at <dir> does not match this jac: ...`, naming the entry points that differ.
- With no runtime at all: `no runtime found: jac looks for rt/core.jac beside <dir> and in each directory above it; pass --rt <dir>`.

The rest of the toolchain (Clang's headers, each target's C library and runtime, the C libraries, CPython, Node) is the `lib/` beside jac's `bin/`. `JAC_LIB_DIR` names another `lib/`. A checkout's `build/bin/jac` has `build/lib` beside it and needs none; a compiler built anywhere else in a checkout (a stage of the bootstrap, a compiler you build while working on jac) is run with `JAC_LIB_DIR=build/lib`. It never relocates jac's own Rust toolchain, which is always the `lib/rust` of the jac that runs. See [Environment variables](../reference/environment.md).

## What goes wrong

| Message | Cause |
|---|---|
| `error[...]` diagnostics, then `N errors` | The program has errors: see [check](check.md) |
| `it needs the program's main module` | No `.jac` file was named, outside a project |
| `it takes one program, and was given 'a.jac' and 'b.jac'` | Two main modules. Name one; it imports the others |
| `'web' is neither a program's main module nor an app` | An app's name, in a directory with no `archwire.jac` |
| `--cpu native is this machine's processor: not for a build for another platform` | `--cpu native` with `--target` |
| `a crate's build takes -o and --release, and '--target' is an option of a Jac program's build` | An option other than `-o` and `--release` with a `Cargo.toml`. `jac cargo build --target <target>` builds a crate for another target ([Rust](../interop/rust.md)) |
| `--gui builds a Windows program (the GUI subsystem): not a library, a test runner, or for another platform` | `--gui` without `--target windows-x86_64` |
| `error[E5135]: the C file <path> does not compile` | A C module's source failed; Clang's own errors are above it |
| `compilation failed`, `link failed` | An internal failure after the program checked: report it |
