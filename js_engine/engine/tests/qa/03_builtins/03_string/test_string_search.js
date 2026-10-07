// STRING_COMPREHENSIVE_TEST_PLAN §9 — indexOf, lastIndexOf, includes, startsWith, endsWith
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_search.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// STR-F-001
assertEq("hello world".indexOf("world"), 6, "STR-F-001: indexOf found");
assertEq("hello".indexOf("xyz"), -1, "STR-F-001: indexOf not found");
assertEq("hello".indexOf("l", 3), 3, "STR-F-001: indexOf fromIndex");
assertEq("hello".indexOf("l", -10), 2, "STR-F-001: indexOf negative fromIndex clamp");
assertEq("hello world hello".lastIndexOf("hello"), 12, "STR-F-001: lastIndexOf");
assertEq("hello world".lastIndexOf("xyz"), -1, "STR-F-001: lastIndexOf not found");
assertEq("hello".lastIndexOf("l"), 3, "STR-F-001: lastIndexOf last l");

// STR-F-002
assert("hello world".includes("world"), "STR-F-002: includes found");
assert(!"hello".includes("World"), "STR-F-002: includes case-sensitive");
assert("hello world".includes("world", 5), "STR-F-002: includes fromIndex");
assert(!"hello".includes(NaN), "STR-F-002: includes NaN coerced not in hello");
assert("NaN".includes(NaN), "STR-F-002: includes NaN coerced matches NaN substring");

// STR-F-003
assert("hello world".startsWith("hello"), "STR-F-003: startsWith true");
assert(!"hello world".startsWith("world"), "STR-F-003: startsWith false");
assert("hello world".startsWith("world", 6), "STR-F-003: startsWith position");
assert("hello world".endsWith("world"), "STR-F-003: endsWith true");
assert("hello world".endsWith("hello", 5), "STR-F-003: endsWith length arg");
assert(!"abc".endsWith("abcd"), "STR-F-003: endsWith false");

__jacDone();
