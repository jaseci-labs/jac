// RT-041: clearTimeout — cancels a pending timer
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_cleartimeout.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var cancelled = false;
var id = setTimeout(function() { cancelled = true; }, 50);
clearTimeout(id);

setTimeout(function() {
    assert(!cancelled, "RT-041: timer was cancelled — callback must not have fired");
    __jacDone();
}, 150);
