// RT-040 through RT-045: Timer globals exist as functions (synchronous)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_timer_types.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

assert(typeof setTimeout === "function",    "RT-040: typeof setTimeout === 'function'");
assert(typeof clearTimeout === "function",  "RT-041: typeof clearTimeout === 'function'");
assert(typeof setInterval === "function",   "RT-042: typeof setInterval === 'function'");
assert(typeof clearInterval === "function", "RT-043: typeof clearInterval === 'function'");
assert(typeof setImmediate === "function",  "RT-044: typeof setImmediate === 'function'");
assert(typeof clearImmediate === "function","RT-045: typeof clearImmediate === 'function'");

// setTimeout / setInterval must return a usable timer handle.
// Browsers/js_engine return a number; Node.js returns a Timeout object — both are valid.
var id1 = setTimeout(function(){}, 9999);
assert(id1 !== null && id1 !== undefined, "RT-040: setTimeout returns a non-null timer handle");
clearTimeout(id1);

var id2 = setInterval(function(){}, 9999);
assert(id2 !== null && id2 !== undefined, "RT-042: setInterval returns a non-null timer handle");
clearInterval(id2);

__jacDone();
