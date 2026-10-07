// ASYNC-001 through ASYNC-004: Async generators and for-await-of
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/18_async_iteration/test_async_iteration.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function main() {
    // ASYNC-001: async function* — async generator
    async function* asyncCounter(start, end) {
        for (var i = start; i <= end; i++) {
            await new Promise(function(r) { setTimeout(r, 120); });
            yield i;
        }
    }
    var vals1 = [];
    for await (var v of asyncCounter(1, 4)) { vals1.push(v); }
    assertEq(vals1.join(","), "1,2,3,4", "ASYNC-001: async generator values");

    // ASYNC-002: for await...of — async iterable, async generator
    async function* gen2() { yield "a"; yield "b"; yield "c"; }
    var vals2 = [];
    for await (var v2 of gen2()) { vals2.push(v2); }
    assertEq(vals2.join(","), "a,b,c", "ASYNC-002: for-await-of async generator");

    // ASYNC-003: for await + sync Promises
    var promises = [Promise.resolve(10), Promise.resolve(20), Promise.resolve(30)];
    var vals3 = [];
    for await (var p of promises) { vals3.push(p); }
    assertEq(vals3.join(","), "10,20,30", "ASYNC-003: for-await-of over Promise array");

    // ASYNC-004: Async gen next/return/throw — return Promises
    async function* gen4() {
        try {
            yield 1;
            yield 2;
        } catch(e) {
            yield "caught:" + e.message;
        }
    }
    var it4 = gen4();
    var r4a = await it4.next();
    assertEq(r4a.value, 1,    "ASYNC-004: async gen next() returns Promise resolving to {value,done}");
    assertEq(r4a.done,  false,"ASYNC-004: not done");

    var r4t = await it4.throw(new Error("thrown"));
    assertEq(r4t.value, "caught:thrown", "ASYNC-004: throw() caught inside async gen");

    var r4ret = await it4.return("final");
    assertEq(r4ret.value, "final", "ASYNC-004: return() value");
    assertEq(r4ret.done,  true,    "ASYNC-004: done after return()");

    __jacDone();
}

main().catch(function(e) {
    console.error("FAIL: " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
