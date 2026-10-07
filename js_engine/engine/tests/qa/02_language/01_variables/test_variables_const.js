// VARIABLE_COMPREHENSIVE_TEST_PLAN §6 — const binding vs mutation, Grammar conflicts
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_const.js");
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

// VARP-C-001
(function () {
    var threw = false;
    try {
        (function () {
            const varpC1 = 1;
            varpC1 = 2;
        }());
    } catch (e) {
        threw = e instanceof TypeError;
    }
    assert(threw, "VARP-C-001: const reassignment TypeError");
}());

// VARP-C-002 — Grammar example: function f then const f
assertSyntaxError("function f(){} const f = 5;", "VARP-C-002: const same name as function in scope");

// VARP-C-003 — Grammar: inner const g + var g
assertSyntaxError("function outer(){ function f(){ const g = 5; var g; } }", "VARP-C-003: const g then var g same function");

// VARP-C-004
(function () {
    const MY_OBJECT = { key: "value" };
    MY_OBJECT.key = "otherValue";
    assertEq(MY_OBJECT.key, "otherValue", "VARP-C-004: mutate const object property");
}());

// VARP-C-005
(function () {
    const MY_ARRAY = ["HTML", "CSS"];
    MY_ARRAY.push("JAVASCRIPT");
    assertEq(MY_ARRAY.length, 3, "VARP-C-005: const array push");
}());

// VARP-C-006 — inner block const shadows outer; inner var in same block as outer const is error (MDN MY_FAV)
(function () {
    const MY_FAV = 7;
    if (MY_FAV === 7) {
        const MY_FAV = 20;
        assertEq(MY_FAV, 20, "VARP-C-006: inner block const");
    }
    assertEq(MY_FAV, 7, "VARP-C-006: outer const unchanged");
}());

assertSyntaxError(
    "function f(){ const MY_FAV = 7; if (MY_FAV === 7) { var MY_FAV = 20; } }",
    "VARP-C-006: var inner merges with outer const SyntaxError"
);

__jacDone();
