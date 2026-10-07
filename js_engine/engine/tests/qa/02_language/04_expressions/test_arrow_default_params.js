// Regression test: arrow-function default parameters
//
// When the parser encounters `(a = 99) => ...`, it first parses `a = 99`
// as an AssignmentExpression (valid in a grouped expression context).
// After confirming the `=>` token, those items must be reinterpreted as
// AssignmentPattern (default parameter) nodes. Without this rewrite the
// compiled function sees zero parameters, so every argument inside the
// function body is undefined.

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/arrow_default_params");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

// Single default — no argument supplied
var fn1 = (a = 99) => a;
__reg.assertEq(fn1(), 99, "default applied when no arg");

// Single default — explicit argument overrides default
__reg.assertEq(fn1(42), 42, "explicit arg overrides default");

// Falsy explicit argument must NOT trigger default
__reg.assertEq(fn1(0), 0, "falsy arg 0 does not trigger default");

// Multiple params, first has default
var fn2 = (a = 1, b) => a + b;
__reg.assertEq(fn2(undefined, 10), 11, "first default used");
__reg.assertEq(fn2(5, 10), 15, "first default skipped");

// Multiple params, second has default
var fn3 = (a, b = 2) => a + b;
__reg.assertEq(fn3(10), 12, "second default used");
__reg.assertEq(fn3(10, 20), 30, "second default skipped");

// Both params have defaults
var fn4 = (a = 3, b = 7) => a * b;
__reg.assertEq(fn4(), 21, "both defaults applied");
__reg.assertEq(fn4(2), 14, "first overridden, second default");
__reg.assertEq(fn4(2, 5), 10, "both overridden");

// Default is an expression
var fn5 = (a = 2 + 3) => a;
__reg.assertEq(fn5(), 5, "arithmetic default expression");

// Default references an outer variable
var base = 100;
var fn6 = (a = base) => a;
__reg.assertEq(fn6(), 100, "default captures outer variable");

// Arrow assigned to an object property (method pattern)
var holder = (x) => x;
holder.method = (a = 99) => a;
__reg.assertEq(holder.method(), 99, "method default applied");
__reg.assertEq(holder.method(42), 42, "method explicit arg");

// Factory returning arrow with default param (closure capture)
var make = function(offset) { return (a = 10) => a + offset; };
var add5 = make(5);
__reg.assertEq(add5(), 15, "factory-arrow default");
__reg.assertEq(add5(1), 6, "factory-arrow explicit");

__jacDone();
