// GEN-MREST-*: a generator called as a METHOD collects its rest parameter like any
// other call. Regression: the method-call path copied arguments into parameter slots
// one-for-one, so `o.all([g1, g2])` bound `...args` to the array itself (args =
// [g1, g2]) and dropped extra arguments — gensync's `gensync.all(items)` saw the
// wrong items and Babel produced no plugin descriptors (plugin-react did nothing).
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generator_method_rest_params.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
var J = function (v) { return JSON.stringify(v); };

var o = {
    all: function* (...args) { return args; },
    mixed: function* (a, ...rest) { return [a, rest]; },
    *short(...xs) { return xs.length; },
};
assertEq(J(o.all([1, 2]).next().value), "[[1,2]]", "GEN-MREST-001: single array argument stays one argument");
assertEq(J(o.all(1, 2, 3).next().value), "[1,2,3]", "GEN-MREST-002: several arguments are all collected");
assertEq(J(o.all().next().value), "[]", "GEN-MREST-003: no arguments -> empty rest");
assertEq(J(o.mixed("a", "b", "c").next().value), "[\"a\",[\"b\",\"c\"]]", "GEN-MREST-004: leading param + rest");
assertEq(o.short(1, 2, 3, 4).next().value, 4, "GEN-MREST-005: shorthand generator method");
class C { *m(...xs) { yield xs.length; } static *s(...xs) { return xs; } }
assertEq(new C().m(9, 9).next().value, 2, "GEN-MREST-006: class generator method");
assertEq(J(C.s([7]).next().value), "[[7]]", "GEN-MREST-006: static generator method");

__jacDone();
