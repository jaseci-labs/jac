// VARIABLE_COMPREHENSIVE_TEST_PLAN §8, §9 — globalThis, typeof / TDZ / strict
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables_global_typeof.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// VARP-G-001
(function () {
    var prev = globalThis.varpG1Mark;
    globalThis.varpG1Mark = 123;
    assertEq(globalThis.varpG1Mark, 123, "VARP-G-001: read/write via globalThis");
    globalThis.varpG1Mark = prev;
}());

// VARP-G-002
assertEq(typeof globalThis, "object", "VARP-G-002: typeof globalThis");
assert(globalThis !== null && globalThis === globalThis, "VARP-G-002: globalThis is global binding");

// VARP-G-003 — top-level let/const in Node module: not own property of globalThis
let varpG3Let = 1;
const varpG3Const = 2;
assertEq(Object.hasOwn(globalThis, "varpG3Let"), false, "VARP-G-003: top let not own prop of globalThis");
assertEq(Object.hasOwn(globalThis, "varpG3Const"), false, "VARP-G-003: top const not own prop of globalThis");

// VARP-U-002 — typeof in TDZ (const same as let)
assertThrows(function () {
    (function () {
        typeof varpU2;
        const varpU2 = 1;
    }());
}, ReferenceError, "VARP-U-002: typeof const in TDZ throws");

// VARP-U-003
assertThrows(function () {
    "use strict";
    varpU3Undeclared = 1;
}, ReferenceError, "VARP-U-003: strict assign to undeclared ReferenceError");

__jacDone();
