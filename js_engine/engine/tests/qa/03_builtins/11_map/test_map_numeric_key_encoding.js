// MAP-NUMKEY-*: Map/Set keys are SameValueZero, so a number is one key however
// the engine encodes it — the int32 2 and the float64 2.0 that Math.sqrt(4) or an
// Array.from({ length }) index produces. Regression: integral doubles hashed by
// their raw bits and compared unequal to int32 keys, so rollup's chunk assignment
// (a Map keyed by entry index, probed with Array.from indices) missed every
// lookup and split modules the entry chunk already loads into extra chunks.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/11_map/test_map_numeric_key_encoding.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var m = new Map([[2, "two"], [3, "three"]]);
assertEq(Array.from({ length: 5 }, function (_e, i) { return m.has(i); }).join(), "false,false,true,true,false",
    "MAP-NUMKEY-001: Array.from index keys find int32 keys");
assertEq(m.get(Math.sqrt(4)), "two", "MAP-NUMKEY-002: float64 2.0 finds int32 key 2");
assertEq(m.has(Math.sqrt(9)), true, "MAP-NUMKEY-002: float64 3.0 finds int32 key 3");

var m2 = new Map();
m2.set(Math.sqrt(16), "four");
assertEq(m2.get(4), "four", "MAP-NUMKEY-003: int32 finds a float64-stored key");
m2.set(4, "FOUR");
assertEq(m2.size, 1, "MAP-NUMKEY-003: re-set through the other encoding updates, not duplicates");
assertEq(m2.delete(Math.sqrt(16)), true, "MAP-NUMKEY-003: delete through the other encoding");

var idx = Array.from({ length: 4 }, function (_e, i) { return i; });
assertEq(new Map(idx.map(function (i) { return [i, i * 10]; })).get(2), 20, "MAP-NUMKEY-004: Map built from Array.from indices");
assertEq(new Map([[-0, "z"]]).get(0), "z", "MAP-NUMKEY-005: -0 and +0 are one key");
assertEq(new Map([[NaN, "n"]]).get(0 / 0), "n", "MAP-NUMKEY-005: NaN is one key");
assertEq(new Map([[2.5, "x"]]).get(5 / 2), "x", "MAP-NUMKEY-006: non-integral doubles still match");
assertEq(new Map([[2, "x"]]).has(2.5), false, "MAP-NUMKEY-006: 2 and 2.5 stay distinct");

var s = new Set(idx);
assertEq(s.has(1), true, "MAP-NUMKEY-007: Set of Array.from indices has 1");
assertEq(new Set([2]).has(Math.sqrt(4)), true, "MAP-NUMKEY-007: Set int32 vs float64");
var s2 = new Set([Math.sqrt(4)]);
s2.add(2);
assertEq(s2.size, 1, "MAP-NUMKEY-007: Set add through the other encoding does not duplicate");
assertEq(s2.delete(2), true, "MAP-NUMKEY-007: Set delete through the other encoding");

__jacDone();
