// MAP_SET_WEAKMAP_WEAKSET_SYMBOL_AND_WELL_KNOWN_SYMBOLS_COMPREHENSIVE_TEST_PLAN.md
// §6 Symbol-keyed properties — EC-KCS-6 (KCS-P-001..005)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/07_symbol/test_symbol_property_model.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// KCS-P-001
(function kcs_p_001() {
    var k = Symbol("p1");
    var o = {};
    o[k] = 7;
    assertEq(o[k], 7, "KCS-P-001: read symbol key");
    delete o[k];
    assertEq(o[k], undefined, "KCS-P-001: delete symbol key");
})();

// KCS-P-002
(function kcs_p_002() {
    var k = Symbol("p2");
    var o = { a: 1 };
    o[k] = 2;
    assertDeep(Object.keys(o), ["a"], "KCS-P-002: Object.keys skips symbol");
    assert(Object.getOwnPropertyNames(o).indexOf("Symbol(p2)") < 0, "KCS-P-002: getOwnPropertyNames skips symbol");
    assertEq(JSON.stringify(o), "{\"a\":1}", "KCS-P-002: JSON.stringify skips symbol key");
})();

// KCS-P-003
(function kcs_p_003() {
    var k = Symbol("p3");
    var o = {};
    o[k] = 1;
    var syms = Object.getOwnPropertySymbols(o);
    assertEq(syms.length, 1, "KCS-P-003: getOwnPropertySymbols length");
    assertEq(syms[0], k, "KCS-P-003: symbol in getOwnPropertySymbols");
    var rk = Reflect.ownKeys(o);
    assert(rk.indexOf(k) >= 0, "KCS-P-003: Reflect.ownKeys includes symbol");
})();

// KCS-P-004
(function kcs_p_004() {
    var k = Symbol("p4");
    var o = {};
    Object.defineProperty(o, k, { value: 3, writable: false, enumerable: true, configurable: true });
    assertEq(o[k], 3, "KCS-P-004: defineProperty symbol key");
    var d = Object.getOwnPropertyDescriptor(o, k);
    assertEq(d.value, 3, "KCS-P-004: descriptor value");
    assertEq(d.enumerable, true, "KCS-P-004: descriptor enumerable");
})();

// KCS-P-005 — non-enumerable symbol not in Object.assign from source (assign copies enumerable own)
(function kcs_p_005() {
    var k = Symbol("p5");
    var src = {};
    Object.defineProperty(src, k, { value: 9, enumerable: false, configurable: true });
    var out = Object.assign({}, src);
    assertEq(out[k], undefined, "KCS-P-005: assign skips non-enumerable symbol");
    Object.defineProperty(src, k, { value: 9, enumerable: true, configurable: true });
    var out2 = Object.assign({}, src);
    assertEq(out2[k], 9, "KCS-P-005: assign copies enumerable symbol");
    assertEq(Object.prototype.propertyIsEnumerable.call(src, k), true, "KCS-P-005: propertyIsEnumerable true when enumerable");
})();

__jacDone();
