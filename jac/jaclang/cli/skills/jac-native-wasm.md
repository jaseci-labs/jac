---
name: jac-native-wasm
description: Running native-compiled Jac in the browser as WebAssembly - one module with an `na {}` block (compiled to /static/main.wasm by `jac start`) plus a `cl {}` page that instantiates it; `__jac_glob_init()`, BigInt i64 marshalling, externs-as-wasm-imports, and the standalone `jac nacompile --target wasm32` verb. Load when building in-browser native compute: a game loop, simulation, or hot inner loop running client-side. Pair with `jac-cl-components` (the page side) and `jac-native` (the na subset).
---

The native codespace's second target: instead of a host binary, an `na {}` block compiles to **WebAssembly** and runs in the browser, driven by a `cl` page - native-speed compute with no server round-trip. Jac's own wasm linker produces the module; no emscripten, no `wasm-ld`.

## One module, both halves

```jac
# main.jac
na {
    def count_primes(n: int) -> int {
        count = 0;
        i = 2;
        while i < n {
            is_prime = True;
            j = 2;
            while j < i {
                if i % j == 0 { is_prime = False; break; }
                j += 1;
            }
            if is_prime { count += 1; }
            i += 1;
        }
        return count;
    }
}

cl {
    def:pub app -> JsxElement {
        has answer: str = "computing...";
        async can with entry {
            res: any = await WebAssembly.instantiateStreaming(
                fetch("/static/main.wasm"), {"env": {"puts": lambda { return 0; }}}
            );
            wasm: any = res.instance.exports;
            wasm.__jac_glob_init();                        # REQUIRED before any other export
            answer = f"{wasm.count_primes(BigInt(20000))}";  # i64 param must be a BigInt
        }
        return <div><p>{"primes below 20000: "}<b>{answer}</b></p></div>;
    }
}
```

```bash
jac start          # builds the cl bundle AND compiles the na block to /static/main.wasm, serves :8000
jac start --dev    # same, with hot reload   (jac build emits the artifacts without serving)
```

(Serving pipeline per the project-kinds guide and the `jac/examples/raylib_shooter/web` example; the wasm module behavior below is verified by instantiating a `jac nacompile --target wasm32` build under Node.)

## The boundary is the raw wasm ABI (verified)

- **Call `wasm.__jac_glob_init()` once before using any export** - it runs the module's `glob` initializers (the shared-library auto-init has no loader equivalent in wasm, so the JS host calls it).
- **Jac `int` is i64 and crosses as `BigInt`**: `wasm.count_primes(20000)` throws `TypeError: Cannot convert 20000 to a BigInt`; pass `BigInt(20000)`, and int returns arrive as BigInt (`2262n`) - interpolate into an f-string or `Number(...)` it before arithmetic with JS numbers.
- The instantiation import object must satisfy the module's imports; a compute-only module needs just `{"env": {"puts": ...}}` (the native runtime's print hook).
- Exports = your `na` functions plus runtime internals (`memory`, `__jac_glob_init`, `__stack_pointer`, ...). Drive only your own functions.

## `import from ...` externs become wasm imports

An `na` block's C-FFI declarations (`import from raylib { def rlVertex3f(...); ... }`) do **not** link a library on this target - each extern becomes a **wasm import** the JS host must supply in the import object. That makes a graphics module portable: the same `na` source links against `libraylib.so` for a host binary, and against a JS/WebGL shim in the browser. See `jac/examples/raylib_shooter/web/` - `main.jac` holds the `na` game + `cl` page, and `raylib_shim.cl.jac` is a reusable shim that fulfills the rlgl/input/libc imports on WebGL/DOM and drives `init()`/`frame()` per requestAnimationFrame.

There is no `with entry` browser loop - export plain functions (`init`, `frame`, `get_score`) and let JS drive them.

## Standalone emit (no server) - verified end to end

```bash
jac nacompile primes.na.jac --target wasm32 -o primes.wasm   # valid \0asm module, ~500 bytes for a small fn
```

```js
const { instance } = await WebAssembly.instantiate(bytes, { env: { puts: () => 0 } });
instance.exports.__jac_glob_init();
instance.exports.count_primes(BigInt(20000));   // -> 2262n
```

Useful for unit-testing the na half under Node, or hosting the .wasm yourself.

Related: `jac-native` (the na feature subset and its gotchas all apply here), `jac-cl-components`, `jac-project-kinds`.
