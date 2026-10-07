// VIT-TMR-001: Vite V-04 smoke — setTimeout().unref()
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_vite_timer_unref_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var h = setTimeout(function () {}, 5000);
assert(typeof h.unref === "function", "VIT-TMR-001: unref on timer handle");
h.unref();
clearTimeout(h);

__jacDone();
