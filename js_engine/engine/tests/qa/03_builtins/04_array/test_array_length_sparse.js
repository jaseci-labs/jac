// ARRAY_COMPREHENSIVE_TEST_PLAN §3 + sparse / length / generic smoke
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/04_array/test_array_length_sparse.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ── §3 length (ARR-L-*) ─────────────────────────────────────────────────────

var lenArr = [1, 2, 3, 4, 5];
assertEq(lenArr.length, 5, "ARR-L-001: read length");

lenArr.length = 10;
assertEq(lenArr.length, 10, "ARR-L-002: extend length");
assertEq(lenArr[9], undefined, "ARR-L-002: new slots undefined");
assertDeep(Object.keys(lenArr), ["0", "1", "2", "3", "4"], "ARR-L-002: keys only defined indices");

lenArr.length = 3;
assertDeep(lenArr, [1, 2, 3], "ARR-L-003: truncate deletes elements");

var grow = [1, 2];
grow[4] = "x";
assertEq(grow.length, 5, "ARR-L-004: assign past end extends length");

var l5 = false;
try {
    var bad = [1, 2];
    bad.length = -1;
} catch (e) {
    l5 = e instanceof RangeError;
}
assert(l5, "ARR-L-005: length = -1 throws RangeError");

var l5b = false;
try {
    var bad2 = [1, 2];
    bad2.length = Math.pow(2, 32);
} catch (e) {
    l5b = e instanceof RangeError;
}
assert(l5b, "ARR-L-005: length = 2^32 throws RangeError");

// ── Sparse vs dense (MDN overview) ───────────────────────────────────────────

var sparse = ["a", "b", "c"];
sparse[5] = "e";
var fe = [];
sparse.forEach(function (v, i) {
    fe.push(i + ":" + v);
});
assertDeep(fe, ["0:a", "1:b", "2:c", "5:e"], "sparse: forEach skips holes");

var fk = [];
for (var k of sparse.keys()) fk.push(k);
assertEq(fk.length, 6, "sparse: keys visits 0..length-1");

// Generic array-like: join (MDN)
var like = { 0: "a", 1: "b", length: 2 };
assertEq(Array.prototype.join.call(like, "+"), "a+b", "generic: join on array-like");

// Array.prototype.flat.call({}) per MDN
assertDeep(Array.prototype.flat.call({}), [], "generic: flat on {} → []");

__jacDone();
