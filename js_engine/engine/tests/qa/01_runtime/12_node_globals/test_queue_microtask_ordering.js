// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-Q-* (queueMicrotask vs macrotask)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_queue_microtask_ordering.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(typeof queueMicrotask, "function", "NGL-Q-001: typeof queueMicrotask");
var order = [];
setTimeout(function () {
    order.push("macro");
}, 0);
queueMicrotask(function () {
    order.push("micro");
});
setTimeout(function () {
    assert(order.indexOf("micro") < order.indexOf("macro"), "NGL-Q-001: microtask before macrotask");
    __jacDone();
}, 25);
