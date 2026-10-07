// ASYNC_PROMISES_AWAIT_COMPREHENSIVE_TEST_PLAN.md — ECG-ASY-PROMISE-CORE (ASY-S-*)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/17_promises/test_promise_statics.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

function delay(ms, v) {
    return new Promise(function (res) {
        setTimeout(function () {
            res(v);
        }, ms);
    });
}

async function main() {
    // --- ASY-S-001 ---
    var inner = Promise.resolve(5);
    assert(Promise.resolve(inner) === inner, "ASY-S-001: Promise.resolve returns same Promise instance");

    // --- ASY-S-002 ---
    var thenable = {
        then: function (onFulfilled) {
            onFulfilled(88);
        }
    };
    assertEq(await Promise.resolve(thenable), 88, "ASY-S-002: Promise.resolve assimilates thenable");

    // --- ASY-S-003 ---
    var r3 = null;
    await Promise.reject(new Error("rj")).catch(function (e) {
        r3 = e.message;
    });
    assertEq(r3, "rj", "ASY-S-003: Promise.reject delivers exact rejection reason");

    // --- ASY-S-004: result order matches input order, not completion order ---
    var out = await Promise.all([delay(25, "a"), delay(5, "b")]);
    assertEq(out.join(","), "a,b", "ASY-S-004: Promise.all preserves input order despite completion order");

    // --- ASY-S-005 ---
    var firstRej = null;
    await Promise.all([
        Promise.reject(new Error("alpha")),
        Promise.reject(new Error("beta"))
    ]).catch(function (e) {
        firstRej = e.message;
    });
    assertEq(firstRej, "alpha", "ASY-S-005: first rejection in iterator order wins");

    // --- ASY-S-006 ---
    var empty = await Promise.all([]);
    assertEq(empty.length, 0, "ASY-S-006: Promise.all([]) fulfills with empty array");

    // --- ASY-S-007 ---
    var c7 = await Promise.allSettled([Promise.resolve(1), Promise.reject(new Error("n"))]);
    assertEq(c7[0].status, "fulfilled", "ASY-S-007: allSettled first fulfilled");
    assertEq(c7[1].status, "rejected", "ASY-S-007: allSettled second rejected");
    assertEq(c7[1].reason.message, "n", "ASY-S-007: reason on rejected entry");

    // --- ASY-S-008: race first fulfill ---
    var c8a = await Promise.race([delay(40, "slow"), delay(5, "fast")]);
    assertEq(c8a, "fast", "ASY-S-008: race first fulfillment wins");

    // --- ASY-S-008: race first reject ---
    var c8b = null;
    await Promise.race([
        delay(40, "slow"),
        Promise.reject(new Error("early-rej"))
    ]).catch(function (e) {
        c8b = e.message;
    });
    assertEq(c8b, "early-rej", "ASY-S-008: race first rejection wins");

    // --- ASY-S-009 ---
    var c9 = await Promise.any([
        Promise.reject(new Error("a")),
        Promise.resolve("win"),
        Promise.reject(new Error("b"))
    ]);
    assertEq(c9, "win", "ASY-S-009: Promise.any first fulfillment");

    // --- ASY-S-010 ---
    var agg = null;
    await Promise.any([Promise.reject(new Error("x")), Promise.reject(new Error("y"))]).catch(function (e) {
        agg = e;
    });
    assert(agg !== null, "ASY-S-010: all reject yields rejection reason");
    if (typeof AggregateError === "function") {
        assert(agg instanceof AggregateError, "ASY-S-010: AggregateError when supported");
        assert(Array.isArray(agg.errors), "ASY-S-010: errors array on AggregateError");
    }

    // --- ASY-S-011: non-iterable → rejected promise with TypeError (Node returns promise, not sync throw) ---
    var s11a = null;
    await Promise.all(null).catch(function (e) {
        s11a = e;
    });
    assert(s11a instanceof TypeError, "ASY-S-011: Promise.all(null) rejects with TypeError");

    var s11b = null;
    await Promise.allSettled(undefined).catch(function (e) {
        s11b = e;
    });
    assert(s11b instanceof TypeError, "ASY-S-011: Promise.allSettled(undefined) rejects with TypeError");

    var s11c = null;
    await Promise.race(123).catch(function (e) {
        s11c = e;
    });
    assert(s11c instanceof TypeError, "ASY-S-011: Promise.race(non-iterable) rejects with TypeError");

    var s11d = null;
    await Promise.any({}).catch(function (e) {
        s11d = e;
    });
    assert(s11d instanceof TypeError, "ASY-S-011: Promise.any(non-iterable) rejects with TypeError");

    __jacDone();
}

main().catch(function (e) {
    console.error("FAIL: ASY promise statics: " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
