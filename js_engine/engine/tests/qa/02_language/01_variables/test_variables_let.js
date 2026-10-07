// VARIABLE_COMPREHENSIVE_TEST_PLAN §5 — let TDZ, syntax restrictions
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_let.js");
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

// VARP-L-001 — typeof in TDZ throws
assertThrows(function () {
    (function () {
        typeof varpL1;
        let varpL1 = 1;
    }());
}, ReferenceError, "VARP-L-001: typeof let in TDZ throws");

// VARP-L-002 duplicate let
assertSyntaxError("function f(){ let a; let a; }", "VARP-L-002: duplicate let");

// VARP-L-003
assertSyntaxError("function f(){ if (true) let varpL3 = 1; }", "VARP-L-003: let as single if substatement");

// VARP-L-004 — comma list + destructuring on let
(function () {
    let varpL4a = 1, { varpL4b } = { varpL4b: 2 }, [varpL4c] = [3];
    assertEq(varpL4a + varpL4b + varpL4c, 6, "VARP-L-004: let list with object and array patterns");
}());

__jacDone();
