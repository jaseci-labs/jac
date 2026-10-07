// SCOPE_COMPREHENSIVE_TEST_PLAN §10 — for / for-in / for-of / for-await-of scoping
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_for_loops.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// SCP-FO-001 (overlap VAR-005 — explicit SCP id)
for (var scpFo1 = 0; scpFo1 < 2; scpFo1++) {}
assertEq(scpFo1, 2, "SCP-FO-001: var for-loop binding after loop");

// SCP-FO-002
for (let scpFo2 = 0; scpFo2 < 1; scpFo2++) {}
assertEq(typeof scpFo2, "undefined", "SCP-FO-002: let not visible after for");

// SCP-FO-003 fresh binding per iteration
(function () {
    var fns = [];
    for (let scpFo3 = 0; scpFo3 < 3; scpFo3++) {
        fns.push(function () { return scpFo3; });
    }
    assertEq(fns[0](), 0, "SCP-FO-003: closure 0");
    assertEq(fns[2](), 2, "SCP-FO-003: closure 2");
}());

// SCP-FO-004 for-of let
(function () {
    var acc = [];
    for (let scpFo4 of [1, 2]) {
        acc.push(scpFo4);
    }
    assertEq(acc.join(","), "1,2", "SCP-FO-004: for-of let body");
    assertEq(typeof scpFo4, "undefined", "SCP-FO-004: let not after for-of");
}());

// SCP-FO-004 for-in const
(function () {
    var keys = [];
    for (const scpFo4k in { a: 1, b: 2 }) {
        keys.push(scpFo4k);
    }
    assertEq(keys.length, 2, "SCP-FO-004: for-in const");
    assertEq(typeof scpFo4k, "undefined", "SCP-FO-004: const not after for-in");
}());

// SCP-FO-006: a C-style for-head `let` is block-scoped to the loop and must NOT
// collide with a sibling `let`/`const` of the same name declared afterward. The
// for-head binding once consumed the sibling's hoist pre-declaration (false
// SyntaxError "Identifier has already been declared") — fixed by stashing outer
// hoist_predeclared entries around the for-init compile (compile_for).
(function () {
    var sum = 0;
    for (let scpFo6 = 0; scpFo6 < 5; scpFo6++) { sum += scpFo6; }
    let scpFo6 = 99;            // must not throw "already declared"
    assertEq(sum, 10, "SCP-FO-006: for-head let iterates independently");
    assertEq(scpFo6, 99, "SCP-FO-006: sibling let after for-head is a fresh binding");
}());
// SCP-FO-007: two sibling C-style for-loops reusing the same name — legal.
(function () {
    for (let scpFo7 = 0; scpFo7 < 2; scpFo7++) {}
    for (let scpFo7 = 0; scpFo7 < 3; scpFo7++) {}
    assert(true, "SCP-FO-007: sibling for-loops reuse name without error");
}());
// SCP-FO-008: labeled for-head let stays block-scoped; per-iteration capture intact.
(function () {
    scpLbl: for (let scpFo8 = 0; scpFo8 < 3; scpFo8++) { if (scpFo8 === 1) break scpLbl; }
    let scpFo8 = 7;
    assertEq(scpFo8, 7, "SCP-FO-008: labeled for-head let does not leak");
    var fns = [];
    for (let scpFo8b = 0; scpFo8b < 3; scpFo8b++) { fns.push(function () { return scpFo8b; }); }
    let scpFo8b = 42;
    assertEq(fns.map(function (f) { return f(); }).join(","), "0,1,2", "SCP-FO-008: per-iteration capture");
    assertEq(scpFo8b, 42, "SCP-FO-008: sibling after captured loop");
}());

async function runAwait() {
    async function* gen() {
        yield 1;
    }
    for await (let scpFo5 of gen()) {
        assertEq(scpFo5, 1, "SCP-FO-005: for-await let visible in body");
    }
    assertEq(typeof scpFo5, "undefined", "SCP-FO-005: let not after for-await");
}

runAwait().then(function () { __jacDone(); }).catch(function (e) {
    console.error("FAIL: SCP-FO-005 " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
