// OP-020 through OP-023: Logical operators
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_operators/test_logical.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// OP-020: && AND — short-circuit, returns first falsy or last value
assertEq(1 && 2,         2,         "OP-020: 1 && 2 returns last");
assertEq(0 && 2,         0,         "OP-020: 0 && 2 returns first falsy");
assertEq("a" && "b",    "b",        "OP-020: truthy && truthy returns last");
assertEq(null && "b",   null,       "OP-020: null && 'b' returns null");
// short-circuit: right side not evaluated if left is falsy
var sideEffect = false;
null && (sideEffect = true);
assert(!sideEffect, "OP-020: && short-circuits on falsy left");

// OP-021: || OR — short-circuit, returns first truthy or last value
assertEq(1 || 2,          1,         "OP-021: 1 || 2 returns first truthy");
assertEq(0 || 2,          2,         "OP-021: 0 || 2 returns right");
assertEq(false || null,   null,      "OP-021: both falsy returns last");
assertEq("a" || "b",      "a",       "OP-021: truthy || x returns left");
// short-circuit
var se2 = false;
"truthy" || (se2 = true);
assert(!se2, "OP-021: || short-circuits on truthy left");

// OP-022: ! NOT
assertEq(!true,     false, "OP-022: !true === false");
assertEq(!false,    true,  "OP-022: !false === true");
assertEq(!0,        true,  "OP-022: !0 === true");
assertEq(!1,        false, "OP-022: !1 === false");
assertEq(!"",       true,  "OP-022: !'' === true");
assertEq(!"a",      false, "OP-022: !'a' === false");
assertEq(!!0,       false, "OP-022: !!0 === false (ToBoolean)");
assertEq(!!"x",     true,  "OP-022: !!'x' === true (ToBoolean)");

// OP-023: ?? nullish coalescing
assertEq(null ?? "default",      "default", "OP-023: null ?? x returns x");
assertEq(undefined ?? "default", "default", "OP-023: undefined ?? x returns x");
assertEq(0 ?? "default",         0,         "OP-023: 0 ?? x returns 0 (not null/undefined)");
assertEq("" ?? "default",        "",        "OP-023: '' ?? x returns '' (not null/undefined)");
assertEq(false ?? "default",     false,     "OP-023: false ?? x returns false");
assertEq("val" ?? "default",     "val",     "OP-023: 'val' ?? x returns 'val'");

__jacDone();
