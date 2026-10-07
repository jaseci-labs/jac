// RT-042: setInterval — callback fires repeatedly
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_setinterval.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var count = 0;
var id = setInterval(function() {
    count++;
    if (count >= 3) {
        clearInterval(id);
        __jacDone();
    }
}, 30);

setTimeout(function() {
    assert(false, "RT-042: setInterval callback did not fire 3 times within 500ms (count=" + count + ")");
}, 500);
