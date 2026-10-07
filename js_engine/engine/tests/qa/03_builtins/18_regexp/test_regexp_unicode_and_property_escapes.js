// REGEXP_COMPREHENSIVE_TEST_PLAN.md (docs/qa/testing_plans/03_ecmascript_language/) — §6 — ECG-RX-CAPTURES-UNICODE (unicode half)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_unicode_and_property_escapes.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
    __reg.finalize(__jacOrigExit);
}

function assert(cond, msg) {
    __reg.assert(cond, msg);
}
function assertEq(actual, expected, msg) {
    __reg.assertEq(actual, expected, msg);
}
function assertThrows(fn, ErrType, msg) {
    __reg.assertThrows(fn, ErrType, msg);
}

var emoji = "\uD83D\uDE00";
assertEq(/\uD83D/.test(emoji), true, "RX-U-001: high surrogate unit match without u");
assertEq(/\u{1F600}/u.test(emoji), true, "RX-U-001: astral code point with u");

assertEq(new RegExp("\\u{1F600}").test(emoji), false, "RX-U-002: constructor without u does not match astral");
assertEq(new RegExp("\\u{1F600}", "u").test(emoji), true, "RX-U-002: constructor with u matches astral");

assertEq(/\p{L}/u.test("A"), true, "RX-U-003: Unicode property Letter");
assertEq(/\P{L}/u.test("1"), true, "RX-U-003: negated property");
assertThrows(
    function () {
        new RegExp("\\p{NotARealProperty}", "u");
    },
    SyntaxError,
    "RX-U-003: invalid property name SyntaxError"
);

assertEq(/\u017F/ui.test("S"), true, "RX-U-004: case-insensitive Unicode fold long-s to S");
assertEq(/\bfoo\b/u.test("foo"), true, "RX-U-005: boundary with u on ASCII");

__jacDone();
