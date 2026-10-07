// Array tests — js_engine engine
// Note: array prototype methods (push/pop/slice/etc.) are NOT JS-accessible in this engine.
// Tests cover: literals, index access, length, assignment, for...of, for...in, Array.isArray.
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

// ── 1: empty array length ─────────────────────────────────────────────────
var empty = [];
check(1, "empty array length === 0", empty.length, 0);

// ── 2: array literal access ───────────────────────────────────────────────
var nums = [10, 20, 30];
check(2, "nums[0] === 10", nums[0], 10);

// ── 3: array index 1 ──────────────────────────────────────────────────────
check(3, "nums[1] === 20", nums[1], 20);

// ── 4: array index 2 ──────────────────────────────────────────────────────
check(4, "nums[2] === 30", nums[2], 30);

// ── 5: array length ───────────────────────────────────────────────────────
check(5, "nums.length === 3", nums.length, 3);

// ── 6: array element assignment ───────────────────────────────────────────
nums[1] = 99;
check(6, "nums[1] after assignment === 99", nums[1], 99);

// ── 7: string array ───────────────────────────────────────────────────────
var words = ["hello", "world"];
check(7, "words[0] === 'hello'", words[0], "hello");

// ── 8: mixed array ────────────────────────────────────────────────────────
var mixed = [1, "two", true];
check(8, "mixed[2] === true", mixed[2], true);

// ── 9: for...of sum ───────────────────────────────────────────────────────
var arr = [1, 2, 3, 4, 5];
var sum = 0;
for (var x of arr) { sum = sum + x; }
check(9, "for...of sum === 15", sum, 15);

// ── 10: for...of count ────────────────────────────────────────────────────
var count = 0;
for (var v of arr) { count = count + 1; }
check(10, "for...of count === 5", count, 5);

// ── 11: for...in gives string keys ────────────────────────────────────────
var keys = [];
for (var k in arr) { keys[keys.length] = k; }
check(11, "for...in first key === '0'", keys[0], "0");

// ── 12: nested array access ───────────────────────────────────────────────
var matrix = [[1, 2], [3, 4]];
check(12, "matrix[1][0] === 3", matrix[1][0], 3);

// ── 13: nested array element 1,1 ──────────────────────────────────────────
check(13, "matrix[1][1] === 4", matrix[1][1], 4);

// ── 14: Array.isArray true ────────────────────────────────────────────────
check(14, "Array.isArray([]) === true", Array.isArray([]), true);

// ── 15: Array.isArray false ───────────────────────────────────────────────
check(15, "Array.isArray({}) === false", Array.isArray({}), false);

// ── 16: Array.isArray string false ────────────────────────────────────────
check(16, "Array.isArray('abc') === false", Array.isArray("abc"), false);

// ── 17: for...of strings ──────────────────────────────────────────────────
var strs = ["a", "b", "c"];
var concat = "";
for (var s of strs) { concat = concat + s; }
check(17, "for...of string concat === 'abc'", concat, "abc");

// ── 18: array of booleans ─────────────────────────────────────────────────
var bools = [true, false, true];
var trueCount = 0;
for (var b of bools) { if (b) { trueCount = trueCount + 1; } }
check(18, "count of true booleans === 2", trueCount, 2);

// ── 19: sparse-ish: assign to index beyond length ─────────────────────────
var sp = [1, 2, 3];
sp[5] = 99;
check(19, "sp[5] === 99", sp[5], 99);

// ── 20: length after gap assignment ───────────────────────────────────────
check(20, "sp.length === 6", sp.length, 6);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Array tests: " + _passed + " passed, " + _failed + " failed ===");
