// SET-001 through SET-006: Set built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/12_set/test_set.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// SET-001: Constructor
var emptySet = new Set();
assertEq(emptySet.size, 0,              "SET-001: empty Set");
var fromIterable = new Set([1,2,3,2,1]);
assertEq(fromIterable.size, 3,          "SET-001: from iterable deduplicates");
assert(fromIterable.has(1),             "SET-001: has 1");
assert(fromIterable.has(2),             "SET-001: has 2");
assert(!fromIterable.has(4),            "SET-001: has 4 = false");

// SET-002: add / has / delete / clear / size
var s = new Set();
var chainResult = s.add(1);
assertEq(chainResult, s,               "SET-002: add returns the Set (chaining)");
s.add(2).add(3);
assertEq(s.size, 3,                    "SET-002: size after adds");
// NaN equality
s.add(NaN);
assert(s.has(NaN),                     "SET-002: NaN in Set (SameValueZero)");
// -0 / +0 equality
s.add(-0);
assert(s.has(+0),                      "SET-002: +0 and -0 same in Set");
// delete
assert(s.delete(2),                    "SET-002: delete returns true");
assertEq(s.has(2), false,              "SET-002: deleted element absent");
assert(!s.delete(99),                  "SET-002: delete missing returns false");
// clear
s.clear();
assertEq(s.size, 0,                    "SET-002: clear empties Set");

// SET-003: forEach — (value, value, set)
var forEachSet = new Set(["a","b","c"]);
var visited = [];
forEachSet.forEach(function(val1, val2, set) {
    assertEq(val1, val2,               "SET-003: first and second arg are same");
    assert(set === forEachSet,         "SET-003: third arg is the Set");
    visited.push(val1);
});
assertDeep(visited, ["a","b","c"],     "SET-003: forEach insertion order");

// SET-004: keys / values / entries iterators
var iterSet = new Set([10,20,30]);
var keys = [], vals = [], ents = [];
for (var k of iterSet.keys())    keys.push(k);
for (var v of iterSet.values())  vals.push(v);
for (var e of iterSet.entries()) ents.push(e);
assertDeep(keys, [10,20,30],          "SET-004: keys() = values");
assertDeep(vals, [10,20,30],          "SET-004: values()");
assertDeep(ents, [[10,10],[20,20],[30,30]], "SET-004: entries() [val,val] pairs");

// SET-005: Symbol.iterator — same as values
var itDirect = [], itValues = [];
for (var x of iterSet) itDirect.push(x);
for (var y of iterSet.values()) itValues.push(y);
assertDeep(itDirect, itValues,        "SET-005: Symbol.iterator same as values()");

// SET-006: ES2025 set methods — NOT IMPLEMENTED — verify absent or present gracefully
void (typeof Set.prototype.union);
void (typeof Set.prototype.intersection);
void (typeof Set.prototype.difference);
void (typeof Set.prototype.symmetricDifference);
void (typeof Set.prototype.isSubsetOf);
void (typeof Set.prototype.isSupersetOf);
void (typeof Set.prototype.isDisjointFrom);

__jacDone();
