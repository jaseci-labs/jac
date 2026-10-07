// REGEXP_COMPREHENSIVE_TEST_PLAN.md (docs/qa/testing_plans/03_ecmascript_language/) — §5 — ECG-RX-CAPTURES-UNICODE (capture half)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_groups_backrefs_lookarounds.js"
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

// --- RX-G-001 .. RX-G-008 ---
var g1 = /(a)(b)(c)/.exec("xabcy");
assertEq(g1[1], "a", "RX-G-001: first capture");
assertEq(g1[2], "b", "RX-G-001: second capture");
assertEq(g1[3], "c", "RX-G-001: third capture");

var g2 = /(a)?b/.exec("b");
assertEq(g2[0], "b", "RX-G-002: optional group miss");
assertEq(g2[1], undefined, "RX-G-002: capture undefined when unmatched");

var g3 = /(?<foo>a)(?<bar>b)/.exec("xaby");
assert(g3.groups !== undefined, "RX-G-003: groups object present");
assertEq(g3.groups.foo, "a", "RX-G-003: named foo");
assertEq(g3.groups.bar, "b", "RX-G-003: named bar");

assertThrows(
    function () {
        new RegExp("(?<x>a)(?<x>b)");
    },
    SyntaxError,
    "RX-G-004: duplicate capture name SyntaxError"
);

assertEq(/(a)\1/.test("aa"), true, "RX-G-005: backreference matches repeat");
assertEq(/(a)\1/.test("ab"), false, "RX-G-005: backreference rejects mismatch");

var g6 = new RegExp("(?<x>a)\\k<x>");
var m6 = g6.exec("aa");
assert(m6 !== null, "RX-G-006: named backreference match");
assertEq(m6[0], "aa", "RX-G-006: full span");

var la = /(?=a)a/.exec("aa");
assert(la !== null, "RX-G-007: positive lookahead match");
assertEq(la[0], "a", "RX-G-007: positive lookahead consumes following atom");
assertEq(/(?!a)b/.exec("xb")[0], "b", "RX-G-007: negative lookahead");

var g8 = /(?<=a)b/.exec("xab");
assert(g8 !== null, "RX-G-008: lookbehind match");
assertEq(g8.index, 2, "RX-G-008: lookbehind match index");

__jacDone();
