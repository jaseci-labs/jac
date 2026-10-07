// test_cjs_esm_interop.js — CJS-to-ESM namespace synthesis via dynamic import()
//
// When a CJS module is loaded through dynamic import(), the result must be
// an ESM namespace object: { default: <module.exports>, ...namedExports }.
// Three bugs compound to break this:
//
//   Bug A — require_is_esm leaks into nested CJS require() calls inside the
//           dynamic-import target, causing sub-dependencies to be wrapped in
//           namespace objects that the CJS code does not expect.
//
//   Bug B — The module-cache hit path returns the raw cached exports without
//           namespace synthesis when the same CJS module is imported a second
//           time via dynamic import().
//
//   Bug C — The namespace synthesis block was dead code (called an undefined
//           function, silently dropped by the Jac compiler).

var path = require("path");

var passed = 0;
var failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        passed++;
    } else {
        failed++;
        console.log("FAIL " + id + ": " + desc + " — expected " + JSON.stringify(expected) + " got " + JSON.stringify(actual));
    }
}
function checkTrue(id, desc, val) {
    if (val) {
        passed++;
    } else {
        failed++;
        console.log("FAIL " + id + ": " + desc + " — was falsy");
    }
}

var FN_EXPORT = path.resolve(__dirname, "helper_cjs_fn_export.js");
var NESTED    = path.resolve(__dirname, "helper_cjs_with_nested_require.js");

// ── Test 1: CJS function-export — first dynamic import() ─────────────────────
// ns.default must be the exported function, not undefined.
var ns1 = await import(FN_EXPORT);
check(1, "ns.default type (fn-export, first load)", typeof ns1.default, "function");
checkTrue(2, "ns.default is callable", typeof ns1.default === "function");
check(3, "ns.default('world') result", ns1.default("world"), "hello world");

// When module.exports is a function, its own-properties are NOT hoisted as named
// exports (matches Node.js behaviour: only default is set).
check(4, "ns.label undefined (fn-export: props not hoisted)", ns1.label, undefined);

// ── Test 2: Cache-hit path — second dynamic import() of the same module ──────
// The module is already cached; the second import() must still synthesise
// the namespace (not return raw exports).
var ns2 = await import(FN_EXPORT);
check(5, "cache-hit: ns.default type", typeof ns2.default, "function");
check(6, "cache-hit: ns.default('again')", ns2.default("again"), "hello again");

// ── Test 3: Nested CJS require() must NOT be wrapped ─────────────────────────
// helper_cjs_with_nested_require.js does require("./helper_cjs_fn_export.js")
// at top-level. That sub-require must receive the raw CJS exports (a function),
// not a namespace object. If require_is_esm leaks (Bug A), sub becomes a
// namespace and typeof sub === "object", breaking sub().
var ns3 = await import(NESTED);
check(7, "ns3.default type", typeof ns3.default, "object");
check(8, "nested sub was function (not namespace)", ns3.default.subIsFunction, true);
check(9, "nested sub.label correct", ns3.default.subLabel, "greet");
check(10, "nested callSub works", ns3.default.callSub("fix5"), "hello fix5");

// ── Test 4: Object-export with named keys all hoisted onto namespace ──────────
// An object-shaped CJS export should have all its keys available as named
// bindings on the namespace.
check(11, "ns3.subIsFunction on ns directly", ns3.subIsFunction, true);
check(12, "ns3.callSub on ns directly is function", typeof ns3.callSub, "function");

console.log("=== CJS-to-ESM interop tests: " + passed + " passed, " + failed + " failed ===");
