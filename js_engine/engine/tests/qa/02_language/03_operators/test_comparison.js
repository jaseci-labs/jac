// OP-010 through OP-012: Comparison operators
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_operators/test_comparison.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// OP-010: === / !== strict equality
assertEq(1 === 1,         true,  "OP-010: 1 === 1");
assertEq(1 === "1",       false, "OP-010: 1 === '1' (no coercion)");
assertEq(null === null,   true,  "OP-010: null === null");
assertEq(null === undefined, false, "OP-010: null !== undefined");
assertEq(NaN === NaN,     false, "OP-010: NaN !== NaN");
assertEq(+0 === -0,       true,  "OP-010: +0 === -0");
var o = {}; assertEq(o === o, true, "OP-010: same object reference");
assertEq({} === {}, false, "OP-010: different object references");

// OP-011: == / != abstract equality
assert(1 == 1,       "OP-011: 1 == 1");
assert(1 == "1",     "OP-011: 1 == '1' (coercion)");
assert(null == undefined, "OP-011: null == undefined");
assert(!(null == 0), "OP-011: null != 0");
assert(0 == false,   "OP-011: 0 == false");
assert(1 == true,    "OP-011: 1 == true");
assert(1 != 2,       "OP-011: 1 != 2");

// OP-012: < > <= >= relational
assertEq(3 < 5,    true,  "OP-012: 3 < 5");
assertEq(5 > 3,    true,  "OP-012: 5 > 3");
assertEq(3 <= 3,   true,  "OP-012: 3 <= 3");
assertEq(3 >= 3,   true,  "OP-012: 3 >= 3");
assertEq(3 > 3,    false, "OP-012: 3 > 3 is false");
// string lexicographic
assertEq("abc" < "abd", true,  "OP-012: string < lexicographic");
assertEq("b" > "a",     true,  "OP-012: string > lexicographic");
// mixed
assertEq(5 > "3",  true,  "OP-012: number > coerced string");
// NaN comparisons all false
assertEq(NaN < 1,  false, "OP-012: NaN < 1 is false");
assertEq(NaN > 1,  false, "OP-012: NaN > 1 is false");
assertEq(NaN >= 1, false, "OP-012: NaN >= 1 is false");
assertEq(NaN <= 1, false, "OP-012: NaN <= 1 is false");

__jacDone();
