// ASYNC_PROMISES_AWAIT_COMPREHENSIVE_TEST_PLAN.md — ECG-ASY-ERRORS (ASY-E-001..003)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/17_promises/test_async_error_boundaries.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function main() {
    // --- ASY-E-001: combinator rejects when iterator setup throws ---
    var e1 = null;
    await Promise.all({
        [Symbol.iterator]: function () {
            throw new TypeError("iter-open");
        }
    }).catch(function (err) {
        e1 = err;
    });
    assert(e1 instanceof TypeError, "ASY-E-001: Promise.all rejects when Symbol.iterator throws");
    assertEq(e1.message, "iter-open", "ASY-E-001: rejection carries iterator error");

    var e1b = null;
    await Promise.allSettled({
        [Symbol.iterator]: function () {
            throw new Error("open-fail");
        }
    }).catch(function (err) {
        e1b = err;
    });
    assert(e1b instanceof Error, "ASY-E-001: Promise.allSettled rejects on iterator throw");
    assertEq(e1b.message, "open-fail", "ASY-E-001: allSettled rejection reason");

    // --- ASY-E-002: self-resolution cycle → TypeError (defer resolve so same promise is passed) ---
    var p2;
    var resolveP2;
    p2 = new Promise(function (resolve) {
        resolveP2 = resolve;
    });
    resolveP2(p2);
    var e2 = null;
    await p2.catch(function (err) {
        e2 = err;
    });
    assert(e2 instanceof TypeError, "ASY-E-002: resolve with same promise rejects with TypeError");

    // --- ASY-E-003: Promise.any([]) → AggregateError with empty errors ---
    var e3 = null;
    await Promise.any([]).catch(function (err) {
        e3 = err;
    });
    assert(e3 !== null, "ASY-E-003: Promise.any([]) rejects");
    if (typeof AggregateError === "function") {
        assert(e3 instanceof AggregateError, "ASY-E-003: rejection is AggregateError");
        assert(Array.isArray(e3.errors), "ASY-E-003: AggregateError has errors array");
        assertEq(e3.errors.length, 0, "ASY-E-003: errors array is empty");
    }

    __jacDone();
}

main().catch(function (e) {
    console.error("FAIL: ASY async error boundaries: " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
