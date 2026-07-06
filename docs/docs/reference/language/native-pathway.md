# Native Compilation

> **Related:** [Primitives & Codespace Semantics](primitives.md) | [Functions & Objects](functions-objects.md) | [CLI Commands](../cli/index.md)

**In this part:**

- [Overview](#overview) - What native compilation is and when to use it
- [Quick Reference](#quick-reference) - At-a-glance summary of capabilities
- [Native Sections in Jac Applications](#native-sections-in-jac-applications) - Mixing native sections into Python-backed Jac code
- [Python-Native Interop](#python-native-interop) - How the two codespaces communicate
- [Standalone Native Binaries](#standalone-native-binaries) - Compiling `.na.jac` files to executables
- [Type System](#type-system) - Native type mappings and fixed-width types
- [Supported Language Features](#supported-language-features) - What works in native code
- [C Library Interop](#c-library-interop) - Calling C functions from Jac
- [Platform Support](#platform-support-currently) - Supported OS and architecture targets
- [Memory Management](#memory-management) - Reference counting model
- [Debugging](#debugging) - Tools for inspecting native compilation
- [Roadmap Items](#roadmap-items-current-limitations) - Features not yet available in native code
- [Examples](#examples) - Complete native programs

---

## Overview

Jac's native codespace compiles code to **machine-code via LLVM** -- the same Jac syntax, but running as native instructions instead of on the Python runtime. You can use it in two ways:

1. **Inline native sections** -- drop native-compiled functions into any Jac application alongside Python-backed code using a `na { }` block (or `to na:` section header / `na` statement prefix). The compiler generates the interop layer automatically.
2. **Standalone `.na.jac` files** -- compile an entire program to a self-contained binary with `jac nacompile`. No Python runtime, no external compiler, no external linker -- the entire toolchain from source to executable runs within Jac itself.

Native compilation is ideal for:

- **Performance-critical hot paths** -- numeric computation, tight loops, data processing
- **Standalone tools** -- CLI utilities and system programs that run without Python installed
- **Single-binary deployment** -- distribute one executable with no dependencies beyond libc

---

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Inline section** | `na { }` block (or `to na:` header / `na` prefix) in any `.jac` file |
| **Dedicated file** | `.na.jac` extension |
| **Entry point** | `with entry { }` (standalone binaries only) |
| **CLI command** | `jac nacompile <file> [-o output] [--shared]` |
| **Backend** | LLVM IR via llvmlite |
| **Platforms** | Linux (x86_64, aarch64), macOS (x86_64, arm64), Windows (x86_64) |
| **External toolchain** | None -- entire pipeline is self-contained |
| **C interop (in)** | `import from libname` (logical) or `import from "path"` (explicit) |
| **C interop (out)** | `jac nacompile --shared` exports `:pub` symbols as a `.so`/`.dylib`/`.dll` |
| **Std library** | `import math` / `time` / `sys` / `os` / `random` (Python-congruent subset) |
| **Memory model** | Automatic reference counting |
| **Testing** | `test "description" { }` blocks compile native and run via `jac test` |

---

## Native Sections in Jac Applications

The most common way to use native compilation is to tag elements of a regular `.jac` file for the native codespace. Functions in a native section compile to native machine code while the rest of the file runs on Python as usual.

There are three ways to select the native codespace inside a file:

- **`na { ... }` braced block** (recommended) -- every element inside the braces compiles native; the braces bracket exactly the tagged region. Also works inside inner scopes.
- **`to na:` section header** -- every following module-level element compiles native until the next `to X:` header or end of file. Convenient for a module that is mostly native.
- **`na` single-statement prefix** -- tags one declaration.

```jac
# app.jac

# Standard Jac -- runs on Python
def process_data(items: list[dict]) -> list[dict] {
    # Full access to PyPI, walkers, by llm(), etc.
    return [item for item in items if item["active"]];
}

na {
    # Native codespace -- compiles to machine code
    def compute_checksum(data: list[int]) -> int {
        has result: int = 0;
        for val in data {
            result = (result * 31 + val) % 1000000007;
        }
        return result;
    }

    def fibonacci(n: int) -> int {
        if n <= 1 { return n; }
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
}

with entry {
    # Call both Python and native functions seamlessly
    print(compute_checksum([1, 2, 3, 4, 5]));
    print(fibonacci(30));
}
```

The compiler handles everything: native functions are JIT-compiled and callable from the Python side without any manual bridging. You write one file, and each codespace compiles to its own backend.

### When to Use Native Sections

- **Tight loops** over numeric data where Python overhead matters
- **Recursive algorithms** (e.g., tree traversal, dynamic programming)
- **Data transformation** on large collections
- Functions with **no Python library dependencies** -- if you need PyPI packages, keep that code in the Python codespace

### Context Isolation

Native-tagged functions are excluded from Python codegen, and Python functions are excluded from native IR. Each codespace only sees its own definitions at compile time. Cross-codespace calls go through the interop bridge.

---

## Python-Native Interop

When a `.jac` file contains both Python and native-tagged code, the compiler generates interop stubs automatically:

```jac
# interop_example.jac

# Python function
def py_double(x: int) -> int {
    return x * 2;
}

na {
    # Native function that calls the Python function
    def native_add_one_to_doubled(x: int) -> int {
        has doubled: int = py_double(x);
        return doubled + 1;
    }
}

with entry {
    print(native_add_one_to_doubled(5));  # prints 11
}
```

The compiler:

1. Generates a Python-callable stub for each native function
2. Generates a native-callable callback for each Python function referenced from native code
3. Handles type marshalling at the boundary (int, float, str, bool)

!!! note
    Cross-codespace interop works for all Jac types -- primitives, collections, and Jac `obj` classes. The only boundary is Python-style classes (those relying on monkey patching, dynamic attribute injection, or other runtime-mutable behavior), which should stay in the Python codespace.

### Import Between Native Modules

Native files can import from other native files:

```jac
# math_utils.na.jac
def square(x: int) -> int {
    return x * x;
}
```

```jac
# app.na.jac
import from math_utils { square }

with entry {
    print(f"5^2 = {square(5)}");
}
```

The compiler links imported native modules at the IR level -- no dynamic library loading needed.

---

## Standalone Native Binaries

For programs that should run without Python entirely, use `.na.jac` files and compile them with `jac nacompile`.

### Writing a Standalone Program

A `.na.jac` file is entirely native -- every function, object, and expression compiles to machine code. A `with entry {}` block serves as the program's entry point.

```jac
# hello.na.jac

def greet(name: str) -> str {
    return f"Hello, {name}!";
}

with entry {
    print(greet("World"));
}
```

### Compiling

```bash
jac nacompile <filename> [-o <output>]
```

| Option | Description | Default |
|--------|-------------|---------|
| `<filename>` | Input `.na.jac` or `.jac` file | (required) |
| `-o <output>` | Output binary name | Input filename without extension |

```bash
$ jac nacompile hello.na.jac -o hello

=== Compilation Stats ===
Object size:   4,832 bytes
Binary size:   12,288 bytes
Target triple: arm64-apple-macosx

$ ./hello
Hello, World!
```

The output is a fully linked, self-contained executable. No external compiler (gcc, clang) or linker (ld, lld) is invoked -- Jac's built-in compilation pipeline handles everything from LLVM IR generation through to the final binary format for your platform.

!!! info "Auto-promotion"
    Regular `.jac` files can be auto-promoted to native compilation if they only use native-compatible features (no walkers, async, lambdas, etc.) and contain a `with entry {}` block.

### Compilation Pipeline

```mermaid
graph LR
    SRC["Jac Source"] --> PARSE["Parser &<br/>Semantic Analysis"]
    PARSE --> IRGEN["LLVM IR<br/>Generation"]
    IRGEN --> JIT["Machine Code<br/>(via llvmlite)"]
    JIT --> BIN["Standalone<br/>Binary"]
```

1. **Parsing & Semantic Analysis** -- standard Jac frontend (shared with the Python backend)
2. **LLVM IR Generation** -- the `NaIRGenPass` walks the AST and emits LLVM IR using llvmlite's builder
3. **Machine Code Emission** -- llvmlite's MCJIT compiles IR to a relocatable object for the host architecture
4. **Binary Packaging** -- a built-in platform-aware linker produces the final executable (ELF on Linux, Mach-O on macOS), with no external tools required

---

## Shared Libraries (C ABI)

Where `import from "lib.so" { ... }` lets native Jac *call into* C libraries, `jac nacompile --shared` does the inverse: it packages a `.na.jac` module as a **C-ABI shared library** that any C/C++/Python/Rust host can load and call. The same self-contained pipeline emits an ELF `.so`, a Mach-O `.dylib`, or a PE `.dll` -- no system linker required.

```bash
jac nacompile mathlib.na.jac --shared          # -> ./libmathlib.so   (host platform)
jac nacompile mathlib.na.jac --shared --target macos     # -> ./libmathlib.dylib
jac nacompile mathlib.na.jac --shared --target windows   # -> ./libmathlib.dll
```

### Choosing what to export

A shared library has no `with entry {}` -- its surface is whatever you mark **`:pub`**. Only explicitly `:pub` functions and globals are placed in the library's export table; everything else stays internal (callable *within* the library, invisible to a host). This makes `:pub` a curated C-ABI surface rather than a dump of every symbol.

```jac
# mathlib.na.jac
glob:pub counter: int = 7;          # exported global (read via dlsym/GetProcAddress)

def:pub jadd(a: int, b: int) -> int {   # exported function
    return a + b;
}

def helper(x: int) -> int {          # NOT exported -- internal only
    return x * 2;
}

obj:pub Point {
    has x: int = 0, y: int = 0;
}

def:pub make_point(x: int, y: int) -> Point {
    return Point(x=x, y=y);          # returns an opaque handle (see below)
}

def:pub point_sum(p: Point) -> int {
    return p.x + p.y;
}
```

`:pub` symbols exported from imported native modules are re-exported too, so a library can be composed from several `.na.jac` files.

### Calling it from C

The exported names are plain C symbols. Scalars (`int`->`int64`, `float`->`double`, `bool`) pass by value; the library links and loads with the standard toolchain:

```c
// gcc app.c -L. -lmathlib -Wl,-rpath,. -o app
extern long jadd(long, long);
extern long get_counter(void);
int main(void) { return (int)(jadd(2, 3) + get_counter()); }  // 12
```

…or via `dlopen`/`ctypes`:

```python
import ctypes
lib = ctypes.CDLL("./libmathlib.so")
lib.jadd.restype = ctypes.c_int64
lib.jadd.argtypes = [ctypes.c_int64, ctypes.c_int64]
print(lib.jadd(2, 3))   # 5
```

### Opaque object handles and lifetimes

Jac objects, strings, lists and dicts are reference-counted heap values. They cross the C ABI as **opaque handles** (`void*`): a host receives the pointer from one `:pub` function and passes it to another, but must not dereference it directly. Because the library manages those objects with reference counting, it also exports two helpers so a host can manage their lifetime:

```c
void  jac_retain(void *handle);    // take a reference
void  jac_release(void *handle);   // drop a reference (frees at zero)
```

```python
p = lib.make_point(3, 4)     # opaque Point*
lib.point_sum(p)             # -> 7
lib.jac_release(p)           # release when done
```

### Initialization

Module globals are initialized automatically when the library is loaded -- there is no `jac_init()` to remember. The loader runs an injected `__jac_shared_init` via the platform's standard mechanism (ELF `DT_INIT_ARRAY`, Mach-O `__mod_init_func`, PE `DllMain` on `DLL_PROCESS_ATTACH`), which runs this module's and every imported native module's global initializers before any export is called.

### Per-platform output

| Target | Output | Format details |
|--------|--------|----------------|
| Linux (default/host) | `lib<name>.so` | `ET_DYN`, PIC, exported `.dynsym` + `.hash`, `R_*_RELATIVE` fixups, `DT_INIT_ARRAY`, section headers (so `ld -l`, `readelf`, `nm -D` all work) |
| `--target macos` | `lib<name>.dylib` | `MH_DYLIB`, export trie, `__mod_init_func`, `LC_ID_DYLIB`; ad-hoc code-signed on arm64 |
| `--target windows` | `lib<name>.dll` | `IMAGE_FILE_DLL`, export directory, `.reloc` base relocations, `DllMain` entry |

!!! note "What can be exported"
    A `:pub` export's parameters and return value must be C-ABI representable: scalars and pointers (Jac objects/strings/containers as opaque `void*` handles), plus the C struct types from `import from "lib"` interop. Methods are not exported (their symbol is class-qualified, not a valid C name) -- wrap them in a `:pub` free function.

---

## Type System

### Primitive Type Mappings

Native compilation maps Jac types to LLVM types:

| Jac Type | LLVM Type | Size | Notes |
|----------|-----------|------|-------|
| `int` | `i64` | 8 bytes | 64-bit signed integer |
| `float` | `f64` | 8 bytes | 64-bit double precision |
| `bool` | `i1` | 1 bit | Boolean |
| `str` | `i8*` | pointer | Null-terminated byte string |
| `None` | -- | -- | Null pointer |

### Fixed-Width Types

For C interop and precise control, Jac provides fixed-width integer and float types:

| Type | Size | Description |
|------|------|-------------|
| `i8` / `u8` | 1 byte | Signed / unsigned 8-bit |
| `i16` / `u16` | 2 bytes | Signed / unsigned 16-bit |
| `i32` / `u32` | 4 bytes | Signed / unsigned 32-bit |
| `i64` / `u64` | 8 bytes | Signed / unsigned 64-bit |
| `f32` | 4 bytes | Single-precision float |
| `f64` | 8 bytes | Double-precision float |
| `c_void` | pointer | Opaque pointer (for C interop) |

### Collection Internals

Collections are represented as LLVM struct types:

| Jac Type | Internal Layout |
|----------|----------------|
| `list[T]` | `{ i64 capacity, i64 len, T* data }` |
| `dict[K, V]` | `{ K* keys, V* values, i64 len }` |
| `set[T]` | `{ T* data, i64 len }` |
| `tuple[T, ...]` | LLVM literal struct (fields packed by type) |

---

## Supported Language Features

### Data Types

| Feature | Example |
|---------|---------|
| Integers | `x: int = 42;` |
| Floats | `y: float = 3.14;` |
| Strings | `s: str = "hello";` |
| Booleans | `b: bool = True;` |
| None | `x: int? = None;` |
| Lists | `items: list[int] = [1, 2, 3];` |
| Dictionaries | `m: dict[str, int] = {"a": 1};` |
| Sets | `s: set[int] = {1, 2, 3};` |
| Tuples | `t: tuple[int, str] = (1, "a");` |
| Enums | `enum Color { RED=0, BLUE=1 }` |
| Typed-base enums | `enum HttpStatus: int { OK=200, NOT_FOUND=404 }` (members are real `int`) |
| Objects | `obj Point { has x: int; }` |

### Control Flow

| Feature | Example |
|---------|---------|
| If/elif/else | `if x > 0 { ... } elif x == 0 { ... } else { ... }` |
| While loops | `while x > 0 { x -= 1; }` |
| For-in range | `for i in range(10) { ... }` |
| For-in collection | `for item in items { ... }` |
| For-in lazy adapters | `for x in map(f, items) { ... }`, also `filter` / `enumerate` / `zip` |
| Break / Continue | `break;` / `continue;` |
| Ternary | `x = a if condition else b;` |

### Functions

| Feature | Example |
|---------|---------|
| Free functions | `def add(a: int, b: int) -> int { return a + b; }` |
| Methods | `def increment() { self.count += 1; }` |
| Default parameters | `def bias(x: int, b: int = 100) -> int { ... }` |
| Init constructor | `def init(x: int) { self.x = x; }` |
| Postinit hook | `def postinit() { self.setup(); }` |
| Recursion | `def fib(n: int) -> int { return fib(n-1) + fib(n-2); }` |

### Operators

| Category | Operators |
|----------|-----------|
| Arithmetic | `+`, `-`, `*`, `/`, `//`, `%`, `**` |
| Comparison | `<`, `>`, `<=`, `>=`, `==`, `!=` |
| Logical | `and`, `or`, `not` |
| Bitwise | `&`, `\|`, `^`, `<<`, `>>` |
| Membership | `in`, `not in` |
| Identity | `is`, `is not` |
| Augmented assignment | `+=`, `-=`, `*=`, `//=`, `%=` |

### String Operations

| Feature | Example |
|---------|---------|
| String literals | `"hello"`, `'world'` |
| F-strings | `f"value={x}"` |
| Raw f-strings | `rf"value={x}"` |
| Concatenation | `s1 + s2` |
| Length | `len(s)` |
| Indexing | `s[0]` |
| `strip()` | `s.strip()` |
| `split(sep)` | `s.split(",")` |
| `upper()` / `lower()` | `s.upper()` |
| `find(sub)` | `s.find("x")` |
| `startswith()` / `endswith()` | `s.startswith("abc")` |
| `join()` | `",".join(parts)` |
| `replace()` | `s.replace("a", "b")` |
| `count()` | `s.count("a")` |

### List Operations

| Feature | Example |
|---------|---------|
| Literal creation | `[1, 2, 3]` |
| Indexing / assignment | `items[0]`, `items[i] = 5` |
| `append()` / `pop()` | `items.append(4)`, `items.pop()` |
| `insert()` / `remove()` | `items.insert(0, val)`, `items.remove(val)` |
| `clear()` / `copy()` | `items.clear()`, `items.copy()` |
| `index()` / `reverse()` / `sort()` | `items.index(val)`, `items.reverse()`, `items.sort()` |
| `len()` / `in` | `len(items)`, `val in items` |
| Comprehensions | `[x * 2 for x in items]` |

### Dict Operations

| Feature | Example |
|---------|---------|
| Literal creation | `{"a": 1, "b": 2}` |
| Get / set by key | `d[key]`, `d[key] = val` |
| `len()` / `in` | `len(d)`, `key in d` |
| `keys()` / `values()` / `items()` | `d.keys()`, `d.values()`, `d.items()` |
| `get()` / `pop()` | `d.get(key)`, `d.pop(key)` |
| `clear()` / `copy()` / `update()` | `d.clear()`, `d.copy()`, `d.update(other)` |
| Comprehensions | `{k: v * 2 for k, v in d.items()}` |

### Set Operations

| Feature | Example |
|---------|---------|
| Literal creation | `{1, 2, 3}` |
| `add()` / `remove()` / `discard()` | `s.add(4)`, `s.remove(val)`, `s.discard(val)` |
| `pop()` / `clear()` / `copy()` | `s.pop()`, `s.clear()`, `s.copy()` |
| `len()` / `in` | `len(s)`, `val in s` |
| `union()` / `intersection()` / `difference()` | `s1 \| s2`, `s1 & s2`, `s1 - s2` |
| Comprehensions | `{x * 2 for x in items}` |

### Object-Oriented Programming

| Feature | Example |
|---------|---------|
| Object declaration | `obj Point { has x: int; has y: int; }` |
| Field defaults | `has count: int = 0;` |
| Methods | `def sum() -> int { return self.x + self.y; }` |
| Constructor (`init`) | `def init(x: int, y: int) { ... }` |
| Keyword / positional construction | `Point(x=10, y=20)` or `Point(10, 20)` |
| Single inheritance | `obj Dog(Animal) { ... }` |
| Method override (virtual dispatch) | Subclass methods override parent via vtables |
| Chained access | `obj.inner.field`, `obj.inner.method()` |

### Exception Handling

| Feature | Example |
|---------|---------|
| `try / except` | Basic exception catching |
| `try / except / else` | Else block runs when no exception raised |
| `try / except / finally` | Finally block always runs |
| Multiple handlers | `except ValueError { ... } except KeyError { ... }` |
| Exception binding | `except ValueError as e { ... }` |
| Nested try blocks | Try inside try |
| `raise` | `raise ValueError("bad input");` |
| Exception hierarchy | Catching a parent type catches child types |

**Supported exception types:** `Exception`, `ValueError`, `TypeError`, `RuntimeError`, `ZeroDivisionError`, `IndexError`, `KeyError`, `OverflowError`, `AttributeError`, `AssertionError`, `MemoryError`

### File I/O and Context Managers

| Feature | Example |
|---------|---------|
| `open(path, mode)` | `f = open("data.txt", "r");` -- raises `FileNotFoundError` if the path is missing (CPython-congruent) |
| `f.read()` / `f.readline()` | Read entire file or one line |
| `f.write(data)` / `f.flush()` | Write string, flush buffer |
| `f.close()` | Close file handle |
| `with` statement | `with open("f.txt", "r") as f { ... }` |
| Custom context managers | Objects with `__enter__()` and `__exit__()` |

### Builtin Functions

| Function | Notes |
|----------|-------|
| `print()` | Multiple args, mixed types |
| `len()` | Strings, lists, dicts, sets |
| `range()` | For-loop iteration |
| `abs()` / `min()` / `max()` / `pow()` | Numeric builtins |
| `chr()` / `ord()` | Character conversion |
| `str()` / `int()` | Type conversion |
| `input()` | Read a line from stdin |
| `map()` / `filter()` | Lazy iterator adapters; iterate in a `for` loop |
| `enumerate()` / `zip()` | Lazy adapters yielding tuples; unpack in a `for` loop |

The `map`, `filter`, `enumerate`, and `zip` builtins are lazy iterator adapters: a `for` loop consumes them, and they compose without building intermediate lists (e.g. `for x in map(double, filter(is_even, items)) { ... }`, or `for (i, x) in enumerate(items) { ... }`). They are supported as `for`-loop iterables; binding an iterator to a variable and advancing it with `next()` is not available.

### Standard Library Modules

Native Jac ships a growing, **Python-congruent** subset of the standard library:
the *same* `import X` + `X.func(...)` source compiles and runs on both the
Python/`sv` pathway and the native/`na` pathway, with the native side lowering
to libc/libm. Where behavior can still diverge, it is noted per module below.

| Module | Status | Lowering |
|--------|--------|----------|
| `math` | full (results match CPython to within floating-point ULP) | libm |
| `time` | full | `clock_gettime` / `nanosleep` |
| `sys` | subset | constants + argv/exit |
| `os` / `os.path` | subset | libc |
| `random` | seed-sequence faithful | CPython MT19937 |

Anything not yet lowered is **rejected at compile time** (rather than silently
producing a wrong binary), so an unsupported `import` or member fails loudly.

#### `math` -- Floating-Point Math

`import math` lowers to libm, so results are congruent with CPython (which also
calls libm) to within floating-point ULP.

| Group | Members |
|-------|---------|
| Constants | `pi`, `e`, `tau`, `inf`, `nan` |
| Powers / roots | `sqrt`, `cbrt`, `pow` |
| Trig + inverses | `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `hypot` |
| Hyperbolic + inverses | `sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh` |
| Exp / log | `exp`, `expm1`, `log` (one- or two-arg), `log2`, `log10`, `log1p` |
| Rounding (return `int`) | `floor`, `ceil`, `trunc` |
| Misc | `fabs`, `fmod`, `copysign`, `remainder`, `degrees`, `radians` |
| Special | `gamma`, `lgamma`, `erf`, `erfc` |
| Predicates (return `bool`) | `isnan`, `isinf`, `isfinite` |

```jac
import math;

with entry {
    print(math.sqrt(16.0));        # 4.0
    print(math.hypot(3.0, 4.0));   # 5.0
    print(math.floor(2.7));        # 2  (int)
    print(math.log(8.0, 2.0));     # 3.0
}
```

#### `time` -- Clocks and Sleep

`import time` lowers to POSIX clocks. Wall-clock values are inherently
non-deterministic, but each reader is congruent with its CPython counterpart.

| Feature | Notes |
|---------|-------|
| `time.time()` | Unix epoch seconds (`float`), `CLOCK_REALTIME` |
| `time.monotonic()` / `time.perf_counter()` | Monotonic seconds (`float`) |
| `time.time_ns()` / `time.monotonic_ns()` / `time.perf_counter_ns()` | Integer nanoseconds |
| `time.sleep(secs)` | Suspend for `secs` (fractional seconds OK), via `nanosleep` |

#### `sys` -- Interpreter and Process

| Feature | Example |
|---------|---------|
| `sys.argv` | `args = sys.argv;` -- `list[str]`, `argv[0]` is the program name |
| `sys.exit(code)` | `sys.exit(1);` -- exit with a status code |
| `sys.maxsize` | `INT64_MAX` (native `int` is 64-bit) |
| `sys.byteorder` | `"little"` / `"big"` (host arch) |
| `sys.platform` | e.g. `"linux"` / `"darwin"` |

`sys.argv` works both with `jac run --autonative` and standalone binaries
compiled via `jac nacompile`.

#### `os` and `os.path` -- Operating System

`import os` lowers to libc. `os.getcwd()` / `os.getenv(name)` return strings
(`getenv` returns `None` for an unset variable); the mutating calls operate on
the real filesystem.

| `os` | Notes |
|------|-------|
| `os.getpid()` | Process id (`int`) |
| `os.getcwd()` | Current working directory (`str`) |
| `os.getenv(name)` | Environment value or `None` |
| `os.chdir(path)` | Change directory |
| `os.mkdir(path)` / `os.rmdir(path)` | Create / remove a directory |
| `os.remove(path)` / `os.unlink(path)` | Remove a file |
| `os.rename(src, dst)` | Rename |
| `os.system(cmd)` | Run a shell command, return its exit code |

| `os.path` | Notes |
|-----------|-------|
| `os.path.join(*parts)` | Join with `/`; an absolute part or trailing slash is handled |
| `os.path.basename(p)` / `os.path.dirname(p)` | Final component / parent |
| `os.path.exists(p)` | `access(F_OK)` |
| `os.path.isfile(p)` / `os.path.isdir(p)` | `stat`-based |

`split` / `splitext` / `abspath` / `normpath` are not yet lowered.

#### `random` -- Pseudo-Random Numbers

`import random` uses a faithful re-implementation of CPython's **MT19937**, so
`random.seed(n)` followed by the same calls produces the **same sequence** on
the `sv` and `na` pathways (seed an integer first for reproducibility).

| Feature | Notes |
|---------|-------|
| `random.seed(n)` | Seed from an integer (CPython `init_by_array`) |
| `random.random()` | Float in `[0, 1)` (53-bit, `genrand_res53`) |
| `random.getrandbits(k)` | `k` up to 64 |
| `random.randint(a, b)` | Inclusive, via the `_randbelow` rejection loop |
| `random.randrange(stop)` / `randrange(start, stop)` | Half-open |
| `random.uniform(a, b)` | Float in `[a, b]` |

```jac
import random;

with entry {
    random.seed(42);
    print(random.random());        # matches CPython's seed(42) stream
    print(random.randint(1, 100));
}
```

```jac
import sys;

with entry {
    args = sys.argv;
    print("argc:", len(args));
    for i in range(1, len(args)) {
        print("arg:", args[i]);
    }
    if "--verbose" in args {
        print("Verbose mode enabled");
    }
}
```

```bash
$ jac nacompile cli_tool.na.jac -o cli_tool
$ ./cli_tool hello --verbose world
argc: 4
arg: hello
arg: --verbose
arg: world
Verbose mode enabled
```

---

## C Library Interop

Native Jac can call functions from any shared C library -- system libraries like libc and libm, or third-party libraries like [raylib](https://www.raylib.com/) -- using `import from`. (For plain math, prefer `import math` above, which lowers to libm for you; the example below shows the lower-level C-interop mechanism.)

```jac
# Import math functions from libm
import from "/usr/lib/libm.so.6" {
    def sqrt(x: f64) -> f64;
    def pow(base: f64, exp: f64) -> f64;
}

def hypotenuse(a: float, b: float) -> float {
    return sqrt(pow(a, 2.0) + pow(b, 2.0));
}

with entry {
    print(f"hypotenuse(3, 4) = {hypotenuse(3.0, 4.0)}");
}
```

Fixed-width types (`f64`, `i32`, `c_void`, etc.) are only needed inside the `import from` declaration to match the C function's ABI signature. Everywhere else -- your own functions, variables, call sites -- you use standard Jac types (`int`, `float`, `str`, etc.) and the compiler handles coercion automatically.

### Platform-neutral library names

A library can be named by its **logical name** -- a dotted, extensionless identifier instead of a literal filename. The compiler resolves the platform-correct filename from the target triple, so a single unchanged `.na.jac` targets Linux, macOS, and Windows. For example, using [raylib](https://www.raylib.com/) for graphics:

<!-- jac-skip -->
```jac
import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> c_void;
    def WindowShouldClose() -> i32;
    def BeginDrawing() -> c_void;
    def EndDrawing() -> c_void;
    def CloseWindow() -> c_void;
    def ClearBackground(color: i32) -> c_void;
    def DrawText(text: str, x: i32, y: i32, fontSize: i32, color: i32) -> c_void;
}
```

`import from raylib` resolves to `libraylib.so` on Linux (ELF), `libraylib.dylib` on macOS (Mach-O), and `raylib.dll` on Windows (PE) -- the `lib` prefix and extension follow each platform's convention, exactly like a linker's `-lraylib`. The resolved name becomes the binary's needed-library entry; combined with the `$ORIGIN` / `@loader_path` runpath, the loader finds the library whether it is installed on the system **or** staged next to the executable.

C-string parameters use `str` in the declaration; the compiler lowers `str` to the `i8*` ABI shape shown in the [primitive-type table](#primitive-type-mappings) above. The `i8*` form is an internal LLVM type and is not part of Jac's surface syntax.

Two more forms compose with this, mirroring Python's relative imports:

| Import | Resolves to (Linux / macOS) | Search scope |
|--------|------------------------------|--------------|
| `import from raylib` | `libraylib.so` / `libraylib.dylib` | system loader cache **and** binary directory |
| `import from .raylib` | `$ORIGIN/libraylib.so` / `@loader_path/libraylib.dylib` | binary directory only |
| `import from vendor.raylib` | `$ORIGIN/vendor/libraylib.so` / `@loader_path/vendor/libraylib.dylib` | `vendor/` beside the binary |

A leading `.` makes the lookup relative to the binary's own directory; a dotted path maps the leading components to a sub-directory. Both compose with the `$ORIGIN` / `@loader_path` runpath so a bundled library is found no matter where the program is launched from.

### Explicit and pinned paths

When you need an exact file -- a versioned soname or an absolute system path that the logical form cannot express -- give a literal string instead. It is recorded verbatim, with no prefix/extension rewriting:

```jac
# A pinned, versioned system library.
import from "/usr/lib/libm.so.6" {
    def sqrt(x: f64) -> f64;
}
```

This is the form used for the libm example above. Any library that exposes a C ABI can be called either way -- by logical name for portability, or by explicit path when a specific file is required.

!!! note "Choosing a form"
    Prefer the logical name (`import from raylib`) for portable code: the platform's `.so` / `.dylib` / `.dll` filename is chosen for you. Reach for an explicit string only when you must pin an exact path or a versioned soname (e.g. `libfoo.so.5`), which the extensionless form does not name.

---

## Platform Support (Currently)

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux | x86_64 | Supported |
| Linux | aarch64 | Supported |
| macOS | x86_64 | Supported |
| macOS | arm64 (Apple Silicon) | Supported |
| Windows | x86_64 | Supported (cross-build via `--target windows`, producing a PE `.exe` / `.dll`) |

The platform and architecture are auto-detected at compile time. The correct binary format (ELF on Linux, Mach-O on macOS, PE on Windows) is produced automatically -- no external compiler or linker is needed on any platform.

!!! note "macOS arm64"
    On Apple Silicon, ad-hoc code signing is applied automatically as required by macOS.

---

## Memory Management

Native Jac uses **automatic reference counting** for memory management. Heap-allocated values (objects, strings, lists, dicts, sets) carry a reference count that is incremented on copy and decremented when a reference goes out of scope. Memory is freed when the count reaches zero.

!!! warning "Current Status"
    Deep release of nested structures is currently disabled to prevent use-after-free in complex ownership scenarios. This means certain long-running native programs may leak memory. Programs with bounded allocation are unaffected. Proper ownership tracking is a planned improvement.

### Reserved `__rc_*` runtime hooks

Five names are **reserved intrinsics** on the native pathway: `__rc_debug_enable()`, `__rc_debug_disable()`, `__rc_gc_disable()`, `__rc_gc_enable()`, and `__rc_collect_cycles()`. A call to any of them is dispatched by name to the corresponding runtime helper *before* normal call classification and symbol resolution -- ahead of builtins, module functions, and locals. You therefore cannot define or import your own function under one of these names in native code and expect it to be called; the name is claimed by the RC runtime (defining one would also collide with the runtime's own emitted symbol). The dispatch lives in a single table in the native code generator (`_codegen_rc_intrinsic`).

These hooks exist only in native code. On the Python backend they have no runtime implementation, and a call surfaces an unresolved-type diagnostic at check time rather than silently type-checking.

### Reference-count elision

A move assignment `b = a` would normally emit a defensive `__rc_retain` on the source so that both slots can be released independently. When the move is the *last* use of `a`, that retain is pure overhead: the reference can simply be handed to `b` and the source slot nulled, so `a`'s later cleanup release loads null and is a no-op and the object is freed exactly once.

The native backend decides where this is safe with `RcElisionProofPass`, a small intraprocedural pass that runs unconditionally in the native codegen path -- *before* `NaIRGenPass` and independent of the [ownership & borrow checker](ownership-borrowing.md), which does not run under `nacompile` (`type_check=False`). The pass reads only the syntactic AST and the CFG; it consults no checker or symbol facts, so the elision is sound whether or not the ownership diagnostics ever ran.

It is deliberately conservative -- it proves only the safe case and retains everywhere else. An assignment `b = a` is elided only when:

- `b` is a single, plain, **local** name (never a field, subscript, global, or parameter);
- the binding is not a `borrow`/`val` binding;
- `a` is a plain **local** name (an `own` *parameter* is never elided);
- **every** use of `a` in its function is an alias-value into a plain local -- this one invariant excludes call-args, returns, field/container stores, `&a` borrows, and closure/concurrent captures, any of which is a use that is not an alias-value; and
- `a` is **dead-out** at the move site, proven by backward liveness over the CFG. A later use reached through a loop back-edge without an intervening redefinition keeps `a` live and blocks the elision, so a `b = a` inside a loop is elided only when `a` is redefined each iteration before the move.

The proof is scoped to the exact move site (`Assignment.na_move_lowerable`), not to a symbol, so a variable moved at its last use elides there even if it was aliased earlier.

---

## Testing

`test` blocks in native context compile to native code and run through `jac test` -- the same harness used everywhere else in Jac. A test in a `.na.jac` module, or inside an inline `na { }` block, executes inside the module's JIT engine with full native semantics: the same integer, float, string, and object behavior as the code it exercises.

```jac
# vectors.na.jac

def dot(x1: float, y1: float, x2: float, y2: float) -> float {
    return x1 * x2 + y1 * y2;
}

test "dot product" {
    assert dot(1.0, 0.0, 0.0, 1.0) == 0.0;
    assert dot(2.0, 3.0, 4.0, 5.0) == 23.0;
}
```

```bash
jac test vectors.na.jac
```

Each native test runs under an implicit exception handler: a failing `assert` -- or any uncaught runtime raise (`IndexError`, `ZeroDivisionError`, ...) -- fails that one test and reports through the standard pass/fail pipeline. The failure message carries the assert site as `file:line`. All `jac test` options (`-t` name filtering, directory discovery, `--maxfail`, `--xit`) behave identically for native tests, and a mixed module can hold Python and native tests side by side -- each runs in its own codespace.

Assert messages in native tests are limited to string literals: `assert cond, "message"` includes the literal in the failure report, while a dynamic message such as an f-string is not evaluated (the report falls back to the assert location).

!!! warning "Process isolation"
    Native tests run in-process via the JIT. A test that crashes the process outright -- for example a segfault through a bad C-interop pointer -- takes the test runner down with it, unlike an assert failure, which is caught and reported.

---

## Debugging

### Dumping LLVM IR

Set the `JAC_DUMP_IR` environment variable to write the generated LLVM IR to a file:

```bash
JAC_DUMP_IR=/tmp/output.ll jac nacompile program.na.jac
```

This produces a human-readable `.ll` file that can be inspected with any text editor or processed with LLVM tools (`llc`, `opt`, `llvm-dis`).

### Bytecode Cache

The Jac compiler caches compiled bytecode at `~/Library/Caches/jac/bytecode/` (macOS) or `~/.cache/jac/bytecode/` (Linux). When modifying the compiler itself, clear this cache to ensure changes take effect:

```bash
rm -rf ~/Library/Caches/jac/bytecode/   # macOS
rm -rf ~/.cache/jac/bytecode/           # Linux
```

---

## Roadmap Items (Current limitations)

The following Jac features are **not yet available** in the native codespace:

| Feature | Reason |
|---------|--------|
| Walkers, nodes, edges | Graph-spatial constructs require the Jac runtime |
| Async / await | No async runtime in native code |
| Generators (`yield`) | Not yet implemented |
| Lambda expressions | Not yet implemented |
| Inline Python (`::py::`) | No Python interpreter in native binaries |
| Decorators | Not yet implemented |
| Multiple inheritance | Single inheritance only |
| `by llm()` | Requires Python runtime for LLM calls |
| PyPI imports | No Python ecosystem in native binaries |

!!! tip
    If you need a feature from the list above, keep that code in the Python codespace and use `na { }` blocks only for the performance-critical parts. The compiler handles the interop automatically.

---

## Examples

### Fibonacci (Recursion)

```jac
# fibonacci.na.jac

def fib(n: int) -> int {
    if n <= 1 { return n; }
    return fib(n - 1) + fib(n - 2);
}

with entry {
    for i in range(10) {
        print(f"fib({i}) = {fib(i)}");
    }
}
```

### Lazy Iterators (map / filter / enumerate / zip)

```jac
# pipeline.na.jac

def double(x: int) -> int { return x * 2; }
def is_even(x: int) -> bool { return x % 2 == 0; }

with entry {
    nums: list[int] = [1, 2, 3, 4, 5, 6];

    # map and filter compose lazily, with no intermediate lists
    total: int = 0;
    for x in map(double, filter(is_even, nums)) {
        total = total + x;
    }
    print(f"sum of doubled evens: {total}");

    # enumerate and zip yield tuples unpacked in the loop header
    for (i, n) in enumerate(nums) {
        print(f"#{i}: {n}");
    }
    scores: list[int] = [10, 20, 30];
    for (n, s) in zip(nums, scores) {
        print(f"{n} scored {s}");
    }
}
```

### Objects and Inheritance

```jac
# animals.na.jac

obj Animal {
    has name: str;

    def speak() -> str {
        return "...";
    }
}

obj Dog(Animal) {
    def speak() -> str {
        return f"{self.name} says Woof!";
    }
}

obj Cat(Animal) {
    def speak() -> str {
        return f"{self.name} says Meow!";
    }
}

with entry {
    has animals: list[Animal] = [
        Dog(name="Rex"),
        Cat(name="Whiskers"),
        Dog(name="Buddy")
    ];

    for animal in animals {
        print(animal.speak());
    }
}
```

### Exception Handling

```jac
# safe_div.na.jac

def safe_divide(a: int, b: int) -> str {
    try {
        result = a // b;
        return f"{a} / {b} = {result}";
    } except ZeroDivisionError {
        return "Error: division by zero";
    }
}

with entry {
    print(safe_divide(10, 3));
    print(safe_divide(10, 0));
}
```

### Command-Line Tool with `sys.argv`

```jac
# greeter.na.jac
import sys;

with entry {
    args = sys.argv;
    if len(args) < 2 {
        print("Usage: greeter <name> [--shout]");
        sys.exit(1);
    }
    name = args[1];
    shout = "--shout" in args;
    greeting = f"Hello, {name}!";
    if shout {
        print(greeting.upper());
    } else {
        print(greeting);
    }
}
```

```bash
$ jac nacompile greeter.na.jac -o greeter
$ ./greeter World --shout
HELLO, WORLD!
```

### Mixing Native and Python

<!-- jac-skip -->
```jac
# mixed.jac

# Python side -- full ecosystem access
import from json { dumps }

def serialize(data: dict) -> str {
    return dumps(data);
}

na {
    # Native side -- compiled to machine code
    def sum_squares(n: int) -> int {
        has total: int = 0;
        for i in range(n) {
            total += i * i;
        }
        return total;
    }
}

with entry {
    result = sum_squares(1000);
    print(f"Sum of squares: {result}");
}
```

### Chess Engine

For a complete walkthrough that covers `--autonative`, `nacompile`, `sys.argv`, declaration/implementation separation, and nearly every other native feature, see the **[Build a Chess Engine](../../tutorials/native/chess.md)** tutorial.
