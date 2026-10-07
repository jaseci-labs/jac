// NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NCJS-REQ-103
// Counts how many times this file's body has been evaluated (survives cache delete via globalThis).
var g = typeof globalThis !== "undefined" ? globalThis : typeof global !== "undefined" ? global : {};
if (typeof g.__ncjs_eval_counter === "undefined") {
    g.__ncjs_eval_counter = 0;
}
g.__ncjs_eval_counter++;
module.exports = { evalCount: g.__ncjs_eval_counter };
