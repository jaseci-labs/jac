// Phase 2.3 — Iterators & Symbol.iterator
// Self-reporting pass/fail test suite for the built js_engine engine.

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

// ── 1: for...of array — sum ────────────────────────────────────────────────
var sum = 0;
for (var x of [1, 2, 3]) { sum = sum + x; }
check(1, "for...of [1,2,3] sum === 6", sum, 6);

// ── 2: for...of string — concatenate ──────────────────────────────────────
var s = "";
for (var c of "abc") { s = s + c; }
check(2, "for...of 'abc' builds 'abc'", s, "abc");

// ── 3: for...of empty array ───────────────────────────────────────────────
var n = 0;
for (var v of []) { n = n + 1; }
check(3, "for...of [] iterates 0 times", n, 0);

// ── 4: for...of empty string ──────────────────────────────────────────────
var n2 = 0;
for (var c2 of "") { n2 = n2 + 1; }
check(4, "for...of '' iterates 0 times", n2, 0);

// ── 5: for...of accumulate string ─────────────────────────────────────────
var res = "";
for (var v2 of [10, 20, 30]) { res = res + v2; }
check(5, "for...of [10,20,30] concatenates '102030'", res, "102030");

// ── 6: for...of count chars ───────────────────────────────────────────────
var nc = 0;
for (var ch of "hello") { nc = nc + 1; }
check(6, "for...of 'hello' counts 5 chars", nc, 5);

// ── 7: for...in plain object key count ────────────────────────────────────
var keyCount = 0;
for (var k in { x: 1, y: 2, z: 3 }) { keyCount = keyCount + 1; }
check(7, "for...in {x,y,z} counts 3 keys", keyCount, 3);

// ── 8: Symbol keys hidden from for...in ───────────────────────────────────
var obj = {};
var hiddenSym = Symbol("hidden");
obj[hiddenSym] = 99;
obj["visible"] = 1;
var visCount = 0;
for (var k2 in obj) { visCount = visCount + 1; }
check(8, "Symbol key hidden from for...in (count === 1)", visCount, 1);

// ── 9: split().length — intern seeding ────────────────────────────────────
check(9, "'a,b,c'.split(',').length === 3", "a,b,c".split(",").length, 3);

// ── 10: string .length ────────────────────────────────────────────────────
check(10, "'hello'.length === 5", "hello".length, 5);

// ── 11: empty string .length ──────────────────────────────────────────────
check(11, "''.length === 0", "".length, 0);

// ── 12: array .length ─────────────────────────────────────────────────────
check(12, "[1,2,3,4].length === 4", [1, 2, 3, 4].length, 4);

// ── 13: split round-trip ──────────────────────────────────────────────────
var parts = "x-y-z".split("-");
check(13, "'x-y-z'.split('-') round-trip === 'xyz'", parts[0] + parts[1] + parts[2], "xyz");

// ── 14: Symbol.iterator typeof on array ───────────────────────────────────
check(14, "[1,2][Symbol.iterator] typeof === 'function'", typeof [1, 2][Symbol.iterator], "function");

// ── 15: Symbol.iterator callable — returns object ─────────────────────────
var iter = [1, 2, 3][Symbol.iterator]();
check(15, "arr[Symbol.iterator]() typeof === 'object'", typeof iter, "object");

// ── 16: Symbol.iterator typeof on string ─────────────────────────────────
check(16, "'abc'[Symbol.iterator] typeof === 'function'", typeof "abc"[Symbol.iterator], "function");

// ── 17: array index access ────────────────────────────────────────────────
var arr2 = [10, 20, 30];
check(17, "[10,20,30][0]+[1]+[2] === 60", arr2[0] + arr2[1] + arr2[2], 60);

// ── 18: nested for...of ───────────────────────────────────────────────────
var total = 0;
for (var row of [[1, 2], [3, 4]]) {
    for (var cell of row) { total = total + cell; }
}
check(18, "nested for...of [[1,2],[3,4]] sum === 10", total, 10);

// ── 19: for...of with break ───────────────────────────────────────────────
var first = -1;
for (var item of [42, 99, 7]) { first = item; break; }
check(19, "for...of with break stops at first === 42", first, 42);

// ── 20: chained: split then for...of ─────────────────────────────────────
var words = "one two three".split(" ");
var joined = "";
for (var w of words) { joined = joined + w; }
check(20, "split then for...of joins 'onetwothree'", joined, "onetwothree");

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Iterator tests: " + _passed + " passed, " + _failed + " failed ===");
