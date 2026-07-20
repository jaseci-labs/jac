# WebAssembly in the Browser

Compile Jac's native (`na`) subset to WebAssembly and run it in the browser at native speed -- with Jac's own wasm linker, no emscripten, no wasm-ld, no toolchain to install.

**What you'll do:**

1. Compile a `.na.jac` module to a `.wasm` binary with one command
2. Load and call it from JavaScript
3. See how `na` blocks integrate into a `web-static` app, where the compiler does steps 1-2 for you

**Time:** ~15 minutes

---

## 1. Write a native module

The `na` codespace is the statically-compiled subset of Jac ([native pathway reference](../../reference/language/native-pathway.md)). Create `sum.na.jac`:

```jac
def:pub add(a: int, b: int) -> int {
    return a + b;
}
```

## 2. Compile to WebAssembly

```bash
jac nacompile sum.na.jac --target wasm32 -o sum.wasm
```

```
Wasm module written to sum.wasm (541 bytes).
Instantiate in a browser/Node with an `env` import object.
```

That's a complete, standards-compliant wasm module (MVP profile) in half a kilobyte. Jac assembled and linked it itself -- the same `jac` binary that compiles to Python bytecode carries an LLVM backend and its own wasm linker.

## 3. Call it from JavaScript

Every `:pub` function becomes a wasm export. Load it the standard way:

```html
<script type="module">
  const { instance } = await WebAssembly.instantiateStreaming(
    fetch("sum.wasm"),
    { env: {} }   // runtime imports (I/O like print lands here)
  );
  instance.exports.__jac_glob_init();          // initialize module globals once
  console.log(instance.exports.add(2n, 3n));   // 5n
</script>
```

Two things to know, both visible in that snippet:

- **Jac `int` is 64-bit**, so integer parameters and returns cross the boundary as JavaScript `BigInt` -- call `add(2n, 3n)`, not `add(2, 3)`. `float` crosses as a plain `number`.
- **Call `__jac_glob_init()` once after instantiation** to initialize module globals. If your module does I/O (e.g. `print`), supply the corresponding functions on the `env` import object; a pure-computation module needs nothing.

## 4. The integrated path: `na` blocks in a web app

Hand-loading wasm is the mechanics; in a real app you don't do any of it. In a [`web-static` project](../../quick-guide/project-kinds.md#in-browser-native-wasm), the native code in your app module -- inferred from extern-decl imports and their users, or marked with an explicit `na` block -- is compiled to wasm and wired to your client code by the build:

```bash
jac create wasmapp --kind web-static
```

Put hot-path code in an `na` block and UI in `cl`; `jac start` (or `jac build --client web`) compiles `cl` → JavaScript and `na` → wasm into `.jac/client/dist/`, and serves them together.

For a full worked example of the pattern -- a game loop running as wasm, rendered through a JavaScript shim -- see the raylib shooter in the repo ([`jac/examples/raylib_shooter/web`](https://github.com/jaseci-labs/jaseci/tree/main/jac/examples/raylib_shooter/web)): `main.jac` holds the `na` game and the `cl` page, and `raylib_shim.cl.jac` supplies the wasm module's imports as WebGL/DOM functions.

## Where to go next

- [Native pathway reference](../../reference/language/native-pathway.md) -- the `na` subset, targets, optimization levels, shared libraries
- `jac guide jac-native-wasm` -- the bundled quick reference (also available to AI agents)
- [Build a Chess Engine](chess.md) -- the native pathway compiled to a host binary instead
- [Full-stack web apps](../../build/fullstack-web.md) -- where in-browser native fits the bigger picture
