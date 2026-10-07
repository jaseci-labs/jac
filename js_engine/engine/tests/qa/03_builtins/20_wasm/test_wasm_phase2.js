// WASM-P2-*: WebAssembly Phase 2 — native Wasmtime backend (docs/wasm.md).
// Covers the one-way path: validate, compile/new Module, instantiate/new
// Instance, exported-function calls, and WebAssembly.Memory (instance-exported
// + standalone) with a live external ArrayBuffer .buffer and detach-on-grow.
// Imports / Table / Global / trap→RuntimeError are Phase 3.
//
// This test is written to pass BYTE-IDENTICALLY under Node and js_engine.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/20_wasm/test_wasm_phase2.js");
var __jacOrigExit = process.exit.bind(process);
function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// (module (func (export "add") (param i32 i32) (result i32)
//   local.get 0 local.get 1 i32.add))
var ADD = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,
  0x01,0x07,0x01,0x60,0x02,0x7f,0x7f,0x01,0x7f,
  0x03,0x02,0x01,0x00,
  0x07,0x07,0x01,0x03,0x61,0x64,0x64,0x00,0x00,
  0x0a,0x09,0x01,0x07,0x00,0x20,0x00,0x20,0x01,0x6a,0x0b
]);

// (module
//   (memory (export "mem") 1 10)
//   (func (export "store8") (param i32 i32) local.get 0 local.get 1 i32.store8)
//   (func (export "load8") (param i32) (result i32) local.get 0 i32.load8_u))
var MEM = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,
  0x01,0x0b,0x02,0x60,0x02,0x7f,0x7f,0x00,0x60,0x01,0x7f,0x01,0x7f,
  0x03,0x03,0x02,0x00,0x01,
  0x05,0x04,0x01,0x01,0x01,0x0a,
  0x07,0x18,0x03,
    0x03,0x6d,0x65,0x6d,0x02,0x00,
    0x06,0x73,0x74,0x6f,0x72,0x65,0x38,0x00,0x00,
    0x05,0x6c,0x6f,0x61,0x64,0x38,0x00,0x01,
  0x0a,0x13,0x02,
    0x09,0x00,0x20,0x00,0x20,0x01,0x3a,0x00,0x00,0x0b,
    0x07,0x00,0x20,0x00,0x2d,0x00,0x00,0x0b
]);

// (module (global (export "g") i32 (i32.const 42)))
var GLOB = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,
  0x06,0x06,0x01,0x7f,0x00,0x41,0x2a,0x0b,
  0x07,0x05,0x01,0x01,0x67,0x03,0x00
]);

// Invalid module (bad version word).
var BAD = new Uint8Array([0x00,0x61,0x73,0x6d,0x99,0x00,0x00,0x00,0x00]);

async function main() {
  // WASM-P2-01: validate good + bad
  assertEq(WebAssembly.validate(ADD), true, "WASM-P2-01: validate(add) true");
  assertEq(WebAssembly.validate(BAD), false, "WASM-P2-01: validate(bad) false");

  // WASM-P2-02: compile + Module static introspection
  var mod = await WebAssembly.compile(ADD);
  assertEq(Object.prototype.toString.call(mod), "[object WebAssembly.Module]",
    "WASM-P2-02: Module toStringTag");
  assertEq(JSON.stringify(WebAssembly.Module.exports(mod)),
    JSON.stringify([{ name: "add", kind: "function" }]),
    "WASM-P2-02: Module.exports records");
  assertEq(JSON.stringify(WebAssembly.Module.imports(mod)), "[]",
    "WASM-P2-02: Module.imports empty");

  // WASM-P2-03: instantiate Module → Instance, call exports
  var inst = await WebAssembly.instantiate(mod, {});
  assertEq(inst.exports.add(2, 3), 5, "WASM-P2-03: add(2,3)=5");
  assertEq(inst.exports.add(40, 2), 42, "WASM-P2-03: add(40,2)=42");
  assertEq(inst.exports.add(-1, 1), 0, "WASM-P2-03: add(-1,1)=0");

  // WASM-P2-04: new Module / new Instance
  var m2 = new WebAssembly.Module(ADD);
  var i2 = new WebAssembly.Instance(m2, {});
  assertEq(i2.exports.add(7, 8), 15, "WASM-P2-04: new Instance add(7,8)=15");

  // WASM-P2-05: instantiate bytes → {module,instance}
  var res = await WebAssembly.instantiate(MEM, {});
  assert(res.module instanceof WebAssembly.Module, "WASM-P2-05: result.module is Module");
  assert(res.instance instanceof WebAssembly.Instance, "WASM-P2-05: result.instance is Instance");
  var memInst = res.instance;

  // WASM-P2-06: exported Memory + live buffer round-trip
  var mem = memInst.exports.mem;
  assertEq(Object.prototype.toString.call(mem), "[object WebAssembly.Memory]",
    "WASM-P2-06: Memory toStringTag");
  assertEq(mem.buffer.byteLength, 65536, "WASM-P2-06: 1 page = 65536 bytes");
  var u8 = new Uint8Array(mem.buffer);
  u8[10] = 0xAB; u8[11] = 0xCD;
  assertEq(memInst.exports.load8(10), 0xAB, "WASM-P2-06: JS write → WASM read [10]");
  assertEq(memInst.exports.load8(11), 0xCD, "WASM-P2-06: JS write → WASM read [11]");
  memInst.exports.store8(20, 0x7E);
  assertEq(new Uint8Array(mem.buffer)[20], 0x7E, "WASM-P2-06: WASM write → JS read [20]");

  // WASM-P2-07: standalone WebAssembly.Memory + grow + detach-on-grow
  var sm = new WebAssembly.Memory({ initial: 1, maximum: 4 });
  var oldBuf = sm.buffer;
  assertEq(sm.buffer.byteLength, 65536, "WASM-P2-07: standalone 1 page");
  new Uint8Array(sm.buffer)[0] = 0xDE;
  new Uint8Array(sm.buffer)[65535] = 0xAD;
  var prev = sm.grow(2);
  assertEq(prev, 1, "WASM-P2-07: grow returns prev pages 1");
  assertEq(oldBuf.byteLength, 0, "WASM-P2-07: old buffer detached (byteLength 0)");
  var nb = sm.buffer;
  assertEq(nb.byteLength, 196608, "WASM-P2-07: grown to 3 pages");
  var nv = new Uint8Array(nb);
  assertEq(nv[0], 0xDE, "WASM-P2-07: old byte [0] preserved");
  assertEq(nv[65535], 0xAD, "WASM-P2-07: old byte [65535] preserved");
  nv[100000] = 0x55;
  assertEq(new Uint8Array(sm.buffer)[100000], 0x55, "WASM-P2-07: new page writable");

  // WASM-P2-08: exported global read (.value) — es-module-lexer needs this
  var gInst = (await WebAssembly.instantiate(GLOB, {})).instance;
  var g = gInst.exports.g;
  assertEq(Object.prototype.toString.call(g), "[object WebAssembly.Global]",
    "WASM-P2-08: Global toStringTag");
  assertEq(g.value, 42, "WASM-P2-08: exported global .value read");

  // WASM-P2-09: error classes exist and inherit from Error
  assert(new WebAssembly.CompileError("x") instanceof Error, "WASM-P2-09: CompileError is Error");
  assert(new WebAssembly.LinkError("x") instanceof Error, "WASM-P2-09: LinkError is Error");
  assert(new WebAssembly.RuntimeError("x") instanceof Error, "WASM-P2-09: RuntimeError is Error");
}

main().then(function () {
  __reg.finalize(__jacOrigExit);
}, function (e) {
  __reg.fail("main() threw: " + (e && e.stack ? e.stack : e));
  __reg.finalize(__jacOrigExit);
});
