// CLO-001 through CLO-020: Closures and scope (incl. per-iteration loop-body lexicals)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/09_closures/test_closures.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// CLO-001: basic closure — captures outer variable after return
function makeAdder(x) {
    return function(y) { return x + y; };
}
var add5 = makeAdder(5);
assertEq(add5(3), 8,  "CLO-001: closure captures outer var");
assertEq(add5(10), 15,"CLO-001: reusable closure");

// CLO-002: mutation — inner modifies captured var, visible to siblings
function makeCounter() {
    var count = 0;
    return {
        inc: function() { count++; },
        get: function() { return count; }
    };
}
var ctr = makeCounter();
ctr.inc(); ctr.inc(); ctr.inc();
assertEq(ctr.get(), 3, "CLO-002: sibling closures share captured var");

// CLO-003: loop + var — classic bug: all closures share same var binding
var varFns = [];
for (var vi = 0; vi < 3; vi++) {
    varFns.push(function() { return vi; });
}
// After loop, vi === 3; all closures return 3
assertEq(varFns[0](), 3, "CLO-003: var loop closures share final value (0)");
assertEq(varFns[1](), 3, "CLO-003: var loop closures share final value (1)");
assertEq(varFns[2](), 3, "CLO-003: var loop closures share final value (2)");

// CLO-004: loop + let — fresh binding per iteration
var letFns = [];
for (let li = 0; li < 3; li++) {
    letFns.push(function() { return li; });
}
assertEq(letFns[0](), 0, "CLO-004: let loop gives fresh binding (0)");
assertEq(letFns[1](), 1, "CLO-004: let loop gives fresh binding (1)");
assertEq(letFns[2](), 2, "CLO-004: let loop gives fresh binding (2)");

// CLO-005: multi-level nesting
function outer() {
    var a = 1;
    return function middle() {
        var b = 2;
        return function inner() {
            return a + b;
        };
    };
}
assertEq(outer()()(), 3, "CLO-005: multi-level closure captures at each level");

// CLO-006: closure over function parameters
function multiplier(factor) {
    return function(n) { return n * factor; };
}
var triple = multiplier(3);
var double = multiplier(2);
assertEq(triple(7), 21, "CLO-006: closure over parameter (triple)");
assertEq(double(7), 14, "CLO-006: closure over parameter (double)");

// CLO-007: IIFE scope — private variable pattern
var module = (function() {
    var private = 0;
    return {
        inc: function() { private++; },
        val: function() { return private; }
    };
})();
module.inc(); module.inc();
assertEq(module.val(), 2,          "CLO-007: IIFE private variable");
assertEq(typeof private, "undefined", "CLO-007: private not accessible outside");

// CLO-008: closure + this — regular function loses this, arrow preserves
function Widget(name) {
    this.name = name;
    this.getNameRegular = function() {
        var inner = function() { return this; };
        return inner(); // 'this' inside inner is globalThis (or undefined strict)
    };
    this.getNameArrow = function() {
        var inner = () => this.name;
        return inner();
    };
}
var w = new Widget("button");
assertEq(w.getNameArrow(), "button", "CLO-008: arrow closure preserves this");

// CLO-009: counter factory — inc/dec/get
function counterFactory(init) {
    var n = init;
    return {
        inc: function() { n++; },
        dec: function() { n--; },
        get: function() { return n; },
        reset: function() { n = init; }
    };
}
var cf = counterFactory(10);
cf.inc(); cf.inc(); cf.dec();
assertEq(cf.get(), 11, "CLO-009: counter factory inc/dec");
cf.reset();
assertEq(cf.get(), 10, "CLO-009: counter factory reset");

// CLO-010: for-of + let/const — fresh binding per iteration (CLONE_CELL fix)
var ofFns = [];
for (const x of [10, 20, 30]) {
    ofFns.push(function() { return x; });
}
assertEq(ofFns[0](), 10, "CLO-010: for-of const captures iteration value (0)");
assertEq(ofFns[1](), 20, "CLO-010: for-of const captures iteration value (1)");
assertEq(ofFns[2](), 30, "CLO-010: for-of const captures iteration value (2)");

// CLO-011: for-in + let — fresh binding per iteration
var inFns = [];
var inObj = { a: 1, b: 2, c: 3 };
for (let k in inObj) {
    inFns.push(function() { return k; });
}
assertEq(inFns[0](), "a", "CLO-011: for-in let captures iteration key (0)");
assertEq(inFns[1](), "b", "CLO-011: for-in let captures iteration key (1)");
assertEq(inFns[2](), "c", "CLO-011: for-in let captures iteration key (2)");

// CLO-012: for-of + array destructuring — each destructured slot gets a fresh cell
var destrFns = [];
for (const [name, val] of [["a", 1], ["b", 2], ["c", 3]]) {
    destrFns.push(function() { return name + "=" + val; });
}
assertEq(destrFns[0](), "a=1", "CLO-012: for-of destructuring captures per-iteration (0)");
assertEq(destrFns[1](), "b=2", "CLO-012: for-of destructuring captures per-iteration (1)");
assertEq(destrFns[2](), "c=3", "CLO-012: for-of destructuring captures per-iteration (2)");

// ─────────────────────────────────────────────────────────────────────────────
// CLO-013..019: a let/const declared in the loop BODY (not the loop head) is a
// fresh per-iteration binding — a closure made in iteration N must capture
// iteration N's value, not the last one. Distinct from CLO-004 (head binding).
// Regression: loop-body lexicals previously aliased the final iteration's cell.
// ─────────────────────────────────────────────────────────────────────────────

// CLO-013: for-of, body `const`
var b013 = [];
for (const p of ["A", "B", "C"]) { const c = p + "!"; b013.push(function () { return c; }); }
assertEq(b013.map(function (f) { return f(); }).join(","), "A!,B!,C!",
    "CLO-013: for-of body const is per-iteration");

// CLO-014: C-style for(;;), body `let`
var b014 = [];
for (let i = 0; i < 3; i++) { let v = i * 10; b014.push(function () { return v; }); }
assertEq(b014.map(function (f) { return f(); }).join(","), "0,10,20",
    "CLO-014: for(;;) body let is per-iteration");

// CLO-015: while, body `let`
var b015 = [], k = 0;
while (k < 3) { let w = k * 100; b015.push(function () { return w; }); k++; }
assertEq(b015.map(function (f) { return f(); }).join(","), "0,100,200",
    "CLO-015: while body let is per-iteration");

// CLO-016: do-while, body `const`
var b016 = [], d = 0;
do { const q = "n" + d; b016.push(function () { return q; }); d++; } while (d < 3);
assertEq(b016.map(function (f) { return f(); }).join(","), "n0,n1,n2",
    "CLO-016: do-while body const is per-iteration");

// CLO-017: for-in, body `const` (keys of an ordered object)
var b017 = [];
for (const key in { x: 0, y: 0, z: 0 }) { const kk = key.toUpperCase(); b017.push(function () { return kk; }); }
assertEq(b017.map(function (f) { return f(); }).join(","), "X,Y,Z",
    "CLO-017: for-in body const is per-iteration");

// CLO-018: multiple body lexicals + a nested block, all per-iteration
var b018 = [];
for (const n of [1, 2, 3]) {
    const a = n;
    let b = n * n;
    { const inner = a + b; b018.push(function () { return inner; }); }
}
assertEq(b018.map(function (f) { return f(); }).join(","), "2,6,12",
    "CLO-018: multiple body lexicals + nested block are per-iteration");

// CLO-019: body lexical and head binding stay independent; mutation of the
// body `let` after capture is observed (closure holds the cell, not a snapshot).
var b019get = [], b019inc = [];
for (let i = 0; i < 3; i++) {
    let acc = i;
    b019get.push(function () { return acc; });
    b019inc.push(function () { acc += 100; });
}
b019inc[1](); // bump iteration 1's binding only
assertEq(b019get.map(function (f) { return f(); }).join(","), "0,101,2",
    "CLO-019: body let cell is captured (mutation visible, isolated per iteration)");

// CLO-020: TDZ still enforced for a body `const` used before its declaration
// within the same iteration (the per-iteration fresh cell must start in TDZ,
// not silently read undefined or a prior iteration's value).
var b020threw = false;
for (const _ of [0]) {
    try { void useBeforeDecl; } catch (e) { b020threw = (e instanceof ReferenceError); }
    const useBeforeDecl = 1;
    void useBeforeDecl;
}
assertEq(b020threw, true, "CLO-020: body const TDZ enforced within the iteration");

__jacDone();
