// ARRAY_COMPREHENSIVE_TEST_PLAN §5.2, §10 — Symbol.iterator, keys/values/entries
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_iterators_symbols.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ARR-Y-010 (function identity — use assert not assertEq; JSON.stringify hides functions in failure output)
if (typeof Symbol !== "undefined" && Symbol.iterator) {
    assert([][Symbol.iterator] === [].values, "ARR-Y-010: @@iterator same function as values");
}

// ARR-Y-011 spread / for-of / Array.from
var itArr = [1, 2, 3];
assertDeep(Array.from(itArr), [1, 2, 3], "ARR-Y-011: Array.from iterable");
assertDeep([...itArr], [1, 2, 3], "ARR-Y-011: spread");
var fo = [];
for (var x of itArr) fo.push(x);
assertDeep(fo, [1, 2, 3], "ARR-Y-011: for-of");

// ARR-Y-012 manual next
var iter = [10, 20][Symbol.iterator]();
var n1 = iter.next();
var n2 = iter.next();
var n3 = iter.next();
assertEq(n1.value, 10, "ARR-Y-012: next value");
assertEq(n1.done, false, "ARR-Y-012: not done");
assertEq(n3.done, true, "ARR-Y-012: done");

// ARR-Y-013 sparse — values yield undefined for holes
var sp = [1, , 3];
var sv = [];
for (var y of sp) sv.push(y);
assertDeep(sv, [1, undefined, 3], "ARR-Y-013: iterator yields undefined for hole");

// ARR-IT-004 new iterator each call
var arr = [1, 2];
assert(arr.keys() !== arr.keys(), "ARR-IT-004: keys() new object");
assert(arr.values() !== arr.values(), "ARR-IT-004: values() new object");
assert(arr.entries() !== arr.entries(), "ARR-IT-004: entries() new object");

// ARR-IT-001 keys on sparse (MDN colors example pattern)
var colors = ["red", "yellow", "blue"];
colors[5] = "purple";
var ks = [];
for (var kk of colors.keys()) ks.push(kk);
assertDeep(ks, [0, 1, 2, 3, 4, 5], "ARR-IT-001: keys all indices to length-1");

// ARR-IT-002 values
var vs = [];
for (var vv of [10, 20, 30].values()) vs.push(vv);
assertDeep(vs, [10, 20, 30], "ARR-IT-002: values");

// ARR-IT-003 entries
var es = [];
for (var ent of [10, 20, 30].entries()) es.push(ent);
assertDeep(
    es,
    [
        [0, 10],
        [1, 20],
        [2, 30],
    ],
    "ARR-IT-003: entries"
);

__jacDone();
