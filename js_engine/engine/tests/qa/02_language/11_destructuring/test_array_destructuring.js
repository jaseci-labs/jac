// DST-001 through DST-008: Array destructuring
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/11_destructuring/test_array_destructuring.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// DST-001: basic array destructuring, extra elements ignored
var [d1a, d1b] = [1, 2, 3];
assertEq(d1a, 1, "DST-001: first element");
assertEq(d1b, 2, "DST-001: second element (extra 3 ignored)");

// DST-002: skip elements
var [, , d2c] = [1, 2, 3];
assertEq(d2c, 3, "DST-002: skip first two elements");

// DST-003: default values (used when undefined)
var [d3a = 10, d3b = 20] = [5];
assertEq(d3a, 5,  "DST-003: provided value overrides default");
assertEq(d3b, 20, "DST-003: default used when undefined");
var [d3c = 99] = [undefined];
assertEq(d3c, 99, "DST-003: explicit undefined triggers default");
var [d3d = 99] = [null];
assertEq(d3d, null, "DST-003: null does NOT trigger default");

// DST-004: rest element
var [d4first, ...d4rest] = [1, 2, 3, 4];
assertEq(d4first,       1,    "DST-004: first element");
assertEq(d4rest.length, 3,    "DST-004: rest collects remaining");
assertEq(d4rest[0],     2,    "DST-004: rest[0]");
assertEq(Array.isArray(d4rest), true, "DST-004: rest is Array");

// DST-005: nested array destructuring
var [[d5a, d5b], [d5c, d5d]] = [[1, 2], [3, 4]];
assertEq(d5a, 1, "DST-005: nested [0][0]");
assertEq(d5b, 2, "DST-005: nested [0][1]");
assertEq(d5c, 3, "DST-005: nested [1][0]");
assertEq(d5d, 4, "DST-005: nested [1][1]");

// DST-006: swap
var d6a = "x", d6b = "y";
[d6a, d6b] = [d6b, d6a];
assertEq(d6a, "y", "DST-006: swap a");
assertEq(d6b, "x", "DST-006: swap b");

// DST-007: from iterables
var [d7a, d7b, d7c] = "abc";
assertEq(d7a, "a", "DST-007: from string");
// Set
var [d7s1, d7s2] = new Set([10, 20]);
assertEq(d7s1, 10, "DST-007: from Set first");
assertEq(d7s2, 20, "DST-007: from Set second");
// generator
function* d7gen() { yield "p"; yield "q"; yield "r"; }
var [d7g1, d7g2] = d7gen();
assertEq(d7g1, "p", "DST-007: from generator first");
assertEq(d7g2, "q", "DST-007: from generator second");

// DST-008: destructuring in function parameters
function d8fn([first, second]) {
    return first + second;
}
assertEq(d8fn([3, 7]), 10, "DST-008: array destructuring in params");

__jacDone();
