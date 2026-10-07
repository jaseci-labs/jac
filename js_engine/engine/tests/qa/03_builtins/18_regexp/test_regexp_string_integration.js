// REGEXP_COMPREHENSIVE_TEST_PLAN.md (docs/qa/testing_plans/03_ecmascript_language/) — §8–9 (RX-I-*, RX-ERR-003..004) — ECG-RX-PROTOCOL-INTEGRATION
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/03_builtins/18_regexp/test_regexp_string_integration.js"
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
function assertThrowsTypeError(fn, msg) {
    __reg.assertThrowsTypeError(fn, msg);
}

// --- RX-I-001 .. RX-I-005 ---
var m1 = "hello".match(/l/);
assert(m1 !== null && m1[0] === "l", "RX-I-001: match non-global array");
assertDeep("hello".match(/l/g), ["l", "l"], "RX-I-001: match global collects");

var it = "hello".matchAll(/l/g);
var a = it.next();
assertEq(a.done, false, "RX-I-002: matchAll iterator first");
assertEq(a.value[0], "l", "RX-I-002: first match string");
assertThrowsTypeError(function () {
    "hello".matchAll(/l/);
}, "RX-I-002: matchAll non-global TypeError");

assertEq("hello".search(/l/), 2, "RX-I-003: search found index");
assertEq("hello".search(/z/), -1, "RX-I-003: search miss");

assertEq("a1b".replace(/\d/g, function (m) {
    return m + m;
}), "a11b", "RX-I-004: replace function replacer order");
assertEq("aa".replaceAll(/a/g, "b"), "bb", "RX-I-004: replaceAll global regexp");
assertThrowsTypeError(function () {
    "a".replaceAll(/a/, "b");
}, "RX-I-004: replaceAll non-global TypeError");

assertDeep("a1b2".split(/\d/), ["a", "b", ""], "RX-I-005: split regexp");
assertDeep("a1b".split(/(\d)/), ["a", "1", "b"], "RX-I-005: split with capture");

// --- RX-ERR-003 .. RX-ERR-004 (string surface; overlap RX-I-002/004) ---
assertThrowsTypeError(function () {
    "x".matchAll(/y/);
}, "RX-ERR-003: matchAll TypeError non-global");

assertThrowsTypeError(function () {
    "x".replaceAll(/y/, "z");
}, "RX-ERR-004: replaceAll TypeError non-global regexp");

__jacDone();
