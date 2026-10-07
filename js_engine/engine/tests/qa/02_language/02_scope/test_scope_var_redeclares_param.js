// SCP-VP-*: a body `var` with the same name as a formal parameter (ES §10.2.11).
// Simple parameter list: the var IS the parameter binding, so it keeps the
// argument until assigned. Parameter expressions (defaults): the body has its
// own binding, initialized with the parameter's value. Regression: the engine
// gave the body var a fresh, never-initialized slot, so the parameter read as
// undefined everywhere in the body — e.g. convert-source-map's
// readFromFileMap(sm, read) { exec(sm) … var sm = read(filename) } broke every
// source map Vite's dev server loaded.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/02_scope/test_scope_var_redeclares_param.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ── simple parameter lists ──
function f1(a) { var a; return a; }
assertEq(f1(1), 1, "SCP-VP-001: `var a;` keeps the argument");
function f2(a) { var r = a; try { var a = "x"; } catch (e) {} return [r, a]; }
assertEq(f2(2).join(), "2,x", "SCP-VP-002: var in a try block, read before it runs");
function f3(a) { var r = a; if (false) { var a = 1; } return r; }
assertEq(f3(3), 3, "SCP-VP-003: var in a dead branch");
function f4(a, b) { var r = [a, b]; for (var a of [9]) {} return r.concat(a); }
assertEq(f4(5, 6).join(), "5,6,9", "SCP-VP-004: for-of var over a parameter");
var f5 = function (a) { var r = a; var a = "late"; return [r, a]; };
assertEq(f5(7).join(), "7,late", "SCP-VP-005: function expression");
function f6(a) { var a = a + 1; return a; }
assertEq(f6(10), 11, "SCP-VP-006: initializer reads the parameter");
function f7(a) { var a = 42; return arguments[0]; }
assertEq(f7(1), 42, "SCP-VP-007: sloppy arguments stays aliased to the shared binding");
function readFromFileMap(sm, read) {
    var r = /sourceMappingURL=(\S+)/.exec(sm);
    var filename = r[1];
    try { var sm = read(filename); return sm; } catch (e) { return "error"; }
}
assertEq(readFromFileMap("//# sourceMappingURL=a.js.map", function (f) { return "read:" + f; }),
    "read:a.js.map", "SCP-VP-008: convert-source-map readFromFileMap pattern");

// ── parameter expressions: separate binding, starts with the parameter value ──
function g1(a = 1) { var a; return a; }
assertEq(g1(), 1, "SCP-VP-101: default value flows into the body var");
assertEq(g1(5), 5, "SCP-VP-101: argument flows into the body var");
function g2(a, b = function () { return a; }) { var r = a; var a = 1; return [r, a, b()]; }
assertEq(g2(5).join(), "5,1,5", "SCP-VP-102: body var starts at the param value; the default's closure keeps the param");
function g3({ x }, y = x) { var x; return [x, y]; }
assertEq(g3({ x: 3 }).join(), "3,3", "SCP-VP-103: destructured parameter + default");
function g4(a, ...rest) { var rest; return rest.length + a; }
assertEq(g4(1, 2, 3), 3, "SCP-VP-104: rest parameter keeps its array");

__jacDone();
