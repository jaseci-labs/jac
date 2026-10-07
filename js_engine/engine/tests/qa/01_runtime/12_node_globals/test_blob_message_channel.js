// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-U-002 (Blob / MessageChannel)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_blob_message_channel.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

if (typeof Blob !== "undefined") {
    var b = new Blob(["x"]);
    assertEq(typeof b.size, "number", "NGL-U-002: Blob.size");
}
if (typeof MessageChannel !== "undefined") {
    var ch = new MessageChannel();
    assertEq(typeof ch.port1.postMessage, "function", "NGL-U-002: MessageChannel ports");
}

__jacDone();
