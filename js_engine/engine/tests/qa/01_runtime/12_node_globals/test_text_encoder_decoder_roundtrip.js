// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-T-002 (UTF-8 encode/decode round-trip)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/01_runtime/12_node_globals/test_text_encoder_decoder_roundtrip.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

if (typeof TextEncoder === "undefined") {
    console.log("skip NGL-T-002: TextEncoder not available");
    __jacDone();
} else {
    var enc = new TextEncoder();
    var bytes = enc.encode("caf\u00e9");
    assert(bytes instanceof Uint8Array, "NGL-T-002: encode returns Uint8Array");
    var dec = new TextDecoder("utf-8");
    assertEq(dec.decode(bytes), "caf\u00e9", "NGL-T-002: decode round-trip UTF-8");
    __jacDone();
}
