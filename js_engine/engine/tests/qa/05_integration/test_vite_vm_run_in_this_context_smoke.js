// VIT-VM-001: Vite V-10 smoke
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/05_integration/test_vite_vm_run_in_this_context_smoke.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assertEq(actual, expected, msg) {
    __reg.assertEq(actual, expected, msg);
}

assertEq(require("vm").runInThisContext("40 + 2"), 42, "VIT-VM-001");
__jacDone();
