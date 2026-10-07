// VARIABLE_COMPREHENSIVE_TEST_PLAN §4 — var hoisting, binding lists, implicit global
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_var.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// VARP-V-001
(function () {
    assertEq(typeof varpV1, "undefined", "VARP-V-001: var before decl typeof undefined");
    var varpV1 = 3;
    assertEq(varpV1, 3, "VARP-V-001: after assignment");
}());

// VARP-V-002 — Grammar hoisting example shape
(function () {
    var log = [];
    (function () {
        log.push(typeof varpV2);
        var varpV2 = "local value";
        log.push(varpV2);
    }());
    assertEq(log[0], "undefined", "VARP-V-002: inner var undefined before line");
    assertEq(log[1], "local value", "VARP-V-002: then assigned");
}());

// VARP-V-003
(function () {
    var varpV3 = 1;
    var varpV3 = 2;
    assertEq(varpV3, 2, "VARP-V-003: redeclare with initializer");
    var varpV3;
    assertEq(varpV3, 2, "VARP-V-003: bare redeclare keeps value");
}());

// VARP-V-004
(function () {
    var varpV4x = varpV4y, varpV4y = "A";
    assertEq(varpV4x, undefined, "VARP-V-004: x from y before y initialized");
    assertEq(varpV4y, "A", "VARP-V-004: y is A");
}());

// VARP-V-005
(function () {
    var saved = globalThis.varpV5y;
    (function () {
        var varpV5x = varpV5y = 1;
        assertEq(varpV5x, 1, "VARP-V-005: x local");
    }());
    assertEq(globalThis.varpV5y, 1, "VARP-V-005: sloppy creates global y");
    globalThis.varpV5y = saved;
}());

assertThrows(function () {
    "use strict";
    (function () {
        var varpV5sx = varpV5sy = 1;
        return varpV5sx;
    }());
}, ReferenceError, "VARP-V-005: strict unqualified assignment throws");

// VARP-V-006 — implicit global sloppy vs strict
(function () {
    var prev = globalThis.varpV6Implicit;
    new Function("function f(){ varpV6Implicit = 99; } f();")();
    assertEq(globalThis.varpV6Implicit, 99, "VARP-V-006: sloppy assignment creates global");
    globalThis.varpV6Implicit = prev;
}());

assertThrows(function () {
    "use strict";
    (function () {
        varpV6Strict = 1;
    }());
}, ReferenceError, "VARP-V-006: strict undeclared assign in function");

__jacDone();
