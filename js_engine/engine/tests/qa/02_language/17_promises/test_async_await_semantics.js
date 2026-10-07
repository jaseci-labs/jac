// ASYNC_PROMISES_AWAIT_COMPREHENSIVE_TEST_PLAN.md — ECG-ASY-AWAIT (ASY-A-001..009, ASY-E-004)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/17_promises/test_async_await_semantics.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function main() {
    // --- ASY-A-001 ---
    async function a1() {
        return 6;
    }
    var pr = a1();
    assert(pr instanceof Promise, "ASY-A-001: async function returns Promise");
    assertEq(await pr, 6, "ASY-A-001: fulfilled with return value");

    // --- ASY-A-002 ---
    assertEq(await (async function () { return await Promise.resolve(3); })(), 3, "ASY-A-002: return await resolved");

    // --- ASY-A-003 ---
    var caught = null;
    try {
        await (async function () {
            throw new Error("async-throw");
        })();
    } catch (e) {
        caught = e.message;
    }
    assertEq(caught, "async-throw", "ASY-A-003: throw in async body rejects returned promise");

    // --- ASY-A-004 ---
    assertEq(await (async function () { return await Promise.resolve("x"); })(), "x", "ASY-A-004: await promise resumes with value");

    // --- ASY-A-005 ---
    assertEq(
        await (async function () {
            try {
                await Promise.reject(new Error("await-rej"));
                return "bad";
            } catch (e) {
                return "ok:" + e.message;
            }
        })(),
        "ok:await-rej",
        "ASY-A-005: await rejected promise throws into async body"
    );

    // --- ASY-A-006 ---
    assertEq(await (async function () { return await 99; })(), 99, "ASY-A-006: await non-thenable value");

    // --- ASY-A-007 ---
    var th = {
        then: function (f) {
            f(4);
        }
    };
    assertEq(await (async function () { return await th; })(), 4, "ASY-A-007: await assimilates thenable");

    // --- ASY-A-008 ---
    var arrow = async function (x) {
        return x * 3;
    };
    assertEq(await arrow(4), 12, "ASY-A-008: async arrow");
    var obj = {
        async m() {
            return await Promise.resolve(8);
        }
    };
    assertEq(await obj.m(), 8, "ASY-A-008: async method");

    // --- ASY-A-009: return await rejected — promise still rejects (same reason) ---
    var eDirect = null;
    await (async function () {
        return Promise.reject(new Error("rd"));
    })().catch(function (e) {
        eDirect = e.message;
    });
    var eAwait = null;
    await (async function () {
        return await Promise.reject(new Error("rd"));
    })().catch(function (e) {
        eAwait = e.message;
    });
    assertEq(eDirect, "rd", "ASY-A-009: return rejected promise rejects async result");
    assertEq(eAwait, "rd", "ASY-A-009: return await rejected promise rejects async result with same reason");

    // --- ASY-E-004: try/finally with await on fulfill and reject paths ---
    var fin = "";
    assertEq(
        await (async function () {
            try {
                return await Promise.resolve(1);
            } finally {
                fin += "F";
            }
        })(),
        1,
        "ASY-E-004: finally runs after fulfilled await"
    );
    assertEq(fin, "F", "ASY-E-004: finally recorded for fulfill path");

    var fin2 = "";
    var caughtE4 = null;
    try {
        await (async function () {
            try {
                await Promise.reject(new Error("e4"));
            } finally {
                fin2 += "G";
            }
        })();
    } catch (e) {
        caughtE4 = e.message;
    }
    assertEq(caughtE4, "e4", "ASY-E-004: rejection propagates after finally");
    assertEq(fin2, "G", "ASY-E-004: finally runs on reject path before throw propagates");

    __jacDone();
}

main().catch(function (e) {
    console.error("FAIL: ASY async await semantics: " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
