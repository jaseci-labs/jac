// Vite V-04: setTimeout/setInterval return handles with .unref() / .ref()
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/04_timers/test_timer_unref_ref.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var t = setTimeout(function () {}, 10000);
assert(typeof t === "object" && t !== null, "V-04: setTimeout returns object handle");
assert(typeof t.unref === "function", "V-04: handle has unref");
assert(typeof t.ref === "function", "V-04: handle has ref");
assert(t.unref() === t, "V-04: unref returns this");
assert(t.ref() === t, "V-04: ref returns this");
clearTimeout(t);

var iv = setInterval(function () {}, 10000);
assert(typeof iv.unref === "function", "V-04: interval handle has unref");
clearInterval(iv);

__jacDone();
