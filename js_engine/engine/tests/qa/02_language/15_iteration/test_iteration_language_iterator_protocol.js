// ITERATION_COMPREHENSIVE_TEST_PLAN.md — ITR-* (iterables, iterators, for…of)
// Extended: ITR-N-006 (well-formed next result), ITR-F-007 (try/finally vs IteratorClose)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/15_iteration/test_iteration_language_iterator_protocol.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// --- §2 Iterator protocol (ITR-N-*) + ITR-N-006 (well-formed result) ---

// ITR-N-001: manual next() until done: true
(function itrN001() {
    var i = 0;
    var it = {
        next: function () {
            if (i++ < 2) {
                return { value: i, done: false };
            }
            return { value: undefined, done: true };
        }
    };
    var a = it.next();
    assertEq(a.value, 1, "ITR-N-001: first next value");
    assertEq(a.done, false, "ITR-N-001: first next not done");
    var b = it.next();
    assertEq(b.value, 2, "ITR-N-001: second next value");
    var c = it.next();
    assertEq(c.done, true, "ITR-N-001: done true");
})();

// ITR-N-002: next missing or not callable → TypeError when stepping
(function itrN002() {
    assertThrows(
        function () {
            var it = {
                [Symbol.iterator]: function () {
                    return {};
                }
            };
            for (var x of it) {
                void x;
            }
        },
        TypeError,
        "ITR-N-002: missing next throws TypeError"
    );
    assertThrows(
        function () {
            var it2 = {
                [Symbol.iterator]: function () {
                    return { next: "not-fn" };
                }
            };
            for (var y of it2) {
                void y;
            }
        },
        TypeError,
        "ITR-N-002: non-callable next throws TypeError"
    );
})();

// ITR-N-006: next() must return object — ill-shaped → TypeError (plan cross-cutting)
(function itrN006() {
    assertThrows(
        function () {
            var it = {
                [Symbol.iterator]: function () {
                    return {
                        next: function () {
                            return "bad";
                        }
                    };
                }
            };
            for (var z of it) {
                void z;
            }
        },
        TypeError,
        "ITR-N-006: next returning non-object throws TypeError"
    );
})();

// ITR-N-003: IteratorClose — for…of break calls return with undefined
(function itrN003() {
    var sawArg;
    var saw = false;
    var boxed = {
        [Symbol.iterator]: function () {
            return {
                next: function () {
                    if (!saw) {
                        saw = true;
                        return { value: 1, done: false };
                    }
                    return { value: undefined, done: true };
                },
                return: function (v) {
                    sawArg = v;
                    return { done: true };
                }
            };
        }
    };
    for (var x of boxed) {
        if (x === 1) {
            break;
        }
    }
    assertEq(sawArg, undefined, "ITR-N-003: return called with undefined on break");
})();

// ITR-N-004: return throws — propagates to surrounding try/catch
(function itrN004() {
    var boxed = {
        [Symbol.iterator]: function () {
            return {
                n: 0,
                next: function () {
                    this.n++;
                    if (this.n === 1) {
                        return { value: 1, done: false };
                    }
                    return { value: undefined, done: true };
                },
                return: function () {
                    throw new Error("close-fail");
                }
            };
        }
    };
    var caught = false;
    try {
        for (var x of boxed) {
            if (x === 1) {
                break;
            }
        }
    } catch (e) {
        caught = e instanceof Error && e.message === "close-fail";
    }
    assert(caught, "ITR-N-004: throw from iterator return propagates");
})();

// ITR-N-005: generator iterator .throw() (surface check; deep cases in GEN-005)
(function itrN005() {
    function* g() {
        try {
            yield 1;
        } catch (ex) {
            yield "got-" + ex.message;
        }
    }
    var it = g();
    assertEq(it.next().value, 1, "ITR-N-005: first yield");
    var r = it.throw(new Error("boom"));
    assertEq(r.value, "got-boom", "ITR-N-005: throw delivered to generator");
})();

__jacDone();
