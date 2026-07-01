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
jac bundle
# → dist/greetlib-0.1.0-py3-none-any.whl
```

Upload it with `twine`, then `pip install greetlib` anywhere. The wheel ships your compiled modules and runs under the `jac` binary -- it does not list `jaclang` as a runtime dependency.

## npm package {#js-package}

The client-side counterpart: a `cl` component (or function) library published to npm so any JavaScript/TypeScript project can `npm install` it. `jac bundle --target npm` compiles your client modules to ES-module JavaScript, generates `package.json`, and emits `.d.ts` declarations. (Modules that cross a server boundary can't ship as standalone npm packages -- keep server-coupled code in your app.)

## Shared library (C ABI) {#native-lib}

The native counterpart: an `na` module compiled to a **C-ABI shared library** (`.so` / `.dylib` / `.dll`) that any language with a C FFI -- C, C++, Rust, Go (`cgo`), Python (`ctypes`) -- can link or `dlopen`:

```bash
jac nacompile mathlib.na.jac --shared                    # → ./libmathlib.so
jac nacompile mathlib.na.jac --shared --target macos     # → ./libmathlib.dylib
jac nacompile mathlib.na.jac --shared --target windows   # → ./libmathlib.dll
```

Scalars pass by value; Jac objects and strings cross as opaque handles with `jac_retain`/`jac_release` for lifetime management. Jac's own linker emits the ELF/Mach-O/PE file -- no `gcc`/`ld`, and the `--target` cross-builds need no extra toolchain.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces (`sv`/`cl`/`na`) decide which package kind you build
- **Look it up** → [Publishing packages](../reference/publishing.md) · [Publishing to npm](../reference/publishing.md#publishing-to-npm-npmjsorg) · [Native pathway -- shared libraries](../reference/language/native-pathway.md#shared-libraries-c-abi)

## Going further

- Use a library in an app → [Backend APIs & services](backend-apis.md) · [Full-stack web apps](fullstack-web.md)
- Ship an executable instead of a library → [CLI tools & native binaries](cli-and-native.md#native-binary)
