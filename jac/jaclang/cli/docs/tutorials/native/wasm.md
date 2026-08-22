# WebAssembly in the Browser

Compile Jac's native (`na`) subset to WebAssembly and run it in the browser at native speed -- with Jac's own wasm linker, no emscripten, no wasm-ld, no toolchain to install.

**What you'll do:**

1. Compile a native Jac module to a `.wasm` binary with one command
2. Load and call it from JavaScript
3. See how `na` blocks integrate into a `web-static` app, where the compiler does steps 1-2 for you

**Time:** ~15 minutes

---

## 1. Write a native module

The `na` codespace is the statically-compiled subset of Jac ([native pathway reference](../../reference/language/native-pathway.md)). Create `sum.jac` (compiling it with `jac nacompile` forces it native):

```jac
def:pub add(a: int, b: int) -> int {
    return a + b;
}
```

## 2. Compile to WebAssembly

```bash
jac nacompile sum.jac --target wasm32 -o sum.wasm
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

## 4. The integrated path: `na import`

Hand-loading wasm is the mechanics; in a real app you don't do any of it.
Client code imports a native module the same way it imports a server one --
with a marked import:

```jac
import from .sum { add }

async def show_sum {
    print(await add(2, 3));
}
```

That one import does all the wiring. The client build compiles `sum.jac`
to `/static/sum.wasm`, and `add` is bound to a generated stub that fetches
and instantiates the module lazily on the first call -- which is why the
call is `await`ed. On the server the import compiles to nothing: an
`na import` never executes the native module under Python (a *plain* import
of a native module is the server-side ctypes crossing instead).

If the native module declares its own FFI externs (say, raylib calls), the
page must supply their JavaScript implementations before the first call:

```jac
import from "@jac/wasm_host" { set_na_env }

import from .arena { init }

async def launch(shim: any, env_fns: dict) {
    set_na_env("arena", shim, {"env": env_fns});
    game = await init();
}
```

A pure-computation module like `sum` needs no `set_na_env` at all.

For a full worked example of the pattern -- a borrow-checked, zero-GC game
loop running as wasm, rendered through a WebGL shim -- see the shooter on
jaclang.org's own source (`game/arena.jac` and `game/webgl_host.jac`):
`webgl_host.jac` reaches the game through exactly the `na import` +
`set_na_env` pair above.

## Concurrency on wasm

WebAssembly builds are single-threaded by design today: the toolchain
has no wasm-threads/shared-memory-atomics story, so `flow for` and
`flow` call expressions always take their sequential lowering on the
wasm triple. This is documented behavior, not a bug -- the checker's
disjointness and sendability rules guarantee the sequential result is
identical to the parallel one, so the same source runs parallel on a
native host (enforced zero-RC and atomic-rc builds) and sequential in
the browser with byte-identical output. Parallel fan-out on wasm lands
only if and when a wasm-threads story exists.

## Where to go next

- [Native pathway reference](../../reference/language/native-pathway.md) -- the `na` subset, targets, optimization levels, shared libraries
- `jac guide jac-native-wasm` -- the bundled quick reference (also available to AI agents)
- [Build a Chess Engine](chess.md) -- the native pathway compiled to a host binary instead
- [Full-stack web apps](../../build/fullstack-web.md) -- where in-browser native fits the bigger picture
