/**
 * Regression test: closures in sibling block-scopes capture the correct binding.
 *
 * When two sibling blocks each declare a block-scoped variable with the same name
 * (e.g. `const key` in two consecutive for-of loops), an arrow or function
 * expression defined inside the second block must capture the second block's
 * binding, not the first block's binding.
 */
"use strict";

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/sibling_scope_capture");

// ── const for-of sibling loops ────────────────────────────────────────────────
// Arrow in the second loop captures the second loop's `key`, not the first's.
(function() {
    var first  = { A: 1, B: 2 };
    var second = { X: 10, Y: 20 };
    var results = [];

    for (var [key] of Object.entries(first)) {
        // first loop; key captured here is not tested
        void key;
    }
    for (var [key] of Object.entries(second)) {
        var k = key;
        results.push((function() { return k; })());
    }

    __reg.assertEq(results.length, 2, "for-of sibling length");
    __reg.assertEq(results[0], "X",   "for-of sibling: key[0]");
    __reg.assertEq(results[1], "Y",   "for-of sibling: key[1]");
})();

// ── const for-in sibling loops ────────────────────────────────────────────────
(function() {
    var obj1 = { a: 1 };
    var obj2 = { p: 10, q: 20 };
    var collected = [];

    for (var key in obj1) { void key; }
    for (var key in obj2) {
        var k = key;
        collected.push((function() { return k; })());
    }

    __reg.assertEq(collected.length, 2, "for-in sibling length");
    __reg.assertEq(collected[0], "p",   "for-in sibling: key[0]");
    __reg.assertEq(collected[1], "q",   "for-in sibling: key[1]");
})();

// ── Vite loadEnv pattern: mixed for-of / for-in with filter ──────────────────
// Mirrors the real-world pattern that originally surfaced this bug.
(function() {
    var raw = { VITE_A: "alpha", OTHER: "skip", VITE_B: "beta" };
    var prefix = "VITE_";
    var matched = [];

    for (var key in raw) {
        // first pass: unused iteration
        void key;
    }
    for (var key in raw) {
        var k = key;
        if (k.startsWith(prefix)) {
            matched.push(k);
        }
    }

    __reg.assertEq(matched.length, 2,        "loadEnv: matched count");
    __reg.assertEq(matched[0],    "VITE_A",  "loadEnv: first match");
    __reg.assertEq(matched[1],    "VITE_B",  "loadEnv: second match");
})();

// ── Regression guard: simple variable capture still works ────────────────────
(function() {
    var values = [10, 20, 30];
    var fns = values.map(function(v) { return function() { return v; }; });
    __reg.assertEq(fns[0](), 10, "simple capture [0]");
    __reg.assertEq(fns[1](), 20, "simple capture [1]");
    __reg.assertEq(fns[2](), 30, "simple capture [2]");
})();

__reg.finalize();
