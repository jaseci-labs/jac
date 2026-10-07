// SCOPE_COMPREHENSIVE_TEST_PLAN §11 — default parameter scope vs function body
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_parameters.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// SCP-P-001 body not visible in default initializer
assertThrows(function () {
    (function (a = scpP1Body) {
        var scpP1Body = 1;
        return a;
    }());
}, ReferenceError, "SCP-P-001: default cannot see body var");

assertThrows(function () {
    (function (a = scpP1go()) {
        function scpP1go() { return 1; }
        return a;
    }());
}, ReferenceError, "SCP-P-001: default cannot see body function");

// SCP-P-002 earlier param in later default
(function () {
    function f(scpPa, scpPb = scpPa + 1) {
        return scpPb;
    }
    assertEq(f(10), 11, "SCP-P-002: later default uses earlier param");
}());

// SCP-P-003 MDN — default closure sees parameter `a`, not body `var a`
(function () {
    function scpP3f(a, b = function () { return a; }) {
        var a = 1;
        return b();
    }
    assertEq(scpP3f(), undefined, "SCP-P-003: f() default sees param a (undefined)");
    assertEq(scpP3f(5), 5, "SCP-P-003: f(5) default sees param a");
}());

// SCP-P-004 — arrow has no own `arguments`; resolves from enclosing function (MDN)
assertEq(
    (function (x) { return () => arguments[0]; })(5)(),
    5,
    "SCP-P-004: arrow inherits enclosing arguments, not own binding"
);

__jacDone();
