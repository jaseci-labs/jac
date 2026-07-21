# Jac Cube Shooter - full-stack (native wasm + client WebGL) via `jac start`

The same rlgl cube shooter as the parent example, as a **full-stack Jac app**: the
game code infers the native codespace from its extern raylib import and is
compiled to WebAssembly, the page is a React component that infers client from
its JSX, and `jac start` builds + serves both. One markerless app module, no
hand-run build steps, no `.mjs`.

```bash
jac start          # build the cl bundle + na->wasm, serve on http://localhost:8000
jac start --dev    # same with hot reload
# open http://localhost:8000, click the canvas: WASD move, mouse/arrows aim,
# Space fire, Tab release the cursor
```

(`jac build` produces the same artifacts under `.jac/client/dist/` without serving.)

## How it fits together

```
main.jac
  import from raylib { ... }  ...game...  init()  frame()  get_score()
        -> extern decls seed native; compiled to /static/main.wasm by the
           client build (pure-Jac wasm linker)
  import from .raylib_shim { run_game };  def:pub app -> JsxElement { <canvas/> }
        -> JSX seeds client; React bundle calls run_game(canvas) on mount

raylib_shim.jac      (reusable client library)
  emulates raylib's scalar rlgl immediate-mode API + input on WebGL/DOM,
  instantiates /static/main.wasm via @jac/wasm_host, and drives
  init()/frame() per requestAnimationFrame.
```

The game's `import from raylib { ... }` externs do **not** link a native
library here - they become the wasm module's **imports**, which `raylib_shim`
satisfies. Same source contract as the native build; a different host fulfills it.

libc is NOT part of that contract anymore: the native floor links its libc
(string/float formatting, allocator, libm) into `main.wasm` itself, and the
remaining host surface (console `write`, os stubs, time) is the versioned
`jac_host1` import module supplied by the `@jac/wasm_host` runtime library.
The shim provides only the game's raylib externs under `env`. The build also
writes `main.wasm.imports.json` next to the module listing the exact import
surface per namespace.

### Why the shim is a separate module

The shim is generic browser infra (a WebGL/DOM raylib emulation), not app code -
so it lives in a reusable client library, imported like `react`; its
`@jac/wasm_host` npm import is the structural signal that places it client. It
is also where the low-level glue (typed-array/`BigInt` marshalling, bitwise
allocator math) lives. The game and the page stay in `main.jac`.

## What's a shim vs. real raylib

This renders with a hand-written WebGL emulation of the rlgl subset the game uses

- it is raylib-*compatible*, not raylib itself.

## Files

| File | Role |
|------|------|
| `main.jac` | native-inferred game (-> `main.wasm`) + client-inferred page that mounts the canvas |
| `raylib_shim.jac` | WebGL/DOM shim: rlgl + input -> the wasm's `env` (app FFI) imports; `jac_host1` comes from `@jac/wasm_host` |
| `jac.toml` | project + `[client]` + react deps |
| `.jac/client/dist/` | build output (git-ignored): `client.*.js` + `main.wasm` |
