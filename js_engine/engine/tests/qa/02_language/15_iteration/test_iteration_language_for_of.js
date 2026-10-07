// ITERATION_COMPREHENSIVE_TEST_PLAN.md — ITR-* (iterables, iterators, for…of)
// Extended: ITR-N-006 (well-formed next result), ITR-F-007 (try/finally vs IteratorClose)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/15_iteration/test_iteration_language_for_of.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// --- §3 for…of (ITR-F-*) ---

// ITR-F-001: GetIterator / @@iterator — not for…in (array, string, Map, Set, generator)
(function itrF001() {
    var a = [];
    for (var v of [7, 8]) {
        a.push(v);
    }
    assertEq(a.join(","), "7,8", "ITR-F-001: for…of array");
    var s = "";
    for (var ch of "xy") {
        s += ch;
    }
    assertEq(s, "xy", "ITR-F-001: for…of string");
    var m = new Map([["p", 1]]);
    var mp = "";
    for (var e of m) {
        mp += e[0] + e[1];
    }
    assertEq(mp, "p1", "ITR-F-001: for…of Map default iterator");
    var st = new Set([9]);
    var one = 0;
    for (var sv of st) {
        one = sv;
    }
    assertEq(one, 9, "ITR-F-001: for…of Set");
    function* gen() {
        yield 3;
    }
    var gsum = 0;
    for (var gv of gen()) {
        gsum += gv;
    }
    assertEq(gsum, 3, "ITR-F-001: for…of generator");
})();

// ITR-F-002: destructuring in loop head
(function itrF002() {
    var m = new Map([
        ["a", 1],
        ["b", 2]
    ]);
    var keys = [];
    for (const pair of m) {
        keys.push(pair[0]);
    }
    assertEq(keys.join(""), "ab", "ITR-F-002: const binding in for…of Map");
    var pairs = [];
    for (const [k, v] of m) {
        pairs.push(k + ":" + v);
    }
    assertEq(pairs.join("|"), "a:1|b:2", "ITR-F-002: destructuring [k,v] in head");
})();

// ITR-F-003: break / continue vs IteratorClose; labeled continue outer closes
(function itrF003() {
    var returnCount = 0;
    function makeIter() {
        return {
            [Symbol.iterator]: function () {
                var step = 0;
                return {
                    next: function () {
                        step++;
                        if (step <= 3) {
                            return { value: step, done: false };
                        }
                        return { value: undefined, done: true };
                    },
                    return: function () {
                        returnCount++;
                        return { done: true };
                    }
                };
            }
        };
    }
    for (var x of makeIter()) {
        if (x < 3) {
            continue;
        }
        break;
    }
    assertEq(returnCount, 1, "ITR-F-003: break invokes return once (continue does not)");
    var closes = 0;
    function makeShort() {
        return {
            [Symbol.iterator]: function () {
                return {
                    next: function () {
                        return { value: 1, done: false };
                    },
                    return: function () {
                        closes++;
                        return { done: true };
                    }
                };
            }
        };
    }
    outer: for (var i = 0; i < 2; i++) {
        for (var y of makeShort()) {
            continue outer;
        }
    }
    assertEq(closes, 2, "ITR-F-003: labeled continue outer invokes IteratorClose each exit");
})();

// ITR-F-004: throw from body — return invoked (IteratorClose)
(function itrF004() {
    var closed = false;
    var boxed = {
        [Symbol.iterator]: function () {
            return {
                once: false,
                next: function () {
                    if (!this.once) {
                        this.once = true;
                        return { value: 1, done: false };
                    }
                    return { value: undefined, done: true };
                },
                return: function () {
                    closed = true;
                    return { done: true };
                }
            };
        }
    };
    var errCaught = false;
    try {
        for (var x of boxed) {
            throw new Error("body");
        }
    } catch (e) {
        errCaught = e.message === "body";
    }
    assert(errCaught, "ITR-F-004: body throw caught");
    assert(closed, "ITR-F-004: IteratorClose after throw from body");
})();

// ITR-F-005: non-iterable RHS → TypeError
(function itrF005() {
    assertThrows(
        function () {
            for (var x of null) {
                void x;
            }
        },
        TypeError,
        "ITR-F-005: null is not iterable"
    );
    assertThrows(
        function () {
            for (var y of {}) {
                void y;
            }
        },
        TypeError,
        "ITR-F-005: plain object without @@iterator throws"
    );
})();

// ITR-F-006: const binding is per iteration (closure capture)
(function itrF006() {
    var fs = [];
    for (const i of [10, 20]) {
        fs.push(function () {
            return i;
        });
    }
    assertEq(fs[0](), 10, "ITR-F-006: const first iteration binding");
    assertEq(fs[1](), 20, "ITR-F-006: const second iteration binding");
})();

// ITR-F-007: try/finally — IteratorClose (return) before finally runs (plan gap)
(function itrF007() {
    var log = [];
    var boxed = {
        [Symbol.iterator]: function () {
            return {
                n: 0,
                next: function () {
                    if (this.n++ === 0) {
                        return { value: 1, done: false };
                    }
                    return { value: undefined, done: true };
                },
                return: function () {
                    log.push("return");
                    return { done: true };
                }
            };
        }
    };
    try {
        for (var x of boxed) {
            log.push("body");
            break;
        }
    } finally {
        log.push("finally");
    }
    assertEq(log.join(","), "body,return,finally", "ITR-F-007: return before finally on break");
})();

__jacDone();
