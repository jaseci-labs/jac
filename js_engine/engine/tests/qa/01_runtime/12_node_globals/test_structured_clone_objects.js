// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-S-001, NGL-S-002 (structuredClone objects/arrays)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_structured_clone_objects.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

if (typeof structuredClone !== "function") {
    console.log("skip NGL-S-001/S-002: structuredClone not available");
    __jacDone();
} else {
    var o = { a: 1, nested: { b: 2 } };
    var c = structuredClone(o);
    assert(c !== o, "NGL-S-002: clone is not same reference");
    assertEq(c.a, 1, "NGL-S-002: shallow field copied");
    assertEq(c.nested.b, 2, "NGL-S-002: nested structure copied");
    assert(c.nested !== o.nested, "NGL-S-002: nested object cloned");
    var arr = structuredClone([1, [2, 3]]);
    assertEq(arr[1][0], 2, "NGL-S-002: array clone");
    __jacDone();
}
