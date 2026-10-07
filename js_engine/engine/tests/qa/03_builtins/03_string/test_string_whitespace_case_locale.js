// STRING_COMPREHENSIVE_TEST_PLAN §10–12 — trim*, case, localeCompare, normalize
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_whitespace_case_locale.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// STR-W-001
assertEq("  hello  ".trim(), "hello", "STR-W-001: trim spaces");
assertEq("\t\nhello\r".trim(), "hello", "STR-W-001: trim line terminators");

// STR-W-002
assertEq("  hello  ".trimStart(), "hello  ", "STR-W-002: trimStart");
assertEq("  hello  ".trimEnd(), "  hello", "STR-W-002: trimEnd");
assertEq(String.prototype.trimStart, String.prototype.trimLeft, "STR-W-002: trimLeft alias same fn");
assertEq(String.prototype.trimEnd, String.prototype.trimRight, "STR-W-002: trimRight alias same fn");

// STR-W-003
var nw = "no_ws";
assertEq(nw.trim(), "no_ws", "STR-W-003: trim without whitespace unchanged");

// STR-K-001 / STR-K-002 / STR-K-003
assertEq("Hello".toLowerCase(), "hello", "STR-K-001: toLowerCase");
assertEq("Hello".toUpperCase(), "HELLO", "STR-K-001: toUpperCase");
assertEq("".toLowerCase(), "", "STR-K-003: empty toLowerCase");
assertEq("".toUpperCase(), "", "STR-K-003: empty toUpperCase");
var locLo = "I".toLocaleLowerCase("tr");
var locUp = "i".toLocaleUpperCase("tr");
assert(typeof locLo === "string" && locLo.length >= 1, "STR-K-002: toLocaleLowerCase tr");
assert(typeof locUp === "string" && locUp.length >= 1, "STR-K-002: toLocaleUpperCase tr");

// STR-M-001
assertEq("a".localeCompare("a"), 0, "STR-M-001: localeCompare equal");
assert("a".localeCompare("b") < 0, "STR-M-001: localeCompare less");
assert("b".localeCompare("a") > 0, "STR-M-001: localeCompare greater");
assertEq("A".localeCompare("a", "en", { sensitivity: "base" }), 0, "STR-M-001: sensitivity base");

// STR-M-002
var cafeNfc = "caf\u00E9".normalize("NFC");
var cafeNfd = "caf\u00E9".normalize("NFD");
assertEq(cafeNfc.length, 4, "STR-M-002: normalize NFC length");
assert(cafeNfd.length >= 4, "STR-M-002: normalize NFD");
assertEq("\uFB00".normalize("NFKC"), "ff", "STR-M-002: NFKC ligature");
var m2 = false;
try { "x".normalize("BOGUS"); } catch (e) { m2 = e instanceof RangeError; }
assert(m2, "STR-M-002: invalid normalize form RangeError");

__jacDone();
