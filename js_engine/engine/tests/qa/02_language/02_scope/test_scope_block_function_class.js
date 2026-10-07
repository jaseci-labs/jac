// SCOPE_COMPREHENSIVE_TEST_PLAN §5, §6, §7 — block, strict function, function decl, class TDZ
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_block_function_class.js");
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
function assertThrows(fn, Err, msg) {
    try { fn(); assert(false, msg + " (no throw)"); }
    catch (ex) { assert(ex instanceof Err, msg + " (wrong: " + ex + ")"); }
}

// SCP-B-001
(function () {
    var scpB1 = 1;
    {
        var scpB1 = 2;
    }
    assertEq(scpB1, 2, "SCP-B-001: var in block mutates outer");
}());

// SCP-B-002
(function () {
    {
        let scpB2 = 2;
        assertEq(scpB2, 2, "SCP-B-002: let in block");
    }
    assertEq(typeof scpB2, "undefined", "SCP-B-002: let not after block");
}());

// SCP-B-003 strict function in block
(function () {
    "use strict";
    {
        assertEq(typeof scpB3foo, "function", "SCP-B-003: block function hoisted inside block");
        scpB3foo();
        function scpB3foo() {}
    }
    assertEq(typeof scpB3foo, "undefined", "SCP-B-003: block function not on outer scope");
    assertEq("scpB3foo" in globalThis, false, "SCP-B-003: not globalThis");
}());

// SCP-B-005 empty block
(function () {
    {};
    { let scpB5 = 1; assertEq(scpB5, 1, "SCP-B-005: compound block"); }
}());

// SCP-FN-001 hoisted call
(function () {
    assertEq(scpFn1(), 99, "SCP-FN-001: call before declaration");
    function scpFn1() { return 99; }
}());

// SCP-FN-002 function expression not hoisted as function
(function () {
    var threw = false;
    try {
        scpFn2Expr();
    } catch (e) {
        threw = e instanceof TypeError;
    }
    assert(threw, "SCP-FN-002: var FE not callable before assignment");
    var scpFn2Expr = function () { return 1; };
}());

// SCP-FN-003 — direct eval adds hoisted function to enclosing var scope (Node: module scope, not always globalThis)
eval("function scpFn3Glob() { return 3; }");
assertEq(typeof scpFn3Glob, "function", "SCP-FN-003: eval function decl visible in enclosing scope");
assertEq(scpFn3Glob(), 3, "SCP-FN-003: callable");

// SCP-FN-004 inner function same name as param
(function (scpFn4a) {
    function scpFn4a() { return "fn"; }
    assertEq(typeof scpFn4a, "function", "SCP-FN-004: inner function shadows param name");
}(1));

assertSyntaxError(
    "\"use strict\"; { function scpDup() {} function scpDup() {} }",
    "SCP-FN-006: duplicate block functions strict"
);

// SCP-CL-001 class TDZ
assertThrows(function () {
    (function () {
        const c = new ScpCl1();
        class ScpCl1 {}
        return c;
    }());
}, ReferenceError, "SCP-CL-001: class before declaration line");

// SCP-CL-002 class expression vs binding
(function () {
    var ScpCE = class { m() { return 4; } };
    assertEq(new ScpCE().m(), 4, "SCP-CL-002: class expression assigned to var");
}());

__jacDone();
