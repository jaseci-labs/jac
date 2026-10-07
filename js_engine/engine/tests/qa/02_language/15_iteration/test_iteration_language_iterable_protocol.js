// ITERATION_COMPREHENSIVE_TEST_PLAN.md — ITR-* (iterables, iterators, for…of)
// Extended: ITR-N-006 (well-formed next result), ITR-F-007 (try/finally vs IteratorClose)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/15_iteration/test_iteration_language_iterable_protocol.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// --- §1 Iterable protocol (ITR-I-*) ---

// ITR-I-001: [Symbol.iterator]() returns iterator — for…of + Array.from
(function itrI001() {
    var iterable = {
        [Symbol.iterator]: function () {
            var n = 0;
            return {
                next: function () {
                    n++;
                    if (n <= 2) {
                        return { value: n * 10, done: false };
                    }
                    return { value: undefined, done: true };
                }
            };
        }
    };
    var out = [];
    for (var v of iterable) {
        out.push(v);
    }
    assertEq(out.join(","), "10,20", "ITR-I-001: for…of over custom iterable");
    var from = Array.from(iterable);
    assertEq(from.join(","), "10,20", "ITR-I-001: Array.from custom iterable");
})();

// ITR-I-002: @@iterator not callable or returns non-object → TypeError
(function itrI002() {
    assertThrows(
        function () {
            var bad = { [Symbol.iterator]: 123 };
            for (var x of bad) {
                void x;
            }
        },
        TypeError,
        "ITR-I-002: non-callable @@iterator throws TypeError"
    );
    assertThrows(
        function () {
            var bad2 = {
                [Symbol.iterator]: function () {
                    return 1;
                }
            };
            for (var y of bad2) {
                void y;
            }
        },
        TypeError,
        "ITR-I-002: @@iterator returning non-object throws TypeError"
    );
})();

// ITR-I-003: generator as @@iterator
(function itrI003() {
    var obj = {
        [Symbol.iterator]: function* () {
            yield "a";
            yield "b";
        }
    };
    var acc = [];
    for (var ch of obj) {
        acc.push(ch);
    }
    assertEq(acc.join(""), "ab", "ITR-I-003: generator @@iterator drives for…of");
})();

// ITR-I-004: arguments object is iterable (typical sloppy / non-strict function)
(function itrI004() {
    function f() {
        var parts = [];
        for (var a of arguments) {
            parts.push(a);
        }
        return parts.join("-");
    }
    assertEq(f(1, 2, 3), "1-2-3", "ITR-I-004: for…of arguments");
})();

__jacDone();
