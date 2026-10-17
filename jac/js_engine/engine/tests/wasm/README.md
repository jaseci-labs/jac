# WebAssembly runtime tests

`test_externref_js_values.js` runs through the built JavaScript engine and
checks i32/i64 execution plus WebAssembly reference behavior: externref identity
and undefined/null, funcref wrappers, table round-trips, and retained host
callbacks across multiple instances.

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
