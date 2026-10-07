// GC-GLOB-001 fixture: module top-level bindings stored in the VM globals map
// must survive collection.
//
// ESM top-level `function` declarations (and top-level `var`) are stored in the
// VM's `self.globals` dict via STORE_MODULE_GLOBAL / CREATE_GLOBAL_FN_BINDING,
// and are deliberately kept OFF globalThis (ES module semantics). Regression:
// gc_mark_roots walked the operand stack + call-frame fields but NOT
// self.globals, so anything reachable only through a module-global binding —
// a top-level function's closure and the cells it captured — was swept mid
// execution. Real-world: vite@6's debug chunk has a self-referential top-level
// function `createDebug` whose own-name cell was collected, so a later call
// read `createDebug` as undefined → "Cannot read properties of undefined
// (reading 'useColors')".
//
// Shape below mirrors that: a top-level function `makeLogger` returns a
// self-referential inner function `createDebug`; the inner function's own-name
// cell lives in makeLogger's (returned, dead) scope and is reachable only via
// the module-global `logger` binding. A forced GC with heavy churn must not
// sweep it.
//
// Runs under `js_engine --gc` (the .sh wrapper forces the flag).

function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }

// Top-level function declaration → stored in self.globals.
function makeLogger() {
  function createDebug(ns) {
    // Self-reference: `createDebug` here is a free var captured from makeLogger's
    // scope. Its cell is reachable only through the returned function.
    const uc = createDebug.useColors();
    return ns + ":" + uc;
  }
  createDebug.useColors = function () { return "C"; };
  createDebug.self = createDebug;
  return createDebug;
}

// Top-level `var` binding → also self.globals.
var logger = makeLogger();

// First use before any GC.
if (logger("a") !== "a:C") fail("GC-GLOB-001: baseline call wrong: " + logger("a"));

// makeLogger has returned; the createDebug cell is reachable ONLY via `logger`
// (a module-global). Force collections with heavy object churn so any freed
// slot is recycled.
let sink = null;
for (let round = 0; round < 4; round++) {
  __JS_ENGINE_GC.collect();
  for (let i = 0; i < 60000; i++) { sink = { i: i, a: [i, i + 1], s: "g" + i, n: { d: i } }; }
}
__JS_ENGINE_GC.collect();
for (let i = 0; i < 60000; i++) { sink = { i: i, e: ["k", i] }; }

// Second use after GC — the self-reference must still resolve.
let r;
try {
  r = logger("b");
} catch (e) {
  fail("GC-GLOB-001: call after GC threw (self-ref cell swept): " + e.message);
}
if (r !== "b:C") fail("GC-GLOB-001: call after GC wrong (module-global swept): " + JSON.stringify(r));

// The function's own properties must also survive.
if (typeof logger.useColors !== "function") fail("GC-GLOB-001: logger.useColors swept");
if (logger.self !== logger) fail("GC-GLOB-001: logger.self identity broken across GC");

console.log("GC-GLOB-001 ok " + (sink ? "" : ""));
process.exit(0);
