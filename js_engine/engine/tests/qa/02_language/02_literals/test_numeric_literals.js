// Octal (0o) and binary (0b) numeric literals — P2 §6.7
"use strict";

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_literals/test_numeric_literals.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

assertEq(0o755, 493, "NUM-LIT-001: 0o755 octal");
assertEq(0o777, 511, "NUM-LIT-002: 0o777 umask");
assertEq(0b1010, 10, "NUM-LIT-003: 0b1010 binary");
assertEq(0b11111111, 255, "NUM-LIT-004: 0b11111111 binary");
assertEq(0O77, 63, "NUM-LIT-005: 0O77 uppercase O");
assertEq(0B0, 0, "NUM-LIT-006: 0B0 uppercase B");
assertEq(0o7_7_7, 511, "NUM-LIT-007: 0o7_7_7 separators");

__jacDone();
