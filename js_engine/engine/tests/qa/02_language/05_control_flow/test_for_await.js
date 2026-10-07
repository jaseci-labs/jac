// CF-013: for await...of — async iterables
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/05_control_flow/test_for_await.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function main() {
    // CF-013: for-await-of over async generator
    async function* asyncGen() {
        yield 1;
        yield 2;
        yield 3;
    }
    var vals = [];
    for await (var v of asyncGen()) { vals.push(v); }
    assertEq(vals.join(","), "1,2,3", "CF-013: for-await-of over async generator");

    // CF-013: for-await-of over array of Promises
    var promises = [Promise.resolve("a"), Promise.resolve("b"), Promise.resolve("c")];
    var resolved = [];
    for await (var p of promises) { resolved.push(p); }
    assertEq(resolved.join(","), "a,b,c", "CF-013: for-await-of over Promise array");

    __jacDone();
}

main().catch(function(e) {
    console.error("FAIL: CF-013 async error: " + e);
    __reg.bump(); __jacDone();
});
__jacDone();
