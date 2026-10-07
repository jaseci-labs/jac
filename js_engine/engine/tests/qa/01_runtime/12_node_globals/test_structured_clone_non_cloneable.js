// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-S-004 (structuredClone rejects functions)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_structured_clone_non_cloneable.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

if (typeof structuredClone !== "function") {
    console.log("skip NGL-S-004: structuredClone not available");
    __jacDone();
} else {
    try {
        structuredClone(function () {});
        assert(false, "NGL-S-004: clone function should throw");
    } catch (e) {
        var ok =
            e &&
            (e.name === "DataCloneError" ||
                (typeof DOMException !== "undefined" && e instanceof DOMException));
        assert(ok, "NGL-S-004: non-cloneable function throws DataCloneError / DOMException");
    }
    __jacDone();
}
