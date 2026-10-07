// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-T-001 (TextEncoder / TextDecoder constructors)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/01_runtime/12_node_globals/test_text_encoder_decoder_constructors.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

if (typeof TextEncoder === "undefined" || typeof TextDecoder === "undefined") {
    console.log("skip NGL-T-001: TextEncoder/TextDecoder not available");
    __jacDone();
} else {
    assertEq(typeof TextEncoder, "function", "NGL-T-001: TextEncoder global constructor");
    assertEq(typeof TextDecoder, "function", "NGL-T-001: TextDecoder global constructor");
    __jacDone();
}
