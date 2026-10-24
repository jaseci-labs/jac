# WebAssembly runtime tests

`test_externref_js_values.js` runs through the built JavaScript engine and
checks i32/i64 execution plus WebAssembly reference behavior: externref identity
and undefined/null, funcref wrappers, table round-trips, and retained host
callbacks across multiple instances. Its memory section covers growth
buffer semantics on every grow path: wasm-side `memory.grow` opcodes (one,
repeated, and shared/re-exported memories), growth followed by an imported
JS callback in the same wasm call, and failed growth leaving the current
buffer attached.

From the `jac/` repository directory:

```bash
zig build js-engine
zig-out/js/bin/node js_engine/engine/tests/wasm/test_externref_js_values.js
```

`spec_driver.jac` and `spec_cmds.py` can run the official WebAssembly spec
fixtures when they are available locally. The fixture corpus is not vendored:

```bash
python3 js_engine/engine/tests/wasm/spec_cmds.py \
  /path/to/spec-testsuite/spec /tmp/wasm-spec-cmds
jac build --native js_engine/engine/tests/wasm/spec_driver.jac -o /tmp/wasm-spec
for f in /tmp/wasm-spec-cmds/*.cmds; do
  timeout 120 /tmp/wasm-spec "$f"
done
```

## Spec-corpus CI lane

The `js-engine` lane's `wasm-spec` job regenerates the corpus on every run —
the same pinned testsuite snapshot the reference fixtures were built from —
so no binary fixture is vendored here:

1. clone the WebAssembly spec testsuite at the pinned commit,
2. `wast2json` (wabt 1.0.36) every top-level suite,
3. flatten with `spec_cmds.py`,
4. build `spec_driver.jac` natively and run the 88 suites sharded 4 ways.

`gen_fixtures.py` drives steps 1-2 and pins the exclusions; the per-suite
logs upload as artifacts on every run.
