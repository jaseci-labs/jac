// Math tests — js_engine engine
// Tests all 35 Math methods (§21.3 ECMAScript) and 7 constants.
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

// Floating-point approximate equality (within 1e-9)
function near(id, desc, actual, expected) {
    var diff = actual - expected;
    if (diff < 0) { diff = -diff; }
    var ok = diff < 1e-9;
    if (ok) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

// ── Constants ──────────────────────────────────────────────────────────────
check(1,  "Math.PI",       Math.PI,       3.141592653589793);
check(2,  "Math.E",        Math.E,        2.718281828459045);
check(3,  "Math.LN2",      Math.LN2,      0.6931471805599453);
check(4,  "Math.LN10",     Math.LN10,     2.302585092994046);
check(5,  "Math.LOG2E",    Math.LOG2E,    1.4426950408889634);
check(6,  "Math.LOG10E",   Math.LOG10E,   0.4342944819032518);
check(7,  "Math.SQRT2",    Math.SQRT2,    1.4142135623730951);

// ── Math.abs ───────────────────────────────────────────────────────────────
check(8,  "Math.abs(-5)",          Math.abs(-5),          5);
check(9,  "Math.abs(5)",           Math.abs(5),           5);
check(10, "Math.abs(-3.14)",       Math.abs(-3.14),       3.14);
check(11, "Math.abs(0)",           Math.abs(0),           0);

// ── Math.ceil ───────────────────────────────────────────────────────────────
check(12, "Math.ceil(3.1)",        Math.ceil(3.1),        4);
check(13, "Math.ceil(-3.1)",       Math.ceil(-3.1),       -3);
check(14, "Math.ceil(3.0)",        Math.ceil(3.0),        3);

// ── Math.floor ─────────────────────────────────────────────────────────────
check(15, "Math.floor(3.9)",       Math.floor(3.9),       3);
check(16, "Math.floor(-3.1)",      Math.floor(-3.1),      -4);
check(17, "Math.floor(3.0)",       Math.floor(3.0),       3);

// ── Math.round ─────────────────────────────────────────────────────────────
check(18, "Math.round(3.5)",       Math.round(3.5),       4);
check(19, "Math.round(3.4)",       Math.round(3.4),       3);
check(20, "Math.round(-3.5)",      Math.round(-3.5),      -3);
check(21, "Math.round(-3.6)",      Math.round(-3.6),      -4);

// ── Math.trunc ─────────────────────────────────────────────────────────────
check(22, "Math.trunc(3.9)",       Math.trunc(3.9),       3);
check(23, "Math.trunc(-3.9)",      Math.trunc(-3.9),      -3);
check(24, "Math.trunc(0.9)",       Math.trunc(0.9),       0);

// ── Math.sqrt ──────────────────────────────────────────────────────────────
near(25,  "Math.sqrt(9)",          Math.sqrt(9),          3.0);
near(26,  "Math.sqrt(2)",          Math.sqrt(2),          1.4142135623730951);
near(27,  "Math.sqrt(0)",          Math.sqrt(0),          0.0);

// ── Math.cbrt ──────────────────────────────────────────────────────────────
near(28,  "Math.cbrt(27)",         Math.cbrt(27),         3.0);
near(29,  "Math.cbrt(-8)",         Math.cbrt(-8),         -2.0);

// ── Math.pow ───────────────────────────────────────────────────────────────
near(30,  "Math.pow(2,10)",        Math.pow(2,10),        1024.0);
near(31,  "Math.pow(9,0.5)",       Math.pow(9, 0.5),      3.0);
near(32,  "Math.pow(2,-1)",        Math.pow(2, -1),       0.5);
check(33, "Math.pow(0,0)",         Math.pow(0, 0),        1);

// ── Math.exp / Math.expm1 ─────────────────────────────────────────────────
near(34,  "Math.exp(0)",           Math.exp(0),           1.0);
near(35,  "Math.exp(1)",           Math.exp(1),           2.718281828459045);
near(36,  "Math.expm1(0)",         Math.expm1(0),         0.0);
near(37,  "Math.expm1(1)",         Math.expm1(1),         1.718281828459045);

// ── Math.log / Math.log2 / Math.log10 / Math.log1p ────────────────────────
near(38,  "Math.log(1)",           Math.log(1),           0.0);
near(39,  "Math.log(Math.E)",      Math.log(Math.E),      1.0);
near(40,  "Math.log2(8)",          Math.log2(8),          3.0);
near(41,  "Math.log2(1)",          Math.log2(1),          0.0);
near(42,  "Math.log10(1000)",      Math.log10(1000),      3.0);
near(43,  "Math.log10(1)",         Math.log10(1),         0.0);
near(44,  "Math.log1p(0)",         Math.log1p(0),         0.0);
near(45,  "Math.log1p(Math.E-1)",  Math.log1p(Math.E - 1), 1.0);

// ── Math.sin / Math.cos / Math.tan ────────────────────────────────────────
near(46,  "Math.sin(0)",           Math.sin(0),           0.0);
near(47,  "Math.sin(PI/2)",        Math.sin(Math.PI / 2), 1.0);
near(48,  "Math.cos(0)",           Math.cos(0),           1.0);
near(49,  "Math.cos(PI)",          Math.cos(Math.PI),    -1.0);
near(50,  "Math.tan(0)",           Math.tan(0),           0.0);
near(51,  "Math.tan(PI/4)",        Math.tan(Math.PI / 4), 1.0);

// ── Math.asin / Math.acos / Math.atan / Math.atan2 ────────────────────────
near(52,  "Math.asin(0)",          Math.asin(0),          0.0);
near(53,  "Math.asin(1)",          Math.asin(1),          Math.PI / 2);
near(54,  "Math.acos(1)",          Math.acos(1),          0.0);
near(55,  "Math.acos(0)",          Math.acos(0),          Math.PI / 2);
near(56,  "Math.atan(0)",          Math.atan(0),          0.0);
near(57,  "Math.atan(1)",          Math.atan(1),          Math.PI / 4);
near(58,  "Math.atan2(1,1)",       Math.atan2(1, 1),      Math.PI / 4);
near(59,  "Math.atan2(0,1)",       Math.atan2(0, 1),      0.0);
near(60,  "Math.atan2(1,0)",       Math.atan2(1, 0),      Math.PI / 2);

// ── Math.sinh / Math.cosh / Math.tanh ─────────────────────────────────────
near(61,  "Math.sinh(0)",          Math.sinh(0),          0.0);
near(62,  "Math.cosh(0)",          Math.cosh(0),          1.0);
near(63,  "Math.tanh(0)",          Math.tanh(0),          0.0);

// ── Math.asinh / Math.acosh / Math.atanh ──────────────────────────────────
near(64,  "Math.asinh(0)",         Math.asinh(0),         0.0);
near(65,  "Math.acosh(1)",         Math.acosh(1),         0.0);
near(66,  "Math.atanh(0)",         Math.atanh(0),         0.0);

// ── Math.hypot ─────────────────────────────────────────────────────────────
near(67,  "Math.hypot(3,4)",       Math.hypot(3, 4),      5.0);
near(68,  "Math.hypot(0)",         Math.hypot(0),         0.0);
near(69,  "Math.hypot(3,4,0)",     Math.hypot(3, 4, 0),   5.0);
check(70, "Math.hypot()",          Math.hypot(),          0);

// ── Math.max / Math.min ────────────────────────────────────────────────────
check(71, "Math.max(1,5,3)",       Math.max(1, 5, 3),     5);
check(72, "Math.max(-1,-5,-3)",    Math.max(-1, -5, -3),  -1);
check(73, "Math.max(7)",           Math.max(7),            7);
check(74, "Math.min(1,5,3)",       Math.min(1, 5, 3),     1);
check(75, "Math.min(-1,-5,-3)",    Math.min(-1, -5, -3),  -5);
check(76, "Math.min(7)",           Math.min(7),            7);
// Empty calls return ±Infinity
check(77, "Math.max() === -Inf",   Math.max(),             -Infinity);
check(78, "Math.min() === +Inf",   Math.min(),             Infinity);

// ── Math.sign ──────────────────────────────────────────────────────────────
check(79, "Math.sign(42)",         Math.sign(42),          1);
check(80, "Math.sign(-42)",        Math.sign(-42),        -1);
check(81, "Math.sign(0)",          Math.sign(0),           0);
check(82, "Math.sign(-0)",         Math.sign(-0),          0);

// ── Math.clz32 ─────────────────────────────────────────────────────────────
check(83, "Math.clz32(1)",         Math.clz32(1),          31);
check(84, "Math.clz32(0x80000000)",Math.clz32(0x80000000), 0);
check(85, "Math.clz32(0)",         Math.clz32(0),          32);
check(86, "Math.clz32(2)",         Math.clz32(2),          30);

// ── Math.imul ──────────────────────────────────────────────────────────────
check(87, "Math.imul(3,4)",        Math.imul(3, 4),        12);
check(88, "Math.imul(-1,-1)",      Math.imul(-1, -1),      1);
// 2^31 * 2 wraps to 0 in 32-bit
check(89, "Math.imul(2147483648,2)", Math.imul(2147483648, 2), 0);

// ── Math.fround ────────────────────────────────────────────────────────────
// fround(0) = 0, fround(1) = 1  (exact in float32)
near(90, "Math.fround(0)",         Math.fround(0),         0.0);
near(91, "Math.fround(1)",         Math.fround(1),         1.0);

// ── Math.random ────────────────────────────────────────────────────────────
var _r1 = Math.random();
var _r2 = Math.random();
check(92, "Math.random() >= 0",    _r1 >= 0,               true);
check(93, "Math.random() < 1",     _r1 < 1,                true);
// Two calls should not always be equal (astronomically unlikely to collide)
// We only check types here to stay deterministic
check(94, "typeof Math.random() === 'number'", typeof _r2, "number");

// ── NaN propagation ─────────────────────────────────────────────────────────
check(95, "Math.sqrt(-1) isNaN",   isNaN(Math.sqrt(-1)),   true);
check(96, "Math.log(-1) isNaN",    isNaN(Math.log(-1)),    true);
check(97, "Math.asin(2) isNaN",    isNaN(Math.asin(2)),    true);

// ── typeof checks for all 35 methods ─────────────────────────────────────────
var _mfns = [
    "abs","acos","acosh","asin","asinh","atan","atan2","atanh",
    "cbrt","ceil","clz32","cos","cosh","exp","expm1",
    "floor","fround","hypot","imul","log","log10","log1p","log2",
    "max","min","pow","random","round","sign","sin","sinh","sqrt","tan","tanh","trunc"
];
var _ok = 0;
for (var _i = 0; _i < _mfns.length; _i++) {
    if (typeof Math[_mfns[_i]] === "function") { _ok = _ok + 1; }
}
check(98, "all 35 Math methods are functions (" + _ok + "/35)", _ok, 35);

// ── Summary ──────────────────────────────────────────────────────────────────
console.log("");
console.log("=== Math tests: " + _passed + " passed, " + _failed + " failed ===");
