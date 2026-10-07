// Number tests — js_engine engine
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

// ── 1: parseInt ───────────────────────────────────────────────────────────
check(1, "parseInt('42') === 42", parseInt("42"), 42);

// ── 2: parseInt with radix ────────────────────────────────────────────────
check(2, "parseInt('ff', 16) === 255", parseInt("ff", 16), 255);

// ── 3: parseFloat ─────────────────────────────────────────────────────────
check(3, "parseFloat('3.14') === 3.14", parseFloat("3.14"), 3.14);

// ── 4: isNaN true ─────────────────────────────────────────────────────────
check(4, "isNaN(NaN) === true", isNaN(NaN), true);

// ── 5: isNaN false ────────────────────────────────────────────────────────
check(5, "isNaN(42) === false", isNaN(42), false);

// ── 6: isFinite true ──────────────────────────────────────────────────────
check(6, "isFinite(1) === true", isFinite(1), true);

// ── 7: isFinite false (Infinity) ──────────────────────────────────────────
check(7, "isFinite(Infinity) === false", isFinite(Infinity), false);

// ── 8: Number.isNaN ───────────────────────────────────────────────────────
check(8, "Number.isNaN(NaN) === true", Number.isNaN(NaN), true);

// ── 9: Number.isNaN does not coerce ──────────────────────────────────────
check(9, "Number.isNaN('NaN') === false", Number.isNaN("NaN"), false);

// ── 10: Number.isFinite ───────────────────────────────────────────────────
check(10, "Number.isFinite(100) === true", Number.isFinite(100), true);

// ── 11: Number.isInteger ──────────────────────────────────────────────────
check(11, "Number.isInteger(3) === true", Number.isInteger(3), true);

// ── 12: Number.isInteger float ────────────────────────────────────────────
check(12, "Number.isInteger(3.5) === false", Number.isInteger(3.5), false);

// ── 13: Number.isSafeInteger ──────────────────────────────────────────────
check(13, "Number.isSafeInteger(9007199254740991) === true", Number.isSafeInteger(9007199254740991), true);

// ── 14: Number.isSafeInteger too large ────────────────────────────────────
check(14, "Number.isSafeInteger(9007199254740992) === false", Number.isSafeInteger(9007199254740992), false);

// ── 15: Number.MAX_SAFE_INTEGER ───────────────────────────────────────────
check(15, "Number.MAX_SAFE_INTEGER === 9007199254740991", Number.MAX_SAFE_INTEGER, 9007199254740991);

// ── 16: Number.MIN_SAFE_INTEGER ───────────────────────────────────────────
check(16, "Number.MIN_SAFE_INTEGER === -9007199254740991", Number.MIN_SAFE_INTEGER, -9007199254740991);

// ── 17: Number.POSITIVE_INFINITY ─────────────────────────────────────────
check(17, "Number.POSITIVE_INFINITY === Infinity", Number.POSITIVE_INFINITY, Infinity);

// ── 18: Number.NEGATIVE_INFINITY ─────────────────────────────────────────
check(18, "Number.NEGATIVE_INFINITY === -Infinity", Number.NEGATIVE_INFINITY, -Infinity);

// ── 19: toFixed ───────────────────────────────────────────────────────────
check(19, "(3.14159).toFixed(2) === '3.14'", (3.14159).toFixed(2), "3.14");

// ── 20: toFixed zero decimals ─────────────────────────────────────────────
check(20, "(3.7).toFixed(0) === '4'", (3.7).toFixed(0), "4");

// ── 21: toPrecision ───────────────────────────────────────────────────────
check(21, "(123.456).toPrecision(5) === '123.46'", (123.456).toPrecision(5), "123.46");

// ── 22: toExponential ─────────────────────────────────────────────────────
check(22, "(12345).toExponential(2) === '1.23e+4'", (12345).toExponential(2), "1.23e+4");

// ── 23: Number() coercion from string ─────────────────────────────────────
check(23, "Number('42') === 42", Number("42"), 42);

// ── 24: Number() coercion from bool ───────────────────────────────────────
check(24, "Number(true) === 1", Number(true), 1);

// ── 25: Math.PI constant ──────────────────────────────────────────────────
check(25, "Math.PI === 3.141592653589793", Math.PI, 3.141592653589793);

// ── 26: Math.E constant ───────────────────────────────────────────────────
check(26, "Math.E === 2.718281828459045", Math.E, 2.718281828459045);

// ── 27: Math.SQRT2 constant ───────────────────────────────────────────────
check(27, "Math.SQRT2 === 1.4142135623730951", Math.SQRT2, 1.4142135623730951);

// ── 28: Number.EPSILON ────────────────────────────────────────────────────
check(28, "Number.EPSILON > 0 && Number.EPSILON < 0.001", Number.EPSILON > 0 && Number.EPSILON < 0.001, true);

// ── 29: Arithmetic: integer floor division via parseInt ───────────────────
check(29, "parseInt(7/2) === 3", parseInt(7 / 2), 3);

// ── 30: NaN not equal to itself ───────────────────────────────────────────
check(30, "NaN !== NaN", NaN !== NaN, true);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Number tests: " + _passed + " passed, " + _failed + " failed ===");
