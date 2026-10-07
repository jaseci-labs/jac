// COERCE-001 through COERCE-042: Type coercion and conversion
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_coercion/test_coercion.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── == null/undefined (COERCE-001) ───────────────────────────────────────────
assert(null == undefined,  "COERCE-001: null == undefined");
assert(!(null == 0),       "COERCE-001: null != 0");
assert(!(undefined == 0),  "COERCE-001: undefined != 0");
assert(!(null == false),   "COERCE-001: null != false");

// ── == number/string (COERCE-002) ────────────────────────────────────────────
assert(0 == "",     "COERCE-002: 0 == '' (empty string coerces to 0)");
assert(1 == "1",    "COERCE-002: 1 == '1' (string coerced to number)");
assert(0 == "0",    "COERCE-002: 0 == '0' (string '0' coerces to number 0)");

// ── == boolean (COERCE-003) ──────────────────────────────────────────────────
assert(true == 1,     "COERCE-003: true == 1");
assert(false == 0,    "COERCE-003: false == 0");
assert(true == "1",   "COERCE-003: true == '1'");
assert(false == "",   "COERCE-003: false == ''");
assert(!(true == "true"), "COERCE-003: true != 'true'");

// ── == object/primitive (COERCE-004) ─────────────────────────────────────────
assert([1] == 1,           "COERCE-004: [1] == 1");
assert([] == false,        "COERCE-004: [] == false");

// ── NaN equality (COERCE-005) ────────────────────────────────────────────────
assert(!(NaN == NaN),  "COERCE-005: NaN == NaN is false");
assert(NaN != NaN,     "COERCE-005: NaN != NaN is true");

// ── ToNumber from string (COERCE-010) ────────────────────────────────────────
assertEq(+"123",   123,       "COERCE-010: +'123' === 123");
assertEq(+"3.14",  3.14,      "COERCE-010: +'3.14' === 3.14");
assertEq(+"",      0,         "COERCE-010: +'' === 0");
assertEq(+" ",     0,         "COERCE-010: +' ' === 0");
assert(isNaN(+"abc"),         "COERCE-010: +'abc' is NaN");
assertEq(+"0x1A",  26,        "COERCE-010: +'0x1A' === 26");

// ── ToNumber from bool/null/undefined (COERCE-011) ───────────────────────────
assertEq(+true,      1,   "COERCE-011: +true === 1");
assertEq(+false,     0,   "COERCE-011: +false === 0");
assertEq(+null,      0,   "COERCE-011: +null === 0");
assert(isNaN(+undefined), "COERCE-011: +undefined is NaN");

// ── ToNumber from object (COERCE-012) ────────────────────────────────────────
var withValueOf = { valueOf: function() { return 42; } };
assertEq(+withValueOf, 42, "COERCE-012: valueOf() used for ToNumber");
var withToString = { toString: function() { return "7"; } };
assertEq(+withToString, 7, "COERCE-012: toString() fallback for ToNumber");
var withToPrimitive = {};
Object.defineProperty(withToPrimitive, Symbol.toPrimitive, {
    value: function(hint) { return hint === "number" ? 99 : 0; }
});
assertEq(+withToPrimitive, 99, "COERCE-012: Symbol.toPrimitive used for ToNumber");

// ── ToString from number (COERCE-020) ────────────────────────────────────────
assertEq(String(123),       "123",       "COERCE-020: String(123)");
assertEq(String(NaN),       "NaN",       "COERCE-020: String(NaN)");
assertEq(String(Infinity),  "Infinity",  "COERCE-020: String(Infinity)");
assertEq(String(-0),        "0",         "COERCE-020: String(-0) === '0'");

// ── ToString from bool/null/undefined (COERCE-021) ───────────────────────────
assertEq(String(true),      "true",      "COERCE-021: String(true)");
assertEq(String(false),     "false",     "COERCE-021: String(false)");
assertEq(String(null),      "null",      "COERCE-021: String(null)");
assertEq(String(undefined), "undefined", "COERCE-021: String(undefined)");

// ── ToString from object (COERCE-022) ────────────────────────────────────────
var objStr = { toString: function() { return "custom"; } };
assertEq(String(objStr), "custom", "COERCE-022: toString() used for String()");
var objTP = {};
Object.defineProperty(objTP, Symbol.toPrimitive, {
    value: function(hint) { return hint === "string" ? "tp-string" : "other"; }
});
assertEq(String(objTP), "tp-string", "COERCE-022: Symbol.toPrimitive('string') for ToString");

// ── ToBoolean falsy values (COERCE-030) ──────────────────────────────────────
assert(!false,             "COERCE-030: false is falsy");
assert(!0,                 "COERCE-030: 0 is falsy");
assert(!(-0),              "COERCE-030: -0 is falsy");
assert(!"",                "COERCE-030: '' is falsy");
assert(!null,              "COERCE-030: null is falsy");
assert(!undefined,         "COERCE-030: undefined is falsy");
assert(!NaN,               "COERCE-030: NaN is falsy");

// ── ToBoolean truthy values (COERCE-031) ─────────────────────────────────────
assert(true,               "COERCE-031: true is truthy");
assert(!!1,                "COERCE-031: 1 is truthy");
assert(!!"0",              "COERCE-031: '0' is truthy");
assert(!!"false",          "COERCE-031: 'false' is truthy");
assert(!![],               "COERCE-031: [] is truthy");
assert(!!{},               "COERCE-031: {} is truthy");
assert(!!(function(){}),   "COERCE-031: function is truthy");

// ── Boolean() vs !! (COERCE-032) ─────────────────────────────────────────────
assertEq(Boolean(0),   false, "COERCE-032: Boolean(0) === false");
assertEq(!!0,          false, "COERCE-032: !!0 === false");
assertEq(Boolean("x"), true,  "COERCE-032: Boolean('x') === true");
assertEq(!!"x",        true,  "COERCE-032: !!'x' === true");

// ── + string concat (COERCE-040) ─────────────────────────────────────────────
assertEq("a" + "b",  "ab",  "COERCE-040: string concat");
assertEq("a" + 1,    "a1",  "COERCE-040: string + number");
assertEq(1 + "2",    "12",  "COERCE-040: number + string");

// ── + numeric (COERCE-041) ───────────────────────────────────────────────────
assertEq(1 + 2,      3,     "COERCE-041: numeric addition");
assertEq(true + 1,   2,     "COERCE-041: true + 1 === 2");
assertEq(null + 1,   1,     "COERCE-041: null + 1 === 1");

// ── + object edge cases (COERCE-042) ─────────────────────────────────────────
// []+[] = "" (both stringify to "")
assertEq([] + [],    "",             "COERCE-042: []+[] === ''");
// []+{} = "[object Object]"
assertEq([] + {},    "[object Object]", "COERCE-042: []+{} === '[object Object]'");

__jacDone();
