// VARIABLE_COMPREHENSIVE_TEST_PLAN §2, §3 — declaration/initialization, dynamic typing
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_declaration_init.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertSyntaxError(src, msg) {
    try {
        new Function(src);
        assert(false, msg + " (expected SyntaxError)");
    } catch (ex) {
        assert(ex instanceof SyntaxError, msg + " (got " + ex + ")");
    }
}

// VARP-D-001
(function () {
    let varpD1;
    assertEq(varpD1, undefined, "VARP-D-001: let without initializer is undefined");
}());

// VARP-D-002
(function () {
    var varpD2;
    assertEq(varpD2, undefined, "VARP-D-002: var without initializer is undefined");
}());

// VARP-D-003
(function () {
    let varpD3a = 42;
    let varpD3b;
    varpD3b = 42;
    assertEq(varpD3a, varpD3b, "VARP-D-003: let with initializer matches split decl+assign");
}());

// VARP-D-004
assertSyntaxError("function f(){ const varpD4; }", "VARP-D-004: const without initializer");

// VARP-D-005
(function () {
    var varpD5a = 1, varpD5b = 2;
    assertEq(varpD5a + varpD5b, 3, "VARP-D-005: var comma list");
    let varpD5c = 3, varpD5d = 4;
    assertEq(varpD5c + varpD5d, 7, "VARP-D-005: let comma list");
    const varpD5e = 5, varpD5f = 6;
    assertEq(varpD5e + varpD5f, 11, "VARP-D-005: const comma list");
}());

// VARP-D-006
(function () {
    let varpD6a = 1, varpD6b = varpD6a + 1;
    assertEq(varpD6b, 2, "VARP-D-006: later binding uses earlier in list");
}());

// VARP-T-001
(function () {
    let answer = 42;
    assertEq(typeof answer, "number", "VARP-T-001: typeof number");
    answer = "Thanks for all the fish!";
    assertEq(typeof answer, "string", "VARP-T-001: typeof after reassignment to string");
}());

// VARP-T-002
(function () {
    var threw = false;
    try {
        (function () {
            const varpT2 = 1;
            varpT2 = "x";
        }());
    } catch (e) {
        threw = e instanceof TypeError;
    }
    assert(threw, "VARP-T-002: const reassignment TypeError");
}());

__jacDone();
