// MAP_SET_WEAKMAP_WEAKSET_SYMBOL_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// §7 Well-known symbols — EC-KCS-7 (KCS-WK-001..009)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/07_symbol/test_well_known_symbol_protocols.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }
function assertThrowsTypeError(fn, msg) { __reg.assertThrowsTypeError(fn, msg); }

// Sloppy-mode fragment: `with` is disallowed in strict code (including async bodies).
(function kcs_wk_007_unscopables_sloppy() {
    if (typeof Symbol.unscopables !== "symbol") return;
    var o = { foo: 1 };
    o[Symbol.unscopables] = { foo: true };
    var foo = 99;
    var got;
    with (o) { got = foo; }
    assertEq(got, 99, "KCS-WK-007: unscopables hides property from with binding");
})();

(async function kcs_wk_main() {
    try {
        // KCS-WK-001 — custom @@iterator: for-of, spread
        (function kcs_wk_001() {
            var iterable = {};
            iterable[Symbol.iterator] = function () {
                var i = 0;
                var data = [1, 2];
                return {
                    next: function () {
                        return i < data.length ? { value: data[i++], done: false } : { value: undefined, done: true };
                    }
                };
            };
            var a = [];
            for (var v of iterable) a.push(v);
            assertDeep(a, [1, 2], "KCS-WK-001: for-of");
            assertDeep([...iterable], [1, 2], "KCS-WK-001: spread");
        })();

        // KCS-WK-002 — asyncIterator + for-await-of
        var asyncIterable = {};
        asyncIterable[Symbol.asyncIterator] = function () {
            var i = 0;
            var data = [10, 20];
            return {
                next: function () {
                    return Promise.resolve(
                        i < data.length ? { value: data[i++], done: false } : { value: undefined, done: true }
                    );
                }
            };
        };
        var acc = [];
        for await (var x of asyncIterable) acc.push(x);
        assertDeep(acc, [10, 20], "KCS-WK-002: for-await-of async iterator");

        // KCS-WK-003 — toPrimitive hints + error propagation
        (function kcs_wk_003() {
            var o = {
                [Symbol.toPrimitive]: function (hint) {
                    if (hint === "number") return 7;
                    if (hint === "string") return "s";
                    return false;
                }
            };
            assertEq(+o, 7, "KCS-WK-003: number hint");
            assertEq(String(o), "s", "KCS-WK-003: string hint via String()");
            assertEq(o + "", "false", "KCS-WK-003: default hint");
            var bad = {
                [Symbol.toPrimitive]: function () {
                    throw new TypeError("wk003");
                }
            };
            var threw = false;
            try { void (+bad); } catch (e) { threw = e instanceof TypeError && e.message === "wk003"; }
            assert(threw, "KCS-WK-003: toPrimitive throw propagates");
        })();

        // KCS-WK-004 — hasInstance
        (function kcs_wk_004() {
            var even = { [Symbol.hasInstance]: function (n) { return n % 2 === 0; } };
            assert(4 instanceof even, "KCS-WK-004: hasInstance true");
            assert(!(5 instanceof even), "KCS-WK-004: hasInstance false");
        })();

        // KCS-WK-005 — toStringTag
        (function kcs_wk_005() {
            var tagged = { [Symbol.toStringTag]: "Taggy" };
            assertEq(Object.prototype.toString.call(tagged), "[object Taggy]", "KCS-WK-005: toStringTag");
        })();

        // KCS-WK-006 — species on Array subclass (optional / engine-dependent result type)
        (function kcs_wk_006() {
            assertEq(typeof Symbol.species, "symbol", "KCS-WK-006: Symbol.species exists");
            class MyArray extends Array {
                static get [Symbol.species]() { return Array; }
            }
            var ma = new MyArray(1, 2, 3);
            var mapped = ma.map(function (x) { return x; });
            assert(mapped !== undefined, "KCS-WK-006: map with species does not crash");
        })();

        // KCS-WK-007 — isConcatSpreadable (unscopables: see sloppy IIFE above)
        (function kcs_wk_007_concat() {
            if (typeof Symbol.isConcatSpreadable !== "symbol") return;
            var arr = [1, 2];
            var fake = { 0: 3, 1: 4, length: 2 };
            fake[Symbol.isConcatSpreadable] = true;
            assertDeep(arr.concat(fake), [1, 2, 3, 4], "KCS-WK-007: isConcatSpreadable spreads array-like");
        })();

        // KCS-WK-008 — string/regexp hooks when implemented
        (function kcs_wk_008() {
            if (typeof Symbol.match === "symbol" && RegExp.prototype[Symbol.match]) {
                var threw = false;
                try { "a".match(RegExp.prototype); } catch (e) { threw = e instanceof TypeError; }
                assert(threw, "KCS-WK-008: String.prototype.match with RegExp.prototype throws");
            }
        })();

        // KCS-WK-009 — object literal computed well-known symbol method callable
        (function kcs_wk_009() {
            var o = {
                [Symbol.toPrimitive]: function (hint) {
                    if (hint === "number") return 11;
                    return 0;
                }
            };
            assertEq(+o, 11, "KCS-WK-009: literal Symbol.toPrimitive number hint");
        })();

        __jacDone();
    } catch (e) {
        console.error("FAIL: KCS-WK-main: " + e);
        __reg.bump(); return;
    }
})();
__jacDone();
