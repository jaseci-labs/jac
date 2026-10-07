// JSON tests — js_engine engine
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

// ── 1: stringify number ───────────────────────────────────────────────────
check(1, "JSON.stringify(42) === '42'", JSON.stringify(42), "42");

// ── 2: stringify string ───────────────────────────────────────────────────
check(2, "JSON.stringify('hi') === '\"hi\"'", JSON.stringify("hi"), "\"hi\"");

// ── 3: stringify true ─────────────────────────────────────────────────────
check(3, "JSON.stringify(true) === 'true'", JSON.stringify(true), "true");

// ── 4: stringify null ─────────────────────────────────────────────────────
check(4, "JSON.stringify(null) === 'null'", JSON.stringify(null), "null");

// ── 5: stringify simple object ────────────────────────────────────────────
var simple = JSON.stringify({ a: 1 });
check(5, "stringify {a:1} contains '\"a\"'", simple.indexOf("\"a\"") !== -1, true);

// ── 6: stringify then parse round-trip number ─────────────────────────────
var n = JSON.parse(JSON.stringify(123));
check(6, "round-trip number === 123", n, 123);

// ── 7: round-trip string ──────────────────────────────────────────────────
var s = JSON.parse(JSON.stringify("hello"));
check(7, "round-trip string === 'hello'", s, "hello");

// ── 8: round-trip boolean ─────────────────────────────────────────────────
var b = JSON.parse(JSON.stringify(false));
check(8, "round-trip false === false", b, false);

// ── 9: round-trip null ────────────────────────────────────────────────────
var nu = JSON.parse(JSON.stringify(null));
check(9, "round-trip null === null", nu, null);

// ── 10: parse integer ─────────────────────────────────────────────────────
check(10, "JSON.parse('42') === 42", JSON.parse("42"), 42);

// ── 11: parse float ───────────────────────────────────────────────────────
check(11, "JSON.parse('3.14') === 3.14", JSON.parse("3.14"), 3.14);

// ── 12: parse string ──────────────────────────────────────────────────────
check(12, "JSON.parse('\"abc\"') === 'abc'", JSON.parse("\"abc\""), "abc");

// ── 13: parse bool true ───────────────────────────────────────────────────
check(13, "JSON.parse('true') === true", JSON.parse("true"), true);

// ── 14: parse bool false ──────────────────────────────────────────────────
check(14, "JSON.parse('false') === false", JSON.parse("false"), false);

// ── 15: parse null ────────────────────────────────────────────────────────
check(15, "JSON.parse('null') === null", JSON.parse("null"), null);

// ── 16: parse object property ─────────────────────────────────────────────
var obj = JSON.parse("{\"x\":10,\"y\":20}");
check(16, "parsed obj.x === 10", obj.x, 10);

// ── 17: parse object property y ───────────────────────────────────────────
check(17, "parsed obj.y === 20", obj.y, 20);

// ── 18: parse array element ───────────────────────────────────────────────
var arr = JSON.parse("[1,2,3]");
check(18, "parsed arr[0] === 1", arr[0], 1);

// ── 19: parse array element 2 ────────────────────────────────────────────
check(19, "parsed arr[2] === 3", arr[2], 3);

// ── 20: nested object round-trip ─────────────────────────────────────────
var orig = { user: { name: "Bob", age: 30 } };
var rt = JSON.parse(JSON.stringify(orig));
check(20, "nested round-trip user.name === 'Bob'", rt.user.name, "Bob");

// ── 21: nested round-trip age ─────────────────────────────────────────────
check(21, "nested round-trip user.age === 30", rt.user.age, 30);

// ── 22: object with array value round-trip ────────────────────────────────
var oa = { items: [1, 2, 3] };
var oart = JSON.parse(JSON.stringify(oa));
check(22, "items[1] round-trip === 2", oart.items[1], 2);

// ── 23: stringify array ───────────────────────────────────────────────────
check(23, "JSON.stringify([1,2]) === '[1,2]'", JSON.stringify([1, 2]), "[1,2]");

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== JSON tests: " + _passed + " passed, " + _failed + " failed ===");
