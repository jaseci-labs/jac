// RT-070: WebSocket global
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/07_websocket_global/test_websocket_global.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// WebSocket is exposed as a global in js_engine and Node.js v21+.
// Skip gracefully on older runtimes that don't expose it globally.
if (typeof WebSocket === "undefined") {
    __jacDone();
}

assertEq(typeof WebSocket, "function", "RT-070: typeof WebSocket === 'function'");
assertEq(WebSocket.CONNECTING, 0, "RT-070: WebSocket.CONNECTING === 0");
assertEq(WebSocket.OPEN,       1, "RT-070: WebSocket.OPEN === 1");
assertEq(WebSocket.CLOSING,    2, "RT-070: WebSocket.CLOSING === 2");
assertEq(WebSocket.CLOSED,     3, "RT-070: WebSocket.CLOSED === 3");

__jacDone();
