// Vite V-15: AbortController / AbortSignal globals
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/01_runtime/12_node_globals/test_abort_controller_globals.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}

if (typeof AbortController !== "function" || typeof AbortSignal !== "function") {
    console.log("skip V-15: AbortController/AbortSignal not available");
    __jacDone();
} else {
    var ac = new AbortController();
    assert(ac.signal !== undefined && ac.signal !== null, "V-15: controller.signal");
    assert(ac.signal.aborted === false, "V-15: not aborted initially");
    ac.abort();
    assert(ac.signal.aborted === true, "V-15: aborted after abort()");
    __jacDone();
}
