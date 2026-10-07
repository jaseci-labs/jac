// RT-045: clearImmediate — cancels a pending immediate
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_clearimmediate.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var fired = false;
var id = setImmediate(function() { fired = true; });
clearImmediate(id);

setTimeout(function() {
    assert(!fired, "RT-045: immediate was cleared — callback must not have fired");
    __jacDone();
}, 100);
