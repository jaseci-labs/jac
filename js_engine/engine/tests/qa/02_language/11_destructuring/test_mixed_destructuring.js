// DST-020 through DST-023: Mixed destructuring
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/11_destructuring/test_mixed_destructuring.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// DST-020: object containing array
var { arr: [d20x, d20y] } = { arr: [1, 2] };
assertEq(d20x, 1, "DST-020: object+array x");
assertEq(d20y, 2, "DST-020: object+array y");

// DST-021: array of objects
var [{ a: d21a }, { b: d21b }] = [{ a: 1 }, { b: 2 }];
assertEq(d21a, 1, "DST-021: array+object a");
assertEq(d21b, 2, "DST-021: array+object b");

// DST-022: 3-level deep nesting
var { level1: { level2: [d22a, d22b] } } = { level1: { level2: [10, 20] } };
assertEq(d22a, 10, "DST-022: 3-level nesting [0]");
assertEq(d22b, 20, "DST-022: 3-level nesting [1]");

// DST-023: destructuring in for-of
var map = new Map([["k1", "v1"], ["k2", "v2"], ["k3", "v3"]]);
var pairs = [];
for (const [k, v] of map) {
    pairs.push(k + "=" + v);
}
assertEq(pairs.join(","), "k1=v1,k2=v2,k3=v3", "DST-023: destructuring in for-of Map");

// Object destructuring in for-of
var people = [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }];
var names = [];
for (const { name, age } of people) {
    names.push(name + ":" + age);
}
assertEq(names.join(","), "Alice:30,Bob:25", "DST-023: object destructuring in for-of");

__jacDone();
