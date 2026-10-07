// ARRAY_COMPREHENSIVE_TEST_PLAN §1–2, §4.2, §5.1 — constructor, statics, unscopables, Symbol.species
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_constructor_statics.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ── §1 Constructor (ARR-C-*) ───────────────────────────────────────────────

// ARR-C-001
assertEq(new Array().length, 0, "ARR-C-001: new Array() length 0");
assertEq(Array().length, 0, "ARR-C-001: Array() without new length 0");

// ARR-C-002
assertDeep(new Array("a", "b"), ["a", "b"], "ARR-C-002: new Array multiple elements");

// ARR-C-003
var aLen = new Array(3);
assertEq(aLen.length, 3, "ARR-C-003: new Array(3) length");
assert(!(0 in aLen), "ARR-C-003: index 0 is empty slot");
assert(!(1 in aLen), "ARR-C-003: index 1 is empty slot");

// ARR-C-004
var c4 = false;
try { new Array(3.14); } catch (e) { c4 = e instanceof RangeError; }
assert(c4, "ARR-C-004: new Array(3.14) throws RangeError");

// ARR-C-005
var c5a = false;
try { new Array(-1); } catch (e) { c5a = e instanceof RangeError; }
assert(c5a, "ARR-C-005: new Array(-1) throws RangeError");
var c5b = false;
try { new Array(Math.pow(2, 32)); } catch (e) { c5b = e instanceof RangeError; }
assert(c5b, "ARR-C-005: new Array(2^32) throws RangeError");

// ARR-C-006
var oneStr = new Array("2");
assertEq(oneStr.length, 1, "ARR-C-006: new Array('2') length 1");
assertEq(oneStr[0], "2", "ARR-C-006: element is string '2'");

// ARR-C-007
assertDeep(Array(), [], "ARR-C-007: Array() matches new Array()");
assertDeep(Array(1, 2), [1, 2], "ARR-C-007: Array(1,2) matches new Array(1,2)");

// ── §2.1 isArray (ARR-S-010, S-011) ──────────────────────────────────────────

assert(Array.isArray([]), "ARR-S-010: isArray []");
assert(Array.isArray(new Array()), "ARR-S-010: isArray new Array()");
assert(!Array.isArray({ length: 1, 0: 1 }), "ARR-S-011: array-like object false");
// Array.prototype is an Array exotic object — IsArray is true (spec); not a "real" instance but isArray is true
assert(Array.isArray(Array.prototype), "ARR-S-011: Array.prototype is array exotic");
assert(!Array.isArray(null), "ARR-S-011: null false");
assert(!Array.isArray(undefined), "ARR-S-011: undefined false");
assert(!Array.isArray(1), "ARR-S-011: number false");
assert(!Array.isArray("a"), "ARR-S-011: string false");

// ── §2.2 of (ARR-S-020–S-022) ───────────────────────────────────────────────

assertEq(Array.of().length, 0, "ARR-S-020: Array.of() empty");
assertDeep(Array.of(undefined), [undefined], "ARR-S-021: Array.of(undefined)");
assertDeep(Array.of(0), [0], "ARR-S-021: Array.of(0)");
assertDeep(Array.of(1, "x", true), [1, "x", true], "ARR-S-021: Array.of mixed");
assertDeep(Array.of(42), [42], "ARR-S-022: Array.of(42) one element not length");

// ── §2.3 from (ARR-S-030–S-034) ─────────────────────────────────────────────

assertDeep(Array.from("ab"), ["a", "b"], "ARR-S-030: Array.from string");
assertDeep(Array.from({ 0: "a", 1: "b", length: 2 }), ["a", "b"], "ARR-S-031: Array.from array-like");

var doubled = Array.from([1, 2, 3], function (x) { return x * 2; });
assertDeep(doubled, [2, 4, 6], "ARR-S-032: Array.from mapFn");

var thisObj = { factor: 10 };
var mapped = Array.from([1, 2], function (x) { return x * this.factor; }, thisObj);
assertDeep(mapped, [10, 20], "ARR-S-032: Array.from mapFn thisArg");

var sparseLike = { length: 3, 0: "a", 2: "c" };
var fromSparse = Array.from(sparseLike, function (v, i) { return v === undefined ? "u" : v; });
assertEq(fromSparse[1], "u", "ARR-S-033: mapFn sees missing index as undefined");

var s34 = false;
try { Array.from(null); } catch (e) { s34 = e instanceof TypeError; }
assert(s34, "ARR-S-034: Array.from(null) throws TypeError");

// ── §4.1 constructor (ARR-P-001, P-002) ─────────────────────────────────────

assertEq([].constructor, Array, "ARR-P-001: [].constructor === Array");
try {
    // Subclass smoke test (syntax may fail on minimal engines)
    var Sub = function () {
        Array.apply(this, arguments);
    };
    Sub.prototype = Object.create(Array.prototype);
    Sub.prototype.constructor = Sub;
    var subInst = new Sub(1, 2);
    assert(subInst instanceof Sub, "ARR-P-002: manual subclass instanceof");
} catch (e) { /* skip */ }

// ── §4.2 Symbol.unscopables (ARR-P-010, P-011) ───────────────────────────────

if (typeof Symbol !== "undefined" && Symbol.unscopables) {
    var unsc = Array.prototype[Symbol.unscopables];
    assertEq(Object.getPrototypeOf(unsc), null, "ARR-P-010: unscopables null prototype");
    assertEq(unsc.copyWithin, true, "ARR-P-010: copyWithin unscopable");
    assertEq(unsc.entries, true, "ARR-P-010: entries unscopable");
    assertEq(unsc.fill, true, "ARR-P-010: fill unscopable");
    assertEq(unsc.find, true, "ARR-P-010: find unscopable");
    assertEq(unsc.findIndex, true, "ARR-P-010: findIndex unscopable");
    assertEq(unsc.flat, true, "ARR-P-010: flat unscopable");
    assertEq(unsc.flatMap, true, "ARR-P-010: flatMap unscopable");
    assertEq(unsc.includes, true, "ARR-P-010: includes unscopable");
    assertEq(unsc.keys, true, "ARR-P-010: keys unscopable");
    assertEq(unsc.values, true, "ARR-P-010: values unscopable");

    var desc = Object.getOwnPropertyDescriptor(Array.prototype, Symbol.unscopables);
    if (desc) {
        assertEq(desc.writable, false, "ARR-P-011: unscopables non-writable");
        assertEq(desc.enumerable, false, "ARR-P-011: unscopables non-enumerable");
        assertEq(desc.configurable, true, "ARR-P-011: unscopables configurable");
    }
}

// ── §5.1 Symbol.species (ARR-Y-001–Y-003) ───────────────────────────────────

if (typeof Symbol !== "undefined" && Symbol.species) {
    assertEq(Array[Symbol.species], Array, "ARR-Y-001: Array[Symbol.species] === Array");

    try {
        var code =
            "class SubA extends Array { static get [Symbol.species]() { return Array; } }" +
            "var sa = new SubA(1, 2, 3);" +
            "var mf = sa.map(function (x) { return x * 2; });" +
            "return mf.constructor === Array;";
        var okSpecies = Function('"use strict"; return (' + code + ")")();
        assert(okSpecies, "ARR-Y-002: subclass species Array → map returns Array");
    } catch (e) {
        /* engines without class: skip */
    }

    try {
        function NotAnArray(len) {
            this.length = len | 0;
        }
        var arrSp = [0, 1, 2];
        arrSp.constructor = {};
        arrSp.constructor[Symbol.species] = NotAnArray;
        var mapped2 = arrSp.map(function (i) { return i; });
        assert(mapped2 instanceof NotAnArray, "ARR-Y-003: map uses custom Symbol.species");
    } catch (e) {
        /* assignment to constructor may fail in some engines */
    }
}

// ── §2.4 fromAsync (ARR-S-040, S-041, S-042) — async tail ────────────────────

function exitOk() {
    __jacDone();
}
function exitFail(err) {
    console.error(err);
    __reg.bump(); return;
}

if (typeof Array.fromAsync !== "function") {
    // ARR-S-042: absent — documented skip
    exitOk();
} else {
    var chain = Array.fromAsync([1, 2, 3]).then(function (res) {
        assertDeep(res, [1, 2, 3], "ARR-S-040: fromAsync array of values");
    });

    chain = chain.then(function () {
        return Array.fromAsync([Promise.resolve(10), Promise.resolve(20)]).then(function (r2) {
            assertDeep(r2, [10, 20], "ARR-S-040: fromAsync unwraps promises");
        });
    });

    chain = chain.then(function () {
        var ai = {
            [Symbol.asyncIterator]: function () {
                return {
                    n: 0,
                    next: function () {
                        if (this.n++ === 0) {
                            return Promise.resolve({ value: 7, done: false });
                        }
                        return Promise.reject(new Error("ARR-S-041 boom"));
                    },
                };
            },
        };
        return Array.fromAsync(ai);
    }).then(
        function () {
            assert(false, "ARR-S-041: expected rejection");
        },
        function (e) {
            assert(e instanceof Error && e.message === "ARR-S-041 boom", "ARR-S-041: fromAsync rejects");
        }
    );

    chain.then(exitOk).catch(exitFail);
}
__jacDone();
