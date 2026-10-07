// ASYNC_PROMISES_AWAIT_COMPREHENSIVE_TEST_PLAN.md — ECG-ASY-PROMISE-CORE (ASY-P-*, ASY-T-*)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/17_promises/test_promises_core.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrowsSync(fn, ErrClass, msg) {
    try {
        fn();
        console.error("FAIL: " + msg + " | expected synchronous throw");
        __reg.bump(); return;
    } catch (e) {
        if (!(e instanceof ErrClass)) {
            console.error("FAIL: " + msg + " | wrong type: " + (e && e.name));
            __reg.bump(); return;
        }
    }
}

async function main() {
    // --- ASY-P-001: executor synchronous before constructor returns ---
    var ran = false;
    var p001 = new Promise(function (resolve) {
        ran = true;
        resolve(41);
    });
    assert(ran, "ASY-P-001: executor ran synchronously before await");
    assertEq(await p001, 41, "ASY-P-001: resolved value");

    // --- ASY-P-002: resolve fulfills; observable via then ---
    var p002 = new Promise(function (resolve) {
        resolve("ok");
    });
    assertEq(await p002.then(function (v) { return v + "!"; }), "ok!", "ASY-P-002: fulfill via microtask chain");

    // --- ASY-P-003: reject observable; later resolve ignored ---
    var p003 = new Promise(function (resolve, reject) {
        reject(new Error("first"));
        resolve(99);
    });
    var msg003 = null;
    await p003.catch(function (e) {
        msg003 = e.message;
    });
    assertEq(msg003, "first", "ASY-P-003: reject wins; later resolve ignored");

    // --- ASY-P-004: throw in executor rejects promise ---
    var p004 = new Promise(function () {
        throw new Error("exec-throw");
    });
    var caught004 = false;
    await p004.catch(function (e) {
        caught004 = e.message === "exec-throw";
    });
    assert(caught004, "ASY-P-004: executor throw rejects promise");

    // --- ASY-P-005: non-callable executor → TypeError ---
    assertThrowsSync(
        function () {
            new Promise(1);
        },
        TypeError,
        "ASY-P-005: non-function executor throws TypeError"
    );

    // --- ASY-P-006: resolve then reject keeps fulfillment ---
    var p006 = new Promise(function (resolve, reject) {
        resolve(1);
        reject(new Error("no"));
    });
    assertEq(await p006, 1, "ASY-P-006: first resolve wins; later reject ignored");

    // --- ASY-P-007: reject then resolve keeps rejection ---
    var p007 = new Promise(function (resolve, reject) {
        reject(new Error("stay"));
        resolve(2);
    });
    var m007 = null;
    await p007.catch(function (e) {
        m007 = e.message;
    });
    assertEq(m007, "stay", "ASY-P-007: first reject wins; later resolve ignored");

    // --- ASY-P-008: resolve with thenable that later rejects ---
    var lateThenable = {
        then: function (_f, rej) {
            setTimeout(function () {
                rej(new Error("late-rej"));
            }, 0);
        }
    };
    var p008 = new Promise(function (resolve) {
        resolve(lateThenable);
    });
    var m008 = null;
    await p008.catch(function (e) {
        m008 = e.message;
    });
    assertEq(m008, "late-rej", "ASY-P-008: promise adopts thenable that eventually rejects");

    // --- ASY-T-001: then maps fulfillment ---
    var t1 = await Promise.resolve(2)
        .then(function (v) {
            return v + 1;
        })
        .then(function (v) {
            return String(v) + "x";
        });
    assertEq(t1, "3x", "ASY-T-001: then chain maps fulfilled value");

    // --- ASY-T-002: throw in onFulfilled rejects child promise ---
    var t2msg = null;
    await Promise.resolve(1)
        .then(function () {
            throw new Error("in-then");
        })
        .catch(function (e) {
            t2msg = e.message;
        });
    assertEq(t2msg, "in-then", "ASY-T-002: throw in onFulfilled rejects derived promise");

    // --- ASY-T-003: then(undefined, onRejected) recovers ---
    var t3 = await Promise.reject(new Error("z"))
        .then(undefined, function () {
            return 10;
        })
        .then(function (v) {
            return v + 1;
        });
    assertEq(t3, 11, "ASY-T-003: onRejected recovers to fulfillment");

    // --- ASY-T-004: catch is sugar for then(undefined, fn) ---
    var t4a = await Promise.reject(new Error("c")).catch(function () {
        return "recovered";
    });
    assertEq(t4a, "recovered", "ASY-T-004: catch handles rejection like then(undefined, fn)");

    // --- ASY-T-005: omitted handlers pass through ---
    var t5 = await Promise.resolve(100)
        .then()
        .then(undefined)
        .then(function (v) {
            return v + 1;
        });
    assertEq(t5, 101, "ASY-T-005: omitted then handlers pass fulfillment");

    var t5r = await Promise.reject(new Error("pass"))
        .then()
        .catch(function (e) {
            return e.message;
        });
    assertEq(t5r, "pass", "ASY-T-005: omitted fulfillment handler passes rejection");

    // --- ASY-T-006: return Promise from handler flattens ---
    var t6 = await Promise.resolve(1).then(function () {
        return Promise.resolve(2);
    });
    assertEq(t6, 2, "ASY-T-006: returned Promise is adopted (flattened)");
    var thenable6 = {
        then: function (f) {
            f(7);
        }
    };
    var t6b = await Promise.resolve(0).then(function () {
        return thenable6;
    });
    assertEq(t6b, 7, "ASY-T-006: returned thenable is assimilated");

    // --- ASY-T-007 / ASY-T-008: finally runs both paths; pass-through unless throw/rejected ---
    var finLog = "";
    var t7a = await Promise.resolve("ok").finally(function () {
        finLog += "A";
    });
    assertEq(t7a, "ok", "ASY-T-007: fulfill passes through finally");
    await Promise.reject(new Error("r")).finally(function () {
        finLog += "B";
    }).catch(function () {});
    assertEq(finLog, "AB", "ASY-T-007: finally ran for fulfill and reject");

    var t8 = await Promise.resolve(7).finally(function () {
        return Promise.resolve(999);
    });
    assertEq(t8, 7, "ASY-T-008: fulfilled finally ignores returned fulfilled promise");
    var t8b = null;
    await Promise.resolve(1)
        .finally(function () {
            return Promise.reject(new Error("fin-rej"));
        })
        .catch(function (e) {
            t8b = e.message;
        });
    assertEq(t8b, "fin-rej", "ASY-T-008: rejected thenable from finally rejects chain");

    // --- ASY-T-009: handler not invoked synchronously with registration ---
    var ranSync = false;
    Promise.resolve(1).then(function () {
        ranSync = true;
    });
    assert(!ranSync, "ASY-T-009: then callback not run in same synchronous turn as then()");
    await Promise.resolve();
    assert(ranSync, "ASY-T-009: then callback runs after current turn (microtask)");

    __jacDone();
}

main().catch(function (e) {
    console.error("FAIL: ASY promises core: " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
