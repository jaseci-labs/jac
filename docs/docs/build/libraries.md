# I like to build … Reusable libraries & packages

Redistributable code with no entry point -- a Python wheel for PyPI, a JavaScript/TypeScript package for npm, or a C-ABI shared library any language can link. The public surface is whatever you mark `:pub`. These map to the `py-package`, `js-package`, and `native-lib` [project kinds](../quick-guide/project-kinds.md).

## Your 5-minute quick win {#py-package}

A reusable library packaged as a standard pip wheel. Any `def:pub` is part of the public API:

```jac
# greetlib.jac
def:pub greet(name: str) -> str { return f"Hello, {name}!"; }
```

```toml
# jac.toml
[project]
name = "greetlib"
version = "0.1.0"
```

```bash
jac build --as wheel
# → dist/greetlib-0.1.0-py3-none-any.whl
```

Upload it with `twine`, then `pip install greetlib` anywhere. The wheel ships your compiled modules and runs under the `jac` binary -- it does not list `jaclang` as a runtime dependency.

## npm package {#js-package}

The client-side counterpart: a `cl` component (or function) library published to npm so any JavaScript/TypeScript project can `npm install` it -- whether or not they use Jac. `jac build --as npm` compiles your client modules to ES-module JavaScript, generates `package.json`, and emits `.d.ts` declarations.

```jac
# greetui/index.cl.jac
def:pub Greeting(name: str) -> JsxElement {
    return <h1>Hello, {name}!</h1>;
}
```

```toml
# jac.toml
[project]
name = "greetui"
version = "0.1.0"
description = "A tiny Jac component library"

[project.include]
packages = ["greetui"]

[npm]
name = "@myscope/greetui"   # optional scoped npm name
```

```bash
jac build --as npm
# → dist/myscope-greetui-0.1.0.tgz   (run jac build --as wheel to build the wheel too)
```

The generated `package.json` wires in `@jaseci/runtime` automatically for JSX/reactive code. Upload it with `npm publish` (Jac builds the tarball but doesn't upload, exactly like `twine` for wheels).

!!! note "npm packages must be standalone client code"
    A module that crosses a server boundary (an `sv` import or call) can't run from a plain `npm install`, so `jac build --as npm` rejects it with a clear error. Keep server-coupled code in your app, not in the published library.

## Shared library (C ABI) {#native-lib}

The native counterpart: an `na` module compiled to a **C-ABI shared library** (`.so` / `.dylib` / `.dll`) that any language with a C FFI -- C, C++, Rust, Go (`cgo`), Python (`ctypes`) -- can link or `dlopen`. Like the other packages it has no entry point; the public surface is whatever you mark `:pub`.

```jac
# mathlib.na.jac
glob:pub counter: int = 7;                  # exported global

def:pub jadd(a: int, b: int) -> int {       # exported function
    return a + b;
}

obj:pub Point {
    has x: int = 0, y: int = 0;
}

def:pub make_point(x: int, y: int) -> Point { return Point(x=x, y=y); }
def:pub point_sum(p: Point) -> int { return p.x + p.y; }
```

```bash
jac nacompile mathlib.na.jac --shared                    # → ./libmathlib.so
jac nacompile mathlib.na.jac --shared --target macos     # → ./libmathlib.dylib
jac nacompile mathlib.na.jac --shared --target windows   # → ./libmathlib.dll
```

Load it like any other shared library -- here from Python via `ctypes`:

```python
import ctypes
lib = ctypes.CDLL("./libmathlib.so")
lib.jadd.restype = ctypes.c_int64
lib.jadd.argtypes = [ctypes.c_int64, ctypes.c_int64]
print(lib.jadd(2, 3))   # 5
```

Scalars pass by value; Jac objects and strings cross as opaque handles (a `void*` you hand back to the library), with exported `jac_retain`/`jac_release` to manage their reference-counted lifetime, and module globals initialize automatically on load. Jac's own linker emits the ELF/Mach-O/PE file -- no `gcc`/`ld`, and the `--target` cross-builds need no extra toolchain.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces (`sv`/`cl`/`na`) decide which package kind you build
- **Build it for real** → [Publish a Library](../tutorials/extend/publish-a-library.md) -- scaffold → test → wheel → PyPI, then the npm flow
- **Look it up** → [Publishing packages](../reference/publishing.md) · [Publishing to npm](../reference/publishing.md#publishing-to-npm-npmjsorg) · [Native pathway -- shared libraries](../reference/language/native-pathway.md#shared-libraries-c-abi)

## Going further

- Use a library in an app → [Backend APIs & services](backend-apis.md) · [Full-stack web apps](fullstack-web.md)
- Ship an executable instead of a library → [CLI tools & native binaries](cli-and-native.md#native-binary)
