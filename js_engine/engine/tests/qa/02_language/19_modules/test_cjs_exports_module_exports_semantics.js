// testing_plans/04_node_globals/NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — G3
// NCJS-EXP-*
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/19_modules/test_cjs_exports_module_exports_semantics.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// NCJS-EXP-001
assert(exports === module.exports, "NCJS-EXP-001: exports initially aliases module.exports");

// NCJS-EXP-002
var ex2 = require("./mod_fixture_exports.js");
assertEq(ex2.a, 1, "NCJS-EXP-002: exports property visible to importer");
assertEq(ex2.b, "x", "NCJS-EXP-002: exports string property");

// NCJS-EXP-003
var ex3 = require("./mod_fixture_exports_rebind.js");
assertEq(ex3.brokenProp, undefined, "NCJS-EXP-003: rebind exports does not change module.exports");

// NCJS-EXP-004
var ex4 = require("./mod_fixture_function.js");
assertEq(typeof ex4, "function", "NCJS-EXP-004: module.exports function visible");
assertEq(ex4(4), 16, "NCJS-EXP-004: exported function callable");

// NCJS-EXP-005
var ex5 = require("./fixtures_cjs_globals/exports_then_reassign.js");
assertEq(ex5.phase, 1, "NCJS-EXP-005: importer sees module.exports after reassignment");
assertEq(ex5.stale, undefined, "NCJS-EXP-005: exports.* after module.exports= does not attach to export");

// NCJS-EXP-101 — circular partial exports (same fixtures as MOD-008)
var circA = require("./mod_fixture_circ_a.js");
assert(circA.fromA !== undefined, "NCJS-EXP-101: circular partial exports fromA");
assertEq(circA.fromB, "b-value", "NCJS-EXP-101: circular partial exports fromB");

// NCJS-EXP-102 — mutation after load visible via cached reference
var late = require("./fixtures_cjs_globals/late_mutate.js");
assertEq(late.n, 1, "NCJS-EXP-102: initial export");
late.n = 99;
var late2 = require("./fixtures_cjs_globals/late_mutate.js");
assert(late === late2, "NCJS-EXP-102: same cached export object");
assertEq(late2.n, 99, "NCJS-EXP-102: mutation visible through cache");

// NCJS-EXP-103 / NCJS-EXP-004 — bump replaces module.exports
var rb = require("./fixtures_cjs_globals/reexport_bump.js");
assertEq(rb.tag, "first", "NCJS-EXP-103: initial tag");
var refBefore = rb;
rb.bump();
var rb2 = require("./fixtures_cjs_globals/reexport_bump.js");
assertEq(rb2.tag, "second", "NCJS-EXP-103: require returns new module.exports");
assertEq(refBefore.tag, "first", "NCJS-EXP-103: captured reference keeps old object shape");
assert(refBefore !== rb2, "NCJS-EXP-103: identity differs after bump");

console.log("ok cjs exports / module.exports semantics (NCJS-EXP-*)");
__jacDone();
