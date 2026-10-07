// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-P-002 (performance mark/measure)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_performance_mark_measure.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var _ph = require("node:perf_hooks");
if (typeof globalThis !== "undefined") {
    globalThis.performance = _ph.performance;
}
if (typeof performance === "undefined" || typeof performance.mark !== "function") {
    console.log("skip NGL-P-002: performance.mark not available");
    __jacDone();
} else {
    performance.mark("ngl-p002-start");
    performance.mark("ngl-p002-end");
    performance.measure("ngl-p002", "ngl-p002-start", "ngl-p002-end");
    var entries = performance.getEntriesByName("ngl-p002", "measure");
    assert(entries.length >= 1, "NGL-P-002: measure creates PerformanceMeasure");
    __jacDone();
}
