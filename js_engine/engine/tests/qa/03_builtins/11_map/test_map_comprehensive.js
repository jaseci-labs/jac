// MAP_SET_WEAKMAP_WEAKSET_SYMBOL_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// §1 Map — EC-KCS-1 (KCS-M-004..006) + EC-KCS-2 (KCS-M-007..009)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/11_map/test_map_comprehensive.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertThrowsTypeError(fn, msg) { __reg.assertThrowsTypeError(fn, msg); }

// KCS-M-004 — overwrite does not reorder keys; size unchanged
(function kcs_m_004() {
    var m = new Map([["a", 1], ["b", 2]]);
    m.set("a", 99);
    assertEq(m.size, 2, "KCS-M-004: size unchanged after overwrite");
    var keys = [];
    m.forEach(function (_v, k) { keys.push(k); });
    assertDeep(keys, ["a", "b"], "KCS-M-004: insertion order preserved after overwrite");
    assertEq(m.get("a"), 99, "KCS-M-004: value updated");
})();

// KCS-M-005 — @@iterator same as entries
(function kcs_m_005() {
    var m = new Map([[1, "x"]]);
    assertEq(m[Symbol.iterator], m.entries, "KCS-M-005: Symbol.iterator is entries");
})();

// KCS-M-006 — forEach thisArg and (value, key, map) args
(function kcs_m_006() {
    var m = new Map([["a", 1]]);
    var seenThis = false;
    var ctx = { id: 42 };
    m.forEach(function (v, k, map) {
        assertEq(v, 1, "KCS-M-006: forEach value");
        assertEq(k, "a", "KCS-M-006: forEach key");
        assert(map === m, "KCS-M-006: forEach third arg is map");
        assertEq(this.id, 42, "KCS-M-006: forEach thisArg");
        seenThis = true;
    }, ctx);
    assert(seenThis, "KCS-M-006: forEach ran");
})();

// KCS-M-007 — null/undefined yield empty map; other non-iterables throw; malformed entries throw
(function kcs_m_007() {
    var mNull = new Map(null);
    assertEq(mNull.size, 0, "KCS-M-007: new Map(null) yields empty map");
    var mUndef = new Map(undefined);
    assertEq(mUndef.size, 0, "KCS-M-007: new Map(undefined) yields empty map");
    assertThrowsTypeError(function () { new Map(true); }, "KCS-M-007: new Map(boolean) throws TypeError");
    assertThrowsTypeError(function () { new Map(1); }, "KCS-M-007: new Map(number) throws TypeError");
    assertThrowsTypeError(function () { new Map({}); }, "KCS-M-007: new Map(plain object) throws TypeError");
    assertThrowsTypeError(function () { new Map([1, 2]); }, "KCS-M-007: new Map(array of non-objects) throws TypeError");
})();

// KCS-M-008 — brand checks on Map.prototype methods
(function kcs_m_008() {
    assertThrowsTypeError(function () { Map.prototype.set.call({}, "a", 1); }, "KCS-M-008: set on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.get.call({}, "a"); }, "KCS-M-008: get on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.has.call({}, "a"); }, "KCS-M-008: has on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.delete.call({}, "a"); }, "KCS-M-008: delete on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.clear.call({}); }, "KCS-M-008: clear on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.forEach.call({}, function () {}); }, "KCS-M-008: forEach on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.keys.call({}); }, "KCS-M-008: keys on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.values.call({}); }, "KCS-M-008: values on non-Map throws");
    assertThrowsTypeError(function () { Map.prototype.entries.call({}); }, "KCS-M-008: entries on non-Map throws");
})();

// KCS-M-009 — IteratorClose when constructor fails after valid entry (invalid map entry)
(function kcs_m_009() {
    var closed = false;
    var iterable = {
        [Symbol.iterator]: function () {
            return {
                i: 0,
                next: function () {
                    this.i++;
                    if (this.i === 1) return { value: ["a", 1], done: false };
                    return { value: 42, done: false };
                },
                return: function () {
                    closed = true;
                    return {};
                }
            };
        }
    };
    var threw = false;
    try { new Map(iterable); } catch (e) { threw = e instanceof TypeError; }
    assert(threw, "KCS-M-009: invalid entry throws TypeError");
    assert(closed, "KCS-M-009: iterator return invoked (IteratorClose)");
})();

__jacDone();
