// ARRAY_COMPREHENSIVE_TEST_PLAN §8 — toReversed, toSorted, toSpliced, with (+ species note)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_es2023.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

var base = [1, 2, 3, 4, 5];

if (typeof base.toReversed === "function") {
    var rev = base.toReversed();
    assertDeep(rev, [5, 4, 3, 2, 1], "ARR-23-001: toReversed");
    assertDeep(base, [1, 2, 3, 4, 5], "ARR-23-001: original unchanged");
    var sp = [1, , 3];
    var spr = sp.toReversed();
    assertEq(spr[0], 3, "ARR-23-001: sparse reversed first");
    assertEq(spr[2], 1, "ARR-23-001: sparse reversed last");
}

if (typeof base.toSorted === "function") {
    var mixed = [3, 1, 2];
    var sor = mixed.toSorted();
    assertDeep(sor, [1, 2, 3], "ARR-23-002: toSorted default");
    assertDeep(mixed, [3, 1, 2], "ARR-23-002: original unchanged");
    assertDeep(
        [10, 2, 1].toSorted(function (a, b) {
            return a - b;
        }),
        [1, 2, 10],
        "ARR-23-002: toSorted compareFn"
    );
}

if (typeof base.toSpliced === "function") {
    var ts = base.toSpliced(1, 2, 20, 30);
    assertDeep(ts, [1, 20, 30, 4, 5], "ARR-23-003: toSpliced");
    assertDeep(base, [1, 2, 3, 4, 5], "ARR-23-003: original unchanged");
}

if (typeof base.with === "function") {
    var w = base.with(2, 99);
    assertDeep(w, [1, 2, 99, 4, 5], "ARR-23-004: with");
    assertDeep(base, [1, 2, 3, 4, 5], "ARR-23-004: original unchanged");
    assertDeep([1, 2, 3].with(-1, 0), [1, 2, 0], "ARR-23-004: with negative index");
    var wr = false;
    try {
        [1, 2, 3].with(99, 1);
    } catch (e) {
        wr = e instanceof RangeError;
    }
    assert(wr, "ARR-23-004: with OOB throws RangeError");
}

// ARR-23-005 — ES2023 methods use Array constructor, not species
if (typeof base.toReversed === "function" && typeof Symbol !== "undefined" && Symbol.species) {
    try {
        var ok = Function(
            '"use strict";' +
                "class Sub extends Array {}" +
                "var s = new Sub(1, 2, 3);" +
                "return s.toReversed().constructor === Array && s.map(function(x){return x;}).constructor === Sub;"
        )();
        assert(ok, "ARR-23-005: toReversed uses Array; map uses subclass");
    } catch (e) {
        /* no class */
    }
}

__jacDone();
