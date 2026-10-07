// DST-010 through DST-017: Object destructuring
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/11_destructuring/test_object_destructuring.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// DST-010: basic object destructuring
var { a: d10a, b: d10b } = { a: 1, b: 2 };
assertEq(d10a, 1, "DST-010: destructure a");
assertEq(d10b, 2, "DST-010: destructure b");
// shorthand
var { x: d10x, y: d10y } = { x: "hello", y: "world" };
assertEq(d10x, "hello", "DST-010: shorthand x");
assertEq(d10y, "world", "DST-010: shorthand y");

// DST-011: rename
var { name: personName, age: personAge } = { name: "Alice", age: 30 };
assertEq(personName, "Alice", "DST-011: rename property");
assertEq(personAge,  30,      "DST-011: rename property (age)");

// DST-012: defaults
var { p: d12p = 10, q: d12q = 20 } = { p: 5 };
assertEq(d12p, 5,  "DST-012: provided value overrides default");
assertEq(d12q, 20, "DST-012: default used when key missing");
var { r: d12r = 99 } = { r: undefined };
assertEq(d12r, 99, "DST-012: explicit undefined triggers default");

// DST-013: rest
var { a: d13a, ...d13rest } = { a: 1, b: 2, c: 3 };
assertEq(d13a,       1, "DST-013: extracted property");
assertEq(d13rest.b,  2, "DST-013: rest.b");
assertEq(d13rest.c,  3, "DST-013: rest.c");
assertEq("a" in d13rest, false, "DST-013: rest does not include extracted");

// DST-014: nested
var { a: { b: d14b } } = { a: { b: 42 } };
assertEq(d14b, 42, "DST-014: nested object destructuring");

// DST-015: computed keys
var key = "dynamic";
var { [key]: d15val } = { dynamic: "found" };
assertEq(d15val, "found", "DST-015: computed key destructuring");

// DST-016: destructuring in function parameters
function d16fn({ name, age = 0 }) {
    return name + "/" + age;
}
assertEq(d16fn({ name: "Bob", age: 25 }), "Bob/25", "DST-016: obj destructure in params");
assertEq(d16fn({ name: "Eve" }),           "Eve/0",  "DST-016: default in param destructure");

// DST-017: assignment destructuring (must wrap in parens)
var d17a, d17b;
({ a: d17a, b: d17b } = { a: "x", b: "y" });
assertEq(d17a, "x", "DST-017: assignment destructuring a");
assertEq(d17b, "y", "DST-017: assignment destructuring b");

__jacDone();
