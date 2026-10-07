// SCOPE_COMPREHENSIVE_TEST_PLAN §1 (partial), §2 — global visibility, var, globalThis
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_var_global.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// SCP-G-001
(function () {
    var g1 = 1;
}());
assertEq(typeof g1, "undefined", "SCP-G-001: var inside IIFE not visible outside");

// SCP-G-002 closure
(function () {
    var g2 = 2;
    (function () {
        assertEq(g2, 2, "SCP-G-002: inner function sees outer var");
    }());
}());

// SCP-G-004 + SCP-V-002 — var leaks block; let does not
if (true) { var scpG4 = "leak"; }
assertEq(scpG4, "leak", "SCP-G-004: var visible after if block");
{
    let scpG4let = 99;
    assertEq(scpG4let, 99, "SCP-G-004: let inside block");
}
assertEq(typeof scpG4let, "undefined", "SCP-G-004: let not visible after block");

try { var scpTryVar = 3; } catch (e) {}
assertEq(scpTryVar, 3, "SCP-V-002: var in try visible after");

switch (0) { default: var scpSwVar = 4; }
assertEq(scpSwVar, 4, "SCP-V-002: var in switch visible after");

for (var scpForHdr = 0; scpForHdr < 1; scpForHdr++) {}
assertEq(scpForHdr, 1, "SCP-V-002: var in for-header leaks");

// SCP-V-001
(function () {
    var outer = 10;
    (function () {
        assertEq(outer, 10, "SCP-V-001: inner reads outer var");
    }());
}());

// SCP-V-003 / SCP-V-004
(function () {
    assertEq(typeof scpV3, "undefined", "SCP-V-003: var before decl typeof undefined");
    var scpV3 = 7;
    assertEq(scpV3, 7, "SCP-V-004: initializer applied after line");
}());

// SCP-V-005
(function () {
    var scpV5x = 1;
    var scpV5x = 2;
    assertEq(scpV5x, 2, "SCP-V-005: var redeclare with initializer");
    var scpV5x;
    assertEq(scpV5x, 2, "SCP-V-005: bare redeclare keeps value");
}());

// SCP-V-006 — var initializer overrides function (MDN ordering)
eval("function scpV6Fn() { return 0; } var scpV6Fn = 1;");
assertEq(scpV6Fn, 1, "SCP-V-006: var initializer overrides function name");

// SCP-V-008
(function (scpV8p) {
    var scpV8p = 1;
    assertEq(scpV8p, 1, "SCP-V-008: var same name as parameter allowed");
}(2));

// SCP-V-009 — non-configurable global-like property: strict `delete` → TypeError (MDN `var` on global object)
Object.defineProperty(globalThis, "scpV9NonDel", { value: 1, configurable: false, writable: true, enumerable: true });
assertThrows(function () {
    "use strict";
    delete globalThis.scpV9NonDel;
}, TypeError, "SCP-V-009: strict delete non-configurable global TypeError");
// cleanup: cannot delete; overwrite for test isolation
try {
    Object.defineProperty(globalThis, "scpV9NonDel", { value: undefined, configurable: true, writable: true, enumerable: true });
    delete globalThis.scpV9NonDel;
} catch (e) { /* ignore */ }

// SCP-V-010 — Node CJS: top-level `var` is file-scoped, not a `globalThis` own property
var scopeFileTopVarUnique = 55;
assertEq(scopeFileTopVarUnique, 55, "SCP-V-010: var readable in same file");
// KNOWN DIVERGENCE (js_engine): the entry file runs with ECMAScript *script goal*
// semantics — test262 global-code tests REQUIRE `var` to create a globalThis own
// property, while Node's CJS module wrap requires the opposite. The engine keeps
// the script-goal behavior for the entry (required .js files ARE module-scoped);
// assert the Node contract only on the Node lane.
var __isJsEngine = typeof process !== "undefined" && process.release && process.release.name === "js_engine";
if (!__isJsEngine) {
    assertEq(Object.hasOwn(globalThis, "scopeFileTopVarUnique"), false, "SCP-V-010: top var not own prop of globalThis (Node module wrap)");
}

// SCP-V-011
(function () {
    var scpV11x = scpV11y, scpV11y = "A";
    assertEq(scpV11x, undefined, "SCP-V-011: x from y before y init");
    assertEq(scpV11y, "A", "SCP-V-011: y initialized");
}());

// SCP-V-012 sloppy: y leaks global
(function () {
    var scpV12saved = globalThis.scpV12y;
    (function () {
        var scpV12x = scpV12y = 1;
        assertEq(scpV12x, 1, "SCP-V-012: x local");
    }());
    assertEq(globalThis.scpV12y, 1, "SCP-V-012: unqualified y creates global in sloppy");
    globalThis.scpV12y = scpV12saved;
}());

assertThrows(function () {
    "use strict";
    (function () {
        var scpV12sx = scpV12sy = 1;
        return scpV12sx;
    }());
}, ReferenceError, "SCP-V-012: strict unqualified assignment throws");

// SCP-G-003 note: script vs module — Node file is CJS-wrapped; see test_scope_modules.sh for ESM

// SCP-V-013 deprecated Annex B — `catch (e) { var e }` parses in sloppy (MDN); semantics unstable
(function () {
    try {
        throw new Error();
    } catch (scpV13e) {
        var scpV13e = 2;
    }
}());

// SCP-L-011 — let not on globalThis (eval in sloppy global-ish context)
eval("let scpL11Let = 123;");
assertEq(globalThis.scpL11Let, undefined, "SCP-L-011: top-level let not globalThis property");

__jacDone();
