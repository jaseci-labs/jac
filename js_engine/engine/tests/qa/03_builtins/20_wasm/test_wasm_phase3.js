// WASM-P3-*: WebAssembly Phase 3 — imports, tables, globals, traps, i64/BigInt
// (docs/wasm.md Phase 3). Native Wasmtime backend.
//
// Covers: JS→WASM imported callbacks (value flows both ways), WebAssembly.Table
// (get/set/grow/length), WebAssembly.Global (read+write .value, mutable check,
// exported mutable global set), trap→RuntimeError distinct from CompileError /
// LinkError, and i64 params/results/globals round-tripping as BigInt.
//
// Written to pass BYTE-IDENTICALLY under Node and js_engine (asserts on
// error-constructor names / instanceof, not on message text).
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/20_wasm/test_wasm_phase3.js");
var __jacOrigExit = process.exit.bind(process);
function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// (import "env" "add" (func (param i32 i32)(result i32)))
// (func (export "callAdd")(param i32 i32)(result i32) local.get0 local.get1 call $add)
var IMPORT_CALL = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,0x01,0x07,0x01,0x60,
  0x02,0x7f,0x7f,0x01,0x7f,0x02,0x0b,0x01,0x03,0x65,0x6e,0x76,
  0x03,0x61,0x64,0x64,0x00,0x00,0x03,0x02,0x01,0x00,0x07,0x0b,
  0x01,0x07,0x63,0x61,0x6c,0x6c,0x41,0x64,0x64,0x00,0x01,0x0a,
  0x0a,0x01,0x08,0x00,0x20,0x00,0x20,0x01,0x10,0x00,0x0b
]);

// (table (export "t") 2 10 funcref) (func (export "f0")(result i32) i32.const 100)
// (elem (i32.const 0) $f0)
var TABLE = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,0x01,0x05,0x01,0x60,
  0x00,0x01,0x7f,0x03,0x02,0x01,0x00,0x04,0x05,0x01,0x70,0x01,
  0x02,0x0a,0x07,0x0a,0x02,0x01,0x74,0x01,0x00,0x02,0x66,0x30,
  0x00,0x00,0x09,0x07,0x01,0x00,0x41,0x00,0x0b,0x01,0x00,0x0a,
  0x07,0x01,0x05,0x00,0x41,0xe4,0x00,0x0b
]);

// (global (export "g") (mut i32) (i32.const 7))
// (func (export "getG")(result i32) global.get 0)
// (func (export "setG")(param i32) local.get0 global.set 0)
var GLOBAL_MUT = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,0x01,0x09,0x02,0x60,
  0x00,0x01,0x7f,0x60,0x01,0x7f,0x00,0x03,0x03,0x02,0x00,0x01,
  0x06,0x06,0x01,0x7f,0x01,0x41,0x07,0x0b,0x07,0x13,0x03,0x01,
  0x67,0x03,0x00,0x04,0x67,0x65,0x74,0x47,0x00,0x00,0x04,0x73,
  0x65,0x74,0x47,0x00,0x01,0x0a,0x0d,0x02,0x04,0x00,0x23,0x00,
  0x0b,0x06,0x00,0x20,0x00,0x24,0x00,0x0b
]);

// (func (export "boom") unreachable)
var TRAP = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,0x01,0x04,0x01,0x60,
  0x00,0x00,0x03,0x02,0x01,0x00,0x07,0x08,0x01,0x04,0x62,0x6f,
  0x6f,0x6d,0x00,0x00,0x0a,0x05,0x01,0x03,0x00,0x00,0x0b
]);

// (func (export "id64")(param i64)(result i64) local.get0)
// (func (export "inc64")(param i64)(result i64) local.get0 i64.const1 i64.add)
// (global (export "g64") (mut i64) (i64.const 0))
// (func (export "getG64")(result i64) global.get 0)
var I64 = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,0x01,0x0a,0x02,0x60,
  0x01,0x7e,0x01,0x7e,0x60,0x00,0x01,0x7e,0x03,0x04,0x03,0x00,
  0x00,0x01,0x06,0x06,0x01,0x7e,0x01,0x42,0x00,0x0b,0x07,0x1f,
  0x04,0x04,0x69,0x64,0x36,0x34,0x00,0x00,0x05,0x69,0x6e,0x63,
  0x36,0x34,0x00,0x01,0x03,0x67,0x36,0x34,0x03,0x00,0x06,0x67,
  0x65,0x74,0x47,0x36,0x34,0x00,0x02,0x0a,0x13,0x03,0x04,0x00,
  0x20,0x00,0x0b,0x07,0x00,0x20,0x00,0x42,0x01,0x7c,0x0b,0x04,
  0x00,0x23,0x00,0x0b
]);

// Import an i64 host fn: (import "env" "id" (func (param i64)(result i64)))
// (func (export "roundtrip")(param i64)(result i64) local.get0 call $id)
var IMPORT_I64 = new Uint8Array([
  0x00,0x61,0x73,0x6d,0x01,0x00,0x00,0x00,0x01,0x06,0x01,0x60,
  0x01,0x7e,0x01,0x7e,0x02,0x0a,0x01,0x03,0x65,0x6e,0x76,0x02,
  0x69,0x64,0x00,0x00,0x03,0x02,0x01,0x00,0x07,0x0d,0x01,0x09,
  0x72,0x6f,0x75,0x6e,0x64,0x74,0x72,0x69,0x70,0x00,0x01,0x0a,
  0x08,0x01,0x06,0x00,0x20,0x00,0x10,0x00,0x0b
]);

// Invalid module (garbage) for CompileError.
var BAD = new Uint8Array([0x00, 0x01, 0x02, 0x03]);

async function main() {
  // WASM-P3-01: imported JS callback — value flows both ways
  var log = [];
  var imInst = (await WebAssembly.instantiate(IMPORT_CALL, {
    env: { add: function (a, b) { log.push([a, b]); return a + b; } }
  })).instance;
  assertEq(imInst.exports.callAdd(3, 4), 7, "WASM-P3-01: callAdd(3,4)=7 (import ran)");
  assertEq(JSON.stringify(log), "[[3,4]]", "WASM-P3-01: JS import callback observed args");
  assertEq(imInst.exports.callAdd(40, 2), 42, "WASM-P3-01: callAdd(40,2)=42");

  // WASM-P3-02: new Instance with imports (sync path)
  var im2 = new WebAssembly.Instance(new WebAssembly.Module(IMPORT_CALL), {
    env: { add: function (a, b) { return a * 2 + b; } }
  });
  assertEq(im2.exports.callAdd(10, 1), 21, "WASM-P3-02: sync Instance import callback");

  // WASM-P3-03: Table get/set/grow/length
  var tInst = (await WebAssembly.instantiate(TABLE, {})).instance;
  var t = tInst.exports.t;
  assertEq(Object.prototype.toString.call(t), "[object WebAssembly.Table]", "WASM-P3-03: Table toStringTag");
  assertEq(t.length, 2, "WASM-P3-03: table.length=2");
  assertEq(t.get(1), null, "WASM-P3-03: empty slot get()=null");
  assertEq(typeof t.get(0), "function", "WASM-P3-03: filled slot get() is a function");
  var prevLen = t.grow(3);
  assertEq(prevLen, 2, "WASM-P3-03: grow returns prev length 2");
  assertEq(t.length, 5, "WASM-P3-03: table.length=5 after grow");
  t.set(4, null);
  assertEq(t.get(4), null, "WASM-P3-03: set(4,null) then get()=null");

  // Standalone Table
  var st = new WebAssembly.Table({ initial: 3, maximum: 8, element: "anyfunc" });
  assertEq(st.length, 3, "WASM-P3-03: standalone Table length=3");
  assertEq(st.get(0), null, "WASM-P3-03: standalone Table slot null");

  // WASM-P3-04: exported mutable Global — read + write .value + WASM setter
  var gInst = (await WebAssembly.instantiate(GLOBAL_MUT, {})).instance;
  var g = gInst.exports.g;
  assertEq(Object.prototype.toString.call(g), "[object WebAssembly.Global]", "WASM-P3-04: Global toStringTag");
  assertEq(g.value, 7, "WASM-P3-04: initial global .value=7");
  assertEq(gInst.exports.getG(), 7, "WASM-P3-04: WASM getG()=7");
  g.value = 99;
  assertEq(g.value, 99, "WASM-P3-04: .value set reflected on read");
  assertEq(gInst.exports.getG(), 99, "WASM-P3-04: WASM sees JS-set value");
  gInst.exports.setG(123);
  assertEq(g.value, 123, "WASM-P3-04: JS sees WASM-set value");

  // WASM-P3-05: standalone Global (mutable + immutable)
  var sg = new WebAssembly.Global({ value: "i32", mutable: true }, 5);
  assertEq(sg.value, 5, "WASM-P3-05: standalone mutable global init");
  sg.value = 8;
  assertEq(sg.value, 8, "WASM-P3-05: standalone mutable global set");
  var ig = new WebAssembly.Global({ value: "i32" }, 3);
  assertEq(ig.value, 3, "WASM-P3-05: immutable global read");
  var threwImmutable = false;
  try { ig.value = 9; } catch (e) { threwImmutable = (e instanceof TypeError); }
  assertEq(threwImmutable, true, "WASM-P3-05: immutable global set throws TypeError");

  // WASM-P3-06: trap → RuntimeError (distinct from CompileError / LinkError)
  var trInst = (await WebAssembly.instantiate(TRAP, {})).instance;
  var trapClass = "";
  try { trInst.exports.boom(); } catch (e) { trapClass = e.constructor.name; assert(e instanceof WebAssembly.RuntimeError, "WASM-P3-06: trap is RuntimeError"); }
  assertEq(trapClass, "RuntimeError", "WASM-P3-06: unreachable → RuntimeError");

  // CompileError (bad bytes)
  var compileClass = "";
  try { await WebAssembly.compile(BAD); } catch (e) { compileClass = e.constructor.name; assert(e instanceof WebAssembly.CompileError, "WASM-P3-06: bad bytes is CompileError"); }
  assertEq(compileClass, "CompileError", "WASM-P3-06: bad bytes → CompileError");

  // LinkError (import member present but not callable)
  var linkClass = "";
  try { await WebAssembly.instantiate(IMPORT_CALL, { env: { add: 5 } }); }
  catch (e) { linkClass = e.constructor.name; assert(e instanceof WebAssembly.LinkError, "WASM-P3-06: bad import is LinkError"); }
  assertEq(linkClass, "LinkError", "WASM-P3-06: non-callable import → LinkError");

  // missing module namespace → TypeError (Node semantics)
  var missClass = "";
  try { await WebAssembly.instantiate(IMPORT_CALL, {}); } catch (e) { missClass = e.constructor.name; }
  assertEq(missClass, "TypeError", "WASM-P3-06: missing import namespace → TypeError");

  // WASM-P3-07: i64 param/result round-trips as BigInt
  var iInst = (await WebAssembly.instantiate(I64, {})).instance;
  assertEq(typeof iInst.exports.id64(10n), "bigint", "WASM-P3-07: i64 result is bigint");
  assertEq(iInst.exports.id64(10n), 10n, "WASM-P3-07: id64(10n)=10n");
  assertEq(iInst.exports.inc64(41n), 42n, "WASM-P3-07: inc64(41n)=42n");
  var big = 9007199254740993n; // 2^53 + 1, beyond Number precision
  assertEq(iInst.exports.id64(big), big, "WASM-P3-07: large i64 round-trips exactly");

  // WASM-P3-08: i64 mutable global as BigInt
  var g64 = iInst.exports.g64;
  assertEq(typeof g64.value, "bigint", "WASM-P3-08: i64 global .value is bigint");
  assertEq(g64.value, 0n, "WASM-P3-08: i64 global init 0n");
  g64.value = 12345678901234n;
  assertEq(g64.value, 12345678901234n, "WASM-P3-08: i64 global set BigInt");
  assertEq(iInst.exports.getG64(), 12345678901234n, "WASM-P3-08: WASM reads i64 global set from JS");

  // WASM-P3-09: i64 flows through an imported host callback (both directions)
  var i64log = [];
  var ihInst = (await WebAssembly.instantiate(IMPORT_I64, {
    env: { id: function (x) { i64log.push(typeof x); return x + 1n; } }
  })).instance;
  assertEq(ihInst.exports.roundtrip(1000n), 1001n, "WASM-P3-09: i64 host import round-trip");
  assertEq(i64log[0], "bigint", "WASM-P3-09: host import received BigInt arg");
}

main().then(function () {
  __reg.finalize(__jacOrigExit);
}, function (e) {
  __reg.fail("main() threw: " + (e && e.stack ? e.stack : e));
  __reg.finalize(__jacOrigExit);
});
