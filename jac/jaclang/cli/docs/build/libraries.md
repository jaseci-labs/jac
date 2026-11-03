# I like to build … Reusable libraries & packages

Redistributable code with no entry point -- a Jac package for other Jac projects, a JavaScript/TypeScript package for npm, or a C-ABI shared library any language can link. The public surface is whatever you mark `:pub`. The npm and shared-library forms map to the `js-package` and `native-lib` [project kinds](../quick-guide/project-kinds.md).

## Your 5-minute quick win {#jac-package}

A reusable library other Jac projects install with `jac install`. A scoped `name` makes the project a package, and `exports` lists the modules consumers may import:

```jac
# greetings.jac
def:pub greet(name: str) -> str { return f"Hello, {name}!"; }
```

```toml
# jac.toml
[project]
name = "acme/greetlib"
version = "0.1.0"
jac-version = ">=0.38"
exports = ["greetings"]

[project.urls]
repository = "https://github.com/acme/greetlib"
```

```bash
jac publish --dry-run     # build, check and show the API diff; upload nothing
jac publish               # build and open the index pull request
```

A consumer runs `jac install acme/greetlib`, then writes `import from acme.greetlib.greetings { greet }`. One package can hold server, client and native code together and carry its own PyPI and npm dependencies. See [Packages](../reference/packages.md) for the manifest and the publish gates.

## npm package {#js-package}

For JavaScript and TypeScript consumers: a `cl` component (or function) library published to npm so any JavaScript/TypeScript project can `npm install` it -- whether or not they use Jac. `jac build --as npm` compiles your client modules to ES-module JavaScript, generates `package.json`, and emits `.d.ts` declarations.

```jac
# greetui/index.jac
def:pub Greeting(name: str) -> JsxElement {
    <h1>Hello, {name}!</h1>
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
# → dist/myscope-greetui-0.1.0.tgz
```

The generated `package.json` wires in `@jaseci/runtime` automatically for JSX/reactive code. Upload it with `npm publish` (Jac builds the tarball but doesn't upload).

!!! note "npm packages must be standalone client code"
    A module that crosses a server boundary (an `sv` import or call) can't run from a plain `npm install`, so `jac build --as npm` rejects it with a clear error. Keep server-coupled code in your app, not in the published library.

## Shared library (C ABI) {#native-lib}

The native counterpart: an `na` module compiled to a **C-ABI shared library** (`.so` / `.dylib` / `.dll`) that any language with a C FFI -- C, C++, Rust, Go (`cgo`), Python (`ctypes`) -- can link or `dlopen`. Like the other packages it has no entry point; the public surface is whatever you mark `:pub`.

```jac
# mathlib.jac
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
jac build --native mathlib.jac --lib                    # → ./libmathlib.so
jac build --native mathlib.jac --lib --target macos     # → ./libmathlib.dylib
jac build --native mathlib.jac --lib --target windows   # → ./libmathlib.dll
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

## Using Jac from a Python project {#python-projects}

A Python project has two ways to use Jac code. `jac build --as source` exports editable Python, JavaScript, and C with the required Jac runtime source, and the output rebuilds and runs without Jac; see [`jac build`](../reference/cli/index.md#jac-build). Or call the `jac` binary as a subprocess.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces (`sv`/`cl`/`na`) decide which package kind you build
- **Build it for real** → [Packages](../reference/packages.md) -- write a Jac package, then check and publish it with `jac publish`
- **Look it up** → [Packages](../reference/packages.md) · [Publishing to npm](../reference/publishing.md) · [Native pathway -- shared libraries](../reference/language/native-pathway.md#shared-libraries-c-abi)

## Going further

- Use a library in an app → [Backend APIs & services](backend-apis.md) · [Full-stack web apps](fullstack-web.md)
- Ship an executable instead of a library → [CLI tools & native binaries](cli-and-native.md#native-binary)
