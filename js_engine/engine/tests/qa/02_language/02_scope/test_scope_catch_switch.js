// SCOPE_COMPREHENSIVE_TEST_PLAN §8, §9 — try/catch/finally, switch + var/let
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_catch_switch.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// SCP-TC-001 catch binding only in catch
(function () {
    var saw = 0;
    try {
        throw 1;
    } catch (scpTc1e) {
        assertEq(scpTc1e, 1, "SCP-TC-001: catch binding visible");
        saw = 1;
    }
    assertEq(saw, 1, "SCP-TC-001: ran catch");
    assertEq(typeof scpTc1e, "undefined", "SCP-TC-001: catch binding not outside");
}());

// SCP-TC-003 catch binding writable
(function () {
    try {
        throw "raw";
    } catch (scpTc3e) {
        scpTc3e = new Error(String(scpTc3e));
        assertEq(scpTc3e instanceof Error, true, "SCP-TC-003: reassigned catch binding");
    }
}());

// SCP-TC-004 optional catch
(function () {
    var ok = false;
    try {
        JSON.parse("{");
    } catch {
        ok = true;
    }
    assert(ok, "SCP-TC-004: optional catch runs");
}());

// SCP-TC-006 let in try not visible in catch
(function () {
    var inCatch = 0;
    try {
        let scpTc6 = 42;
        throw 1;
    } catch (e) {
        inCatch = typeof scpTc6 === "undefined" ? 1 : -1;
    }
    assertEq(inCatch, 1, "SCP-TC-006: try let not in catch scope");
}());

// SCP-SW-001 var in case visible across switch
(function () {
    switch (1) {
        case 1:
            var scpSw1 = 10;
            break;
        default:
            break;
    }
    assertEq(scpSw1, 10, "SCP-SW-001: var in case visible after switch");
}());

// SCP-SW-002 inner blocks allow duplicate let in cases
(function () {
    switch (1) {
        case 0: {
            let scpSw2 = 0;
            assertEq(scpSw2, 0, "SCP-SW-002: case 0 block");
            break;
        }
        case 1: {
            let scpSw2 = 1;
            assertEq(scpSw2, 1, "SCP-SW-002: case 1 block");
            break;
        }
        default:
            break;
    }
}());

__jacDone();
