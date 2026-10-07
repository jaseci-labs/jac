// NODE_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NGL-U-003 (WebSocket global presence)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/12_node_globals/test_websocket_presence.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var wsType = typeof WebSocket;
assert(
    wsType === "undefined" || wsType === "function",
    "NGL-U-003: WebSocket is undefined or a constructor"
);

__jacDone();
