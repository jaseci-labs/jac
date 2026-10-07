// VIT-AB-001: Vite V-15 smoke
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_vite_abort_globals_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}

assert(typeof AbortController === "function", "VIT-AB-001: AbortController");
assert(new AbortController().signal.aborted === false, "VIT-AB-001: signal");
__jacDone();
