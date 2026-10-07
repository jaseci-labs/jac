// VIT-SC-001: Vite V-17 smoke — structuredClone global
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_vite_structured_clone_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assert(typeof structuredClone === "function", "VIT-SC-001: structuredClone global");
var o = { x: 1, y: { z: 2 } };
var c = structuredClone(o);
assert(c !== o && c.y !== o.y, "VIT-SC-001: deep clone");
assertEq(c.y.z, 2, "VIT-SC-001: nested value");

__jacDone();
