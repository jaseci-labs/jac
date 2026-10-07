// VARIABLE_COMPREHENSIVE_TEST_PLAN §7 — destructuring variable declarations
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_destructuring_decl.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertDeepEq(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertSyntaxError(src, msg) {
    try {
        new Function(src);
        assert(false, msg + " (expected SyntaxError)");
    } catch (ex) {
        assert(ex instanceof SyntaxError, msg + " (got " + ex + ")");
    }
}

// VARP-X-001
(function () {
    const varpArr = [1, 2, 3];
    const [varpX1a, varpX1b] = varpArr;
    assertEq(varpX1a + varpX1b, 3, "VARP-X-001: array destructuring const");
}());

// VARP-X-002
(function () {
    const [varpX2a, , varpX2b, ...varpX2rest] = [10, 20, 30, 40, 50];
    assertEq(varpX2a, 10, "VARP-X-002: elision");
    assertEq(varpX2b, 30, "VARP-X-002: third element");
    assertDeepEq(varpX2rest, [40, 50], "VARP-X-002: rest");
    const [varpX2d = 99] = [];
    assertEq(varpX2d, 99, "VARP-X-002: default in array pattern");
}());

// VARP-X-003
(function () {
    const varpX3 = { a: 1, b: 2, prop1: 3 };
    const { a, b } = varpX3;
    assertEq(a + b, 3, "VARP-X-003: object shorthand binding a,b");
    const { prop1: varpX3x } = varpX3;
    assertEq(varpX3x, 3, "VARP-X-003: rename prop1 to x");
}());

// VARP-X-004
(function () {
    const { varpX4a = 1, varpX4b = 2 } = {};
    assertEq(varpX4a + varpX4b, 3, "VARP-X-004: object pattern defaults");
}());

// VARP-X-005
(function () {
    const varpKey = "dyn";
    const { [varpKey]: varpX5v } = { dyn: 42 };
    assertEq(varpX5v, 42, "VARP-X-005: computed key in pattern");
}());

// VARP-X-006 — assignment expression needs parens
(function () {
    var varpX6a;
    var varpX6o = { a: 7 };
    ({ a: varpX6a } = varpX6o);
    assertEq(varpX6a, 7, "VARP-X-006: parenthesized object destructuring assign");
}());

// VARP-X-007 — `{a} = obj` at statement start is block, not assignment pattern (SyntaxError / parse failure)
assertSyntaxError("var o={a:1}; {a} = o;", "VARP-X-007: unparenthesized object literal statement");

// VARP-X-008
(function () {
    let varpX8simple = 0, [varpX8e] = [5], { varpX8f } = { varpX8f: 6 };
    assertEq(varpX8simple + varpX8e + varpX8f, 11, "VARP-X-008: let list simple + patterns");
}());

__jacDone();
