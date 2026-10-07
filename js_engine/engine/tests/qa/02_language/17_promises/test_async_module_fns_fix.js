// Async function defined in a required module creates a closure after an await point.
// The VM must resume the async frame in the originating module's compilation context
// so that inner function creation resolves to the correct compiled function.
// _helper_async_module_fns.js is a separate compilation unit used to exercise
// cross-module async resume.

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/17_promises/test_async_module_fns_fix.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var helper = require("./_helper_async_module_fns");

async function main() {

    // Required-module async fn creates an inner function after a single await.
    // Expected: the inner function runs correctly and returns double(21) = 42.
    var r1 = await helper.asyncArrowAfterAwait(21);
    assertEq(r1, 42, "cross-module async fn resumes and creates closure: double(21) === 42");

    // Required-module async fn creates two inner functions (add, mul) after a single await.
    // Expected: add(mul(3,13), 3) = 42.
    var r2 = await helper.asyncChainedAfterAwait(3, 13);
    assertEq(r2, 42, "cross-module async fn creates two closures after await: 3*13+3 === 42");

    // Required-module async fn suspends twice before creating an inner function.
    // Expected: triple(14) = 42.
    var r3 = await helper.asyncNestedAwait();
    assertEq(r3, 42, "cross-module async fn creates closure after two awaits: triple(14) === 42");

    // Async fn defined in the same module creates a closure after an await.
    // Expected: double(21) = 42 (same-module case must not regress).
    async function localAsync(n) {
        await Promise.resolve();
        var double = function(x) { return x * 2; };
        return double(n);
    }
    var r4 = await localAsync(21);
    assertEq(r4, 42, "same-module async closure after await: double(21) === 42");

    // Cross-module and same-module async calls run concurrently via Promise.all.
    // Expected: each returns the correct value without interfering with the other.
    async function localMul(a, b) {
        await Promise.resolve();
        var mul = function(x, y) { return x * y; };
        return mul(a, b);
    }
    var p1 = helper.asyncArrowAfterAwait(7);
    var p2 = localMul(6, 7);
    var results = await Promise.all([p1, p2]);
    assertEq(results[0], 14, "Promise.all: cross-module double(7) === 14");
    assertEq(results[1], 42, "Promise.all: same-module mul(6,7) === 42");
}

main().then(__jacDone).catch(function(e) {
    __reg.assert(false, "FATAL: " + (e && e.stack ? e.stack : String(e)));
    __jacDone();
});
