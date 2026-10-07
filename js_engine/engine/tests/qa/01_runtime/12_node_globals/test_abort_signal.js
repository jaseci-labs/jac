// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-A-002 (AbortSignal static helpers)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_abort_signal.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(typeof AbortSignal, "function", "NGL-A-002: AbortSignal");
if (typeof AbortSignal.abort === "function") {
    var s = AbortSignal.abort("ngl-reason");
    assertEq(s.aborted, true, "NGL-A-002: AbortSignal.abort static");
}
if (typeof AbortSignal.timeout === "function") {
    var t = AbortSignal.timeout(1);
    assertEq(t.aborted, false, "NGL-A-002: timeout signal starts open");
}

__jacDone();
