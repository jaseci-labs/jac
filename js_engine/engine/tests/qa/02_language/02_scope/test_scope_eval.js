// SCOPE_COMPREHENSIVE_TEST_PLAN §12 — direct vs indirect eval scope
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_eval.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }
function assertSyntaxError(src, msg) {
    try {
        new Function(src);
        assert(false, msg + " (expected SyntaxError)");
    } catch (ex) {
        assert(ex instanceof SyntaxError, msg + " (got " + ex + ")");
    }
}

// SCP-EV-001 — non-strict direct eval: var visible in enclosing function
(function () {
    eval("var scpEv1Local = 41;");
    assertEq(scpEv1Local, 41, "SCP-EV-001: direct eval var in caller scope");
}());

// SCP-EV-002 — indirect eval: no caller locals
(function () {
    var scpEv2x = 99;
    assertThrows(function () {
        (0, eval)("scpEv2x");
    }, ReferenceError, "SCP-EV-002: indirect eval cannot read caller var");
}());

// SCP-EV-003 — strict direct eval: var does not bind in enclosing function
(function () {
    "use strict";
    eval("var scpEv3Inner = 1;");
    assertEq(typeof scpEv3Inner, "undefined", "SCP-EV-003: strict eval var not in outer scope");
}());

// SCP-EV-004 — strict caller, indirect eval still creates global `var` (separate script; MDN)
(function () {
    "use strict";
    (0, eval)("var scpEv4GlobalMark = 77;");
    assertEq(globalThis.scpEv4GlobalMark, 77, "SCP-EV-004: indirect eval binds on global");
    try { delete globalThis.scpEv4GlobalMark; } catch (e) { /* ignore */ }
}());

// SCP-EV-005
assertSyntaxError("'use strict'; let eval = 1;", "SCP-EV-005: strict cannot bind eval");

__jacDone();
