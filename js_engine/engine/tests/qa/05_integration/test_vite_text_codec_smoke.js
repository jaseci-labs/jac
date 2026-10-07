// VIT-TC-001: Vite V-16 smoke — TextEncoder/TextDecoder for dependency UTF-8 paths
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/05_integration/test_vite_text_codec_smoke.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}
function assertEq(actual, expected, msg) {
    __reg.assertEq(actual, expected, msg);
}

assert(typeof TextEncoder === "function", "VIT-TC-001: TextEncoder global");
assert(typeof TextDecoder === "function", "VIT-TC-001: TextDecoder global");

var enc = new TextEncoder();
var bytes = enc.encode("vite");
assert(bytes instanceof Uint8Array, "VIT-TC-001: encode returns Uint8Array");
assertEq(new TextDecoder("utf-8").decode(bytes), "vite", "VIT-TC-001: UTF-8 round-trip");

__jacDone();
