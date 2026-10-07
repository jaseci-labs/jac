// PROM-001 through PROM-012: Promises and async/await
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/17_promises/test_promises.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

async function main() {
    // PROM-001: Constructor — executor runs synchronously, receives resolve/reject
    var executorRan = false;
    var p1 = new Promise(function(resolve, reject) {
        executorRan = true;
        resolve(42);
    });
    assert(executorRan, "PROM-001: executor runs synchronously");
    assertEq(await p1, 42, "PROM-001: resolved value");

    var p1r = new Promise(function(resolve, reject) { reject(new Error("fail")); });
    var caught1 = await p1r.catch(function(e) { return "caught:" + e.message; });
    assertEq(caught1, "caught:fail", "PROM-001: reject triggers catch");

    // PROM-002: then — onFulfilled, onRejected, chaining
    var p2 = Promise.resolve(1)
        .then(function(v) { return v + 1; })
        .then(function(v) { return v * 3; });
    assertEq(await p2, 6, "PROM-002: chained then");

    // onRejected in then
    var p2r = Promise.reject(new Error("x"))
        .then(null, function(e) { return "handled:" + e.message; });
    assertEq(await p2r, "handled:x", "PROM-002: then onRejected");

    // PROM-003: catch
    var p3 = Promise.reject(new Error("catch-me"))
        .catch(function(e) { return "caught:" + e.message; });
    assertEq(await p3, "caught:catch-me", "PROM-003: catch handler");
    // catch is sugar for then(undefined, handler) — recovered value continues chain
    var p3chain = Promise.reject(new Error("c"))
        .catch(function(e) { return 99; })
        .then(function(v) { return v + 1; });
    assertEq(await p3chain, 100, "PROM-003: catch recovery continues chain");

    // PROM-004: finally — called on both fulfilled and rejected, value passes through
    var fin4a = "";
    var p4a = Promise.resolve("ok").finally(function() { fin4a = "fin-ran"; });
    assertEq(await p4a, "ok",      "PROM-004: finally fulfilled value passes through");
    assertEq(fin4a, "fin-ran",     "PROM-004: finally ran on fulfill");

    var fin4b = "";
    var p4b = Promise.reject(new Error("rej"))
        .finally(function() { fin4b = "fin-ran"; })
        .catch(function(e) { return "caught"; });
    await p4b;
    assertEq(fin4b, "fin-ran",    "PROM-004: finally ran on reject");

    // PROM-005: Promise.resolve — wraps value, returns same Promise
    assertEq(await Promise.resolve(7), 7, "PROM-005: resolve wraps value");
    var existing = Promise.resolve(5);
    assert(Promise.resolve(existing) === existing, "PROM-005: resolve returns same Promise");

    // PROM-006: Promise.reject — always wraps (never unwraps)
    var rejVal = null;
    await Promise.reject(new Error("rej6")).catch(function(e) { rejVal = e.message; });
    assertEq(rejVal, "rej6", "PROM-006: reject wraps error");

    // PROM-007: Promise.all
    var all7 = await Promise.all([Promise.resolve(1), Promise.resolve(2), Promise.resolve(3)]);
    assertEq(all7.join(","), "1,2,3",  "PROM-007: all fulfilled, order preserved");
    // one rejects — all rejects
    var rej7 = null;
    await Promise.all([Promise.resolve(1), Promise.reject(new Error("boom")), Promise.resolve(3)])
        .catch(function(e) { rej7 = e.message; });
    assertEq(rej7, "boom", "PROM-007: one reject causes all to reject");
    // empty
    var empty7 = await Promise.all([]);
    assertEq(empty7.length, 0, "PROM-007: empty array resolves to []");

    // PROM-008: Promise.allSettled
    var settled = await Promise.allSettled([
        Promise.resolve("ok"),
        Promise.reject(new Error("no")),
        Promise.resolve(42)
    ]);
    assertEq(settled.length, 3,             "PROM-008: allSettled length");
    assertEq(settled[0].status,  "fulfilled","PROM-008: first fulfilled");
    assertEq(settled[0].value,   "ok",       "PROM-008: first value");
    assertEq(settled[1].status,  "rejected", "PROM-008: second rejected");
    assertEq(settled[1].reason.message, "no","PROM-008: second reason");
    assertEq(settled[2].status,  "fulfilled","PROM-008: third fulfilled");

    // PROM-009: Promise.race — first settles wins
    function delay(ms, v) { return new Promise(function(r) { setTimeout(function() { r(v); }, ms); }); }
    var race9 = await Promise.race([delay(50, "slow"), delay(10, "fast")]);
    assertEq(race9, "fast", "PROM-009: race returns first settled");

    // PROM-010: Promise.any — first fulfill; all reject = AggregateError
    var any10 = await Promise.any([
        Promise.reject(new Error("r1")),
        Promise.resolve("winner"),
        Promise.reject(new Error("r2"))
    ]);
    assertEq(any10, "winner", "PROM-010: any returns first fulfilled");
    // all reject
    var agg = null;
    await Promise.any([Promise.reject(new Error("a")), Promise.reject(new Error("b"))])
        .catch(function(e) { agg = e; });
    assert(agg !== null,                 "PROM-010: all rejected gives AggregateError");
    assert(Array.isArray(agg.errors),    "PROM-010: AggregateError has errors array");

    // PROM-011: Microtask ordering — then runs before setTimeout
    var order11 = [];
    setTimeout(function() { order11.push("macro"); }, 0);
    await Promise.resolve().then(function() { order11.push("micro"); });
    // at this point micro has run; macro runs after
    assertEq(order11[0], "micro", "PROM-011: Promise.then before setTimeout macro");

    // PROM-012: Promise chain — multi-level, error propagation, recovery
    var chain12 = await Promise.resolve(1)
        .then(function(v) { return v + 1; })           // 2
        .then(function(v) { throw new Error("mid"); }) // throws
        .then(function(v) { return "skipped"; })        // skipped
        .catch(function(e) { return e.message; })       // "mid"
        .then(function(v) { return v + "-recovered"; });// "mid-recovered"
    assertEq(chain12, "mid-recovered", "PROM-012: error propagation and recovery in chain");

    __jacDone();
}

main().catch(function(e) {
    console.error("FAIL: unhandled: " + e);
    __reg.bump(); __jacDone();
});
