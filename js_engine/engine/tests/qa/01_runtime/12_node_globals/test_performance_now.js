// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-P-001 (global performance.now)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_performance_now.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(typeof performance, "object", "NGL-P-001: performance object");
assert(typeof performance.now === "function", "NGL-P-001: performance.now");
var t0 = performance.now();
var t1 = performance.now();
assert(t1 >= t0, "NGL-P-001: now is monotonic");
if (typeof performance.timeOrigin === "number") {
    assert(isFinite(performance.timeOrigin), "NGL-P-001: timeOrigin finite when defined");
}

__jacDone();
