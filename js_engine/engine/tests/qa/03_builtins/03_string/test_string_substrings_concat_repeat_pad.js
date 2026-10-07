// STRING_COMPREHENSIVE_TEST_PLAN §7–8 — slice, substring, substr, concat, repeat, pad
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_substrings_concat_repeat_pad.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var s0 = "hello world";

// STR-Z-001
assertEq(s0.slice(6), "world", "STR-Z-001: slice from index");
assertEq(s0.slice(0, 5), "hello", "STR-Z-001: slice start end");
assertEq(s0.slice(-5), "world", "STR-Z-001: slice negative start");
assertEq(s0.slice(6, -1), "worl", "STR-Z-001: slice negative end");

// STR-Z-002
assertEq("hello".substring(1, 3), "el", "STR-Z-002: substring");
assertEq("hello".substring(3, 1), "el", "STR-Z-002: substring swaps args");

// STR-Z-003 (legacy substr)
assertEq("hello".substr(1, 2), "el", "STR-Z-003: substr start length");
assertEq("hello".substr(-3), "llo", "STR-Z-003: substr negative start");
assertEq("abcd".substr(1, "2"), "bc", "STR-Z-003b: substr length ToNumber from string");

// STR-Z-005 — split("") exposes UTF-16 code units; single ASCII must not get an extra empty segment
var eqParts = "=".split("");
assertEq(eqParts.length, 1, "STR-Z-005: split empty sep on '=' has length 1");
assertEq(eqParts[0], "=", "STR-Z-005: split empty sep first element");

// STR-Z-004
var orig = "abc";
var sliced = orig.slice(0, 2);
assertEq(orig, "abc", "STR-Z-004: slice does not mutate");
assertEq(sliced, "ab", "STR-Z-004: slice result");

// STR-U-001
assertEq("hello".concat(" ", "world"), "hello world", "STR-U-001: concat multiple");
assertEq("".concat(1, true), "1true", "STR-U-001: concat coerces");

// STR-U-002
assertEq("ab".repeat(3), "ababab", "STR-U-002: repeat n");
assertEq("x".repeat(0), "", "STR-U-002: repeat 0");
assertEq("x".repeat(1), "x", "STR-U-002: repeat 1");
var u2a = false;
try { "x".repeat(-1); } catch (e) { u2a = e instanceof RangeError; }
assert(u2a, "STR-U-002: repeat negative RangeError");
var u2b = false;
try { "x".repeat(Infinity); } catch (e) { u2b = e instanceof RangeError; }
assert(u2b, "STR-U-002: repeat Infinity RangeError");

// STR-U-003 / STR-U-004
assertEq("5".padStart(3, "0"), "005", "STR-U-003: padStart custom");
assertEq("hi".padStart(5), "   hi", "STR-U-003: padStart default space");
assertEq("5".padEnd(3, "0"), "500", "STR-U-003: padEnd");
assertEq("hello".padStart(3), "hello", "STR-U-003: padStart shorter than string");
assertEq("x".padStart(5, "abc"), "abcax", "STR-U-004: padStart truncates pad string");

__jacDone();
