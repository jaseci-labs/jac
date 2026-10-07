// VIT-SM-001: Vite V-03 smoke — bin/vite.js calls setSourceMapsEnabled early
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/05_integration/test_vite_set_source_maps_enabled_smoke.js"
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

// Mirrors vite packages/vite/bin/vite.js startup sequence (no dynamic import yet).
if (typeof process.setSourceMapsEnabled === "function") {
    assertEq(process.setSourceMapsEnabled(true), undefined, "VIT-SM-001: early enable");
} else {
    assert(false, "VIT-SM-001: setSourceMapsEnabled missing");
}

__jacDone();
