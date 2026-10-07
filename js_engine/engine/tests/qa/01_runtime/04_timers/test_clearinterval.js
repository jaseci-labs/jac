// RT-043: clearInterval — stops a running interval
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_clearinterval.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var fired = false;
var id = setInterval(function() { fired = true; }, 40);
clearInterval(id);

setTimeout(function() {
    assert(!fired, "RT-043: interval was cleared — callback must not have fired");
    __jacDone();
}, 150);
