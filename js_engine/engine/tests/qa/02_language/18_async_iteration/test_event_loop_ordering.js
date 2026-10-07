// ASYNC-010 through ASYNC-014: Event loop ordering
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/18_async_iteration/test_event_loop_ordering.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

// ASYNC-010: Microtask (Promise.then) runs before setTimeout macrotask
var order10 = [];
setTimeout(function() { order10.push("macro"); }, 0);
Promise.resolve().then(function() { order10.push("micro"); });

// ASYNC-011: process.nextTick runs before Promise microtasks
var order11 = [];
Promise.resolve().then(function() { order11.push("micro"); });
process.nextTick(function() { order11.push("nextTick"); });

// ASYNC-012: queueMicrotask ordering — same phase as Promise.then, before setTimeout
var order12 = [];
setTimeout(function() { order12.push("macro"); }, 0);
queueMicrotask(function() { order12.push("qm"); });
Promise.resolve().then(function() { order12.push("prom"); });

// ASYNC-013: setTimeout vs setImmediate ordering
// setImmediate fires in the check phase, after I/O, possibly before or after setTimeout(0)
// We just verify both fire and setImmediate fires without requiring a specific order.
var order13 = [];
setTimeout(function() { order13.push("timeout"); }, 0);
setImmediate(function() { order13.push("immediate"); });

// ASYNC-014: Nested microtasks — spawning a microtask from within a microtask
// runs before any macro task
var order14 = [];
setTimeout(function() { order14.push("macro"); }, 0);
Promise.resolve().then(function() {
    order14.push("micro1");
    // Spawn another microtask from within — must run before macro
    return Promise.resolve().then(function() { order14.push("micro2"); });
});

// Verify everything after one setTimeout fires (allow all microtasks to settle first)
setTimeout(function() {
    // ASYNC-010 check
    assert(order10.indexOf("micro") < order10.indexOf("macro"),
        "ASYNC-010: Promise.then before setTimeout macro");

    // ASYNC-011 check
    assert(order11.indexOf("nextTick") < order11.indexOf("micro"),
        "ASYNC-011: nextTick before Promise microtask");

    // ASYNC-012 check
    assert(order12.indexOf("macro") > order12.indexOf("qm"),
        "ASYNC-012: queueMicrotask before setTimeout macro");
    // queueMicrotask and Promise.then both in microtask queue — just verify both before macro
    assert(order12.indexOf("macro") > order12.indexOf("prom"),
        "ASYNC-012: Promise.then before setTimeout macro (with queueMicrotask)");

    // ASYNC-013 check — both must have fired
    assert(order13.indexOf("timeout") !== -1,   "ASYNC-013: setTimeout fired");
    assert(order13.indexOf("immediate") !== -1,  "ASYNC-013: setImmediate fired");

    // ASYNC-014 check — both microtasks before macro
    assert(order14.indexOf("micro1") !== -1,  "ASYNC-014: micro1 fired");
    assert(order14.indexOf("micro2") !== -1,  "ASYNC-014: micro2 (nested) fired");
    assert(order14.indexOf("macro") > order14.indexOf("micro2"),
        "ASYNC-014: nested microtask before macro");

    __jacDone();
}, 200);
