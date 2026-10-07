// FUNC-040 through FUNC-043: Async functions
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/07_functions/test_async_functions.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function main() {
    // FUNC-040: async function returns a Promise
    async function af() { return 42; }
    var p = af();
    assert(p instanceof Promise, "FUNC-040: async function returns Promise");
    var resolved = await p;
    assertEq(resolved, 42, "FUNC-040: Promise resolves with return value");

    // FUNC-041: await resolved, rejected, non-Promise
    async function awaitResolved() { return await Promise.resolve("ok"); }
    assertEq(await awaitResolved(), "ok", "FUNC-041: await resolved Promise");

    async function awaitRejected() {
        try {
            await Promise.reject(new Error("rejected"));
            return "no-throw";
        } catch(e) {
            return "caught:" + e.message;
        }
    }
    assertEq(await awaitRejected(), "caught:rejected", "FUNC-041: await rejected Promise caught");

    async function awaitNonPromise() { return await 99; }
    assertEq(await awaitNonPromise(), 99, "FUNC-041: await non-Promise returns value");

    // FUNC-042: async arrow function
    var asyncArrow = async (x) => x * 2;
    assertEq(await asyncArrow(5), 10, "FUNC-042: async arrow function");

    var asyncArrowAwait = async () => {
        var v = await Promise.resolve(21);
        return v * 2;
    };
    assertEq(await asyncArrowAwait(), 42, "FUNC-042: async arrow with await");

    // FUNC-043: sequential vs parallel await
    function delay(ms, val) {
        return new Promise(function(res) { setTimeout(function() { res(val); }, ms); });
    }

    // sequential — total time ≈ sum of delays
    var t0 = Date.now();
    var sa = await delay(120, "a");
    var sb = await delay(120, "b");
    var seqTime = Date.now() - t0;
    assertEq(sa, "a", "FUNC-043: sequential await first");
    assertEq(sb, "b", "FUNC-043: sequential await second");
    assert(seqTime >= 200, "FUNC-043: sequential takes at least sum of delays");

    // parallel — total time ≈ max of delays
    var t1 = Date.now();
    var [pa, pb] = await Promise.all([delay(120, "x"), delay(120, "y")]);
    var parTime = Date.now() - t1;
    assertEq(pa, "x", "FUNC-043: parallel result a");
    assertEq(pb, "y", "FUNC-043: parallel result b");
    // parallel should be noticeably faster than sequential
    assert(parTime < seqTime, "FUNC-043: Promise.all faster than sequential");

    __jacDone();
}

main().catch(function(e) {
    console.error("FAIL: async error: " + e);
    __reg.bump(); __jacDone();
});
