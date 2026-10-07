// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-G-* (global / globalThis)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_global_this.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(typeof globalThis, "object", "NGL-G-001: typeof globalThis");
assert(globalThis.globalThis === globalThis, "NGL-G-001: globalThis is self-referential");

if (typeof global !== "undefined") {
    assert(global === globalThis, "NGL-G-002: global aliases globalThis in Node");
}

globalThis.__ngl_g003_test = 4242;
assertEq(globalThis.__ngl_g003_test, 4242, "NGL-G-003: property on globalThis readable");
delete globalThis.__ngl_g003_test;

__jacDone();
