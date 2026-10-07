// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-A-001 (AbortController)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_abort_controller.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(typeof AbortController, "function", "NGL-A-001: AbortController");
var ac = new AbortController();
assertEq(ac.signal.aborted, false, "NGL-A-001: signal not aborted");
ac.abort();
assertEq(ac.signal.aborted, true, "NGL-A-001: abort flips signal");

__jacDone();
