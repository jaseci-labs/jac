// BOOLEAN_COMPREHENSIVE_TEST_PLAN §4–6, §8 — toString, valueOf, constructor, call
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/02_boolean/test_boolean_prototype.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// BOL-T-001
assertEq(true.toString(), "true", "BOL-T-001: true.toString");
assertEq(false.toString(), "false", "BOL-T-001: false.toString");

// BOL-T-002
assertEq(new Boolean(true).toString(), "true", "BOL-T-002: wrapper true");
assertEq(new Boolean(0).toString(), "false", "BOL-T-002: new Boolean(0) -> false string");

// BOL-T-003
assertThrows(function () { Boolean.prototype.toString.call(1); }, TypeError, "BOL-T-003: toString wrong this number");
assertThrows(function () { Boolean.prototype.toString.call({}); }, TypeError, "BOL-T-003: toString wrong this object");

// BOL-T-004 — primitive template ignores overridden Boolean.prototype.toString
(function () {
    var orig = Boolean.prototype.toString;
    try {
        Boolean.prototype.toString = function () { return "Overridden"; };
        assertEq(`${true}`, "true", "BOL-T-004: primitive true template not overridden");
        assertEq(`${new Boolean(true)}`, "Overridden", "BOL-T-004: wrapper uses overridden toString in template");
    } finally {
        Boolean.prototype.toString = orig;
    }
}());

// BOL-V-001
assertEq(new Boolean(false).valueOf(), false, "BOL-V-001: valueOf false wrapper");
assertEq(new Boolean().valueOf(), false, "BOL-V-001: new Boolean() valueOf false");

// BOL-V-002
assertEq(new Boolean("Mozilla").valueOf(), true, "BOL-V-002: non-empty string");

// BOL-V-003
assertEq(true.valueOf(), true, "BOL-V-003: true.valueOf");
assertEq(false.valueOf(), false, "BOL-V-003: false.valueOf");

// BOL-V-004
assertThrows(function () { Boolean.prototype.valueOf.call(1); }, TypeError, "BOL-V-004: valueOf wrong this");

// BOL-R-001
assertEq(true.constructor, Boolean, "BOL-R-001: true.constructor");
assertEq(Object.getPrototypeOf(false), Boolean.prototype, "BOL-R-001: prototype of false");

// BOL-R-002
assertEq(new Boolean(true).constructor, Boolean, "BOL-R-002: wrapper.constructor");

// BOL-G-001 — valid Boolean exotic this for toString
assertEq(Boolean.prototype.toString.call(Object(true)), "true", "BOL-G-001: toString.call(Object(true))");

// BOL-G-002
assertEq(Boolean.prototype.valueOf.call(new Boolean(0)), false, "BOL-G-002: valueOf.call(new Boolean(0))");

// BOL-X-002 (optional cross-check)
assertEq(Object.prototype.toString.call(new Boolean(true)), "[object Boolean]", "BOL-X-002: Object.prototype.toString");

__jacDone();
