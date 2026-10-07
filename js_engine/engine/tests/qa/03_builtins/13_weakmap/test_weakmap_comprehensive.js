// MAP_SET_WEAKMAP_WEAKSET_SYMBOL_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// §3 WeakMap — EC-KCS-3 (subset) + EC-KCS-4 (KCS-WM-004..006)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/13_weakmap/test_weakmap_comprehensive.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrowsTypeError(fn, msg) { __reg.assertThrowsTypeError(fn, msg); }

// KCS-WM-004 — no size / no iteration surface on instance
(function kcs_wm_004() {
    var wm = new WeakMap();
    assertEq(typeof wm.size, "undefined", "KCS-WM-004: WeakMap instance has no size");
    assertEq(typeof wm.keys, "undefined", "KCS-WM-004: no keys()");
    assertEq(typeof wm.values, "undefined", "KCS-WM-004: no values()");
    assertEq(typeof wm.entries, "undefined", "KCS-WM-004: no entries()");
    assertEq(typeof wm.forEach, "undefined", "KCS-WM-004: no forEach");
    assertEq(typeof wm[Symbol.iterator], "undefined", "KCS-WM-004: not iterable via @@iterator");
})();

// KCS-WM-005 — brand checks
(function kcs_wm_005() {
    var k = {};
    assertThrowsTypeError(function () { WeakMap.prototype.get.call({}, k); }, "KCS-WM-005: get on non-WeakMap throws");
    assertThrowsTypeError(function () { WeakMap.prototype.set.call({}, k, 1); }, "KCS-WM-005: set on non-WeakMap throws");
    assertThrowsTypeError(function () { WeakMap.prototype.has.call({}, k); }, "KCS-WM-005: has on non-WeakMap throws");
    assertThrowsTypeError(function () { WeakMap.prototype.delete.call({}, k); }, "KCS-WM-005: delete on non-WeakMap throws");
})();

// KCS-WM-006 — constructor rejects malformed entry (primitive key in pair)
(function kcs_wm_006() {
    assertThrowsTypeError(function () {
        new WeakMap([[{}, 1], ["stringKey", 2]]);
    }, "KCS-WM-006: iterable with string key in entry throws TypeError");
})();

__jacDone();
