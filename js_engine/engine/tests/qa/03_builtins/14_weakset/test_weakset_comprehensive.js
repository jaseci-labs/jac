// MAP_SET_WEAKMAP_WEAKSET_SYMBOL_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// §4 WeakSet — EC-KCS-3 (subset) + EC-KCS-4 (KCS-WS-004..006)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/14_weakset/test_weakset_comprehensive.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrowsTypeError(fn, msg) { __reg.assertThrowsTypeError(fn, msg); }

// KCS-WS-004 — no size / not consumable by for-of
(function kcs_ws_004() {
    var ws = new WeakSet();
    assertEq(typeof ws.size, "undefined", "KCS-WS-004: WeakSet instance has no size");
    assertEq(typeof ws[Symbol.iterator], "undefined", "KCS-WS-004: not iterable via @@iterator");
    var threw = false;
    try {
        for (var x of ws) { void x; }
    } catch (e) {
        threw = e instanceof TypeError;
    }
    assert(threw, "KCS-WS-004: for-of over WeakSet throws TypeError");
})();

// KCS-WS-005 — brand checks
(function kcs_ws_005() {
    var o = {};
    assertThrowsTypeError(function () { WeakSet.prototype.add.call({}, o); }, "KCS-WS-005: add on non-WeakSet throws");
    assertThrowsTypeError(function () { WeakSet.prototype.has.call({}, o); }, "KCS-WS-005: has on non-WeakSet throws");
    assertThrowsTypeError(function () { WeakSet.prototype.delete.call({}, o); }, "KCS-WS-005: delete on non-WeakSet throws");
})();

// KCS-WS-006 — constructor rejects primitive in iterable
(function kcs_ws_006() {
    assertThrowsTypeError(function () { new WeakSet([{} , 1]); }, "KCS-WS-006: primitive element in iterable throws TypeError");
})();

__jacDone();
