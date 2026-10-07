// ITERATION_COMPREHENSIVE_TEST_PLAN.md — ITR-* (iterables, iterators, for…of)
// Extended: ITR-N-006 (well-formed next result), ITR-F-007 (try/finally vs IteratorClose)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/15_iteration/test_iteration_language_builtin_iterables.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// --- §4 Built-in iterables (ITR-B-*) ---

// ITR-B-001: Array @@iterator aligns with values(); holes → undefined
(function itrB001() {
    assertEq(
        [][Symbol.iterator],
        [].values,
        "ITR-B-001: Array @@iterator same as values"
    );
    var holeVals = [];
    for (var hv of [, , 3]) {
        holeVals.push(hv === undefined ? "u" : hv);
    }
    assertEq(holeVals.join(","), "u,u,3", "ITR-B-001: sparse array yields undefined holes");
})();

// ITR-B-002: keys / values / entries — fresh iterator each call
(function itrB002() {
    var arr = [1];
    assert(arr.keys() !== arr.keys(), "ITR-B-002: keys() fresh iterator");
    assert(arr.values() !== arr.values(), "ITR-B-002: values() fresh iterator");
    assert(arr.entries() !== arr.entries(), "ITR-B-002: entries() fresh iterator");
})();

// ITR-B-003: String iterator — UTF-16 / supplementary (plan: two code units or one element per engine)
(function itrB003() {
    var units = [];
    for (var u of "\uD83D\uDC0A") {
        units.push(u);
    }
    assert(
        units.length === 1 || units.length === 2,
        "ITR-B-003: surrogate pair yields one supplementary char or two code units"
    );
    if (units.length === 1) {
        assertEq(units[0].length, 2, "ITR-B-003: single element is UTF-16 pair");
    } else {
        assertEq(units[0].length, 1, "ITR-B-003: high surrogate unit");
        assertEq(units[1].length, 1, "ITR-B-003: low surrogate unit");
    }
    var bmp = [];
    for (var c of "z") {
        bmp.push(c);
    }
    assertEq(bmp.length, 1, "ITR-B-003: BMP character one step");
})();

// ITR-B-004: Map default iterator yields entries
(function itrB004() {
    var m = new Map([
        ["k", 9]
    ]);
    var first = m[Symbol.iterator]().next().value;
    assert(Array.isArray(first), "ITR-B-004: Map iterator yields entry array");
    assertEq(first[0], "k", "ITR-B-004: entry key");
    assertEq(first[1], 9, "ITR-B-004: entry value");
})();

// ITR-B-005: Set @@iterator same as values()
(function itrB005() {
    var s = new Set();
    assertEq(
        Set.prototype[Symbol.iterator],
        Set.prototype.values,
        "ITR-B-005: Set @@iterator same as values"
    );
    assertEq(
        s[Symbol.iterator],
        s.values,
        "ITR-B-005: instance @@iterator same as values"
    );
})();

// ITR-B-006 (for…of TypedArray): see TAB-I-001 in
// regression/02_language/20_typed_arrays/test_typed_arrays_and_binary_data_language_comprehensive.js

__jacDone();
