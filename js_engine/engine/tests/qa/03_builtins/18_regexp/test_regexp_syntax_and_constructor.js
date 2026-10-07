// REGEXP_COMPREHENSIVE_TEST_PLAN.md (docs/qa/testing_plans/03_ecmascript_language/) — §1–2, RX-ERR-001..002 — ECG-RX-SYNTAX
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_syntax_and_constructor.js"
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

// --- RX-C-001 .. RX-C-007 ---
var lit = /abc/;
assertEq(lit.source, "abc", "RX-C-001: literal source");
assertEq(lit.flags, "", "RX-C-001: literal default flags");

var c2a = new RegExp("abc");
var c2b = RegExp("abc");
assertEq(c2a.test("xabcx"), true, "RX-C-002: new RegExp semantics");
assertEq(c2b.test("xabcx"), true, "RX-C-002: RegExp() call semantics");

var base = /foo/gim;
var clone = new RegExp(base);
assertEq(clone.source, "foo", "RX-C-003: clone source");
assertEq(clone.flags, "gim", "RX-C-003: clone flags preserved");

var reflag = new RegExp(base, "i");
assertEq(reflag.flags, "i", "RX-C-004: override flags drops g and m");
assertEq(reflag.global, false, "RX-C-004: global off after override");

assertThrows(
    function () {
        new RegExp("a", "gg");
    },
    SyntaxError,
    "RX-C-005: duplicate flag SyntaxError"
);
assertThrows(
    function () {
        new RegExp("a", "q");
    },
    SyntaxError,
    "RX-C-006: unknown flag SyntaxError"
);

var digit = new RegExp("\\d");
assertEq(digit.test("5"), true, "RX-C-007: string pattern needs escaped backslash");
assertEq(digit.test("x"), false, "RX-C-007: non-digit");

// --- RX-SY-001 .. RX-SY-008 ---
assertEq(/\./.test("a"), false, "RX-SY-001: escaped dot not any char");
assertEq(/\./.test("."), true, "RX-SY-001: escaped dot matches literal");
assertEq(/\*/.test("*"), true, "RX-SY-001: escaped star literal");

assertEq(/[abc]/.test("b"), true, "RX-SY-002: char class member");
assertEq(/[^abc]/.test("x"), true, "RX-SY-002: negated class");
assertEq(/[a-z]/.test("m"), true, "RX-SY-002: range");

assertEq(/\d/.test("0"), true, "RX-SY-003: digit class");
assertEq(/\D/.test("a"), true, "RX-SY-003: non-digit");
assertEq(/\w/.test("_"), true, "RX-SY-003: word char");
assertEq(/\W/.test(" "), true, "RX-SY-003: non-word");
assertEq(/\s/.test(" "), true, "RX-SY-003: whitespace");
assertEq(/\S/.test("z"), true, "RX-SY-003: non-space");

assertEq(/a+/.exec("aaax")[0], "aaa", "RX-SY-004: greedy plus");
assertEq(/a+?/.exec("aaax")[0], "a", "RX-SY-004: lazy plus");
assertEq(/a{2,3}/.exec("aaaax")[0], "aaa", "RX-SY-004: greedy bounded takes upper inclusive max");
assertEq(/a{2,3}?/.exec("aaaax")[0], "aa", "RX-SY-004: lazy bounded");

assertEq(/a|bc/.exec("bcx")[0], "bc", "RX-SY-005: alternation longer branch");
assertEq(/(ab)+/.exec("abab")[0], "abab", "RX-SY-005: grouping quantifier");

assertEq(/^a/m.exec("x\na")[0], "a", "RX-SY-006: multiline ^ after newline");
assertEq(/a$/m.exec("a\nx")[0], "a", "RX-SY-006: multiline $ before newline");

assertEq(/\bword\b/.test("word"), true, "RX-SY-007: word boundary");
assertEq(/\bword\b/.test("sword"), false, "RX-SY-007: no boundary inside token");
assertEq(/\Bword/.test("sword"), true, "RX-SY-007: non-boundary");

assertThrows(
    function () {
        new RegExp("[");
    },
    SyntaxError,
    "RX-SY-008: unterminated class SyntaxError"
);
assertThrows(
    function () {
        new RegExp("(");
    },
    SyntaxError,
    "RX-SY-008: unterminated group SyntaxError"
);

// --- RX-ERR-001 .. RX-ERR-002 (overlap RX-C-005/006/SY-008) ---
assertThrows(
    function () {
        new RegExp("**");
    },
    SyntaxError,
    "RX-ERR-001: invalid grammar SyntaxError"
);

__jacDone();
