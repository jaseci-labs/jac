// VARIABLE_COMPREHENSIVE_TEST_PLAN §1 — identifiers; §9 partial (VARP-U-001)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_identifiers.js");
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

// VARP-I-001
(function () {
    var Früh = "upper";
    var früh = "lower";
    assertEq(Früh, "upper", "VARP-I-001: Früh binding");
    assertEq(früh, "lower", "VARP-I-001: früh distinct from Früh");
}());

// VARP-I-002
(function () {
    var letterName = 1;
    var _name = 2;
    var $credit = 3;
    assertEq(letterName + _name + $credit, 6, "VARP-I-002: valid ASCII identifier starts");
    assertSyntaxError("function f(){ var 1bad = 1; }", "VARP-I-002: digit-first name SyntaxError");
}());

// VARP-I-003
(function () {
    var å = 10;
    var ü = 20;
    assertEq(å + ü, 30, "VARP-I-003: Unicode letters in identifiers");
}());

// VARP-I-004 — Unicode escape in identifier (lexical grammar)
(function () {
    var \u00E5 = 5;
    assertEq(\u00E5, 5, "VARP-I-004: \\u escape in identifier");
}());

// VARP-I-005
assertSyntaxError("function f(){ let if = 1; }", "VARP-I-005: reserved word if as binding");

// VARP-I-006 — `let` as name: sloppy OK, strict reserved (MDN caution)
assertEq(new Function("var let = 2; return let;")(), 2, "VARP-I-006: sloppy var let allowed");
assertSyntaxError("'use strict'; var let = 1;", "VARP-I-006: strict mode rejects var let");

// VARP-U-001
assertEq(typeof varpUndeclaredXyzAbc, "undefined", "VARP-U-001: typeof undeclared is undefined");

__jacDone();
