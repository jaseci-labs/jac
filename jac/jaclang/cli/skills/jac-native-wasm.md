---
name: jac-native-wasm
description: Running native-compiled Jac in the browser as WebAssembly - native code (inferred from extern-decl imports, or an explicit `na` block) compiled to /static/main.wasm by `jac start`, instantiated from a client page; `__jac_glob_init()`, BigInt i64 marshalling, externs-as-wasm-imports, the JS-side libc surface (malloc bump allocator, __multi3, WebAssembly.Module.imports introspection), and standalone `jac nacompile --target wasm32`. Load when building in-browser native compute: a game loop, simulation, or client-side hot loop. Pair with `jac-cl-components` (the page side) and `jac-native` (the native subset).
---

The native codespace's second target: instead of a host binary, your module's native code compiles to **WebAssembly** and runs in the browser, driven by a client page - native-speed compute with no server round-trip. Jac's own wasm linker produces the module; no emscripten, no `wasm-ld`. Native placement is inferred from extern-decl imports (`import from raylib { def ... ; }`) and the code that uses them, so no marker is needed; pure compute with no FFI surface (like `count_primes` below) has nothing to infer from, so you pin it native with an explicit `na` block (see `jac-codespaces`).

## One module, both halves

```jac
# main.jac
def count_primes(n: int) -> int {   # pure compute -> pin native with an na block (see jac-codespaces)
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
```

```bash
jac start          # builds the client bundle AND compiles the native code to /static/main.wasm, serves :8000
jac start --dev    # same, with hot reload   (jac build emits the artifacts without serving)
```

(Serving pipeline per the project-kinds guide and the `jac/examples/raylib_shooter/web` example; the wasm module behavior below is verified by instantiating a `jac nacompile --target wasm32` build under Node.)

## The boundary is the raw wasm ABI (verified)

- **Call `wasm.__jac_glob_init()` once before using any export** - it runs the module's `glob` initializers (the native-lib auto-init has no loader equivalent in wasm, so the JS host calls it).
- **Jac `int` is i64 and crosses as `BigInt`**: `wasm.count_primes(20000)` throws `TypeError: Cannot convert 20000 to a BigInt`; pass `BigInt(20000)`, and int returns arrive as BigInt (`2262n`) - interpolate into an f-string or `Number(...)` it before arithmetic with JS numbers.
- The instantiation import object must satisfy **all** of the module's imports; only a pure-scalar module gets away with `{"env": {"puts": ...}}` (the native runtime's print hook). Anything touching collections/objects/str demands a libc-ish surface - see the next section.
- Exports = your native functions plus runtime internals (`memory`, `__heap_base`, `__jac_glob_init`, `__stack_pointer`, ...). Drive only your own functions.

## The real import surface - a tiny libc the JS host supplies (verified)

The moment a native function allocates (a `list`, a `dict`, an `obj`, str building), the module imports libc symbols. **Discover the exact set with introspection - don't guess**:

```js
const mod = new WebAssembly.Module(bytes);
console.log(WebAssembly.Module.imports(mod));   // every {module:"env", name, kind} to stub
```

Measured: a minimal list-using module demands `puts, malloc, printf, __multi3, memcpy, free, malloc_usable_size, abort`; switch to dict/str work and the set becomes `puts, printf, malloc, free, malloc_usable_size, snprintf, strlen, strcmp, memcpy, abort` - it varies per module, so introspect after each build. **Every listed import must be present or instantiation throws** (`Import #7 "env" "abort": function import requires a callable`) - including FFI externs that are dead at runtime (the shooter shim stubs its unused file functions with `lambda { return 0; }`).

A bump allocator in JS satisfies the memory surface (verified under Node - a list-building `sum_squares(BigInt(1000))` returns the correct `332833500n`):

```js
let mem, heap;
const env = {
  // Jac int args arrive as BigInt EVEN in imports: Number(n) before arithmetic.
  malloc: (n) => { const p = heap; heap = (heap + Number(n) + 7) & ~7; return p; },
  free: () => {},                       // bump allocator: never reclaims
  malloc_usable_size: () => 0,
  memcpy: (d, s, n) => { new Uint8Array(mem.buffer).copyWithin(d, s, s + Number(n)); return d; },
  puts: () => 0, printf: () => 0,
  abort: () => { throw new Error("native abort"); },
  __multi3: (res, al, ah, bl, bh) => {  // 128-bit multiply, BigInt + DataView
    const a = (BigInt.asUintN(64, ah) << 64n) | BigInt.asUintN(64, al);
    const b = (BigInt.asUintN(64, bh) << 64n) | BigInt.asUintN(64, bl);
    const p = BigInt.asUintN(128, a * b), dv = new DataView(mem.buffer);
    dv.setBigUint64(res, p & ((1n << 64n) - 1n), true);
    dv.setBigUint64(res + 8, p >> 64n, true);
  },
};
const { instance } = await WebAssembly.instantiate(bytes, { env });
mem = instance.exports.memory;
heap = instance.exports.__heap_base.value;   // seed the allocator past the module's data
instance.exports.__jac_glob_init();
```

- `str` args to an extern arrive as **pointers into linear memory** - read `new Uint8Array(mem.buffer)` from the pointer until the NUL byte (`raylib_shim.jac::_read_cstr`).
- `f64`/`f32` cross as plain JS numbers; only i64 is BigInt.
- Stdlib on this target: `math.sin` becomes an `env.sin` import (supplying `Math.sin` works, verified), `time.time` needs `clock_gettime`, while `random` is self-contained in-browser (bit-exact with CPython for the same seed). The host-binary stdlib table in `jac-native` does NOT mean "available with no imports" here.

## `import from ...` externs become wasm imports

The native module's C-FFI declarations (`import from raylib { def rlVertex3f(...); ... }`) do **not** link a library on this target - each extern becomes a **wasm import** the JS host must supply in the import object. That makes a graphics module portable: the same native source links against `libraylib.so` for a host binary, and against a JS/WebGL shim in the browser. See `jac/examples/raylib_shooter/web/` - `main.jac` holds the native game + client page, and `raylib_shim.jac` is a reusable shim that fulfills the rlgl/input/libc imports on WebGL/DOM and drives `init()`/`frame()` per requestAnimationFrame.

There is no `with entry` browser loop - export plain functions (`init`, `frame`, `get_score`) and let JS drive them: `__jac_glob_init()` once, then `init()` once, then `frame()` per `requestAnimationFrame` tick (the shim's exact sequence).

## Standalone emit (no server) - verified end to end

```bash
jac nacompile primes.jac --target wasm32 -o primes.wasm   # valid \0asm module, ~500 bytes for a small fn
```

```js
const { instance } = await WebAssembly.instantiate(bytes, { env: { puts: () => 0 } });
instance.exports.__jac_glob_init();
instance.exports.count_primes(BigInt(20000));   // -> 2262n
```

Useful for unit-testing the native half under Node, or hosting the .wasm yourself.

Related: `jac-native` (the native feature subset and its gotchas all apply here), `jac-cl-components`, `jac-project-kinds`.
