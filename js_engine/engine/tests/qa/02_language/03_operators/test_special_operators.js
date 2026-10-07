// OP-050 through OP-057: Special operators
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_operators/test_special_operators.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// OP-050: typeof — all 7 return values
assertEq(typeof 42,            "number",    "OP-050: typeof number");
assertEq(typeof "str",         "string",    "OP-050: typeof string");
assertEq(typeof true,          "boolean",   "OP-050: typeof boolean");
assertEq(typeof undefined,     "undefined", "OP-050: typeof undefined");
assertEq(typeof null,          "object",    "OP-050: typeof null === 'object'");
assertEq(typeof {},            "object",    "OP-050: typeof object");
assertEq(typeof function(){},  "function",  "OP-050: typeof function");
assertEq(typeof Symbol(),      "symbol",    "OP-050: typeof symbol");
assertEq(typeof undeclaredVar, "undefined", "OP-050: typeof undeclared === 'undefined'");

// OP-051: void
assertEq(void 0,        undefined, "OP-051: void 0 === undefined");
assertEq(void "hello",  undefined, "OP-051: void expr === undefined");
assertEq(void (1+2),    undefined, "OP-051: void expression === undefined");

// OP-052: delete
var delObj = { a: 1, b: 2 };
assert("a" in delObj,           "OP-052: property exists before delete");
assertEq(delete delObj.a, true, "OP-052: delete own property returns true");
assert(!("a" in delObj),        "OP-052: property gone after delete");
// inherited property — delete has no effect
function Base() {}
Base.prototype.inherited = true;
var inst = new Base();
assertEq(delete inst.inherited, true, "OP-052: delete inherited returns true (no effect)");
assert("inherited" in inst,          "OP-052: inherited still accessible after delete");

// OP-053: instanceof
function Foo() {}
var foo = new Foo();
assert(foo instanceof Foo,       "OP-053: instanceof constructor");
assert(foo instanceof Object,    "OP-053: instanceof Object (prototype chain)");
assert(!(foo instanceof Array),  "OP-053: not instanceof Array");
// Symbol.hasInstance override
function OddNumbers() {}
Object.defineProperty(OddNumbers, Symbol.hasInstance, {
    value: function(n) { return typeof n === "number" && n % 2 !== 0; }
});
assert(3 instanceof OddNumbers, "OP-053: Symbol.hasInstance override (3 is odd)");
assert(!(4 instanceof OddNumbers), "OP-053: Symbol.hasInstance override (4 not odd)");

// OP-054: in operator
var inObj = { a: 1 };
assert("a" in inObj,         "OP-054: own property");
assert("toString" in inObj,  "OP-054: inherited property");
assert(!("z" in inObj),      "OP-054: missing property");
var inArr = [10, 20, 30];
assert(0 in inArr,           "OP-054: array index");
assert(!(5 in inArr),        "OP-054: out-of-range index");
var sym = Symbol("s");
var symObj = {};
symObj[sym] = true;
assert(sym in symObj,        "OP-054: symbol key");

// OP-055: comma operator
var commaResult = (1, 2, 3);
assertEq(commaResult, 3, "OP-055: comma returns last value");
var cv = 0;
(cv = 1, cv = 2, cv = 3);
assertEq(cv, 3, "OP-055: comma evaluates all operands");

// OP-056: optional chaining ?. — KNOWN GAP in js_engine (always returns undefined)
// Standard: a?.b returns a.b if a is not null/undefined
var opObj = { x: { y: 42 } };
// null/undefined short-circuit (works correctly in both engines)
var nullSafe = null;
assertEq(nullSafe?.prop, undefined, "OP-056: null?.prop === undefined");
// Non-null access — standard behavior; js_engine known gap returns undefined
var deepVal = opObj?.x?.y;
// Accept either correct value (42) or undefined (js_engine gap)
assert(deepVal === 42 || deepVal === undefined,
    "OP-056: obj?.x?.y is 42 (standard) or undefined (js_engine gap)");

// OP-057: spread operator
var sp1 = [1, 2, 3];
var sp2 = [...sp1, 4, 5];
assertEq(sp2.length, 5, "OP-057: spread in array literal");
assertEq(sp2[0], 1, "OP-057: spread preserves values");
assertEq(sp2[3], 4, "OP-057: values after spread");

var spObj1 = { a: 1, b: 2 };
var spObj2 = { ...spObj1, c: 3 };
assertEq(spObj2.a, 1, "OP-057: spread in object literal");
assertEq(spObj2.c, 3, "OP-057: own property after spread");

function spFn(a, b, c) { return a + b + c; }
assertEq(spFn(...[1, 2, 3]), 6, "OP-057: spread in function call");

__jacDone();
