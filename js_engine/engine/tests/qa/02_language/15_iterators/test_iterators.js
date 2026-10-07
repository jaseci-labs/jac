// ITER-001 through ITER-009: Iterator and iterable protocol
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/15_iterators/test_iterators.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ITER-001: Iterator protocol — next() returning {value, done}
function makeRangeIterator(start, end) {
    var current = start;
    return {
        next: function() {
            if (current <= end) {
                return { value: current++, done: false };
            }
            return { value: undefined, done: true };
        }
    };
}
var it = makeRangeIterator(1, 3);
var r1 = it.next(); assertEq(r1.value, 1, "ITER-001: first next()"); assertEq(r1.done, false, "ITER-001: done false");
var r2 = it.next(); assertEq(r2.value, 2, "ITER-001: second next()");
var r3 = it.next(); assertEq(r3.value, 3, "ITER-001: third next()");
var r4 = it.next(); assertEq(r4.done, true, "ITER-001: done true after last"); assertEq(r4.value, undefined, "ITER-001: value undefined after done");

// ITER-002: Iterable protocol — [Symbol.iterator]() returning iterator
function makeRange(start, end) {
    return {
        [Symbol.iterator]: function() { return makeRangeIterator(start, end); }
    };
}
var range = makeRange(1, 3);
var collected = [];
for (var v of range) { collected.push(v); }
assertEq(collected.join(","), "1,2,3", "ITER-002: custom iterable in for-of");
// Reusable: iterate again
var collected2 = [];
for (var v2 of range) { collected2.push(v2); }
assertEq(collected2.join(","), "1,2,3", "ITER-002: iterable reusable");

// ITER-003: Built-in iterables
// Array
var arrVals = [];
for (var av of [10, 20, 30]) { arrVals.push(av); }
assertEq(arrVals.join(","), "10,20,30", "ITER-003: Array iterable");
// String
var chars = [];
for (var ch of "abc") { chars.push(ch); }
assertEq(chars.join(""), "abc", "ITER-003: String iterable");
// Map
var map = new Map([["a", 1], ["b", 2]]);
var mapPairs = [];
for (var [mk, mv] of map) { mapPairs.push(mk + "=" + mv); }
assertEq(mapPairs.join(","), "a=1,b=2", "ITER-003: Map iterable");
// Set
var set = new Set([1, 2, 3]);
var setVals = [];
for (var sv of set) { setVals.push(sv); }
assertEq(setVals.join(","), "1,2,3", "ITER-003: Set iterable");

// ITER-004: for-of + custom — early break
var breakCount = 0;
for (var bv of makeRange(1, 100)) {
    breakCount++;
    if (bv === 3) break;
}
assertEq(breakCount, 3, "ITER-004: early break stops iteration");

// ITER-005: Spread + iterables
var spreadArr = [...makeRange(1, 5)];
assertEq(spreadArr.length, 5,  "ITER-005: spread from custom iterable");
assertEq(spreadArr[0], 1,      "ITER-005: spread first element");
assertEq(spreadArr[4], 5,      "ITER-005: spread last element");
// fn(...iterable)
function sumAll(...args) { return args.reduce((a, b) => a + b, 0); }
assertEq(sumAll(...makeRange(1, 4)), 10, "ITER-005: spread iterable into function call");

// ITER-006: Destructuring + iterables
var [ia, ib, ic] = makeRange(10, 15);
assertEq(ia, 10, "ITER-006: destructure first from iterable");
assertEq(ib, 11, "ITER-006: destructure second from iterable");
assertEq(ic, 12, "ITER-006: destructure third from iterable");

// ITER-007: Array.from with custom iterable
var fromArr = Array.from(makeRange(1, 4));
assertEq(fromArr.length, 4,    "ITER-007: Array.from length");
assertEq(fromArr[0], 1,        "ITER-007: Array.from first");
assertEq(fromArr[3], 4,        "ITER-007: Array.from last");
// with map function
var doubled = Array.from(makeRange(1, 3), function(x) { return x * 2; });
assertEq(doubled.join(","), "2,4,6", "ITER-007: Array.from with mapFn");

// ITER-008: Infinite iterators — lazy + break
function makeInfinite(start) {
    var n = start;
    return {
        [Symbol.iterator]: function() { return this; },
        next: function() { return { value: n++, done: false }; }
    };
}
var infVals = [];
for (var iv of makeInfinite(0)) {
    infVals.push(iv);
    if (iv === 4) break;
}
assertEq(infVals.join(","), "0,1,2,3,4", "ITER-008: infinite iterator with break");

// ITER-009: Iterator return() — called on early break
var returnCalled = false;
var earlyBreakIt = {
    [Symbol.iterator]: function() {
        var n = 0;
        return {
            next: function() { return { value: n++, done: false }; },
            return: function() { returnCalled = true; return { done: true }; }
        };
    }
};
for (var x of earlyBreakIt) {
    if (x === 2) break;
}
assert(returnCalled, "ITER-009: return() called on early break");

__jacDone();
