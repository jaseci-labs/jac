// Regression: CreateDynamicFunction (new Function) ToString-coerces every
// argument. A primitive-wrapper OBJECT (new Object(1) → Number wrapper) must
// ToString to its wrapped primitive ("1"), NOT "[object Object]". The
// Function-ctor coercion helper fell through to a no-obs-context ToString that
// returned "" for cells → "[object Object]", so `new Function(new Object(1))`
// built a body of "[object Object]" and threw "object is not defined" at call
// time (test262 Function/S15.3.2.1_A1_T7). Unwrapping the common wrappers fixes
// it. (Kept as its own suite: test_function_constructor.js is skip-listed.)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/06_function/test_function_ctor_arg_tostring.js");
var __jacOrigExit = process.exit.bind(process);
function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// FN-TS-001 — Number wrapper as the whole body: "1" is a valid expr statement.
var fNum = new Function(new Object(1));
assertEq(fNum(), undefined, "FN-TS-001: new Function(Object(1)) runs (body '1') and returns undefined");

// FN-TS-002 — wrapper stringified inside a body via concatenation.
assertEq(new Function("return " + new Object(41) + " + 1;")(), 42,
  "FN-TS-002: Object(41) stringifies to '41' inside the body");

// FN-TS-003 — String wrapper as a parameter NAME (multi-arg form).
assertEq(new Function(new Object("x"), "return x;")(7), 7,
  "FN-TS-003: String-wrapper param name coerces to 'x'");

// FN-TS-004 — Boolean wrapper stringifies to 'true'/'false'.
assertEq(new Function("return " + new Object(true) + ";")(), true,
  "FN-TS-004: Boolean(true) wrapper stringifies to 'true'");

// FN-TS-005 — array of parameter names still joins with commas (pre-existing
// behavior the wrapper fix must not disturb; used by rollup's harness).
assertEq(new Function(["a", "b"], "return a + b;")(2, 3), 5,
  "FN-TS-005: array param list 'a,b' still works");

// FN-TS-006 — plain string body/params unaffected.
assertEq(new Function("a", "b", "return a * b;")(6, 7), 42,
  "FN-TS-006: plain string params/body");

__reg.finalize(__jacOrigExit);
