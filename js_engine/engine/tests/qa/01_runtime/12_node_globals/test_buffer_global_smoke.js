// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-U-004 (Buffer global)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_buffer_global_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

if (typeof Buffer === "undefined") {
    console.log("skip NGL-U-004: Buffer not available");
    __jacDone();
} else {
    assertEq(typeof Buffer, "function", "NGL-U-004: Buffer global constructor");
    var buf = Buffer.from([1, 2, 3]);
    assertEq(buf.length, 3, "NGL-U-004: Buffer.from works");
    __jacDone();
}
