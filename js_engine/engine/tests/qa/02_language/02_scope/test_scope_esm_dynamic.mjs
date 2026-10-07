// SCP-M-004: dynamic import() is not static import hoisting (runtime load)
function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(a, e, msg) {
    if (a !== e) { console.error("FAIL: " + msg + " | expected: " + JSON.stringify(e) + " | actual: " + JSON.stringify(a)); process.exit(1); }
}

const ns = await import("./test_scope_esm_export.mjs");
assertEq(ns.scpMExported, 100, "SCP-M-004: dynamic import namespace");

process.exit(0);
