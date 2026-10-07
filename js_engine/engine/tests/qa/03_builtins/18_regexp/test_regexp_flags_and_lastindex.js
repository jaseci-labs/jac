// REGEXP_COMPREHENSIVE_TEST_PLAN.md (docs/qa/testing_plans/03_ecmascript_language/) — §3–4, RX-ERR-005 — ECG-RX-FLAGS-STATE
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_flags_and_lastindex.js"
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

// --- RX-F-001 .. RX-F-006, RX-F-008 (RX-F-007 optional in optional file) ---
assertEq(new RegExp("a", "mgi").flags, "gim", "RX-F-001: canonical flag string order");

var f2 = new RegExp("a", "gimsuy");
assertEq(f2.global, true, "RX-F-002: global accessor");
assertEq(f2.ignoreCase, true, "RX-F-002: ignoreCase");
assertEq(f2.multiline, true, "RX-F-002: multiline");
assertEq(f2.dotAll, true, "RX-F-002: dotAll");
assertEq(f2.unicode, true, "RX-F-002: unicode");
assertEq(f2.sticky, true, "RX-F-002: sticky");
var f2d = new RegExp("a", "dg");
assertEq(f2d.hasIndices, true, "RX-F-002: hasIndices from d flag");
if ("unicodeSets" in RegExp.prototype) {
    var f2v = new RegExp("a", "v");
    assertEq(f2v.unicodeSets, true, "RX-F-002: unicodeSets from v flag");
}

assertEq(/./.test("\n"), false, "RX-F-003: dot excludes newline without s");
assertEq(/./s.test("\n"), true, "RX-F-003: dotAll includes newline");

assertEq(/^b/m.exec("a\nb")[0], "b", "RX-F-004: multiline ^ matches line start");
assertEq(/B/i.test("b"), true, "RX-F-005: ignoreCase");

var emojiF = "\uD83D\uDE00";
assertEq(/\u{1F600}/u.test(emojiF), true, "RX-F-006: braced code point with u matches astral");
assertEq(/\u{1F600}/.test(emojiF), false, "RX-F-006: same pattern without u does not match astral");

if ("unicodeSets" in RegExp.prototype) {
    var vre = new RegExp("[a-z]", "v");
    assertEq(vre.unicodeSets, true, "RX-F-008: v sets unicodeSets");
}

// --- RX-E-001 .. RX-E-008 ---
var ex = /(b)(c)/;
var m = ex.exec("abc");
assert(m !== null, "RX-E-001: exec match not null");
assertEq(m[0], "bc", "RX-E-001: full match");
assertEq(m[1], "b", "RX-E-001: capture 1");
assertEq(m[2], "c", "RX-E-001: capture 2");
assertEq(m.index, 1, "RX-E-001: index");
assertEq(m.input, "abc", "RX-E-001: input");

assertEq(/z/.exec("abc"), null, "RX-E-002: exec miss returns null");

var ng = /a/;
ng.lastIndex = 99;
var mng = ng.exec("xa");
assertEq(mng.index, 1, "RX-E-003: non-global ignores lastIndex for match start");

var g = /a/g;
g.lastIndex = 0;
g.exec("aba");
assertEq(g.lastIndex, 1, "RX-E-004: global advances lastIndex after match");

var g2 = /a/g;
g2.lastIndex = 2;
assertEq(g2.exec("bb"), null, "RX-E-005: global miss");
assertEq(g2.lastIndex, 0, "RX-E-005: global miss resets lastIndex to 0");

var y = /a/y;
y.lastIndex = 1;
var my = y.exec("ba");
assert(my !== null, "RX-E-006: sticky match at lastIndex");
assertEq(my.index, 1, "RX-E-006: sticky index");
y.lastIndex = 0;
assertEq(y.exec("ba"), null, "RX-E-006: sticky miss when not at boundary");

var g3 = /a/g;
assertEq(g3.exec("aa").index, 0, "RX-E-007: first global match index");
assertEq(g3.lastIndex, 1, "RX-E-007: lastIndex after first match");
assertEq(g3.exec("aa").index, 1, "RX-E-007: second match index");
assertEq(g3.exec("aa"), null, "RX-E-007: exhausted");
assertEq(g3.lastIndex, 0, "RX-E-007: lastIndex after terminal miss");

var g4 = /a/g;
var t1 = g4.test("ba");
assertEq(t1, true, "RX-E-008: test true");
assertEq(g4.lastIndex, 2, "RX-E-008: lastIndex mirrors exec");
assertEq(g4.test("ba"), false, "RX-E-008: test false");
assertEq(g4.lastIndex, 0, "RX-E-008: lastIndex after false test");

// --- RX-ERR-005 lastIndex coercion ---
var co = /a/g;
co.lastIndex = -0;
co.exec("b");
assertEq(1 / co.lastIndex > 0, true, "RX-ERR-005: -0 lastIndex coerces to +0");
var co2 = /a/g;
co2.lastIndex = 1.7;
co2.exec("xa");
assertEq(co2.lastIndex, 2, "RX-ERR-005: fractional lastIndex truncated for match");

__jacDone();
