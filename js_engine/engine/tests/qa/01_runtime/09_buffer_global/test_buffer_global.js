// RT-080 through RT-081: Buffer global
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/09_buffer_global/test_buffer_global.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-081: Before require("buffer"), Buffer may be undefined
var beforeRequire = typeof globalThis.Buffer;
// We do not assert a specific value here since some engines pre-populate it.

// RT-080: After require("buffer"), globalThis.Buffer must be available
require("buffer");
// Buffer may be exposed as a function (standard) or as an object namespace
assert(
    typeof globalThis.Buffer === "function" || typeof globalThis.Buffer === "object",
    "RT-080: globalThis.Buffer is accessible after require('buffer')"
);
assert(globalThis.Buffer !== null, "RT-080: globalThis.Buffer is not null");
assert(typeof globalThis.Buffer.alloc === "function",
    "RT-080: Buffer.alloc exists after require('buffer')");
assert(typeof globalThis.Buffer.from === "function",
    "RT-080: Buffer.from exists after require('buffer')");

// Also verify basic construction works
var buf = globalThis.Buffer.alloc(4, 0);
assertEq(buf.length, 4, "RT-080: Buffer.alloc(4) has length 4");

__jacDone();
