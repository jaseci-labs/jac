// MAP-STR-001 through MAP-STR-003: new Map(iterable) with a STRING argument.
// A string IS iterable, so per §24.1.1.1 AddEntriesFromIterable the constructor
// must iterate it and then throw the per-element "Iterator value is not an
// entry object" TypeError (each char is not an [k,v] object) — NOT a blanket
// "object is not iterable" error. Companion to the Set string-iterable fix.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/11_map/test_map_string_iterable.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// MAP-STR-001: string arg throws the per-entry TypeError (spec), not not-iterable
var m1Threw = false, m1Msg = "";
try { new Map("ab"); } catch (e) { m1Threw = e instanceof TypeError; m1Msg = String(e.message || ""); }
assert(m1Threw, "MAP-STR-001: new Map(string) throws TypeError");
assert(m1Msg.indexOf("entry") !== -1,
    "MAP-STR-001: error is the per-element entry-object TypeError (got: " + m1Msg + ")");

// MAP-STR-002: entry-pair iterables still construct fine
var m2 = new Map([["k", 1], ["j", 2]]);
assertEq(m2.get("k"), 1, "MAP-STR-002: array-of-pairs arg");
assertEq(m2.size, 2, "MAP-STR-002: size");

// MAP-STR-003: generator of pairs still works
function* pairs() { yield ["a", 1]; yield ["b", 2]; }
assertEq(new Map(pairs()).get("b"), 2, "MAP-STR-003: generator-of-pairs arg");

__jacDone();
