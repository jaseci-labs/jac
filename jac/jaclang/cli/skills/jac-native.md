---
name: jac-native
description: Compiling Jac to native machine code via LLVM - `na {}` blocks for hot loops in regular .jac files, `jac run --autonative`, and standalone zero-dependency binaries via `jac nacompile` (plain .jac or .na.jac); the supported subset, Python-congruent stdlib, C FFI, and gotchas. Load when speeding up a hot loop, building a native binary or CLI tool, or editing any `.na.jac` file. For C-ABI shared libraries see `jac-native-shared`; for in-browser wasm see `jac-native-wasm`.
---

The native codespace compiles Jac through LLVM to machine code - no Python runtime, no external compiler or linker (Jac bundles the whole toolchain). Three verbs:

```bash
jac run app.jac                            # Python path - full language, PyPI, OSP
jac run --autonative app.jac -- x --flag   # try native, silent Python fallback; `--` separates program args
jac nacompile app.jac -o app               # standalone zero-dependency binary
./app x --flag
```

- `jac nacompile` accepts **plain `.jac` too** (auto-promotes when only native-compatible features are used) - it is NOT restricted to `*.na.jac`. A `.na.jac` file is all-native by convention.
- `--autonative` prints `[Module 'app.jac' executed natively]` when a plain `.jac` is promoted; a file using walkers/async just runs on Python with no message.
- A standalone binary REQUIRES `with entry { }` - otherwise: *"No entry point found."*
- `jac nacompile --target wasm32|windows|macos` cross-targets; `--shared` builds a C-ABI library (see the sibling skills).

## Headline example - a CLI tool

```jac
# tool.na.jac
import sys;

def has_flag(args: list[str], flag: str) -> bool {
    for a in args {
        if a == flag { return True; }   # loop with == ; `flag in args` is broken (see gotchas)
    }
    return False;
}

with entry {
    args = sys.argv;                    # list[str]; argv[0] = binary name
    if len(args) < 2 {
        print("Usage: tool <name> [--shout]");
        sys.exit(1);
    }
    greeting = f"Hello, {args[1]}!";
    print(greeting.upper() if has_flag(args, "--shout") else greeting);
}
```

`jac nacompile tool.na.jac -o tool && ./tool World --shout` -> `HELLO, WORLD!`. Same argv via `jac run --autonative tool.na.jac -- World --shout`.

## What the native subset supports (much more than loops)

- **Collections**: `list`/`dict`/`set`/`tuple` literals, indexing, and methods (`append`/`sort`/`pop`/`insert`, `get`/`keys`/`values`/`items`/`update`, `add`/`remove`/union ops); list/dict/set comprehensions.
- **Enums**, incl. typed-base `enum HttpStatus: int { OK=200, NOT_FOUND=404 }` (members usable as `int`).
- **Objects**: `has` fields with defaults, methods, `def init`, `def postinit`, single inheritance with vtable virtual dispatch (`override def`), chained `a.b.c` access. Types may reference later-defined types directly.
- **Functions**: default params, recursion, union types (`Piece | None`).
- **Control flow**: `if/elif/else`, `while`, `for-in` over range/collections/lazy `map`/`filter`/`enumerate`/`zip`, `break`/`continue`, ternary.
- **Exceptions**: `try/except/else/finally`, `raise`, `except ValueError as e`, hierarchy matching.
- **File I/O**: `open`/`read`/`write`/`close`, `with open(...) as f { }`, custom `__enter__`/`__exit__`.
- **Builtins**: `print`, `len`, `range`, `abs`/`min`/`max`/`pow`, `chr`/`ord`, `str`/`int`/`float`, `input`; f-strings. **str methods**: `upper`/`lower`/`strip`/`split`/`join`/`replace`/`find`/`startswith`/`endswith`/`count`; substring `in`.

**Stdlib** (Python-congruent subset, same source runs on both pathways): `math` (libm-backed), `time` (clocks + `sleep`), `sys` (`argv`/`exit`/`maxsize`/`platform`/`byteorder`), `os` + `os.path` subset (`getcwd`/`getenv`/`mkdir`/`remove`/`system`; `join`/`basename`/`exists`/`isfile`), `random` (faithful MT19937 - same seed gives the same sequence as CPython).

Anything else fails **loudly at compile time** - `import json` -> *"Native pathway does not yet support Python module import 'json'"*. Unsupported imports never silently produce a garbage binary. PyPI imports never work natively; keep that code in the Python codespace.

The stdlib table is for **host** binaries. On `--target wasm32` there is no libc/libm to link: each unresolved symbol becomes a wasm *import* the JS host must supply (`math.sin` -> an `env.sin` import, `time.time` -> `clock_gettime`; `random` is self-contained and works in-browser). Supply `Math.sin` etc. from JS or hand-roll - the shooter flagship hand-rolls Taylor `jcos`/`jsin` to keep one source for both targets. See `jac-native-wasm`.

**Not supported** (compile errors): walkers/nodes/edges, `async`, generators/`yield`, decorators, multiple inheritance, `::py::`, `by llm()`, PyPI. Lambdas: see gotchas.

## Gotchas (all verified against the current compiler)

- `print(some_list)` / `print(some_dict)` emits garbage bytes or nothing - print elements in a loop or as f-string scalars. `print(True)` prints `1`; enum members print as their int value; floats print printf-style (`4.000000`).
- **`"x" in list[str]` always returns False** (pointer compare, even for identical literals). `in` works for `list[int]` and for substring-in-str. Loop with `==` instead (see `has_flag` above).
- **A lambda that captures a local variable compiles silently and computes garbage.** Non-capturing expression lambdas happen to work, but the safe rule is: no lambdas in native code - pass named functions. (Calling a function received through an `any` param is a compile error.)
- Forward-decl stubs (`obj Board;`) parse, but field access through a stub-typed value fails (`No matching overload ... "__add__"` / `<Unknown>`). They are unnecessary - just reference later-defined types.
- Booleans are `True`/`False`. Lowercase `true` fails with the misleading `E1002: Cannot return <Unknown>, expected bool`.
- `node` and `root` are reserved words - they cannot be variable names in native code. `by` is one too (`by llm()`), so the natural 3D grid params `ax, ay, az, bx, by, ...` fail E0013 - escape as `` `by `` or rename.
- **Mixing an FFI `i32` with an `int` (i64) in a ternary kills codegen**: `return n if n > 0 else 60;` where `n` came from an `-> i32` extern aborts `jac nacompile` with *"PHI nodes not grouped at top of basic block"* (the widening `zext` lands between the merge block's PHIs). `jac check` passes - it only dies at nacompile. Use an explicit `if { return n; } return 60;` instead.
- Wide flat signatures next to a C import can misbehave: the shooter flagship hit a type-checker param-counting bug on a 12-float-param helper and renamed to short uniform `p0..p11` (minimal repros pass on the current compiler - if you see a phantom arg-count error on a grid-of-floats signature, rename the params).

## `na {}` blocks - native sections inside a regular .jac

```jac
import from json { dumps }           # Python side - full ecosystem

def py_double(x: int) -> int {       # define Python fns BEFORE the na block that calls them
    return x * 2;
}

na {
    def sum_squares(n: int) -> int { # compiled to machine code
        total: int = 0;
        for i in range(n) { total += i * i; }
        return total;
    }
    def add_one_doubled(x: int) -> int {
        return py_double(x) + 1;     # native -> Python call, auto-bridged
    }
}

with entry {
    print(sum_squares(1000));        # Python -> native call, auto-bridged
    print(dumps({"n": add_one_doubled(5)}));   # 332833500 then {"n": 11}
}
```

Run with plain `jac run`. Interop stubs are generated automatically in both directions; primitives, collections, and `obj` instances cross the boundary. Each codespace only sees its own definitions at compile time (context isolation) - a native function referencing a Python function defined *after* the `na` block fails E5090 and returns 0. Variants: `to na:` section header (rest of module is native) or `na` prefix on a single declaration.

## Native-to-native imports + decl/impl separation

```jac
# math_utils.na.jac
def square(x: int) -> int { return x * x; }
```

```jac
# app.na.jac - imports link at the IR level; no dynamic library involved
import from math_utils { square }

obj Piece {
    has value: int;
    def score(b: Board) -> int;      # declaration only - body lives in app.impl.jac
}
obj Board { has bonus: int = 3; }

with entry { print(Piece(value=4).score(Board())); }
```

```
# app.impl.jac - auto-paired by basename
impl Piece.score(b: Board) -> int { return square(self.value) + b.bonus; }
```

One `jac nacompile app.na.jac -o app` compiles the whole graph. This is the chess-engine layout (`jac/examples/chess/`: signatures in `chess.jac`, bodies in `chess.impl.jac`).

## C FFI - calling precompiled C libraries

```jac
import from raylib {                                  # logical name, like a linker's -lraylib:
    def InitWindow(width: i32, height: i32, title: str) -> None;   # -> libraylib.so / .dylib / raylib.dll
    def WindowShouldClose() -> bool;
    def rlVertex3f(x: f32, y: f32, z: f32) -> None;
    def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;
}
```

Pass and return C structs **by value** by declaring them as `obj` inside the same block - the backend lowers them to the platform C struct ABI, so a library's natural by-value API works directly (no scalar workaround needed):

```jac
import from raylib {                                  # same sibling-library resolution as above
    obj Color   { has r: u8, g: u8, b: u8, a: u8; }            # 4B  -> packed into an i32
    obj Vector3 { has x: f32, y: f32, z: f32; }               # 12B -> <2 x float>, float
    obj Camera3D { has position: Vector3, target: Vector3, up: Vector3,
                       fovy: f32, projection: i32; }          # 44B -> MEMORY class (byval)

    def GetColor(hexValue: u32) -> Color;                     # struct returned by value
    def ColorToInt(color: Color) -> i32;                      # struct passed by value
    def DrawCube(position: Vector3, w: f32, h: f32, l: f32, color: Color) -> None;
    def BeginMode3D(camera: Camera3D) -> None;                # 44B struct, passed byval
}

with entry {
    print(ColorToInt(GetColor(0xFF0000FF)));   # a Color round-trips by value across the FFI
    DrawCube(Vector3(x=0.0, y=1.0, z=0.0), 2.0, 2.0, 2.0, Color(r=255, g=0, b=0, a=255));
}
```

- The plain logical name already finds a **sibling** library: every binary gets RUNPATH `$ORIGIN` (`@loader_path` on macOS) plus a bare DT_NEEDED (`libraylib.so`), so the loader checks the binary's own directory first, then `LD_LIBRARY_PATH`/system paths (verified with `readelf -d`). Ship the `.so` next to the binary and it runs from any cwd - the shooter flagship stages `libraylib.so` beside `./shooter` exactly this way.
- `import from .raylib` (leading dot) **pins** sibling-only resolution: DT_NEEDED becomes `$ORIGIN/libraylib.so`, so a system-installed copy is never used as a fallback. `import from vendor.raylib` -> `$ORIGIN/vendor/...`.
- A literal string (`import from "/usr/lib/libm.so.6" { def sqrt(x: f64) -> f64; }`) is only for pinning an exact path or versioned soname - no prefix/extension rewriting.
- Fixed-width types (`i32`, `u8`, `f32`, `f64`, `c_void`) are needed ONLY inside the `import from` declaration to match the C ABI. Everywhere else use standard `int`/`float`/`str`; the compiler coerces at the call site.
- **Structs cross by value.** Declare each C struct as an `obj` of fixed-width fields (nested `obj` structs allowed) inside the `import from` block and call the by-value entry points directly: the compiler classifies each struct per the platform C ABI (System V AMD64 eightbytes on x86_64, AArch64 AAPCS) and emits the matching `byval`/`sret`/register coercion, so a `Color`/`Vector3`/`Camera3D` passed or returned by value round-trips correctly - including >16-byte MEMORY-class aggregates like the 44-byte `Camera3D`. Targets outside x86_64 SysV / AArch64 AAPCS fall back to the legacy path; binding a library's scalar entry points (raylib's `rlVertex3f`/`rlColor4ub`) is still a valid lower-level style, just no longer required.
- No `cc`/`ld` step: each declared symbol becomes an extern Jac's own linker records (DT_NEEDED / LC_LOAD_DYLIB) and the OS loader resolves at run time.

## Debugging

- `JAC_DUMP_IR=/tmp/out.ll jac nacompile app.na.jac` writes the optimized LLVM IR to a readable `.ll` file.
- Stale behavior after moving/regenerating files: use `jac nacompile --scrub` (or `jac run --no-cache`) to wipe the native IR cache, which lives in the module's cache dir (`.jac/cache/native/`, or the global `~/.cache/jac/jir/` for installed sources).
- Memory: automatic reference counting, but deep release of nested structures is currently disabled - long-running daemons may leak; bounded-allocation programs are unaffected.
- Run native test files with `jac test <file>`, not pytest. See `jac-testing` and `jac-debugging`.
