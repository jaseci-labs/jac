// ASYNC_PROMISES_AWAIT_COMPREHENSIVE_TEST_PLAN.md — ECG-ASY-SCHED (ASY-M-*)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/17_promises/test_microtask_ordering.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function main() {
    // --- ASY-M-001: Promise.then before setTimeout(0) ---
    var m1 = [];
    setTimeout(function () {
        m1.push("macro");
    }, 0);
    await Promise.resolve().then(function () {
        m1.push("micro");
    });
    assertEq(m1[0], "micro", "ASY-M-001: microtask runs before pending macrotask");

    // --- ASY-M-002 / M-003: queueMicrotask and nested microtasks before macro ---
    if (typeof queueMicrotask === "function") {
        var m2 = [];
        setTimeout(function () {
            m2.push("macro");
        }, 0);
        queueMicrotask(function () {
            m2.push("qm");
        });
        await Promise.resolve().then(function () {
            m2.push("prom");
        });
        assert(m2.indexOf("qm") !== -1, "ASY-M-002: queueMicrotask ran");
        assert(m2.indexOf("prom") !== -1, "ASY-M-002: Promise.then ran");
        await new Promise(function (r) {
            setTimeout(r, 25);
        });
        assert(m2.indexOf("macro") > m2.indexOf("qm"), "ASY-M-002: queueMicrotask before macro");
        assert(m2.indexOf("macro") > m2.indexOf("prom"), "ASY-M-002: Promise.then before macro");

        var m3 = [];
        setTimeout(function () {
            m3.push("macro");
        }, 0);
        await Promise.resolve().then(function () {
            m3.push("inner1");
            return Promise.resolve().then(function () {
                m3.push("inner2");
            });
        });
        assert(m3.indexOf("inner1") < m3.indexOf("inner2"), "ASY-M-003: nested microtask order");
        await new Promise(function (r) {
            setTimeout(r, 25);
        });
        assert(m3.indexOf("macro") > m3.indexOf("inner2"), "ASY-M-003: nested microtasks before macro");
    }

    // --- ASY-M-004: multiple reactions on same promise run in registration order ---
    var order = [];
    var p = Promise.resolve();
    p.then(function () {
        order.push("1");
    });
    p.then(function () {
        order.push("2");
    });
    p.then(function () {
        order.push("3");
    });
    await p;
    assertEq(order.join(","), "1,2,3", "ASY-M-004: then callbacks on same promise run FIFO");

    // --- ASY-M-005: caught exception in microtask; subsequent microtasks still run ---
    var log = [];
    Promise.resolve().then(function () {
        try {
            throw new Error("boom");
        } catch (e) {
            log.push("caught");
        }
    });
    Promise.resolve().then(function () {
        log.push("after");
    });
    await Promise.resolve();
    assertEq(log.join(","), "caught,after", "ASY-M-005: caught microtask error; subsequent microtask runs");

    __jacDone();
}

main().catch(function (e) {
    console.error("FAIL: ASY microtask ordering: " + e);
    __reg.bump(); __jacDone();
});
