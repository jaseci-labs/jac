// CONDITIONALS_COMPREHENSIVE_TEST_PLAN §1–3 — CND-T-*, CND-I-*, CND-Q-*
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_conditionals_if_ternary.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// --- CND-T-001: falsy values skip if body
(function () {
    function ranIf(cond) {
        var hit = false;
        if (cond) { hit = true; }
        return hit;
    }
    assertEq(ranIf(false), false, "CND-T-001: false");
    assertEq(ranIf(undefined), false, "CND-T-001: undefined");
    assertEq(ranIf(null), false, "CND-T-001: null");
    assertEq(ranIf(0), false, "CND-T-001: 0");
    assertEq(ranIf(-0), false, "CND-T-001: -0");
    assertEq(ranIf(NaN), false, "CND-T-001: NaN");
    assertEq(ranIf(""), false, "CND-T-001: empty string");
})();

// --- CND-T-002: truthy values run if body
(function () {
    function ranIf(cond) {
        var hit = false;
        if (cond) { hit = true; }
        return hit;
    }
    assertEq(ranIf(1), true, "CND-T-002: non-zero number");
    assertEq(ranIf("x"), true, "CND-T-002: non-empty string");
    assertEq(ranIf({}), true, "CND-T-002: object literal");
    assertEq(ranIf([]), true, "CND-T-002: array literal");
    assertEq(ranIf(Symbol()), true, "CND-T-002: Symbol()");
})();

// --- CND-T-003: new Boolean(false) is truthy in if
(function () {
    var hit = false;
    if (new Boolean(false)) { hit = true; }
    assertEq(hit, true, "CND-T-003: wrapper object truthy");
})();

// --- CND-T-004: ternary uses same truthiness (getFee style)
(function () {
    function getFee(isMember) {
        return isMember ? "$2.00" : "$10.00";
    }
    assertEq(getFee(true), "$2.00", "CND-T-004: member");
    assertEq(getFee(false), "$10.00", "CND-T-004: non-member");
    assertEq(getFee(null), "$10.00", "CND-T-004: null falsy");
})();

// --- CND-I-001: if truthy / else falsy
(function () {
    var a = 0;
    if (1) { a = 1; } else { a = 2; }
    assertEq(a, 1, "CND-I-001: truthy branch");
    var b = 0;
    if (0) { b = 1; } else { b = 2; }
    assertEq(b, 2, "CND-I-001: else branch");
})();

// --- CND-I-002: else if chain — first match only
(function () {
    var r = "";
    if (0) { r = "a"; }
    else if (1) { r = "b"; }
    else if (1) { r = "c"; }
    else { r = "d"; }
    assertEq(r, "b", "CND-I-002: first else-if wins");
})();

// --- CND-I-003: block statements for clauses
(function () {
    var x = 0;
    if (true) {
        x++;
        x++;
    } else {
        x = 100;
    }
    assertEq(x, 2, "CND-I-003: multi-statement block");
})();

// --- CND-I-004: dangling else binds to nearest if (MDN checkValue(1,3))
(function () {
    var out = "";
    function checkValue(a, b) {
        if (a === 1)
            if (b === 2)
                out = "both";
            else
                out = "a1-not-b2";
    }
    checkValue(1, 3);
    assertEq(out, "a1-not-b2", "CND-I-004: dangling else pairs with inner if");
    var fixed = "";
    function checkValueBraced(a, b) {
        if (a === 1) {
            if (b === 2) {
                fixed = "both";
            }
        } else {
            fixed = "outer-else";
        }
    }
    checkValueBraced(1, 3);
    assertEq(fixed, "", "CND-I-004: braced outer if — no else for b!==2");
})();

// --- CND-I-005: empty statement bodies
(function () {
    var x = 0;
    if (true) ;
    else x = 1;
    assertEq(x, 0, "CND-I-005: if empty stmt");
    if (false) x = 2;
    else ;
    assertEq(x, 0, "CND-I-005: else empty stmt");
})();

// --- CND-I-006: assignment as condition — single evaluation
(function () {
    var calls = 0;
    function y() { calls++; return 0; }
    var x;
    if ((x = y())) { assert(false, "CND-I-006: should not take truthy branch"); }
    assertEq(calls, 1, "CND-I-006: rhs evaluated once");
    assertEq(x, 0, "CND-I-006: assignment result");
})();

// --- CND-I-007: nested if/else without blocks (readability / binding)
(function () {
    var v = 0;
    if (1)
        if (0)
            v = 1;
        else
            v = 2;
    assertEq(v, 2, "CND-I-007: inner else with outer truthy");
})();

// --- CND-Q-001: basic ternary
assertEq(true ? "a" : "b", "a", "CND-Q-001: truthy");
assertEq(false ? "a" : "b", "b", "CND-Q-001: falsy");

// --- CND-Q-002: MDN falsy list in ternary
(function () {
    function branch(c) { return c ? "t" : "f"; }
    assertEq(branch(false), "f", "CND-Q-002: false");
    assertEq(branch(null), "f", "CND-Q-002: null");
    assertEq(branch(NaN), "f", "CND-Q-002: NaN");
    assertEq(branch(0), "f", "CND-Q-002: 0");
    assertEq(branch(""), "f", "CND-Q-002: empty string");
    assertEq(branch(undefined), "f", "CND-Q-002: undefined");
})();

// --- CND-Q-003: right-associative chain a ? b : c ? d : e  ===  a ? b : (c ? d : e)
(function () {
    assertEq(false ? 1 : true ? 2 : 3, 2, "CND-Q-003: chain matches if-else-if");
    assertEq(false ? 1 : false ? 2 : 3, 3, "CND-Q-003: final else");
})();

// --- CND-Q-004: only chosen branch evaluated (side effects)
(function () {
    var a = 0, b = 0;
    true ? (a = 1) : (b = 1);
    assertEq(a, 1, "CND-Q-004: truthy took consequent");
    assertEq(b, 0, "CND-Q-004: alternate not evaluated");
    a = b = 0;
    false ? (a = 1) : (b = 1);
    assertEq(a, 0, "CND-Q-004: consequent not evaluated");
    assertEq(b, 1, "CND-Q-004: alternate ran");
})();

// --- CND-Q-005: parentheses clarify mixed ternary
(function () {
    var x = (1 + 2 > 0 ? "yes" : "no");
    assertEq(x, "yes", "CND-Q-005: grouped condition");
})();

__jacDone();
