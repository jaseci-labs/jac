// Object tests — js_engine engine
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

// ── 1: empty object ───────────────────────────────────────────────────────
var obj = {};
check(1, "typeof {} === 'object'", typeof obj, "object");

// ── 2: property access ────────────────────────────────────────────────────
var p = { x: 10, y: 20 };
check(2, "p.x === 10", p.x, 10);

// ── 3: property access .y ─────────────────────────────────────────────────
check(3, "p.y === 20", p.y, 20);

// ── 4: bracket notation ───────────────────────────────────────────────────
check(4, "p['x'] === 10", p["x"], 10);

// ── 5: property assignment ────────────────────────────────────────────────
p.z = 30;
check(5, "p.z after assignment === 30", p.z, 30);

// ── 6: nested object ──────────────────────────────────────────────────────
var nested = { a: { b: { c: 42 } } };
check(6, "nested.a.b.c === 42", nested.a.b.c, 42);

// ── 7: 'in' operator true ─────────────────────────────────────────────────
var q = { name: "Alice" };
check(7, "'name' in q === true", "name" in q, true);

// ── 8: 'in' operator false ────────────────────────────────────────────────
check(8, "'age' in q === false", "age" in q, false);

// ── 9: delete property ────────────────────────────────────────────────────
var d = { a: 1, b: 2 };
delete d.a;
check(9, "d.a after delete === undefined", d.a, undefined);

// ── 10: Object.keys length ────────────────────────────────────────────────
var o = { x: 1, y: 2, z: 3 };
check(10, "Object.keys(o).length === 3", Object.keys(o).length, 3);

// ── 11: Object.values length ──────────────────────────────────────────────
check(11, "Object.values(o).length === 3", Object.values(o).length, 3);

// ── 12: Object.entries length ─────────────────────────────────────────────
check(12, "Object.entries(o).length === 3", Object.entries(o).length, 3);

// ── 13: Object.assign copies ──────────────────────────────────────────────
var src = { a: 1, b: 2 };
var target = {};
Object.assign(target, src);
check(13, "target.a after assign === 1", target.a, 1);

// ── 14: Object.assign target.b ────────────────────────────────────────────
check(14, "target.b after assign === 2", target.b, 2);

// ── 15: for...in enumerates keys ──────────────────────────────────────────
var kcount = 0;
var kobj = { a: 1, b: 2, c: 3 };
for (var k in kobj) { kcount = kcount + 1; }
check(15, "for...in count === 3", kcount, 3);

// ── 16: computed property key ─────────────────────────────────────────────
var key = "dynamic";
var co = {};
co[key] = 99;
check(16, "co['dynamic'] === 99", co["dynamic"], 99);

// ── 17: object method call ────────────────────────────────────────────────
var m = { greet: function() { return "hello"; } };
check(17, "m.greet() === 'hello'", m.greet(), "hello");

// ── 18: Object.keys first key via for...of ────────────────────────────────
var keysArr = Object.keys({ a: 1, b: 2 });
check(18, "first key === 'a'", keysArr[0], "a");

// ── 19: Object.values sum ─────────────────────────────────────────────────
var vals = Object.values({ x: 10, y: 20, z: 30 });
var vsum = 0;
for (var v of vals) { vsum = vsum + v; }
check(19, "Object.values sum === 60", vsum, 60);

// ── 20: shorthand check: property set then read ───────────────────────────
var obj2 = {};
obj2["foo"] = "bar";
check(20, "obj2.foo === 'bar'", obj2.foo, "bar");

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Object tests: " + _passed + " passed, " + _failed + " failed ===");
