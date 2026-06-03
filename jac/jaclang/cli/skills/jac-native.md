---
name: jac-native
description: Compiling Jac to a standalone native binary with `jac nacompile` - the `.na.jac` file, the compute-only subset, what silently breaks, and the build/run verbs. Load when building a native binary, a single-file zero-dependency CLI, or any `.na.jac` file.
---

A `.na.jac` file compiles through LLVM to a standalone, zero-dependency executable you can ship to machines that have neither Jac nor Python. It supports a **compute-only subset**: plain `def` functions plus a `with entry` block - no graph, no runtime, no Python.

```jac
# sum.na.jac
def compute_sum(n: int) -> int {
    total: int = 0;
    i: int = 1;
    while i <= n {
        total = total + i;
        i = i + 1;
    }
    return total;
}

with entry {
    print(f"Sum of 1 to 10: {compute_sum(10)}");
}
```

```bash
jac nacompile sum.na.jac -o sum    # emits the native binary `sum`
./sum                              # -> Sum of 1 to 10: 55
```

## The subset that compiles AND runs correctly

- `def` functions with typed params/returns; recursion and loops.
- Primitive types (`int`, `float`, `str`, `bool`) and typed locals (`total: int = 0;`).
- Control flow: `if/elif/else`, `while`, `for ... in range(...)`; arithmetic and comparisons.
- `f"..."` formatting and `print(...)`.
- A `with entry { ... }` block - the program's entry point.
- Booleans are `True` / `False` (capitalized). Lowercase `true`/`false` parse as undefined names and fail with a misleading `E1002: Cannot return <Unknown>, expected bool` - see `jac-core-cheatsheet`.

## Pitfalls

- **The file MUST be named `*.na.jac`**, built with `jac nacompile <file> -o <name>`, then run `./<name>`. (`jac run` is the interpreted path, not native.)
- **A `with entry { }` block is REQUIRED.** Without one, `jac nacompile` hard-errors: *"No entry point found."* A bare library of `def`s does not produce a binary.
- **⚠ Python builtins over iterables and `import`s do NOT work natively - they compile but silently produce empty/garbage output.** `sum(range(1, 101))` compiles, yet the binary prints nothing for it; `import math; math.pi` prints empty. There is no compile error - the wrong value just appears at runtime. **Write the arithmetic explicitly** (an accumulator loop) and inline any constant you'd otherwise import.
- **No graph / OSP / async in native.** Nodes, edges, walkers, `spawn`, `visit`, `report`, persistence (`root`), `async`, and `by llm` belong to the interpreted/served runtimes. A native program is just functions + `with entry`.
- The binary's stdout is exactly what you `print` - none of the `jac run` setup/compile chatter.
