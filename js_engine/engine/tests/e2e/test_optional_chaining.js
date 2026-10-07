// test_optional_chaining.js — optional chaining correctness tests
// ================================================================
// Verifies that `a?.b.c` short-circuits the entire tail when the root
// is nullish.  Previously, `a?.b` evaluated to undefined and then
// GET_PROP c ran unconditionally on that result → TypeError.  The
// correct behaviour is to compile the whole chain inside a single
// short-circuit scope so any nullish root skips ALL remaining accesses.

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + String(expected));
        console.log("     actual:   " + String(actual));
        _failed = _failed + 1;
    }
}

function checkThrows(id, desc, fn) {
    try {
        fn();
        console.log("FAIL " + id + "  " + desc + " (no throw)");
        _failed = _failed + 1;
    } catch (e) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    }
}

// ── 1. Null root: a?.b → undefined ────────────────────────────────────────
var r1 = null;
check(1, "null?.prop === undefined", r1?.prop, undefined);

// ── 2. Undefined root: a?.b → undefined ───────────────────────────────────
var r2;
check(2, "undefined?.prop === undefined", r2?.prop, undefined);

// ── 3. Null root + tail: a?.b.c short-circuits ────────────────────────────
// Before fix: a?.b evaluated to undefined, then GET_PROP c threw TypeError.
var obj3 = null;
check(3, "null?.foo.bar === undefined", obj3?.foo.bar, undefined);

// ── 4. Three-deep tail after optional root ────────────────────────────────
var obj4 = null;
check(4, "null?.a.b.c === undefined", obj4?.a.b.c, undefined);

// ── 5. Non-null root: tail is traversed normally ──────────────────────────
var obj5 = { a: { b: { c: 42 } } };
check(5, "obj?.a.b.c === 42 when obj is non-null", obj5?.a.b.c, 42);

// ── 6. Non-null root but intermediate null: tail throws (NOT optional) ─────
// Only the ?. on the root is optional; .b.c on a null middle is a real error.
var obj6 = { a: null };
checkThrows(6, "obj?.a.b throws when intermediate is null (tail not optional)", function() {
    return obj6?.a.b;
});

// ── 7. Method call in optional chain ──────────────────────────────────────
var obj7 = { getName: function() { return "Alice"; } };
check(7, "obj?.getName() === 'Alice'", obj7?.getName(), "Alice");

// ── 8. Null root: optional method call → undefined ────────────────────────
var obj8 = null;
check(8, "null?.getName() === undefined", obj8?.getName(), undefined);

// ── 9. Optional member access + tail property short-circuits ─────────────────
// a?.b.c: the tail .c must be inside the same short-circuit scope as the
// root ?.b.  When a is null, both accesses are skipped.
var obj9 = null;
check(9, "null?.config.timeout === undefined", obj9?.config.timeout, undefined);

// ── 10. Nested object: two levels with optional root ──────────────────────
var obj10 = { user: { address: { city: "London" } } };
check(10, "obj?.user.address.city === 'London'", obj10?.user.address.city, "London");

// ── 11. Optional index access on null ─────────────────────────────────────
var arr11 = null;
check(11, "null?.[0] === undefined", arr11?.[0], undefined);

// ── 12. Optional index + tail property short-circuits ─────────────────────
var arr12 = null;
check(12, "null?.[0].name === undefined", arr12?.[0].name, undefined);

// ── 13. Valid array: optional index + tail property works ─────────────────
var arr13 = [{ name: "Bob" }, { name: "Carol" }];
check(13, "arr?.[1].name === 'Carol'", arr13?.[1].name, "Carol");

// ── 14. Chained optional (?. on both levels) ──────────────────────────────
var obj14 = { a: null };
check(14, "obj?.a?.b === undefined (double optional)", obj14?.a?.b, undefined);

// ── 15. Vite's exact pattern: key.startsWith after optional ───────────────
// Vite's loadEnv iterates env keys with optional chaining; this was the
// original crash site: `key.startsWith(prefix)` after `a?.b` produced undefined.
var env15 = { VITE_API: "https://api.example.com", NODE_ENV: "production" };
var prefix15 = "VITE_";
var matched15 = [];
for (var k15 in env15) {
    // Simulate: obj?.key giving the value, then .startsWith on it
    var val15 = env15?.[k15];
    if (val15 !== undefined && k15.startsWith(prefix15)) {
        matched15.push(k15);
    }
}
check(15, "Vite loadEnv pattern: matched VITE_ keys", matched15.length, 1);
check(15, "Vite loadEnv pattern: matched key is VITE_API", matched15[0], "VITE_API");

// ── 16. Optional chaining with nullish coalescing ─────────────────────────
var obj16 = null;
var r16 = obj16?.name ?? "default";
check(16, "null?.name ?? 'default' === 'default'", r16, "default");

// ── 17. Non-null result with nullish coalescing ────────────────────────────
var obj17 = { name: "Dave" };
var r17 = obj17?.name ?? "default";
check(17, "obj?.name ?? 'default' === 'Dave'", r17, "Dave");

// ── 18. Optional chain in ternary condition ────────────────────────────────
var obj18 = null;
var r18 = obj18?.active ? "yes" : "no";
check(18, "null?.active ? 'yes' : 'no' === 'no'", r18, "no");

// ── 19. Optional chain result passed to function ──────────────────────────
function len19(s) { return s === undefined ? -1 : s.length; }
var obj19 = null;
check(19, "len(null?.str) === -1", len19(obj19?.str), -1);

// ── 20. Optional chain in arrow function body ──────────────────────────────
var getCity = function(u) { return u?.address.city; };
check(20, "getCity(null) === undefined", getCity(null), undefined);
check(20, "getCity({address:{city:'Paris'}}) === 'Paris'", getCity({ address: { city: "Paris" } }), "Paris");

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Optional-chaining tests: " + _passed + " passed, " + _failed + " failed ===");
if (_failed > 0) process.exit(1);
