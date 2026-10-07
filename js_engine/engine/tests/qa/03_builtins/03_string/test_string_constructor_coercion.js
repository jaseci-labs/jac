// STRING_COMPREHENSIVE_TEST_PLAN §1–2, §4 — constructor, coercion, primitives, eval
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/03_string/test_string_constructor_coercion.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── §1 String() / new String (STR-C-*) ─────────────────────────────────────

// STR-C-001
assertEq(typeof String("x"), "string", "STR-C-001: String('x') typeof string");
assertEq(String("x"), "x", "STR-C-001: String('x') value");

// STR-C-002
var w = new String("x");
assertEq(typeof w, "object", "STR-C-002: new String typeof object");
assert(w instanceof String, "STR-C-002: instanceof String");

// STR-C-003
assertEq(String(null), "null", "STR-C-003: String(null)");
assertEq(String(undefined), "undefined", "STR-C-003: String(undefined)");

// STR-C-004
assertEq(String(true), "true", "STR-C-004: String(true)");
assertEq(String(false), "false", "STR-C-004: String(false)");

// STR-C-005
assertEq(String(0), "0", "STR-C-005: String(0)");
assertEq(String(-1.5), "-1.5", "STR-C-005: String(-1.5)");
assertEq(String(Number.MAX_SAFE_INTEGER), "9007199254740991", "STR-C-005: String(MAX_SAFE_INTEGER)");
assertEq(String(9007199254740993n), "9007199254740993", "STR-C-005: String(BigInt past float precision)");

// STR-C-006
assertEq(String(Symbol("d")), "Symbol(d)", "STR-C-006: String(Symbol)");

// STR-C-007 — spec: new String(Symbol) throws (unlike String() call)
var c7 = false;
try { new String(Symbol("x")); } catch (e) { c7 = e instanceof TypeError; }
assert(c7, "STR-C-007: new String(Symbol) throws TypeError");

// STR-C-008 — object coercion (string hint: toString before valueOf)
var o1 = { toString: function () { return "ts"; }, valueOf: function () { return "vo"; } };
assertEq(String(o1), "ts", "STR-C-008: String(obj) uses toString first");
var o2 = Object.create(null);
o2.valueOf = function () { return "vo"; };
assertEq(String(o2), "vo", "STR-C-008: String(obj) valueOf when no inherited toString");
var o3 = {};
assertEq(String(o3), "[object Object]", "STR-C-008: String({}) default");
var o4 = {
    [Symbol.toPrimitive]: function () { return "prim"; },
    toString: function () { return "ts"; }
};
assertEq(String(o4), "prim", "STR-C-008: @@toPrimitive wins");

// ── §2 Primitives, eval, valueOf, bracket (STR-O-*) ──────────────────────────

// STR-O-001
assertEq(eval("2 + 2"), 4, "STR-O-001: eval string primitive");
var evo = eval(new String("2 + 2"));
assertEq(typeof evo, "object", "STR-O-001: eval(new String) typeof object");
assertEq(Object.prototype.toString.call(evo), "[object String]", "STR-O-001: eval new String is boxed");

// STR-O-002
assertEq(new String("x").valueOf(), "x", "STR-O-002: wrapper valueOf");

// STR-O-003
assertEq("cat"[1], "a", "STR-O-003: bracket index");
(function strictBracket() {
    "use strict";
    var threw = false;
    try { "cat"[0] = "z"; } catch (e) { threw = e instanceof TypeError; }
    assert(threw, "STR-O-003: strict assign string index throws TypeError");
})();

// STR-O-004
assertEq("abc".toUpperCase(), "ABC", "STR-O-004: primitive auto-box toUpperCase");

// ── §4 constructor property (STR-R-001) ──────────────────────────────────────

assertEq("".constructor, String, "STR-R-001: ''.constructor === String");

__jacDone();
