// FUNC-001 through FUNC-030: Functions (synchronous)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/07_functions/test_functions.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── Declarations (FUNC-001) ──────────────────────────────────────────────────
function add(a, b) { return a + b; }
assertEq(add(2, 3), 5, "FUNC-001: basic call");
assert(isNaN(add(1)), "FUNC-001: missing arg is undefined (1+undefined=NaN)");
assertEq(add(1, 2, 3), 3, "FUNC-001: extra args ignored");
// hoisting — function declaration usable before it appears
assertEq(hoistedFn(), "hoisted", "FUNC-001: function declaration hoisted");
function hoistedFn() { return "hoisted"; }

// ── arguments object (FUNC-002) ──────────────────────────────────────────────
function argsTest() {
    return arguments.length;
}
assertEq(argsTest(1, 2, 3), 3, "FUNC-002: arguments.length");
function argsIndex() { return arguments[1]; }
assertEq(argsIndex("a", "b"), "b", "FUNC-002: arguments index access");
// Arrow functions do NOT have their own arguments
var arrowArgs = (function() {
    return (() => arguments[0])();
})(42);
assertEq(arrowArgs, 42, "FUNC-002: arrow inherits outer arguments");

// ── Rest parameters (FUNC-003) ───────────────────────────────────────────────
function restFn(first, ...rest) {
    return { first: first, rest: rest, isArray: Array.isArray(rest) };
}
var rr = restFn(1, 2, 3, 4);
assertEq(rr.first,   1,    "FUNC-003: first positional");
assertEq(rr.rest.length, 3,"FUNC-003: rest collects remaining");
assertEq(rr.isArray, true, "FUNC-003: rest is real Array");
var rr2 = restFn(1);
assertEq(rr2.rest.length, 0, "FUNC-003: rest is empty array when no extra");

// ── Return value (FUNC-004) ──────────────────────────────────────────────────
function explicitReturn() { return 42; }
assertEq(explicitReturn(), 42, "FUNC-004: explicit return");
function implicitReturn() { /* nothing */ }
assertEq(implicitReturn(), undefined, "FUNC-004: implicit return is undefined");
function conditionalReturn(n) {
    if (n > 0) { return "positive"; }
    return "non-positive";
}
assertEq(conditionalReturn(1), "positive",     "FUNC-004: return in block");
assertEq(conditionalReturn(-1), "non-positive","FUNC-004: fallthrough return");

// ── Named function expression (FUNC-010) ─────────────────────────────────────
var nfe = function factorial(n) {
    return n <= 1 ? 1 : n * factorial(n - 1);
};
assertEq(nfe(5), 120, "FUNC-010: named function expression self-reference");
assertEq(typeof factorial, "undefined", "FUNC-010: name not visible outside");

// ── Anonymous function expression (FUNC-011) ──────────────────────────────────
var anon = function() { return "anon"; };
assertEq(anon(), "anon", "FUNC-011: anonymous expression call");
assertEq(anon.name, "anon", "FUNC-011: name inferred from assignment");

// ── IIFE (FUNC-012) ──────────────────────────────────────────────────────────
var iifeVal = (function() { return "iife"; })();
assertEq(iifeVal, "iife", "FUNC-012: IIFE runs immediately");
var iifeWithArg = (function(x) { return x * 2; })(21);
assertEq(iifeWithArg, 42, "FUNC-012: IIFE with arguments");

// ── Arrow functions (FUNC-020 through FUNC-024) ──────────────────────────────
var arrowConcat = (a, b) => a + b;
assertEq(arrowConcat("x", "y"), "xy", "FUNC-020: two-param arrow");
var arrowSingle = x => x * x;
assertEq(arrowSingle(5), 25, "FUNC-020: single param no parens");
var arrowZero = () => 99;
assertEq(arrowZero(), 99, "FUNC-020: zero-param arrow");

// block body with return (FUNC-021)
var arrowBlock = (a, b) => {
    var sum = a + b;
    return sum * 2;
};
assertEq(arrowBlock(3, 4), 14, "FUNC-021: arrow block body with return");

// lexical this (FUNC-022)
function Timer() {
    this.count = 0;
    this.tick = () => { this.count++; };
}
var t = new Timer();
t.tick(); t.tick();
assertEq(t.count, 2, "FUNC-022: arrow lexical this");
// Call/apply cannot rebind arrow this
var other = { count: 99 };
t.tick.call(other);
assertEq(t.count, 3, "FUNC-022: arrow this not rebindable via call");

// no arguments / no new (FUNC-023)
var arrowNoNew = () => {};
var threwNew = false;
try { new arrowNoNew(); } catch(e) { threwNew = true; }
assert(threwNew, "FUNC-023: arrow throws TypeError when called with new");

// arrow returning object literal (FUNC-024)
var makeObj = (k, v) => ({ [k]: v });
assertEq(makeObj("hello", 42).hello, 42, "FUNC-024: arrow returns object literal");

// ── Default parameters (FUNC-030) ────────────────────────────────────────────
function withDefaults(a, b = 10, c = a + b) {
    return { a, b, c };
}
var d1 = withDefaults(5);
assertEq(d1.a,  5,  "FUNC-030: first param provided");
assertEq(d1.b,  10, "FUNC-030: default used for missing param");
assertEq(d1.c,  15, "FUNC-030: default references earlier param");

var d2 = withDefaults(1, 2, 3);
assertEq(d2.b,  2,  "FUNC-030: explicit value overrides default");

var d3 = withDefaults(1, undefined, 99);
assertEq(d3.b,  10, "FUNC-030: undefined triggers default");

var d4 = withDefaults(1, null);
assertEq(d4.b,  null, "FUNC-030: null does NOT trigger default");

__jacDone();
