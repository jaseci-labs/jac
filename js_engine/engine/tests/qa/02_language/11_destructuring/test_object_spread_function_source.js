// OBJ-SPREAD-FN-*: `{ ...fn }` / `const { a, ...rest } = fn` copy a FUNCTION's own
// enumerable properties (CopyDataProperties, ES §7.3.25). Regression: the spread
// opcode only walked object cells, so a function source copied nothing — postcss
// hands every plugin `{ ...postcss, result }` (postcss is a function carrying
// rule/decl/…), and Vite's CSS-modules plugin died with "rule is not a function".
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/11_destructuring/test_object_spread_function_source.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

function postcss() {}
postcss.rule = function (d) { return { rule: d }; };
postcss.decl = function (d) { return d; };
Object.defineProperty(postcss, "hidden", { value: 1, enumerable: false });
var sym = Symbol("s");
postcss[sym] = "sym";

var helpers = { ...postcss, postcss: postcss, result: 1 };
assertEq(typeof helpers.rule, "function", "OBJ-SPREAD-FN-001: spread copies a function's own props");
assertEq(helpers.rule(2).rule, 2, "OBJ-SPREAD-FN-001: copied method is callable");
assertEq(Object.keys(helpers).join(), "rule,decl,postcss,result", "OBJ-SPREAD-FN-002: key order; name/length/prototype and non-enumerables skipped");
assertEq(helpers[sym], "sym", "OBJ-SPREAD-FN-003: enumerable symbol-keyed props copied");

var { rule, ...rest } = postcss;
assertEq(typeof rule, "function", "OBJ-SPREAD-FN-004: destructuring reads a function prop");
assertEq(Object.keys(rest).join(), "decl", "OBJ-SPREAD-FN-004: object rest from a function source");

class K { static a = 1; static b() {} }
assertEq(Object.keys({ ...K }).join(), "a", "OBJ-SPREAD-FN-005: class static fields spread, static methods do not");
// Class bookkeeping slots (static-field list, private brand stamps) never surface.
class P { static a = 1; #x = 1; static b() {} static has(o) { return #x in o; } }
assertEq(Object.keys(P).join(), "a", "OBJ-SPREAD-FN-008: Object.keys(class) hides internal slots");
assertEq(Object.getOwnPropertyNames(P).join(), "length,name,prototype,b,has,a", "OBJ-SPREAD-FN-008: getOwnPropertyNames(class)");
assertEq(Reflect.ownKeys(P).map(String).join(), "length,name,prototype,b,has,a", "OBJ-SPREAD-FN-008: Reflect.ownKeys(class)");

var bound = function () {}.bind(null);
bound.x = 5;
assertEq({ ...bound }.x, 5, "OBJ-SPREAD-FN-006: bound function source");
assertEq(Object.keys({ ...Math.max }).length, 0, "OBJ-SPREAD-FN-007: builtin function has no enumerable own props");

__jacDone();
