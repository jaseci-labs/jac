// BOOLEAN_COMPREHENSIVE_TEST_PLAN §3 — new Boolean() wrapper
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/02_boolean/test_boolean_wrapper.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// BOL-N-001
var bolN1 = new Boolean(1);
assertEq(typeof bolN1, "object", "BOL-N-001: typeof new Boolean");
assert(bolN1 instanceof Boolean, "BOL-N-001: instanceof Boolean");

// BOL-N-002
(function () {
    var ranFalse = false;
    if (new Boolean(false)) { ranFalse = true; }
    assert(ranFalse, "BOL-N-002: if (new Boolean(false)) runs");
    var ranTrue = false;
    if (new Boolean(true)) { ranTrue = true; }
    assert(ranTrue, "BOL-N-002: if (new Boolean(true)) runs");
}());

// BOL-N-003
assertEq(new Boolean().valueOf(), false, "BOL-N-003: new Boolean() internal false");
assertEq(new Boolean(0).valueOf(), false, "BOL-N-003: new Boolean(0) false");
assertEq(new Boolean(null).valueOf(), false, "BOL-N-003: new Boolean(null) false");
assertEq(new Boolean("").valueOf(), false, "BOL-N-003: new Boolean('') false");
assertEq(new Boolean(1).valueOf(), true, "BOL-N-003: new Boolean(1) true");
assertEq(new Boolean({}).valueOf(), true, "BOL-N-003: new Boolean({}) true");

// BOL-N-004
assertEq(new Boolean("false").valueOf(), true, "BOL-N-004: string 'false' coerces to true");

// BOL-N-005
var bolN5 = new Boolean(false);
assertEq(bolN5.valueOf(), false, "BOL-N-005: valueOf false");
assertEq(Boolean(bolN5), true, "BOL-N-005: Boolean(wrapper) is true even for false inside");

__jacDone();
