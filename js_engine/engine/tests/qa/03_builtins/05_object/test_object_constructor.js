// Object() / new Object() constructor — coercion, wrapping, identity, edge cases
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_object_constructor.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── Object() without new ───────────────────────────────────────────────────

// No arguments — empty object
var o1 = Object();
assertEq(typeof o1, "object", "Object() returns object");
assert(o1 !== null,           "Object() is not null");

// undefined → empty object
var o2 = Object(undefined);
assertEq(typeof o2, "object", "Object(undefined) returns object");

// null → empty object
var o3 = Object(null);
assertEq(typeof o3, "object", "Object(null) returns object");

// Number wrapping
var o4 = Object(42);
assertEq(typeof o4, "object", "Object(42) typeof object");
assertEq(o4.valueOf(), 42,    "Object(42).valueOf() === 42");
assertEq(o4 + 0, 42,          "Object(42) coerces to 42 in arithmetic");

// String wrapping
var o5 = Object("hello");
assertEq(typeof o5, "object",   "Object('hello') typeof object");
assertEq(o5.valueOf(), "hello",  "Object('hello').valueOf()");
assertEq(o5.length, 5,          "Object('hello').length === 5");

// Boolean wrapping
var o6 = Object(true);
assertEq(typeof o6, "object",   "Object(true) typeof object");
assertEq(o6.valueOf(), true,    "Object(true).valueOf()");

// Symbol wrapping — may differ per engine
if (typeof Symbol === "function") {
    var sym = Symbol("test");
    var o7 = Object(sym);
    assertEq(typeof o7, "object", "Object(Symbol) typeof object");
}

// Existing object → same reference
var existing = {a: 1, b: 2};
assertEq(Object(existing), existing, "Object(obj) returns same ref");

// Existing array → same reference
var arr = [1, 2, 3];
assertEq(Object(arr), arr, "Object(array) returns same ref");

// Existing function → same reference
var fn = function() { return 42; };
assertEq(Object(fn), fn, "Object(function) returns same ref");

// ── new Object() ───────────────────────────────────────────────────────────

// No arguments
var n1 = new Object();
assertEq(typeof n1, "object", "new Object() is object");
assert(n1 !== null,           "new Object() is not null");

// undefined → empty object
var n2 = new Object(undefined);
assertEq(typeof n2, "object", "new Object(undefined) is object");

// null → empty object
var n3 = new Object(null);
assertEq(typeof n3, "object", "new Object(null) is object");

// Number → wrapper
var n4 = new Object(42);
assertEq(typeof n4, "object", "new Object(42) is object");
assertEq(n4.valueOf(), 42,    "new Object(42).valueOf()");

// String → wrapper
var n5 = new Object("str");
assertEq(typeof n5, "object", "new Object('str') is object");
assertEq(n5.valueOf(), "str", "new Object('str').valueOf()");

// Boolean → wrapper
var n6 = new Object(true);
assertEq(typeof n6, "object", "new Object(true) is object");
assertEq(n6.valueOf(), true,  "new Object(true).valueOf()");

// Object → same reference
var n7ref = {x: 10};
var n7 = new Object(n7ref);
assertEq(n7, n7ref, "new Object(obj) returns same ref");

// ── Negative: Object coercion edge cases ───────────────────────────────────

// Object.keys(null) — should throw TypeError in ES6+
var threwNull = false;
try { Object.keys(null); } catch(e) { threwNull = true; }
assert(threwNull, "Object.keys(null) throws");

// Object.keys(undefined) — should throw TypeError
var threwUndef = false;
try { Object.keys(undefined); } catch(e) { threwUndef = true; }
assert(threwUndef, "Object.keys(undefined) throws");

// Object.keys(42) — coerced to object; numbers have no own enum keys
var numKeys = Object.keys(42);
assert(Array.isArray(numKeys),     "Object.keys(42) returns array");
assertEq(numKeys.length, 0,       "Object.keys(42) is empty");

// Object.keys("abc") — string indices
var strKeys = Object.keys("abc");
assert(Array.isArray(strKeys),     "Object.keys('abc') returns array");
assertEq(strKeys.length, 3,       "Object.keys('abc') has 3 elements");
assertEq(strKeys[0], "0",          "Object.keys('abc')[0] === '0'");
assertEq(strKeys[1], "1",          "Object.keys('abc')[1] === '1'");
assertEq(strKeys[2], "2",          "Object.keys('abc')[2] === '2'");

__jacDone();
