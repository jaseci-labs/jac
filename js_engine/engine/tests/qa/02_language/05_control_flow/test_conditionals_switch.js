// CONDITIONALS_COMPREHENSIVE_TEST_PLAN §4 — CND-S-*
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_conditionals_switch.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// --- CND-S-001: === matching; first matching case
(function () {
    assertEq(1 === "1", false, "CND-S-001: sanity !== strict");
    var r = "";
    switch ("1") {
        case 1: r = "num"; break;
        case "1": r = "str"; break;
    }
    assertEq(r, "str", "CND-S-001: string case matches string discriminant");
})();

// --- CND-S-002: break exits; fall-through without break runs following cases
(function () {
    var acc = [];
    switch (1) {
        case 1: acc.push("a");
        case 2: acc.push("b"); break;
        case 3: acc.push("c");
    }
    assertEq(acc.join(","), "a,b", "CND-S-002: fall-through then break");
})();

// --- CND-S-003: default not last — fall-through into following case (foo === 5 style)
(function () {
    var foo = 5;
    var out = -1;
    switch (foo) {
        case 2:
            out = 2;
            break;
        default:
            out = -1;
        case 1:
            out = 1;
    }
    assertEq(out, 1, "CND-S-003: default then fall into case 1");
})();

// --- CND-S-004: duplicate default is SyntaxError
assertThrows(
    function () { new Function("switch (x) { default: break; default: break; }"); },
    SyntaxError,
    "CND-S-004: two default clauses"
);

// --- CND-S-005: case expressions evaluated only until match (use tags, not console)
(function () {
    var order = [];
    function tag(n, ret) { order.push(n); return ret; }
    switch (tag(0, undefined)) {
        case tag(1, 1):
            break;
        case tag(2, undefined):
            break;
    }
    assertEq(order.join(","), "0,1,2", "CND-S-005: evaluate until matching case");
    order = [];
    switch (undefined) {
        case tag(3, undefined):
            break;
    }
    assertEq(order.join(","), "3", "CND-S-005: first case matches immediately");
})();

// --- CND-S-006: multiple case labels, one body
(function () {
    function g(x) {
        switch (x) {
            case 1:
            case 2:
                return "low";
            default:
                return "other";
        }
    }
    assertEq(g(1), "low", "CND-S-006: case 1");
    assertEq(g(2), "low", "CND-S-006: case 2");
})();

// --- CND-S-007: return exits switch; continue in loop + switch
(function () {
    function f(x) {
        switch (x) {
            case 1: return "one";
            case 2: return "two";
            default: return "def";
        }
    }
    assertEq(f(2), "two", "CND-S-007: return from switch");
    var continued = false;
    for (var i = 0; i < 2; i++) {
        switch (i) {
            case 0: continue;
            case 1: continued = true; break;
        }
    }
    assertEq(continued, true, "CND-S-007: continue from switch in for");
})();

// --- CND-S-008: duplicate lexical in switch without block — SyntaxError; blocks fix
assertThrows(
    function () { new Function("switch (0) { case 0: let x = 1; break; case 1: let x = 2; }"); },
    SyntaxError,
    "CND-S-008: duplicate let in same switch"
);
(function () {
    var ok = 0;
    switch (1) {
        case 0: {
            const x = 1;
            ok += x;
            break;
        }
        case 1: {
            const x = 2;
            ok += x;
            break;
        }
    }
    assertEq(ok, 2, "CND-S-008: block per case allows duplicate names");
})();

// --- CND-S-009: switch (true) pattern
(function () {
    var n = 15;
    var bucket = "";
    switch (true) {
        case n < 0: bucket = "neg"; break;
        case n < 10: bucket = "small"; break;
        case n < 20: bucket = "med"; break;
        default: bucket = "large";
    }
    assertEq(bucket, "med", "CND-S-009: switch(true) range");
})();

// --- CND-S-010: intentional multi-case fall-through
(function () {
    function animalSound(animal) {
        var sound = "";
        switch (animal) {
            case "dog":
            case "wolf":
                sound = "woof";
                break;
            case "cat":
                sound = "meow";
                break;
            default:
                sound = "silence";
        }
        return sound;
    }
    assertEq(animalSound("dog"), "woof", "CND-S-010: dog");
    assertEq(animalSound("wolf"), "woof", "CND-S-010: wolf shares dog");
})();

// ─────────────────────────────────────────────────────────────────────────────
// CND-S-011..014: a `switch` whose default / no-match path runs must be
// stack-neutral — it must POP the discriminant. Regression: the no-match POP was
// dead code (emitted after the unconditional jump), so the discriminant leaked
// onto the operand stack. Harmless around a classic `for` (local counter), but a
// `for-of`/`for-in` keeps its iterator on the operand stack across the body, so
// the stray value desynced it and the loop aborted after ONE iteration. (This is
// what broke `vite build` on js_engine: a switch-with-default inside a for-of.)
// ─────────────────────────────────────────────────────────────────────────────

// CND-S-011: for-of with a switch that hits `default` every iteration
(function () {
    var count = 0;
    for (const x of [1, 2, 3]) {
        switch (x) { case 999: break; default: break; }
        count++;
    }
    assertEq(count, 3, "CND-S-011: for-of body switch(default) is stack-neutral");
})();

// CND-S-012: for-in with a switch that never matches (no default at all)
(function () {
    var keys = [];
    for (const k in { a: 1, b: 2, c: 3 }) {
        switch (k) { case "zzz": break; }  // no default, no match → no-match path
        keys.push(k);
    }
    assertEq(keys.join(","), "a,b,c", "CND-S-012: for-in body switch(no-match) is stack-neutral");
})();

// CND-S-013: default path still selects the default body AND collects values
// (stack balance must not break the switch's own control flow / fall-through).
(function () {
    var out = [];
    for (const x of ["p", "q", "r"]) {
        switch (x) {
            case "q": out.push("Q"); break;
            default:  out.push("D:" + x); break;
        }
    }
    assertEq(out.join(","), "D:p,Q,D:r", "CND-S-013: default body + matched case both run across for-of");
})();

// CND-S-014: nested for-of, each with a defaulting switch — both loops complete.
(function () {
    var n = 0;
    for (const i of [0, 1]) {
        for (const j of [0, 1, 2]) {
            switch (i + j) { case 100: break; default: break; }
            n++;
        }
    }
    assertEq(n, 6, "CND-S-014: nested for-of with defaulting switch completes fully");
})();

__jacDone();
