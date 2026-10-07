// STRING_COMPREHENSIVE_TEST_PLAN §3, §6 — length, at, charAt, charCodeAt, codePointAt
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_length_access.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// STR-L-001
assertEq("".length, 0, "STR-L-001: empty length");
assertEq("abc".length, 3, "STR-L-001: ASCII length");

// STR-L-002 — UTF-16 code units
var emoji = "\uD83D\uDE00";
assertEq(emoji.length, 2, "STR-L-002: astral surrogate pair length 2");

// STR-L-003
(function strictLen() {
    "use strict";
    var threw = false;
    try {
        var s = "ab";
        s.length = 1;
    } catch (e) { threw = e instanceof TypeError; }
    assert(threw, "STR-L-003: strict assign length throws TypeError");
})();

// STR-A-001
assertEq("abc".at(0), "a", "STR-A-001: at positive");
assertEq("abc".at(-1), "c", "STR-A-001: at negative from end");
assertEq("abc".at(99), undefined, "STR-A-001: at OOB undefined");

// STR-A-002
assertEq("abc".charAt(1), "b", "STR-A-002: charAt in range");
assertEq("abc".charAt(99), "", "STR-A-002: charAt OOB empty");

// STR-A-003
assertEq("abc".charCodeAt(0), 97, "STR-A-003: charCodeAt");
assert(isNaN("abc".charCodeAt(99)), "STR-A-003: charCodeAt OOB NaN");

// STR-A-004
assertEq("a".codePointAt(0), 97, "STR-A-004: codePointAt BMP");
assertEq("\uD83D\uDE00".codePointAt(0), 0x1F600, "STR-A-004: codePointAt at high surrogate");
assertEq("\uD83D\uDE00".codePointAt(1), 0xDE00, "STR-A-004: codePointAt at low surrogate");
assertEq("a".codePointAt(1), undefined, "STR-A-004: codePointAt past end undefined");

__jacDone();
