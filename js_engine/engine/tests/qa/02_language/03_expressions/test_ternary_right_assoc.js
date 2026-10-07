// TERN-RA-001: conditional operator is right-associative (Vite cac bundle pattern)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_expressions/test_ternary_right_assoc.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// Right-associative: a ? b : c ? d : e  =>  a ? b : (c ? d : e)
assertEq(true ? 1 : false ? 2 : 3, 1, "TERN-RA-001: right-assoc nested ternary");

// Minified-style chain from vite dist (parse-only; values use stubbed opts)
var opts = { string: [], boolean: [] };
var val = "x";
var nxt = !!~opts.string.indexOf("key")
  ? val == null || val === true
    ? ""
    : String(val)
  : typeof val === "boolean"
    ? val
    : !!~opts.boolean.indexOf("key")
      ? val === "false"
        ? false
        : val === "true" || (val, true)
      : val;
assertEq(nxt, "x", "TERN-RA-002: vite-style nested ternary parses and runs");

// Both branches are AssignmentExpressions: `c ? a : d = v` is `c ? a : (d = v)`.
// Regression: the alternate stopped before `=`, so the statement parsed as
// `(c ? a : d) = v` and silently assigned nothing — Babel's
// `defined != null ? defined : defined = []` left `defined` undefined and
// @babel/types threw while loading (Vite + @vitejs/plugin-react dev server).
var d1; d1 != null ? d1 : d1 = [7];
assertEq(d1 && d1.length, 1, "TERN-RA-003: assignment in the alternate");
var d2 = 5; d2 != null ? d2 : d2 = 9;
assertEq(d2, 5, "TERN-RA-003: alternate assignment not taken");
var d3; true ? d3 = "c" : 0;
assertEq(d3, "c", "TERN-RA-004: assignment in the consequent");
var d4, d5; false ? 0 : false ? d4 = 1 : d5 = 2;
assertEq(d4 === undefined && d5 === 2, true, "TERN-RA-005: nested alternate assignment");
var d6 = 0; var r6 = false ? 0 : d6 += 3;
assertEq(r6 + ":" + d6, "3:3", "TERN-RA-006: compound assignment in the alternate is the value");
var d7 = (function () { let x; false ? 0 : x = 4; return function () { return x; }; })();
assertEq(d7(), 4, "TERN-RA-007: captured let assigned in the alternate");

__jacDone();

