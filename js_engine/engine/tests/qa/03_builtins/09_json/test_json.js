// JSON-001 through JSON-013: JSON built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/09_json/test_json.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// JSON-001: parse primitives
assertEq(JSON.parse("42"),         42,     "JSON-001: parse number");
assertEq(JSON.parse('"hello"'),    "hello","JSON-001: parse string");
assertEq(JSON.parse("true"),       true,   "JSON-001: parse true");
assertEq(JSON.parse("false"),      false,  "JSON-001: parse false");
assertEq(JSON.parse("null"),       null,   "JSON-001: parse null");

// JSON-002: parse objects/arrays
assertDeep(JSON.parse("{}"),            {},             "JSON-002: parse empty object");
assertDeep(JSON.parse("[]"),            [],             "JSON-002: parse empty array");
assertDeep(JSON.parse('{"a":1,"b":2}'), {a:1,b:2},     "JSON-002: parse object");
assertDeep(JSON.parse("[1,2,3]"),        [1,2,3],       "JSON-002: parse array");
var nested = JSON.parse('{"a":{"b":{"c":42}}}');
assertEq(nested.a.b.c, 42,                              "JSON-002: parse nested");

// JSON-003: parse strings with escapes
assertEq(JSON.parse('"\\n"'), "\n",   "JSON-003: parse \\n escape");
assertEq(JSON.parse('"\\t"'), "\t",   "JSON-003: parse \\t escape");
assertEq(JSON.parse('"\\u0041"'), "A","JSON-003: parse \\uXXXX");
assertEq(JSON.parse('"\\/"'), "/",    "JSON-003: parse \\/ escape");

// JSON-004: parse numbers
assertEq(JSON.parse("1.5"),      1.5,   "JSON-004: float");
assertEq(JSON.parse("-42"),     -42,    "JSON-004: negative");
assertEq(JSON.parse("1e3"),      1000,  "JSON-004: scientific notation");
// leading zero should be an error
var threw4 = false;
try { JSON.parse("01"); } catch(e) { threw4 = e instanceof SyntaxError; }
assert(threw4, "JSON-004: leading zero throws SyntaxError");

// JSON-005: parse errors
var invalids = ['invalid', '{a:1}', "{'a':1}", '[1,2,]', '[1,2,', 'undefined'];
for (var i = 0; i < invalids.length; i++) {
    var ok = false;
    try { JSON.parse(invalids[i]); } catch(e) { ok = e instanceof SyntaxError; }
    assert(ok, "JSON-005: invalid JSON throws SyntaxError: " + invalids[i]);
}

// JSON-006: parse reviver — GAP: ignored; verify no crash
var revResult = JSON.parse('{"a":1}', function(key,val){return val;});
assert(typeof revResult === "object" && revResult !== null, "JSON-006: reviver no crash");

// JSON-007: stringify primitives
assertEq(JSON.stringify("hello"),   '"hello"',   "JSON-007: stringify string");
assertEq(JSON.stringify(42),        "42",        "JSON-007: stringify number");
assertEq(JSON.stringify(true),      "true",      "JSON-007: stringify true");
assertEq(JSON.stringify(null),      "null",      "JSON-007: stringify null");
assertEq(JSON.stringify(undefined), undefined,   "JSON-007: stringify undefined returns undefined");

// JSON-008: stringify objects/arrays
assertEq(JSON.stringify({}),        "{}",        "JSON-008: empty object");
assertEq(JSON.stringify([1,2,3]),   "[1,2,3]",   "JSON-008: array");
// key ordering may vary; check round-trip
var obj = {a:1, b:[2,3], c:{d:4}};
assertDeep(JSON.parse(JSON.stringify(obj)), obj,  "JSON-008: nested round-trip");

// JSON-009: stringify special values
assertEq(JSON.stringify(NaN),       "null",      "JSON-009: NaN -> null");
assertEq(JSON.stringify(Infinity),  "null",      "JSON-009: Infinity -> null");
assertEq(JSON.stringify(-Infinity), "null",      "JSON-009: -Infinity -> null");
// undefined and function properties omitted
var withUndef = {a:1, b:undefined, c:function(){}};
var s = JSON.stringify(withUndef);
var parsed = JSON.parse(s);
assertEq(typeof parsed.b, "undefined",            "JSON-009: undefined prop omitted");
assertEq(typeof parsed.c, "undefined",            "JSON-009: function prop omitted");
// undefined in array -> null
assertEq(JSON.stringify([undefined, 1]), "[null,1]","JSON-009: undefined in array -> null");

// JSON-010: stringify toJSON
var customObj = {
    x: 1,
    toJSON: function(key) { return {serialized: true}; }
};
assertEq(JSON.stringify(customObj), '{"serialized":true}', "JSON-010: toJSON custom");
// Date has toJSON
var d = new Date(0);
var ds = JSON.stringify(d);
assertEq(typeof ds, "string",                       "JSON-010: Date toJSON returns string");

// JSON-011: stringify space
var spaced = JSON.stringify({a:1,b:2}, null, 2);
assert(spaced.indexOf("\n") >= 0,                   "JSON-011: space number adds newlines");
var spacedStr = JSON.stringify({a:1}, null, "  ");
assert(spacedStr.indexOf("  ") >= 0,                "JSON-011: space string indents");

// JSON-012: stringify replacer — GAP: may be ignored; verify no crash
var repResult = JSON.stringify({a:1,b:2}, ["a"]);
assert(typeof repResult === "string",               "JSON-012: replacer array no crash");

// JSON-013: stringify circular reference -> TypeError
var circular = {};
circular.self = circular;
var threw13 = false;
try { JSON.stringify(circular); } catch(e) { threw13 = e instanceof TypeError; }
assert(threw13, "JSON-013: circular reference throws TypeError");

__jacDone();
