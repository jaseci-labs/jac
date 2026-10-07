// ASYNC_PROMISES_AWAIT_COMPREHENSIVE_TEST_PLAN.md — ECG-ASY-ITER (ASY-I-001..006, ASY-E-005)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/18_async_iteration/test_async_iteration_semantics.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
async function main() {
    if (typeof Symbol === "undefined" || typeof Symbol.asyncIterator !== "symbol") {
        console.error("FAIL: ASY-I-001: Symbol.asyncIterator not available");
        __reg.bump(); return;
    }

    // --- ASY-I-001: for await over Symbol.asyncIterator ---
    var asyncVals = [];
    var asyncIterable = {
        [Symbol.asyncIterator]: function () {
            var i = 0;
            return {
                next: function () {
                    i++;
                    if (i <= 2) {
                        return Promise.resolve({ value: i * 10, done: false });
                    }
                    return Promise.resolve({ value: undefined, done: true });
                }
            };
        }
    };
    for await (var x of asyncIterable) {
        asyncVals.push(x);
    }
    assertEq(asyncVals.join(","), "10,20", "ASY-I-001: for await consumes Symbol.asyncIterator");

    // --- ASY-I-002: for await over sync Symbol.iterator ---
    var syncVals = [];
    var sync = {
        [Symbol.iterator]: function* () {
            yield 3;
            yield 4;
        }
    };
    for await (var y of sync) {
        syncVals.push(y);
    }
    assertEq(syncVals.join(","), "3,4", "ASY-I-002: for await wraps sync iterator");

    // --- ASY-I-003: abrupt break calls return on async iterator ---
    var returnCalls = 0;
    var iterableBreak = {
        [Symbol.asyncIterator]: function () {
            var n = 0;
            return {
                next: function () {
                    n++;
                    if (n <= 3) {
                        return Promise.resolve({ value: n, done: false });
                    }
                    return Promise.resolve({ value: undefined, done: true });
                },
                return: function () {
                    returnCalls++;
                    return Promise.resolve({ done: true });
                }
            };
        }
    };
    for await (var v of iterableBreak) {
        if (v === 2) {
            break;
        }
    }
    assertEq(returnCalls, 1, "ASY-I-003: for-await break invokes async iterator return");

    // --- ASY-I-004: rejected next() propagates ---
    var iterableRej = {
        [Symbol.asyncIterator]: function () {
            return {
                next: function () {
                    return Promise.reject(new Error("next-fail"));
                }
            };
        }
    };
    var i4caught = null;
    try {
        for await (var _z of iterableRej) {
            /* empty */
        }
    } catch (e) {
        i4caught = e.message;
    }
    assertEq(i4caught, "next-fail", "ASY-I-004: rejected iterator next propagates as throw");

    // --- ASY-I-005 ---
    async function* gen() {
        yield "p";
    }
    var it = gen();
    var n = it.next();
    assert(n instanceof Promise, "ASY-I-005: async generator next() returns Promise");
    var nv = await n;
    assertEq(nv.value, "p", "ASY-I-005: awaited iterator result value");
    assertEq(nv.done, false, "ASY-I-005: not done");

    // --- ASY-I-006: throw/return on async generator iterator ---
    async function* gen6() {
        try {
            yield 1;
            yield 2;
        } catch (e) {
            yield "caught:" + e.message;
        }
    }
    var it6 = gen6();
    await it6.next();
    var r6t = await it6.throw(new Error("t6"));
    assertEq(r6t.value, "caught:t6", "ASY-I-006: throw() drives async generator catch path");
    var r6r = await it6.return("done");
    assertEq(r6r.value, "done", "ASY-I-006: return() supplies completion value");
    assertEq(r6r.done, true, "ASY-I-006: return() marks done");

    // --- ASY-E-005: no asyncIterator and no iterator → TypeError ---
    var e5 = null;
    try {
        await (async function () {
            var bad = { notIterable: true };
            for await (var q of bad) {
                return q;
            }
        })();
    } catch (e) {
        e5 = e;
    }
    assert(e5 instanceof TypeError, "ASY-E-005: for-await-of non-iterable throws TypeError");

    __jacDone();
}

main().catch(function (e) {
    console.error("FAIL: ASY async iteration semantics: " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
