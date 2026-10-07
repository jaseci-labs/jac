// STRING_COMPREHENSIVE_TEST_PLAN §15–17 — isWellFormed, toWellFormed, @@iterator
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_unicode_wellformed_iterator.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// STR-WF-001 / STR-WF-002 — ES2024; skip when host has no implementation
(function wellFormed() {
    if (typeof String.prototype.isWellFormed !== "function") return;
    assertEq("a".isWellFormed(), true, "STR-WF-001: ASCII well-formed");
    assertEq("\uD83D\uDE00".isWellFormed(), true, "STR-WF-001: valid surrogate pair well-formed");
    assertEq("\uD800".isWellFormed(), false, "STR-WF-001: lone high surrogate");
    assertEq("\uDC00".isWellFormed(), false, "STR-WF-001: lone low surrogate");
    assertEq("\uD800".toWellFormed(), "\uFFFD", "STR-WF-002: toWellFormed lone high");
    assertEq("\uDC00".toWellFormed(), "\uFFFD", "STR-WF-002: toWellFormed lone low");
})();

// STR-IT-001
var emoji = "\uD83D\uDE00";
assertDeep(Array.from(emoji), [emoji], "STR-IT-001: spread yields code point string");
assertEq(emoji.split("").length, 2, "STR-IT-001: split yields UTF-16 units");

// STR-IT-002
var it = "ab"[Symbol.iterator]();
var n1 = it.next();
assertEq(n1.done, false, "STR-IT-002: first not done");
assertEq(n1.value, "a", "STR-IT-002: first value");
var n2 = it.next();
assertEq(n2.value, "b", "STR-IT-002: second value");
var n3 = it.next();
assertEq(n3.done, true, "STR-IT-002: exhausted");

__jacDone();
