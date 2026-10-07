// ARRAY_COMPREHENSIVE_TEST_PLAN §6 — mutating methods
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_mutators.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ARR-M-001 push
var p = [1, 2, 3];
assertEq(p.push(4, 5), 5, "ARR-M-001: push returns length");
assertDeep(p, [1, 2, 3, 4, 5], "ARR-M-001: push multiple");

// ARR-M-002 pop
assertEq([].pop(), undefined, "ARR-M-002: pop empty → undefined");
assertEq(p.pop(), 5, "ARR-M-002: pop returns element");

// ARR-M-003 shift
var sh = [1, 2, 3];
assertEq(sh.shift(), 1, "ARR-M-003: shift returns first");
assertDeep(sh, [2, 3], "ARR-M-003: shift reindexes");
assertEq([].shift(), undefined, "ARR-M-003: shift empty");

// ARR-M-004 unshift
var un = [2, 3];
assertEq(un.unshift(0, 1), 4, "ARR-M-004: unshift returns length");
assertDeep(un, [0, 1, 2, 3], "ARR-M-004: unshift order");

// ARR-M-010 splice
var sp = [1, 2, 3, 4, 5];
var rem = sp.splice(1, 2);
assertDeep(rem, [2, 3], "ARR-M-010: splice return removed");
assertDeep(sp, [1, 4, 5], "ARR-M-010: splice delete");
sp.splice(1, 0, 20, 30);
assertDeep(sp, [1, 20, 30, 4, 5], "ARR-M-010: splice insert");
var sp2 = [1, 2, 3, 4, 5];
var tail = sp2.splice(-2);
assertDeep(tail, [4, 5], "ARR-M-011: splice negative start, delete to end");
assertDeep(sp2, [1, 2, 3], "ARR-M-011: remainder");

// ARR-M-012 start beyond length — inserts after end (clamped), does not create sparse gap to index 10
var sp3 = [1, 2, 3];
sp3.splice(10, 0, 9);
assertEq(sp3.length, 4, "ARR-M-012: length grows by one insert");
assertEq(sp3[3], 9, "ARR-M-012: value appended at end");

// ARR-M-020 reverse
var rev = [1, 2, 3];
var rref = rev.reverse();
assert(rref === rev, "ARR-M-020: reverse same reference");
assertDeep(rev, [3, 2, 1], "ARR-M-020: reversed order");

// ARR-M-021 / M-022 sort
var lex = ["banana", "apple", "cherry"];
lex.sort();
assertDeep(lex, ["apple", "banana", "cherry"], "ARR-M-021: default string sort");
var nums = [10, 2, 1, 100];
nums.sort(function (a, b) {
    return a - b;
});
assertDeep(nums, [1, 2, 10, 100], "ARR-M-022: numeric compareFn");

// ARR-M-030 fill
assertDeep([1, 2, 3, 4].fill(0), [0, 0, 0, 0], "ARR-M-030: fill full");
assertDeep([1, 2, 3, 4].fill(7, 1, 3), [1, 7, 7, 4], "ARR-M-030: fill range");
assertDeep([1, 2, 3, 4].fill(5, -2), [1, 2, 5, 5], "ARR-M-030: fill negative start");

// ARR-M-031 fill on holes (newer methods treat hole as undefined)
var hol = new Array(3);
var filled = hol.fill(1);
assertEq(filled[0], 1, "ARR-M-031: fill defines empty slots");

// ARR-M-040 copyWithin
assertDeep([1, 2, 3, 4, 5].copyWithin(1, 3), [1, 4, 5, 4, 5], "ARR-M-040: copyWithin");
assertDeep([1, 2, 3, 4, 5].copyWithin(0, 3, 4), [4, 2, 3, 4, 5], "ARR-M-040: copyWithin with end");
assertDeep([1, 2, 3, 4, 5].copyWithin(-2, -3, -1), [1, 2, 3, 3, 4], "ARR-M-040: negative indices");

__jacDone();
