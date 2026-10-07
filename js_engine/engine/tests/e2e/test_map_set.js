// Phase 2.4 — Map, Set, WeakMap, WeakSet
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

// ── 1: empty Map size === 0 ───────────────────────────────────────────────
var m = new Map();
check(1, "new Map() size === 0", m.size, 0);

// ── 2: Map.set and Map.get ────────────────────────────────────────────────
m.set("a", 1);
check(2, "map.get('a') === 1", m.get("a"), 1);

// ── 3: Map.size after one entry ───────────────────────────────────────────
check(3, "map.size === 1", m.size, 1);

// ── 4: Map.has existing key ───────────────────────────────────────────────
check(4, "map.has('a') === true", m.has("a"), true);

// ── 5: Map.has missing key ────────────────────────────────────────────────
check(5, "map.has('z') === false", m.has("z"), false);

// ── 6: Map.get missing key returns undefined ──────────────────────────────
check(6, "map.get('z') === undefined", m.get("z"), undefined);

// ── 7: Map.set update existing key ────────────────────────────────────────
m.set("a", 99);
check(7, "map.get('a') after update === 99", m.get("a"), 99);

// ── 8: Map size unchanged after update ───────────────────────────────────
check(8, "map.size still 1 after update", m.size, 1);

// ── 9: Map.delete existing key ────────────────────────────────────────────
m.set("b", 2);
var delResult = m.delete("a");
check(9, "map.delete('a') returns true", delResult, true);

// ── 10: Map.delete non-existing key ──────────────────────────────────────
var delResult2 = m.delete("a");
check(10, "map.delete('a') second time returns false", delResult2, false);

// ── 11: Map.size after delete ────────────────────────────────────────────
check(11, "map.size === 1 after deleting 'a'", m.size, 1);

// ── 12: Map constructor from array of pairs ───────────────────────────────
var m2 = new Map([["x", 10], ["y", 20], ["z", 30]]);
check(12, "Map from pairs get('x') === 10", m2.get("x"), 10);
check(12, "Map from pairs get('z') === 30", m2.get("z"), 30);

// ── 13: Map.size from constructor ─────────────────────────────────────────
check(13, "Map from pairs size === 3", m2.size, 3);

// ── 14: Map.keys() returns iterable array ─────────────────────────────────
var kArr = m2.keys();
var kSum = "";
for (var k of kArr) { kSum = kSum + k; }
check(14, "map.keys() iterates 'xyz'", kSum, "xyz");

// ── 15: Map.values() returns iterable array ───────────────────────────────
var vArr = m2.values();
var vSum = 0;
for (var v of vArr) { vSum = vSum + v; }
check(15, "map.values() sum === 60", vSum, 60);

// ── 16: Map.entries() returns [k,v] pair array ────────────────────────────
var eArr = m2.entries();
var eSum = 0;
for (var entry of eArr) {
    eSum = eSum + entry[1];
}
check(16, "map.entries() value sum === 60", eSum, 60);

// ── 17: for...of Map directly gives [k,v] entries ────────────────────────
var mapSum = 0;
var m3 = new Map([[1, 100], [2, 200], [3, 300]]);
for (var pair of m3) {
    mapSum = mapSum + pair[0] + pair[1];
}
check(17, "for..of map pairs sum === 606", mapSum, 606);

// ── 18: Map.clear() ───────────────────────────────────────────────────────
var mc = new Map([["a", 1], ["b", 2]]);
mc.clear();
check(18, "map.clear() size === 0", mc.size, 0);
check(18, "map.clear() get returns undefined", mc.get("a"), undefined);

// ── 19: Map integer keys ──────────────────────────────────────────────────
var mi = new Map();
mi.set(1, "one");
mi.set(2, "two");
check(19, "Map int key get(1) === 'one'", mi.get(1), "one");
check(19, "Map int key get(2) === 'two'", mi.get(2), "two");

// ── 20: empty Set size === 0 ─────────────────────────────────────────────
var s = new Set();
check(20, "new Set() size === 0", s.size, 0);

// ── 21: Set.add and Set.has ───────────────────────────────────────────────
s.add(1);
s.add(2);
s.add(3);
check(21, "set.has(1) === true", s.has(1), true);
check(21, "set.has(4) === false", s.has(4), false);

// ── 22: Set.size ─────────────────────────────────────────────────────────
check(22, "set.size === 3", s.size, 3);

// ── 23: Set deduplication ─────────────────────────────────────────────────
s.add(2);
check(23, "set.size still 3 after re-adding 2", s.size, 3);

// ── 24: Set constructor from array (deduplicates) ─────────────────────────
var s2 = new Set([1, 2, 2, 3, 3, 3]);
check(24, "Set from [1,2,2,3,3,3] size === 3", s2.size, 3);

// ── 25: Set.has after construction ────────────────────────────────────────
check(25, "s2.has(3) === true", s2.has(3), true);

// ── 26: Set.delete ────────────────────────────────────────────────────────
var sDelResult = s2.delete(2);
check(26, "set.delete(2) returns true", sDelResult, true);
check(26, "set.size after delete === 2", s2.size, 2);

// ── 27: Set.delete non-existing ───────────────────────────────────────────
var sDelResult2 = s2.delete(99);
check(27, "set.delete(99) returns false", sDelResult2, false);

// ── 28: for...of Set ─────────────────────────────────────────────────────
var s3 = new Set([10, 20, 30]);
var setSum = 0;
for (var sv of s3) { setSum = setSum + sv; }
check(28, "for..of set sum === 60", setSum, 60);

// ── 29: Set.values() iterable ────────────────────────────────────────────
var vArr2 = s3.values();
var vSum2 = 0;
for (var sv2 of vArr2) { vSum2 = vSum2 + sv2; }
check(29, "set.values() sum === 60", vSum2, 60);

// ── 30: Set.clear() ───────────────────────────────────────────────────────
var sc = new Set([1, 2, 3]);
sc.clear();
check(30, "set.clear() size === 0", sc.size, 0);

// ── 31: Set string values ────────────────────────────────────────────────
var ss = new Set(["a", "b", "c", "a"]);
check(31, "Set strings size === 3", ss.size, 3);
check(31, "Set strings has('b') === true", ss.has("b"), true);

// ── 32: WeakMap does not throw ────────────────────────────────────────────
var wm = new WeakMap();
var obj1 = {};
wm.set(obj1, "value");
check(32, "WeakMap.has(obj1) === true", wm.has(obj1), true);
check(32, "WeakMap.get(obj1) === 'value'", wm.get(obj1), "value");

// ── 33: WeakMap.delete ────────────────────────────────────────────────────
var delWm = wm.delete(obj1);
check(33, "WeakMap.delete returns true", delWm, true);
check(33, "WeakMap.has after delete === false", wm.has(obj1), false);

// ── 34: WeakSet does not throw ────────────────────────────────────────────
var ws = new WeakSet();
var obj2 = {};
ws.add(obj2);
check(34, "WeakSet.has(obj2) === true", ws.has(obj2), true);

// ── 35: WeakSet.delete ────────────────────────────────────────────────────
ws.delete(obj2);
check(35, "WeakSet.has after delete === false", ws.has(obj2), false);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Map/Set tests: " + _passed + " passed, " + _failed + " failed ===");
