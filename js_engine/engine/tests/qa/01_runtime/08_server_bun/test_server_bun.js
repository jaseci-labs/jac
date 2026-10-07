// RT-071 through RT-072: Server and Bun globals
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/08_server_bun/test_server_bun.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-071: Server global — js_engine specific; absent in plain Node.js
if (typeof Server !== "undefined") {
    assertEq(typeof Server, "function", "RT-071: typeof Server === 'function'");
}

// RT-072: Bun global — js_engine specific; absent in plain Node.js
if (typeof Bun !== "undefined") {
    assertEq(typeof Bun, "object", "RT-072: typeof Bun === 'object'");
    assert(Bun !== null, "RT-072: Bun is not null");
    assertEq(typeof Bun.serve, "function", "RT-072: typeof Bun.serve === 'function'");
}

__jacDone();
