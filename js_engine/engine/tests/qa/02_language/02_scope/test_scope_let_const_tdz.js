// SCOPE_COMPREHENSIVE_TEST_PLAN §3, §4 — let, const, TDZ, shadowing, destructuring
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_let_const_tdz.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// SCP-L-001 — try/catch/finally blocks scope let
(function () {
    try {
        let scpL1t = 1;
        assertEq(scpL1t, 1, "SCP-L-001: let in try");
    } catch (e) {}
    assertEq(typeof scpL1t, "undefined", "SCP-L-001: let not visible after try");
}());

// SCP-L-002 shadowing
(function () {
    let scpL2 = "outer";
    {
        let scpL2 = "inner";
        assertEq(scpL2, "inner", "SCP-L-002: inner shadows");
    }
    assertEq(scpL2, "outer", "SCP-L-002: outer unchanged");
}());

// SCP-L-003 TDZ + typeof throws; var contrast
assertThrows(function () {
    (function () {
        typeof scpL3;
        let scpL3 = 1;
    }());
}, ReferenceError, "SCP-L-003: typeof let in TDZ throws");

(function () {
    assertEq(typeof scpL3v, "undefined", "SCP-L-003: typeof var before decl ok");
    var scpL3v = 1;
}());

// SCP-L-004 — function created in TDZ, called after init
(function () {
    var out;
    {
        const f = function () { return scpL4; };
        let scpL4 = 40;
        out = f();
    }
    assertEq(out, 40, "SCP-L-004: call after TDZ ends is ok");
}());

// SCP-L-005 inner let self-ref in TDZ
assertThrows(function () {
    (function () {
        if (true) {
            let scpL5 = scpL5 + 1;
        }
    }());
}, ReferenceError, "SCP-L-005: let self-ref in initializer TDZ");

// SCP-L-006 for-of header TDZ (MDN go example shape)
assertThrows(function () {
    (function go(scpL6n) {
        for (let scpL6n of scpL6n.a) {}
    }({ a: [1, 2, 3] }));
}, ReferenceError, "SCP-L-006: let in for-of header cannot read outer same name");

// SCP-L-013 — inner const taints block (Hoisting glossary)
assertThrows(function () {
    (function () {
        const scpL13 = 1;
        {
            assertEq(scpL13, 1, "SCP-L-013: unreachable if inner shadows whole block");
            const scpL13 = 2;
        }
    }());
}, ReferenceError, "SCP-L-013: inner const makes outer name inaccessible in block");

// SCP-L-014 destructuring let binding list order
(function () {
    let scpL14a = 1, [scpL14b, scpL14c] = [scpL14a, scpL14a + 1];
    assertEq(scpL14b, 1, "SCP-L-014: later pattern sees earlier binding");
    assertEq(scpL14c, 2, "SCP-L-014: second element");
}());

// SCP-C-001 TDZ for const
assertThrows(function () {
    (function () {
        assertEq(scpC1, scpC1);
        const scpC1 = 1;
    }());
}, ReferenceError, "SCP-C-001: const TDZ ReferenceError");

// SCP-C-003 reassignment
assertThrows(function () {
    (function () {
        const scpC3 = 1;
        scpC3 = 2;
    }());
}, TypeError, "SCP-C-003: const reassignment TypeError");

// SCP-C-004 mutate vs reassign
(function () {
    const scpC4 = { x: 1 };
    scpC4.x = 2;
    assertEq(scpC4.x, 2, "SCP-C-004: object property mutable");
    var threw = false;
    try { scpC4 = {}; } catch (e) { threw = e instanceof TypeError; }
    assert(threw, "SCP-C-004: reassign const object TypeError");
}());

// SCP-C-005 inner block const same name
(function () {
    const scpC5 = 1;
    {
        const scpC5 = 2;
        assertEq(scpC5, 2, "SCP-C-005: inner const");
    }
    assertEq(scpC5, 1, "SCP-C-005: outer const");
}());

__jacDone();
