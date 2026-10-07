// RT-044: setImmediate — callback invoked in next event loop iteration
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_setimmediate.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var fired = false;

setImmediate(function() {
    fired = true;
    __jacDone();
});

// guard
setTimeout(function() {
    assert(false, "RT-044: setImmediate callback did not fire within 500ms");
}, 500);
