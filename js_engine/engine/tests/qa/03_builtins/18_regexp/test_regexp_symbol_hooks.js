// REGEXP_COMPREHENSIVE_TEST_PLAN.md (docs/qa/testing_plans/03_ecmascript_language/) — §7 — ECG-RX-PROTOCOL-INTEGRATION (symbol hooks)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_symbol_hooks.js"
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
function assertDeep(actual, expected, msg) {
    __reg.assertDeep(actual, expected, msg);
}

var sym = Symbol.match;
var symAll = Symbol.matchAll;
var symSearch = Symbol.search;
var symReplace = Symbol.replace;
var symSplit = Symbol.split;

// --- RX-M-001 .. RX-M-006, RX-M-007 ---
assertEq(/a/g.toString(), "/a/g", "RX-M-001: toString canonical form");
assertEq(/\//.toString(), "/\\//", "RX-M-001: slash escaped in toString");

var m2 = RegExp.prototype[sym].call(/a/g, "aba");
assertDeep(m2, ["a", "a"], "RX-M-002: @@match global array");

var m2b = RegExp.prototype[sym].call(/a/, "aba");
assert(m2b !== null, "RX-M-002: @@match non-global not null");
assertEq(m2b[0], "a", "RX-M-002: @@match non-global match");

var it = RegExp.prototype[symAll].call(/a/g, "aba");
var n1 = it.next();
assertEq(n1.done, false, "RX-M-003: matchAll first");
assertEq(n1.value[0], "a", "RX-M-003: first value");
var n2 = it.next();
assertEq(n2.done, false, "RX-M-003: matchAll second");
assertEq(n2.value[0], "a", "RX-M-003: second value");
var n3 = it.next();
assertEq(n3.done, true, "RX-M-003: matchAll done");

assertEq(RegExp.prototype[symSearch].call(/l/, "hello"), 2, "RX-M-004: @@search found");
assertEq(RegExp.prototype[symSearch].call(/z/, "hello"), -1, "RX-M-004: @@search miss");

assertEq(
    RegExp.prototype[symReplace].call(/a/g, "aaa", "x"),
    "xxx",
    "RX-M-005: @@replace string replacer"
);
assertEq(
    RegExp.prototype[symReplace].call(/(a)(b)/, "ab", "$2$1"),
    "ba",
    "RX-M-005: @@replace capture swap"
);
var outFn = RegExp.prototype[symReplace].call(/\d/g, "a1b2", function (m) {
    return m + m;
});
assertEq(outFn, "a11b22", "RX-M-005: @@replace function replacer");

var sp = RegExp.prototype[symSplit].call(/\d/, "a1b2c", 3);
assertDeep(sp, ["a", "b", "c"], "RX-M-006: @@split with limit");
var spCap = RegExp.prototype[symSplit].call(/(\d)/, "a1b");
assertDeep(spCap, ["a", "1", "b"], "RX-M-006: @@split capturing group insertion");

var execCalls = 0;
class CountingRegexp extends RegExp {
    exec(s) {
        execCalls++;
        return super.exec(s);
    }
}
var cr = new CountingRegexp("a", "g");
RegExp.prototype[sym].call(cr, "aaa");
assert(execCalls >= 3, "RX-M-007: overridden exec used by @@match loop");

__jacDone();
