// MAP_SET_WEAKMAP_WEAKSET_SYMBOL_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// §5 Symbol — EC-KCS-5 (KCS-Y-001..006)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/07_symbol/test_symbol_core_and_registry.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrowsTypeError(fn, msg) { __reg.assertThrowsTypeError(fn, msg); }

// KCS-Y-001
(function kcs_y_001() {
    var a = Symbol("d");
    var b = Symbol("d");
    assertEq(typeof a, "symbol", "KCS-Y-001: typeof symbol");
    assertEq(a.description, "d", "KCS-Y-001: description");
    assert(a !== b, "KCS-Y-001: distinct symbols same description");
    var noDesc = Symbol();
    assertEq(noDesc.description, undefined, "KCS-Y-001: Symbol() description undefined");
})();

// KCS-Y-002
(function kcs_y_002() {
    assertThrowsTypeError(function () { new Symbol("x"); }, "KCS-Y-002: new Symbol throws TypeError");
})();

// KCS-Y-003
(function kcs_y_003() {
    var a = Symbol.for("kcs-y-003");
    var b = Symbol.for("kcs-y-003");
    assertEq(a, b, "KCS-Y-003: Symbol.for same key same symbol");
})();

// KCS-Y-004
(function kcs_y_004() {
    var g = Symbol.for("kcs-y-004");
    assertEq(Symbol.keyFor(g), "kcs-y-004", "KCS-Y-004: keyFor global symbol");
    var local = Symbol("local");
    assertEq(Symbol.keyFor(local), undefined, "KCS-Y-004: keyFor local symbol undefined");
})();

// KCS-Y-005
(function kcs_y_005() {
    var s = Symbol("coerce");
    assertEq(String(s), "Symbol(coerce)", "KCS-Y-005: String(symbol)");
    assertEq(s.toString(), "Symbol(coerce)", "KCS-Y-005: symbol.toString()");
    assertThrowsTypeError(function () { return Number(s); }, "KCS-Y-005: Number(symbol) throws TypeError");
    assertThrowsTypeError(function () { return s + 1; }, "KCS-Y-005: symbol + number throws TypeError");
})();

// KCS-Y-006 — boxed symbol and prototype brand checks
(function kcs_y_006() {
    var s = Symbol("box");
    var o = Object(s);
    assertEq(typeof o, "object", "KCS-Y-006: Object(symbol) typeof object");
    assert(o instanceof Object, "KCS-Y-006: boxed symbol instanceof Object");
    assertThrowsTypeError(function () { Symbol.prototype.valueOf.call({}); }, "KCS-Y-006: valueOf on non-symbol throws");
    assertThrowsTypeError(function () { Symbol.prototype.toString.call({}); }, "KCS-Y-006: toString on non-symbol throws");
    assertEq(Symbol.prototype.valueOf.call(o), s, "KCS-Y-006: valueOf unwraps boxed symbol");
})();

__jacDone();
