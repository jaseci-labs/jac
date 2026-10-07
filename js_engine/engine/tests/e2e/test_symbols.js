// Symbol tests — js_engine engine
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

// ── 1: typeof Symbol() ────────────────────────────────────────────────────
var s = Symbol("test");
check(1, "typeof Symbol() === 'symbol'", typeof s, "symbol");

// ── 2: symbol description ─────────────────────────────────────────────────
check(2, "symbol.description === 'test'", s.description, "test");

// ── 3: two symbols not equal ──────────────────────────────────────────────
var s1 = Symbol("x");
var s2 = Symbol("x");
check(3, "Symbol('x') !== Symbol('x')", s1 !== s2, true);

// ── 4: Symbol.for returns same symbol ─────────────────────────────────────
var g1 = Symbol.for("global");
var g2 = Symbol.for("global");
check(4, "Symbol.for same key === same symbol", g1 === g2, true);

// ── 5: Symbol.keyFor ─────────────────────────────────────────────────────
check(5, "Symbol.keyFor returns key", Symbol.keyFor(g1), "global");

// ── 6: local symbol not in registry ──────────────────────────────────────
check(6, "Symbol.keyFor local === undefined", Symbol.keyFor(s1), undefined);

// ── 7: symbol as object key ──────────────────────────────────────────────
var symKey = Symbol("k");
var obj = {};
obj[symKey] = 42;
check(7, "object[symbol] === 42", obj[symKey], 42);

// ── 8: symbol key hidden from for...in ───────────────────────────────────
var kcount = 0;
for (var k in obj) { kcount = kcount + 1; }
check(8, "symbol key hidden from for...in (count === 0)", kcount, 0);

// ── 9: symbol key hidden from Object.keys ────────────────────────────────
check(9, "Object.keys with symbol key length === 0", Object.keys(obj).length, 0);

// ── 10: Symbol.iterator exists ───────────────────────────────────────────
check(10, "typeof Symbol.iterator === 'symbol'", typeof Symbol.iterator, "symbol");

// ── 11: Symbol.hasInstance exists ────────────────────────────────────────
check(11, "typeof Symbol.hasInstance === 'symbol'", typeof Symbol.hasInstance, "symbol");

// ── 12: Symbol.toPrimitive exists ────────────────────────────────────────
check(12, "typeof Symbol.toPrimitive === 'symbol'", typeof Symbol.toPrimitive, "symbol");

// ── 13: symbol without description ───────────────────────────────────────
var noDesc = Symbol();
check(13, "symbol with no description — description === undefined", noDesc.description, undefined);

// ── 14: multiple symbol keys on same object ───────────────────────────────
var sk1 = Symbol("a");
var sk2 = Symbol("b");
var multi = {};
multi[sk1] = 1;
multi[sk2] = 2;
check(14, "multi[sk1] === 1", multi[sk1], 1);

// ── 15: second symbol key ─────────────────────────────────────────────────
check(15, "multi[sk2] === 2", multi[sk2], 2);

// ── 16: Symbol.for global registration persists ───────────────────────────
var reg = Symbol.for("persist");
check(16, "Symbol.keyFor persisted key", Symbol.keyFor(reg), "persist");

// ── 17: symbol used as method with custom iterator ────────────────────────
var iterable = {};
iterable[Symbol.iterator] = function() {
    var i = 0;
    return {
        next: function() {
            if (i < 3) {
                var v = i;
                i = i + 1;
                return { value: v, done: false };
            }
            return { value: undefined, done: true };
        }
    };
};
var itsum = 0;
for (var n of iterable) { itsum = itsum + n; }
check(17, "custom Symbol.iterator sum (0+1+2) === 3", itsum, 3);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Symbol tests: " + _passed + " passed, " + _failed + " failed ===");
