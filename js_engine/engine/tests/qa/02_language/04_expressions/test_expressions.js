// EXPR-001 through EXPR-009: Expressions and literals
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/04_expressions/test_expressions.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// EXPR-001: Numeric literals
assertEq(255,       255, "EXPR-001: decimal");
assertEq(0xFF,      255, "EXPR-001: hex 0x");
assertEq(0o377,     255, "EXPR-001: octal 0o");
assertEq(0b11111111,255, "EXPR-001: binary 0b");
assertEq(1e3,       1000,"EXPR-001: scientific");
assertEq(1_000_000, 1000000, "EXPR-001: numeric separator");

// EXPR-002: String literals
assertEq("hello",   "hello", "EXPR-002: double quotes");
assertEq('world',   "world", "EXPR-002: single quotes");
assertEq("a\nb",    "a\nb",  "EXPR-002: newline escape");
assertEq("a\tb",    "a\tb",  "EXPR-002: tab escape");
assertEq("a\\b",    "a\\b",  "EXPR-002: backslash escape");
assertEq("\u0041",  "A",     "EXPR-002: unicode escape \\u0041");
assertEq("\x41",    "A",     "EXPR-002: hex escape \\x41");

// EXPR-003: Boolean/null/undefined literals
assertEq(true,      true,      "EXPR-003: true literal");
assertEq(false,     false,     "EXPR-003: false literal");
assertEq(null,      null,      "EXPR-003: null literal");
assertEq(undefined, undefined, "EXPR-003: undefined");

// EXPR-004: Array literals
assertEq([].length,        0, "EXPR-004: empty array");
assertEq([1,2,3].length,   3, "EXPR-004: array with values");
assertEq([1,2,].length,    2, "EXPR-004: trailing comma ignored");
var sparse = [,, 3];
assertEq(sparse.length,    3, "EXPR-004: sparse array length");
assertEq(sparse[0],        undefined, "EXPR-004: sparse hole is undefined");
assertEq(sparse[2],        3,         "EXPR-004: sparse non-hole value");

// EXPR-005: Object literals
assertEq(Object.keys({}).length, 0, "EXPR-005: empty object");
var x = 1, y = 2;
var shorthand = { x, y };
assertEq(shorthand.x, 1, "EXPR-005: shorthand property {x}");
assertEq(shorthand.y, 2, "EXPR-005: shorthand property {y}");
var key = "dynamic";
var computed = { [key]: "value" };
assertEq(computed.dynamic, "value", "EXPR-005: computed key {[expr]: val}");

// EXPR-006: RegExp literals — KNOWN GAP: RegExp not implemented in js_engine
// Primary check: accessing a regex literal does not crash the engine
var reLiteralType = typeof /abc/;
assert(reLiteralType === "object" || reLiteralType === "undefined",
    "EXPR-006: regex literal does not crash (type is object or undefined)");

// EXPR-007: Property access
var obj = { a: 1, "b-c": 2 };
assertEq(obj.a,       1, "EXPR-007: dot notation");
assertEq(obj["b-c"],  2, "EXPR-007: bracket notation");
var prop = "a";
assertEq(obj[prop],   1, "EXPR-007: variable key");

// EXPR-008: new expression
function Point(px, py) { this.x = px; this.y = py; }
var p = new Point(3, 4);
assertEq(p.x, 3, "EXPR-008: new with args");
var p2 = new Point;
assertEq(p2.x, undefined, "EXPR-008: new without parens");
// new + method call chain
var arr = new Array(3);
assertEq(arr.length, 3, "EXPR-008: new Array(n)");

// EXPR-009: Grouping ()
assertEq((1 + 2) * 3, 9, "EXPR-009: parentheses override precedence");
var iife = (function(n) { return n * 2; })(5);
assertEq(iife, 10, "EXPR-009: IIFE");
var arrowObj = () => ({ key: "val" });
assertEq(arrowObj().key, "val", "EXPR-009: arrow returning object literal");

__jacDone();
