// MAP_SET_WEAKMAP_WEAKSET_SYMBOL_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// §2 Set — EC-KCS-1 (KCS-S-004..005) + EC-KCS-2 (KCS-S-006..008)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/12_set/test_set_comprehensive.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertThrowsTypeError(fn, msg) { __reg.assertThrowsTypeError(fn, msg); }

// KCS-S-004 — keys === values; entries [v,v]; @@iterator === values
(function kcs_s_004() {
    var s = new Set([10, 20]);
    assertEq(s.keys, s.values, "KCS-S-004: keys same function as values");
    assertEq(s[Symbol.iterator], s.values, "KCS-S-004: Symbol.iterator is values");
    var ents = [];
    for (var e of s.entries()) ents.push(e);
    assertDeep(ents, [[10, 10], [20, 20]], "KCS-S-004: entries pairs");
})();

// KCS-S-005 — forEach (v,v,set) and thisArg; order
(function kcs_s_005() {
    var s = new Set(["a", "b"]);
    var ctx = { t: 1 };
    var out = [];
    s.forEach(function (v1, v2, set) {
        assertEq(v1, v2, "KCS-S-005: first two args equal");
        assert(set === s, "KCS-S-005: third arg is set");
        assertEq(this.t, 1, "KCS-S-005: thisArg");
        out.push(v1);
    }, ctx);
    assertDeep(out, ["a", "b"], "KCS-S-005: insertion order");
})();

// KCS-S-006 — null/undefined yield empty set; non-iterables throw
(function kcs_s_006() {
    assertEq(new Set(null).size, 0, "KCS-S-006: new Set(null) yields empty set");
    assertEq(new Set(undefined).size, 0, "KCS-S-006: new Set(undefined) yields empty set");
    assertThrowsTypeError(function () { new Set(true); }, "KCS-S-006: new Set(boolean) throws TypeError");
    assertThrowsTypeError(function () { new Set({}); }, "KCS-S-006: new Set(plain object) throws TypeError");
})();

// KCS-S-007 — brand checks
(function kcs_s_007() {
    assertThrowsTypeError(function () { Set.prototype.add.call({}, 1); }, "KCS-S-007: add on non-Set throws");
    assertThrowsTypeError(function () { Set.prototype.has.call({}, 1); }, "KCS-S-007: has on non-Set throws");
    assertThrowsTypeError(function () { Set.prototype.delete.call({}, 1); }, "KCS-S-007: delete on non-Set throws");
    assertThrowsTypeError(function () { Set.prototype.clear.call({}); }, "KCS-S-007: clear on non-Set throws");
    assertThrowsTypeError(function () { Set.prototype.forEach.call({}, function () {}); }, "KCS-S-007: forEach on non-Set throws");
    assertThrowsTypeError(function () { Set.prototype.keys.call({}); }, "KCS-S-007: keys on non-Set throws");
    assertThrowsTypeError(function () { Set.prototype.values.call({}); }, "KCS-S-007: values on non-Set throws");
    assertThrowsTypeError(function () { Set.prototype.entries.call({}); }, "KCS-S-007: entries on non-Set throws");
})();

// KCS-S-008 — optional Set methods: absent or function (do not require implementation)
(function kcs_s_008() {
    var names = ["union", "intersection", "difference", "symmetricDifference", "isSubsetOf", "isSupersetOf", "isDisjointFrom"];
    for (var i = 0; i < names.length; i++) {
        var n = names[i];
        var t = typeof Set.prototype[n];
        assert(t === "undefined" || t === "function", "KCS-S-008: Set.prototype." + n + " is undefined or function");
    }
})();

__jacDone();
