// VAR-001 through CONST-005: Variable declarations and scoping
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/01_variables/test_variables.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// ── VAR ──────────────────────────────────────────────────────────────────────

// VAR-001: basic declare/assign/multiple/uninitialized
var a = 1, b = 2;
assertEq(a, 1, "VAR-001: declare and assign");
assertEq(b, 2, "VAR-001: multiple declarators");
var c;
assertEq(c, undefined, "VAR-001: uninitialized is undefined");

// VAR-002: hoisting — use before declaration yields undefined (not ReferenceError)
assertEq(typeof hoisted, "undefined", "VAR-002: var hoisting (typeof before decl)");
var hoisted = 42;
assertEq(hoisted, 42, "VAR-002: hoisted var readable after decl");

// VAR-003: function scope — not visible outside function, leaks through blocks
(function() { var inner = "hi"; }());
assertEq(typeof inner, "undefined", "VAR-003: var not visible outside function");

if (true) { var blockVar = "leaked"; }
assertEq(blockVar, "leaked", "VAR-003: var leaks through blocks");

var shadow = "outer";
(function() {
    var shadow = "inner";
    assertEq(shadow, "inner", "VAR-003: var shadows outer inside function");
}());
assertEq(shadow, "outer", "VAR-003: outer var unaffected by inner shadow");

// VAR-004: redeclaration in same scope (no error)
var dup = 1;
var dup = 2;
assertEq(dup, 2, "VAR-004: var redeclaration in same scope ok");

// VAR-005: var in for loop leaks to enclosing scope
for (var i = 0; i < 3; i++) {}
assertEq(i, 3, "VAR-005: var loop variable leaks out");

// ── LET ──────────────────────────────────────────────────────────────────────

// LET-001: block scoping
{
    let blockLet = "inside";
    assertEq(blockLet, "inside", "LET-001: let accessible inside block");
}
assertEq(typeof blockLet, "undefined", "LET-001: let not visible outside block");

// LET-002: TDZ — accessing let before declaration throws ReferenceError
assertThrows(function() {
    (function() {
        var x = tdz_let; // tdz_let not declared yet
        let tdz_let = 1;
        return x;
    }());
}, ReferenceError, "LET-002: accessing let in TDZ throws ReferenceError");

// LET-003: for loop — fresh binding per iteration (closure test)
var fns = [];
for (let li = 0; li < 3; li++) { fns.push(function() { return li; }); }
assertEq(fns[0](), 0, "LET-003: let in for gives fresh binding per iter (0)");
assertEq(fns[1](), 1, "LET-003: let in for gives fresh binding per iter (1)");
assertEq(fns[2](), 2, "LET-003: let in for gives fresh binding per iter (2)");

// LET-005: shadowing — inner block shadows outer, outer unaffected
let ls = "outer";
{
    let ls = "inner";
    assertEq(ls, "inner", "LET-005: inner let shadows outer");
}
assertEq(ls, "outer", "LET-005: outer let unaffected after inner block");

// ── CONST ─────────────────────────────────────────────────────────────────────

// CONST-001: must initialize, reassignment throws TypeError
const cx = 10;
assertEq(cx, 10, "CONST-001: const initialized and readable");
var constReassignThrew = false;
try {
    (function() { const cc = 1; cc = 2; })();
} catch(e) {
    constReassignThrew = true;
}
assert(constReassignThrew, "CONST-001: const reassignment throws");

// CONST-002: block scope + TDZ same as let
{
    const cb = "block";
    assertEq(cb, "block", "CONST-002: const accessible inside block");
}
assertEq(typeof cb, "undefined", "CONST-002: const not visible outside block");

// CONST-003: const with objects/arrays — reference is const, contents mutable
const obj = { x: 1 };
obj.x = 2;
assertEq(obj.x, 2, "CONST-003: const object property mutable");
const arr = [1, 2];
arr.push(3);
assertEq(arr.length, 3, "CONST-003: const array elements mutable");

// CONST-004: const in for-of — fresh binding per iteration
var results = [];
for (const item of [10, 20, 30]) { results.push(item); }
assertEq(results[0], 10, "CONST-004: const in for-of (0)");
assertEq(results[1], 20, "CONST-004: const in for-of (1)");
assertEq(results[2], 30, "CONST-004: const in for-of (2)");

// CONST-004: const in for-in
var forInKeys = [];
for (const k in {a:1, b:2}) { forInKeys.push(k); }
assertEq(forInKeys.length, 2, "CONST-004: const in for-in iterates keys");

__jacDone();
