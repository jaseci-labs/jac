// RT-036: queueMicrotask — callback runs as microtask, before setTimeout
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/03_global_functions/test_queue_microtask.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

assert(typeof queueMicrotask === "function", "RT-036: queueMicrotask is a function");

var order = [];
queueMicrotask(function() { order.push("microtask"); });

setTimeout(function() {
    order.push("timeout");
    assert(order.length === 2, "RT-036: both microtask and timeout fired");
    assert(order[0] === "microtask", "RT-036: microtask ran before setTimeout callback");
    assert(order[1] === "timeout",  "RT-036: timeout ran second");
    __jacDone();
}, 20);
