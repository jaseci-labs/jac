// OP-030 through OP-031: Bitwise operators
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_operators/test_bitwise.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// OP-030: & | ^ ~
assertEq(0b1010 & 0b1100, 0b1000,  "OP-030: bitwise AND");
assertEq(0b1010 | 0b1100, 0b1110,  "OP-030: bitwise OR");
assertEq(0b1010 ^ 0b1100, 0b0110,  "OP-030: bitwise XOR");
assertEq(~5,              -6,       "OP-030: bitwise NOT (~5 === -6)");
assertEq(~0,              -1,       "OP-030: ~0 === -1");
// Truncates to 32-bit integer
assertEq(4294967296 & 1,  0,        "OP-030: truncates to 32-bit (2^32 & 1 === 0)");
assertEq(3.9 & 0xFF,      3,        "OP-030: float truncated to int before bitwise");

// OP-031: << >> >>>
assertEq(1 << 4,          16,       "OP-031: left shift");
assertEq(16 >> 2,         4,        "OP-031: signed right shift");
assertEq(-1 >> 28,        -1,       "OP-031: >> preserves sign (arithmetic shift)");
assertEq(-1 >>> 28,       15,       "OP-031: >>> unsigned right shift (no sign extend)");
assertEq(-1 >>> 0,        4294967295, "OP-031: -1 >>> 0 === 0xFFFFFFFF");

__jacDone();
