// BOOLEAN_COMPREHENSIVE_TEST_PLAN §1–2, §7 — primitives, Boolean(), truthiness vs ==
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/02_boolean/test_boolean_coercion.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

function sameBoolCoercion(x, msg) {
    assertEq(!!x, Boolean(x), msg);
}

// BOL-P-001
assertEq(typeof true, "boolean", "BOL-P-001: typeof true");
assertEq(typeof false, "boolean", "BOL-P-001: typeof false");

// BOL-P-002
assert(true !== false, "BOL-P-002: true !== false");
assertEq(true, true, "BOL-P-002: true === true");
assertEq(false, false, "BOL-P-002: false === false");

// BOL-F-001
assertEq(Boolean(), false, "BOL-F-001: Boolean() no arg");
assertEq(Boolean(undefined), false, "BOL-F-001: Boolean(undefined)");

// BOL-F-002
assertEq(Boolean(null), false, "BOL-F-002: Boolean(null)");

// BOL-F-003
assertEq(Boolean(false), false, "BOL-F-003: Boolean(false)");
assertEq(Boolean(true), true, "BOL-F-003: Boolean(true)");

// BOL-F-004
assertEq(Boolean(0), false, "BOL-F-004: Boolean(0)");
assertEq(Boolean(-0), false, "BOL-F-004: Boolean(-0)");
assertEq(Boolean(NaN), false, "BOL-F-004: Boolean(NaN)");
assertEq(Boolean(1), true, "BOL-F-004: Boolean(1)");
assertEq(Boolean(-1), true, "BOL-F-004: Boolean(-1)");
assertEq(Boolean(Infinity), true, "BOL-F-004: Boolean(Infinity)");

// BOL-F-005
if (typeof BigInt !== "undefined") {
    assertEq(Boolean(0n), false, "BOL-F-005: Boolean(0n)");
    assertEq(Boolean(1n), true, "BOL-F-005: Boolean(1n)");
}

// BOL-F-006
assertEq(Boolean(""), false, "BOL-F-006: Boolean empty string");
assertEq(Boolean("false"), true, "BOL-F-006: Boolean('false')");
assertEq(Boolean("0"), true, "BOL-F-006: Boolean('0')");
assertEq(Boolean("a"), true, "BOL-F-006: Boolean non-empty");

// BOL-F-007
assertEq(Boolean(Symbol("x")), true, "BOL-F-007: Boolean(Symbol)");

// BOL-F-008
assertEq(Boolean({}), true, "BOL-F-008: Boolean({})");
assertEq(Boolean([]), true, "BOL-F-008: Boolean([])");

// BOL-F-009
assertEq(Boolean(new Boolean(false)), true, "BOL-F-009: Boolean wraps object is true");

// BOL-F-010
sameBoolCoercion(undefined, "BOL-F-010: !! vs Boolean undefined");
sameBoolCoercion(null, "BOL-F-010: !! vs Boolean null");
sameBoolCoercion(0, "BOL-F-010: !! vs Boolean 0");
sameBoolCoercion(-0, "BOL-F-010: !! vs Boolean -0");
sameBoolCoercion(NaN, "BOL-F-010: !! vs Boolean NaN");
sameBoolCoercion("", "BOL-F-010: !! vs Boolean ''");
sameBoolCoercion("hi", "BOL-F-010: !! vs Boolean string");
sameBoolCoercion({}, "BOL-F-010: !! vs Boolean object");
sameBoolCoercion([], "BOL-F-010: !! vs Boolean array");
if (typeof BigInt !== "undefined") {
    sameBoolCoercion(0n, "BOL-F-010: !! vs Boolean 0n");
}

// BOL-E-001
(function () {
    var t = false;
    if ([]) { t = true; }
    assert(t, "BOL-E-001: [] is truthy in if");
    assertEq([] == false, true, "BOL-E-001: [] == false per MDN");
}());

// BOL-E-002
assertEq(Boolean(NaN), false, "BOL-E-002: NaN falsy");
assertEq(NaN == false, false, "BOL-E-002: NaN == false is false");
assertEq(Boolean(undefined), false, "BOL-E-002: undefined falsy");
assertEq(undefined == false, false, "BOL-E-002: undefined == false is false");
assertEq(Boolean(null), false, "BOL-E-002: null falsy");
assertEq(null == false, false, "BOL-E-002: null == false is false");

// BOL-E-003
assertEq(Boolean("0"), true, "BOL-E-003: Boolean('0') truthy");
assertEq("0" == false, true, "BOL-E-003: '0' == false per MDN coercion chain");

__jacDone();
