// RT-040: setTimeout — callback fires, delay=0 works, extra args forwarded
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_settimeout.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var step = 0;

// delay=0 fires callback
setTimeout(function() {
    assert(step === 0, "RT-040: delay=0 callback fires (step check)");
    step = 1;
}, 0);

// extra arguments forwarded to callback
setTimeout(function(a, b) {
    assert(a === "hello", "RT-040: first arg forwarded to callback");
    assert(b === 42,      "RT-040: second arg forwarded to callback");
    step = 2;
}, 20, "hello", 42);

// guard: if neither callback fires, we never reach this — engine exits non-zero
setTimeout(function() {
    assert(step === 2, "RT-040: both callbacks ran before guard timeout");
    __jacDone();
}, 200);
