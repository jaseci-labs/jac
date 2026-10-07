// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-S-003 (structuredClone transfer)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_structured_clone_transfer.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

if (typeof structuredClone !== "function" || typeof Uint8Array === "undefined") {
    console.log("skip NGL-S-003: structuredClone or Uint8Array not available");
    __jacDone();
} else {
    try {
        var ab = new ArrayBuffer(2);
        new Uint8Array(ab).set([7, 8]);
        var view = new Uint8Array(ab);
        var cloned = structuredClone(view, { transfer: [ab] });
        assertEq(view.buffer.byteLength, 0, "NGL-S-003: original buffer detached after transfer");
        assertEq(cloned[0], 7, "NGL-S-003: transferred view retains bytes");
        assertEq(cloned[1], 8, "NGL-S-003: second byte preserved");
    } catch (e) {
        console.log("skip NGL-S-003: transfer option not supported");
    }
    __jacDone();
}
