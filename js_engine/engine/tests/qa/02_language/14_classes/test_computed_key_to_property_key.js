// TPK-001 through TPK-012: ToPropertyKey (ES §7.1.19) on computed keys.
// A computed property/method/accessor key runs ToPrimitive(string) — i.e.
// Symbol.toPrimitive("string") → toString → valueOf — and a Symbol result stays
// a Symbol key while anything else is ToString'd. A non-primitive result throws
// TypeError. Covers object literals, class fields, methods, getters, setters, and
// bracket get/set index.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/14_classes/test_computed_key_to_property_key.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assert(cond, msg) { __reg.assert(cond, msg); }

// TPK-001: object-literal computed key coerces via toString
var k1 = { toString() { return "hi"; } };
var o1 = {}; o1[k1] = 5;
assertEq(Object.keys(o1)[0], "hi",  "TPK-001: SET_INDEX key toString coercion");
assertEq(o1.hi,               5,     "TPK-001: value stored under coerced key");

// TPK-002: GET_INDEX key coercion
var src = { hi: 111 };
assertEq(src[k1], 111, "TPK-002: GET_INDEX key toString coercion");

// TPK-003: toString preferred over valueOf for the string hint
var k3 = { toString() { return "TS"; }, valueOf() { return "VO"; } };
var o3 = {}; o3[k3] = 1;
assertEq(Object.keys(o3)[0], "TS", "TPK-003: string hint prefers toString");

// TPK-004: Symbol.toPrimitive returning a String
var k4 = { [Symbol.toPrimitive]() { return "sp"; } };
var o4 = {}; o4[k4] = 9;
assertEq(o4.sp, 9, "TPK-004: Symbol.toPrimitive('string') result used");

// TPK-005: Symbol.toPrimitive returning a Symbol → symbol key (not stringified)
var sk = Symbol("sk");
var k5 = { [Symbol.toPrimitive]() { return sk; } };
var o5 = {}; o5[k5] = 7;
assertEq(o5[sk],                       7, "TPK-005: Symbol result stays a Symbol key");
assertEq(Object.keys(o5).length,       0, "TPK-005: no string key created");
assertEq(Object.getOwnPropertySymbols(o5).length, 1, "TPK-005: one symbol key");

// TPK-006: Symbol key passes through unchanged
var s6 = Symbol("s6");
var o6 = {}; o6[s6] = 42;
assertEq(o6[s6], 42, "TPK-006: Symbol key unchanged");

// TPK-007: number key stringifies
var o7 = {}; o7[1.5] = "x";
assertEq(o7["1.5"], "x", "TPK-007: number key ToString");

// TPK-008: non-primitive result throws TypeError
var bad = { [Symbol.toPrimitive]() { return {}; } };
var threw8 = false;
try { var o8 = {}; o8[bad] = 1; } catch (e) { threw8 = e instanceof TypeError; }
assert(threw8, "TPK-008: object-returning toPrimitive throws TypeError");

// TPK-009: throwing coercion propagates and is catchable
var thrower = { toString() { throw new RangeError("boom"); } };
var msg9 = "";
try { var o9 = {}; o9[thrower] = 1; } catch (e) { msg9 = e.message; }
assertEq(msg9, "boom", "TPK-009: throwing toString propagates");

// TPK-010: class computed field key coercion
var kf = { toString() { return "field"; } };
class C { [kf] = 7; }
assertEq(new C().field, 7, "TPK-010: class computed field key coercion");

// TPK-011: class computed method key coercion
var km = { toString() { return "m"; } };
class D { [km]() { return 1; } }
assertEq(new D().m(), 1, "TPK-011: class computed method key coercion");

// TPK-012: object-literal computed getter/setter install as accessors
var vals = [];
var gk = { toString() { return "acc"; } };
var o12 = {
    get [gk]() { return this._v; },
    set [gk](x) { this._v = x * 2; }
};
o12.acc = 5;
assertEq(o12.acc, 10, "TPK-012: computed accessor key coercion + accessor install");
var d12 = Object.getOwnPropertyDescriptor(o12, "acc");
assert(typeof d12.get === "function" && typeof d12.set === "function",
       "TPK-012: installed as accessor (get+set), not data property");

__jacDone();
