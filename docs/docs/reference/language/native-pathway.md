# Native Compilation

> **Related:** [Primitives & Codespace Semantics](primitives.md) | [Functions & Objects](functions-objects.md) | [CLI Commands](../cli/index.md)

**In this part:**

- [Overview](#overview) - What native compilation is and when to use it
- [Quick Reference](#quick-reference) - At-a-glance summary of capabilities
- [Native Blocks in Jac Applications](#native-blocks-in-jac-applications) - Mixing `na {}` into Python-backed Jac code
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

1. **Inline `na {}` blocks** -- drop native-compiled functions into any Jac application alongside Python-backed code. The compiler generates the interop layer automatically.
2. **Standalone `.na.jac` files** -- compile an entire program to a self-contained binary with `jac nacompile`. No Python runtime, no external compiler, no external linker -- the entire toolchain from source to executable runs within Jac itself.

Native compilation is ideal for:

- **Performance-critical hot paths** -- numeric computation, tight loops, data processing
- **Standalone tools** -- CLI utilities and system programs that run without Python installed
- **Single-binary deployment** -- distribute one executable with no dependencies beyond libc

---

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Inline block** | `na { }` in any `.jac` file |
| **Dedicated file** | `.na.jac` extension |
| **Entry point** | `with entry { }` (standalone binaries only) |
| **CLI command** | `jac nacompile <file> [-o output]` |
| **Backend** | LLVM IR via llvmlite |
| **Platforms** | Linux (x86_64, aarch64), macOS (x86_64, arm64) |
| **External toolchain** | None -- entire pipeline is self-contained |
| **C interop** | `import from "libname"` |
| **Std library** | `import sys` (`sys.argv`, `sys.exit()`) |
| **Memory model** | Automatic reference counting |

---

## Native Blocks in Jac Applications

The most common way to use native compilation is by embedding `na {}` blocks inside a regular `.jac` file. Functions inside a `na {}` block compile to native machine code while the rest of the file runs on Python as usual.

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

### When to Use `na {}` Blocks

- **Tight loops** over numeric data where Python overhead matters
- **Recursive algorithms** (e.g., tree traversal, dynamic programming)
- **Data transformation** on large collections
- Functions with **no Python library dependencies** -- if you need PyPI packages, keep that code in the Python codespace

### Context Isolation

Native functions inside `na {}` are excluded from Python codegen, and Python functions are excluded from native IR. Each codespace only sees its own definitions at compile time. Cross-codespace calls go through the interop bridge.

---

## Python-Native Interop

When a `.jac` file contains both Python and `na {}` code, the compiler generates interop stubs automatically:

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
| Objects | `obj Point { has x: int; }` |

### Control Flow

| Feature | Example |
|---------|---------|
| If/elif/else | `if x > 0 { ... } elif x == 0 { ... } else { ... }` |
| While loops | `while x > 0 { x -= 1; }` |
| For-in range | `for i in range(10) { ... }` |
| For-in collection | `for item in items { ... }` |
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
| `open(path, mode)` | `f = open("data.txt", "r");` |
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

### Standard Library Modules

#### `sys` -- Command-Line Arguments and Exit

Native Jac supports `import sys` for accessing command-line arguments and controlling process exit:

| Feature | Example |
|---------|---------|
| `sys.argv` | `args = sys.argv;` -- list of command-line arguments |
| `sys.exit(code)` | `sys.exit(1);` -- exit the process with a status code |

`sys.argv` is a `list[str]` where `argv[0]` is the program name and subsequent elements are the arguments passed on the command line. This works both with `jac run --autonative` and standalone binaries compiled via `jac nacompile`.

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

Native Jac can call functions from any shared C library -- system libraries like libc and libm, or third-party libraries like [raylib](https://www.raylib.com/) -- using `import from`:

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

### Third-Party Libraries

The same mechanism works with any C-compatible shared library. For example, using [raylib](https://www.raylib.com/) for graphics:

<!-- jac-skip -->
```jac
import from "libraylib.so" {
    def InitWindow(width: i32, height: i32, title: i8*) -> c_void;
    def WindowShouldClose() -> i32;
    def BeginDrawing() -> c_void;
    def EndDrawing() -> c_void;
    def CloseWindow() -> c_void;
    def ClearBackground(color: i32) -> c_void;
    def DrawText(text: i8*, x: i32, y: i32, fontSize: i32, color: i32) -> c_void;
}
```

Any library that exposes a C ABI can be called this way -- just point to the shared library path and declare the function signatures.

!!! note "Platform-specific library paths"
    Library paths differ across platforms. On macOS, shared libraries use `.dylib` (e.g., `libraylib.dylib`). On Linux, they use `.so` (e.g., `libraylib.so`). System libraries are typically at `/usr/lib/libSystem.B.dylib` (macOS) or `/usr/lib/libm.so.6` (Linux).

---

## Platform Support (Currently)

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux | x86_64 | Supported |
| Linux | aarch64 | Supported |
| macOS | x86_64 | Supported |
| macOS | arm64 (Apple Silicon) | Supported |

The platform and architecture are auto-detected at compile time. The correct binary format (ELF on Linux, Mach-O on macOS) is produced automatically -- no external compiler or linker is needed on any platform.

!!! note "macOS arm64"
    On Apple Silicon, ad-hoc code signing is applied automatically as required by macOS.

---

## Memory Management

Native Jac uses **automatic reference counting** for memory management. Heap-allocated values (objects, strings, lists, dicts, sets) carry a reference count that is incremented on copy and decremented when a reference goes out of scope. Memory is freed when the count reaches zero.

!!! warning "Current Status"
    Deep release of nested structures is currently disabled to prevent use-after-free in complex ownership scenarios. This means certain long-running native programs may leak memory. Programs with bounded allocation are unaffected. Proper ownership tracking is a planned improvement.

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
    If you need a feature from the list above, keep that code in the Python codespace and use `na {}` blocks only for the performance-critical parts. The compiler handles the interop automatically.

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
import:py from json { dumps }

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
