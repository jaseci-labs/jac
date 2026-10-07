// STRING_COMPREHENSIVE_TEST_PLAN §5 — String.fromCharCode, fromCodePoint, raw
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_statics.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// STR-S-010
assertEq(String.fromCharCode(65), "A", "STR-S-010: fromCharCode single");
assertEq(String.fromCharCode(65, 66, 67), "ABC", "STR-S-010: fromCharCode multiple");
assertEq(String.fromCharCode(0x2603), "\u2603", "STR-S-010: fromCharCode BMP snowman");

// STR-S-011 — surrogate pair → one astral char
var pair = String.fromCharCode(0xD83D, 0xDE00);
assertEq(pair.length, 2, "STR-S-011: pair is two UTF-16 units");
assertEq(pair, "\uD83D\uDE00", "STR-S-011: astral via two fromCharCode");

// STR-S-012 — NaN / out-of-range treated as 0 modulo 2^16 (spec)
assertEq(String.fromCharCode(NaN), "\0", "STR-S-012: fromCharCode NaN");
assertEq(String.fromCharCode(Infinity), "\0", "STR-S-012: fromCharCode Infinity");

// STR-S-020
assertEq(String.fromCodePoint(0x1F600), "\uD83D\uDE00", "STR-S-020: fromCodePoint astral");
assertEq(String.fromCodePoint(65, 66), "AB", "STR-S-020: fromCodePoint multiple BMP");

// STR-S-021
var s21a = false;
try { String.fromCodePoint(Infinity); } catch (e) { s21a = e instanceof RangeError; }
assert(s21a, "STR-S-021: fromCodePoint(Infinity) RangeError");
var s21b = false;
try { String.fromCodePoint(-1); } catch (e) { s21b = e instanceof RangeError; }
assert(s21b, "STR-S-021: fromCodePoint(-1) RangeError");

// STR-S-030
assertEq(String.raw`\n\t`, "\\n\\t", "STR-S-030: raw preserves escapes");
assertEq(String.raw`line1\nline2`, "line1\\nline2", "STR-S-030: raw backslash-n");

// STR-S-031
assertEq(String.raw`a${1 + 1}b`, "a2b", "STR-S-031: raw substitutions");
var rawTag = function (callSite) {
    assertEq(callSite.raw.length, callSite.length, "STR-S-031: raw and cooked same length slots");
    return String.raw.apply(undefined, arguments);
};
assertEq(rawTag`x${0}y`, "x0y", "STR-S-031: raw callable");

__jacDone();
