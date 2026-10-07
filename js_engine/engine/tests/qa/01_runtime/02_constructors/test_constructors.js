// RT-010 through RT-021: Global constructors
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/02_constructors/test_constructors.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-010: Array
assertEq(typeof Array, "function", "RT-010: typeof Array === 'function'");
assert(Array.isArray([]), "RT-010: Array.isArray([]) works");
assert(Array.isArray(new Array()), "RT-010: new Array() works");

// RT-011: Object
assertEq(typeof Object, "function", "RT-011: typeof Object === 'function'");
assert(typeof Object.keys === "function", "RT-011: Object.keys exists");

// RT-012: Function
assertEq(typeof Function, "function", "RT-012: typeof Function === 'function'");

// RT-013: String
assertEq(typeof String, "function", "RT-013: typeof String === 'function'");
assertEq(String(123), "123", "RT-013: String(123) === '123'");

// RT-014: Number
assertEq(typeof Number, "function", "RT-014: typeof Number === 'function'");
assertEq(Number("42"), 42, "RT-014: Number('42') === 42");

// RT-015: Boolean
assertEq(typeof Boolean, "function", "RT-015: typeof Boolean === 'function'");
assertEq(Boolean(0), false, "RT-015: Boolean(0) === false");

// RT-016: Symbol
assertEq(typeof Symbol, "function", "RT-016: typeof Symbol === 'function'");
assert(typeof Symbol.iterator === "symbol", "RT-016: Symbol.iterator exists");

// RT-017: Error types
assertEq(typeof Error, "function", "RT-017: typeof Error === 'function'");
assertEq(typeof TypeError, "function", "RT-017: typeof TypeError === 'function'");
assertEq(typeof ReferenceError, "function", "RT-017: typeof ReferenceError === 'function'");
assertEq(typeof SyntaxError, "function", "RT-017: typeof SyntaxError === 'function'");
assertEq(typeof RangeError, "function", "RT-017: typeof RangeError === 'function'");

// RT-018: Map / Set
assertEq(typeof Map, "function", "RT-018: typeof Map === 'function'");
assertEq(typeof Set, "function", "RT-018: typeof Set === 'function'");

// RT-019: WeakMap / WeakSet
assertEq(typeof WeakMap, "function", "RT-019: typeof WeakMap === 'function'");
assertEq(typeof WeakSet, "function", "RT-019: typeof WeakSet === 'function'");

// RT-020: Date
assertEq(typeof Date, "function", "RT-020: typeof Date === 'function'");
assertEq(typeof Date.now(), "number", "RT-020: Date.now() returns number");

// RT-021: Promise
assertEq(typeof Promise, "function", "RT-021: typeof Promise === 'function'");
assert(typeof Promise.resolve === "function", "RT-021: Promise.resolve exists");

__jacDone();
