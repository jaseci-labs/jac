---
name: jac-native-shared
description: Building C-ABI shared libraries from Jac with `jac nacompile --shared` - the `:pub` export surface, opaque object handles with jac_retain/jac_release, automatic init on load, and consuming the .so/.dylib/.dll from ctypes or gcc. Load when exposing Jac code to C, C++, Rust, Go, or Python-ctypes hosts, or cross-building a .dylib/.dll. Pair with `jac-native` (the native subset itself).
---

`jac nacompile --shared` packages a native Jac module as a **C-ABI shared library** any FFI-capable host can `dlopen` or link. Jac's own linker emits the file - no gcc/ld/lld, even for cross-targets:

```bash
jac nacompile mathlib.na.jac --shared                    # -> ./libmathlib.so   (host platform)
jac nacompile mathlib.na.jac --shared --target macos     # -> ./libmathlib.dylib (Mach-O, ad-hoc signed on arm64)
jac nacompile mathlib.na.jac --shared --target windows   # -> ./mathlib.dll      (PE, DllMain init)
```

## `:pub` is the export surface - no entry point

A shared library needs **no `with entry { }`** (the entry-required rule is executable-only). Exactly the symbols you mark `:pub` land in the export table; everything else stays internal. With zero `:pub` symbols the build refuses: *"Nothing to export from a shared library"*.

```jac
# mathlib.na.jac
glob:pub counter: int = 7;                   # exported global

def:pub jadd(a: int, b: int) -> int {        # exported function
    return a + b;
}

def helper(x: int) -> int { return x * 2; }  # NOT exported (still callable internally)

obj:pub Point {
    has x: int = 0, y: int = 0;
    def magnitude_sq() -> int { return self.x * self.x + self.y * self.y; }
}

def:pub make_point(x: int, y: int) -> Point { return Point(x=x, y=y); }
def:pub point_sum(p: Point) -> int { return p.x + p.y; }
def:pub greet(name: str) -> str { return "hi " + name; }
```

- **Methods are NOT exported** - `Point.magnitude_sq` has a class-qualified symbol, not a C name. Wrap any method you need in a `:pub` free function (like `point_sum` above).
- `:pub` symbols of imported native modules are **re-exported**, so a library composes from several `.na.jac` files.
- Globals initialize **automatically on load** (ELF `DT_INIT_ARRAY` / Mach-O `__mod_init_func` / PE `DllMain`) - there is no `jac_init()` to call.

## The ABI: scalars by value, objects as opaque handles

Scalars cross by value (`int` -> `int64`, `float` -> `double`, `bool`); `str` crosses as a NUL-terminated `char*` both directions. Jac objects/lists/dicts cross as **opaque `void*` handles** - pass them back into other `:pub` functions, never dereference. The library exports `jac_retain(void*)` / `jac_release(void*)` to manage their refcounted lifetime.

```python
import ctypes
lib = ctypes.CDLL("./libmathlib.so")
lib.jadd.restype = ctypes.c_int64
lib.jadd.argtypes = [ctypes.c_int64, ctypes.c_int64]
print(lib.jadd(2, 3))                                  # 5
print(ctypes.c_int64.in_dll(lib, "counter").value)     # 7 - glob already initialized

lib.make_point.restype = ctypes.c_void_p               # opaque handle out
lib.point_sum.argtypes = [ctypes.c_void_p]             # opaque handle in
lib.point_sum.restype = ctypes.c_int64
p = lib.make_point(3, 4)
print(lib.point_sum(p))                                # 7
lib.jac_release(p)                                     # drop when done (frees at zero)

lib.greet.restype = ctypes.c_char_p
lib.greet.argtypes = [ctypes.c_char_p]
print(lib.greet(b"world"))                             # b'hi world'
```

From C, functions link with the standard toolchain:

```c
// gcc app.c -L. -lmathlib -Wl,-rpath,. -o app
extern long jadd(long, long);
int main(void) { return (int)jadd(2, 3); }   // exit code 5
```

Gotcha: linking an exported **global** directly as `extern long counter;` from gcc-compiled code reads 0 (copy relocations are not supported by the emitted .so). Read globals via `dlsym` (which is what `ctypes.in_dll` does) or expose a `:pub` accessor function.

Cross-built `.dylib`/`.dll` artifacts are structurally valid Mach-O/PE files; build them anywhere, but you can only load-test them on the matching OS.

Related: `jac-native` (subset + FFI in the other direction), `jac-packaging` (PyPI/npm artifacts), `jac-project-kinds`.
