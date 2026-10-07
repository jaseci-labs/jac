// ARRAY_COMPREHENSIVE_TEST_PLAN §7.1–7.8, §11 — non-mutating + concat / isConcatSpreadable
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_nonmutating_search.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ARR-N-001 concat
assertDeep([1, 2].concat([3, 4]), [1, 2, 3, 4], "ARR-N-001: concat arrays");
assertDeep([1].concat(2, 3), [1, 2, 3], "ARR-N-001: concat values");
assertDeep([1].concat([2, [3]]), [1, 2, [3]], "ARR-N-001: nested one level");

// ARR-N-002 / ARR-X-001 ARR-X-002
if (typeof Symbol !== "undefined" && Symbol.isConcatSpreadable) {
    var spreadTrue = { 0: "a", 1: "b", length: 2 };
    spreadTrue[Symbol.isConcatSpreadable] = true;
    assertDeep([].concat(spreadTrue), ["a", "b"], "ARR-X-001: isConcatSpreadable true spreads");

    var spreadFalse = { 0: "x", length: 1 };
    spreadFalse[Symbol.isConcatSpreadable] = false;
    var wrapped = [].concat(spreadFalse);
    assertEq(wrapped.length, 1, "ARR-X-002: isConcatSpreadable false wraps");
    assert(wrapped[0] === spreadFalse, "ARR-X-002: single element is object");
}

// ARR-N-003 Symbol.species on concat (subclass)
if (typeof Symbol !== "undefined" && Symbol.species) {
    try {
        var ok = Function(
            '"use strict";' +
                "class C extends Array { static get [Symbol.species]() { return Array; } }" +
                "var c = new C(1, 2);" +
                "var out = c.concat([3]);" +
                "return out.constructor === Array && out.join() === '1,2,3';"
        )();
        assert(ok, "ARR-N-003: concat respects Symbol.species → Array");
    } catch (e) {
        /* no class */
    }
}

// ARR-N-010 slice
assertDeep([1, 2, 3, 4, 5].slice(), [1, 2, 3, 4, 5], "ARR-N-010: slice full");
assertDeep([1, 2, 3, 4, 5].slice(1, 3), [2, 3], "ARR-N-010: slice range");
assertDeep([1, 2, 3, 4, 5].slice(-2), [4, 5], "ARR-N-010: negative start");
var sparse = [1, , 3];
var sl = sparse.slice();
assert(!(1 in sl) && sl[2] === 3, "ARR-N-010: slice preserves holes");

// ARR-N-020 join
assertEq([1, 2, 3].join(), "1,2,3", "ARR-N-020: default comma");
assertEq([1, 2, 3].join("-"), "1-2-3", "ARR-N-020: custom sep");
assertEq([1, null, undefined, 2].join(","), "1,,,2", "ARR-N-020: null/undefined empty string");
var holJ = ["a", , "c"];
assertEq(holJ.join("-"), "a--c", "ARR-N-020: hole → empty between");

// ARR-N-030 / N-031 toString
assertEq([1, 2, 3].toString(), "1,2,3", "ARR-N-030: toString like join");
assertEq([[1, 2], [3, 4]].toString(), "1,2,3,4", "ARR-N-031: nested toString");

// ARR-N-032 toLocaleString
var loc = [{ toLocaleString: function () { return "Z"; } }];
assertEq(loc.toLocaleString(), "Z", "ARR-N-032: delegates to elements");

// ARR-N-040 indexOf / lastIndexOf
assertEq([1, 2, 3, 2, 1].indexOf(2), 1, "ARR-N-040: indexOf");
assertEq([1, 2, 3].indexOf(99), -1, "ARR-N-040: not found");
assertEq([1, 2, 3, 2, 1].indexOf(2, 2), 3, "ARR-N-040: fromIndex");
assertEq([1, 2, 3, 2, 1].lastIndexOf(2), 3, "ARR-N-040: lastIndexOf");
assertEq([NaN].indexOf(NaN), -1, "ARR-N-041: indexOf NaN");

// ARR-N-050 / N-051 includes
assert([1, 2, 3].includes(2), "ARR-N-050: includes");
assert(![1, 2, 3].includes(99), "ARR-N-051: missing false");
assert([1, NaN, 3].includes(NaN), "ARR-N-050: includes NaN");
assert(![1, 2, 3].includes(2, 2), "ARR-N-050: fromIndex past match");

// ARR-N-060 at
assertEq([1, 2, 3].at(0), 1, "ARR-N-060: at(0)");
assertEq([1, 2, 3].at(-1), 3, "ARR-N-060: at(-1)");
assertEq([1, 2, 3].at(99), undefined, "ARR-N-060: OOB");

// ARR-N-070 flat
assertDeep(
    [
        [1, 2],
        [3, 4],
    ].flat(),
    [1, 2, 3, 4],
    "ARR-N-070: flat 1"
);
assertDeep([1, [2, [3, [4]]]].flat(0), [1, [2, [3, [4]]]], "ARR-N-070: flat 0");
assertDeep([1, [2, [3]]].flat(2), [1, 2, 3], "ARR-N-070: flat 2");
assertDeep([1, [2, [3, [4]]]].flat(Infinity), [1, 2, 3, 4], "ARR-N-070: flat Infinity");

// ARR-N-071 flatMap
assertDeep(
    [1, 2, 3].flatMap(function (x) {
        return [x, x * 2];
    }),
    [1, 2, 2, 4, 3, 6],
    "ARR-N-071: flatMap"
);
var tm = { m: 2 };
assertDeep(
    [1, 2].flatMap(function (x) {
        return [x * this.m];
    }, tm),
    [2, 4],
    "ARR-N-071: flatMap thisArg"
);

__jacDone();
