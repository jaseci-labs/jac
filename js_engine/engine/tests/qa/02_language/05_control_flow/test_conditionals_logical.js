// CONDITIONALS_COMPREHENSIVE_TEST_PLAN §7 — CND-L-*
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_conditionals_logical.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// --- CND-L-001: && short-circuit and return value
(function () {
    var rhs = 0;
    var r = false && (rhs = 1);
    assertEq(rhs, 0, "CND-L-001: rhs not evaluated when lhs falsy");
    assertEq(r, false, "CND-L-001: returns first falsy");
    rhs = 0;
    r = true && (rhs = 1);
    assertEq(rhs, 1, "CND-L-001: rhs evaluated when lhs truthy");
    assertEq(r, 1, "CND-L-001: returns last evaluated when all truthy");
})();

// --- CND-L-002: || short-circuit
(function () {
    var rhs = 0;
    var r = true || (rhs = 1);
    assertEq(rhs, 0, "CND-L-002: rhs skipped when lhs truthy");
    assertEq(r, true, "CND-L-002: returns lhs");
    rhs = 0;
    r = false || (rhs = 1);
    assertEq(rhs, 1, "CND-L-002: rhs evaluated when lhs falsy");
    assertEq(r, 1, "CND-L-002: returns rhs value");
})();

// --- CND-L-003: precedence true || false && false === true
(function () {
    assertEq(true || false && false, true, "CND-L-003: && tighter than ||");
})();

// --- CND-L-004: non-boolean operands preserved
(function () {
    assertEq("" && "foo", "", "CND-L-004: empty string short-circuit");
    assertEq("Cat" && "Dog", "Dog", "CND-L-004: both strings — last value");
})();

__jacDone();
