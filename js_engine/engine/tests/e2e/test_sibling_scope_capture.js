// test_sibling_scope_capture.js — sibling-scope closure capture correctness
// =========================================================================
// Verifies that arrows/closures created in a block scope capture the variable
// from *their* scope, not from an earlier sibling scope that declared a
// variable with the same name.
//
// Before the fix, MAKE_ARROW scanned parent locals by name and always
// returned the first slot with a matching name.  When two sibling blocks
// both declared `const key`, the second block's arrow captured the stale
// slot from the first block, yielding the wrong (often undefined) value.

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + String(expected));
        console.log("     actual:   " + String(actual));
        _failed = _failed + 1;
    }
}

// ── 1. for...of sibling scopes: second loop captures own key ─────────────
// Both loops declare `item`.  Arrow inside the second loop must see the
// second loop's value, not undefined (first loop ran zero iterations).
var seen1 = [];
for (var item1 of []) {
    // first scope: item1 never assigned (zero iterations)
    seen1.push((function() { return item1; })());
}
for (var item1 of ['A', 'B']) {
    // second scope: same var name, different iterations
    seen1.push((function(x) { return x; })(item1));
}
check(1, "second for-of loop sees own value [0]", seen1[0], 'A');
check(1, "second for-of loop sees own value [1]", seen1[1], 'B');

// ── 2. for...in sibling scopes: second loop captures own key ──────────────
var seen2 = [];
var dummy2 = {};
for (var k2 in dummy2) {
    // first scope: no iterations
    seen2.push(k2);
}
var env2 = { FOO: '1', BAR: '2' };
for (var k2 in env2) {
    // second scope: k2 shadowed — arrow must capture this k2
    seen2.push((function(x) { return x; })(k2));
}
check(2, "sibling for-in loops: collected length", seen2.length, 2);
check(2, "sibling for-in loops: first key", seen2[0], 'FOO');
check(2, "sibling for-in loops: second key", seen2[1], 'BAR');

// ── 3. Array.some arrow captures correct key in second for...in ───────────
// Vite loadEnv pattern: filter env keys by prefix using Array.some + arrow.
var matched3 = [];
var prefixes3 = ['VITE_'];

for (var k3 in {}) {
    // first (empty) block — k3 slot exists but is never populated
    prefixes3.some(function(p) { return k3.startsWith(p); });
}

var env3 = { VITE_API: 'x', NODE_ENV: 'y', VITE_SECRET: 'z' };
for (var k3 in env3) {
    // Before fix: k3 inside arrow captured the first-loop slot (undefined)
    // → k3.startsWith threw TypeError and no keys matched.
    if (prefixes3.some(function(p) { return k3.startsWith(p); })) {
        matched3.push(k3);
    }
}
check(3, "Vite loadEnv pattern: matched count", matched3.length, 2);
check(3, "Vite loadEnv pattern: first match", matched3[0], 'VITE_API');
check(3, "Vite loadEnv pattern: second match", matched3[1], 'VITE_SECRET');

// ── 4. Three sibling for...of loops, all same name ─────────────────────────
var out4 = [];
for (var v4 of []) { out4.push(v4); }         // first: 0 iters
for (var v4 of [10, 20]) {                     // second: 2 iters
    out4.push((function(x) { return x; })(v4));
}
for (var v4 of [30]) {                         // third: 1 iter
    out4.push((function(x) { return x; })(v4));
}
check(4, "three sibling loops [0]", out4[0], 10);
check(4, "three sibling loops [1]", out4[1], 20);
check(4, "three sibling loops [2]", out4[2], 30);

// ── 5. Arrow captures loop var alongside an outer var ─────────────────────
var prefix5 = 'X_';
var matching5 = [];

for (var entry5 of []) { /* first scope empty */ }
for (var entry5 of ['X_ONE', 'Y_TWO', 'X_THREE']) {
    // Arrow closes over both `entry5` (inner) and `prefix5` (outer).
    var fn5 = (function(e, p) { return e.startsWith(p); });
    if (fn5(entry5, prefix5)) { matching5.push(entry5); }
}
check(5, "arrow + outer var: matched count", matching5.length, 2);
check(5, "arrow + outer var: first match", matching5[0], 'X_ONE');
check(5, "arrow + outer var: second match", matching5[1], 'X_THREE');

// ── 6. function expression (not arrow) in second sibling scope ─────────────
var seen6 = [];
for (var n6 of []) { seen6.push(n6); }
for (var n6 of [100, 200, 300]) {
    seen6.push((function double(x) { return x * 2; })(n6));
}
check(6, "function expr in second loop [0]", seen6[0], 200);
check(6, "function expr in second loop [1]", seen6[1], 400);
check(6, "function expr in second loop [2]", seen6[2], 600);

// ── 7. Destructuring in for...of sibling scopes ────────────────────────────
var pairs7 = [];
for (var kv7 of []) { pairs7.push(kv7); }
for (var kv7 of [['a', 1], ['b', 2]]) {
    var key7 = kv7[0];
    var val7 = kv7[1];
    pairs7.push((function(k, v) { return k + '=' + v; })(key7, val7));
}
check(7, "destructured for-of sibling: pair 0", pairs7[0], 'a=1');
check(7, "destructured for-of sibling: pair 1", pairs7[1], 'b=2');

// ── 8. Closure factory in second sibling scope ─────────────────────────────
// Ensures the closed-over value is the per-iteration value, not a stale one.
function makeChecker8(prefix) {
    var fns = [];
    for (var x8 of []) { fns.push(function() { return x8; }); }
    for (var x8 of ['hello', 'world']) {
        (function(capture) { fns.push(function() { return capture; }); })(x8);
    }
    return fns;
}
var fns8 = makeChecker8('_');
check(8, "closure factory from second loop [0]", fns8[0](), 'hello');
check(8, "closure factory from second loop [1]", fns8[1](), 'world');

// ── 9. Mixed for...of / for...in sibling with same iterator var name ───────
var results9 = [];
var obj9 = { p: 1, q: 2 };
for (var key9 of []) {
    // first: for...of, zero iterations
    results9.push(key9);
}
for (var key9 in obj9) {
    // second: for...in, key9 bound to each own property name
    results9.push((function(k) { return k + ':' + obj9[k]; })(key9));
}
check(9, "mixed for-of/for-in sibling: entry 0", results9[0], 'p:1');
check(9, "mixed for-of/for-in sibling: entry 1", results9[1], 'q:2');

// ── 10. Array.filter with arrow captures correct slot in sibling scope ──────
var filtered10 = [];
for (var item10 of []) { /* empty first scope */ }
for (var item10 of ['cat', 'car', 'bat', 'can']) {
    // arrow must capture this iteration's item10
    var keep10 = ['cat', 'can', 'bar'].filter(function(x) { return x === item10; });
    if (keep10.length > 0) { filtered10.push(item10); }
}
check(10, "filter in sibling loop: matched count", filtered10.length, 2);
check(10, "filter in sibling loop: first", filtered10[0], 'cat');
check(10, "filter in sibling loop: second", filtered10[1], 'can');

// ── const (block-scoped) sibling loops ────────────────────────────────────
// The next tests use `const`, which creates a separate local slot per block
// scope.  When two sibling loops both declare `const key`, the parent
// function's locals table contains TWO entries named "key" at different
// indices.  An arrow in the second loop must capture ITS slot, not the
// first loop's slot.

// ── 11. const in sibling for-of: second arrow sees its own key ───────────
function test11() {
    var seen = [];
    var prefixes = ['X_'];
    for (const [key] of []) {                       // const key → slot A (0 iterations)
        prefixes.some(p => key.startsWith(p));
    }
    for (const key of ['X_FOO', 'Y_BAR']) {         // const key → slot B (different slot)
        prefixes.some(p => { seen.push(key); return key.startsWith(p); });
    }
    return seen;
}
var r11 = test11();
check(11, "const for-of: captured key length", r11.length, 2);
check(11, "const for-of: captured key [0]", r11[0], 'X_FOO');
check(11, "const for-of: captured key [1]", r11[1], 'Y_BAR');

// ── 12. const in sibling for-in: second arrow sees its own key ───────────
function test12() {
    var seen = [];
    for (const key in {}) {                          // const key → slot A (0 iterations)
        seen.push((function() { return key; })());
    }
    for (const key in { p: 1, q: 2 }) {             // const key → slot B
        seen.push((function() { return key; })());
    }
    return seen;
}
var r12 = test12();
check(12, "const for-in: captured key length", r12.length, 2);
check(12, "const for-in: captured key [0]", r12[0], 'p');
check(12, "const for-in: captured key [1]", r12[1], 'q');

// ── 13. Vite loadEnv pattern with const ──────────────────────────────────
// First loop const [key, value] of entries({}); second loop const key in env.
// Arrow in second loop must capture the SECOND const key, not the first.
function test13() {
    var matched = [];
    var prefixes = ['VITE_'];
    for (const [key, value] of Object.entries({})) {
        if (prefixes.some(p => key.startsWith(p))) matched.push(key);
    }
    for (const key of ['VITE_API', 'NODE_ENV', 'VITE_MODE']) {
        if (prefixes.some(p => key.startsWith(p))) matched.push(key);
    }
    return matched;
}
var r13 = test13();
check(13, "const loadEnv pattern: matched count", r13.length, 2);
check(13, "const loadEnv pattern: first match", r13[0], 'VITE_API');
check(13, "const loadEnv pattern: second match", r13[1], 'VITE_MODE');

// ── 14. Arrow captures const from its own scope (no sibling conflict) ─────
// Regression guard: simple const capture without sibling collision must
// still work correctly after the slot-direct fix.
function test14() {
    var results = [];
    for (const x of [10, 20, 30]) {
        results.push((function() { return x * 2; })());
    }
    return results;
}
var r14 = test14();
check(14, "simple const capture [0]", r14[0], 20);
check(14, "simple const capture [1]", r14[1], 40);
check(14, "simple const capture [2]", r14[2], 60);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Sibling-scope closure capture tests: " + _passed + " passed, " + _failed + " failed ===");
if (_failed > 0) process.exit(1);
