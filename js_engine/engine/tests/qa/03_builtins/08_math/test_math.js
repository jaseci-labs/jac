// MATH-001 through MATH-021: Math built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/08_math/test_math.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertClose(a, e, msg, tol) {
    tol = tol !== undefined ? tol : 1e-9;
    if (Math.abs(a - e) > tol) {
        console.error("FAIL: " + msg + " | expected ~" + e + " | actual: " + a); __reg.bump(); return;
    }
}

// MATH-001: Constants
assertClose(Math.E,       2.718281828, "MATH-001: E",        1e-6);
assertClose(Math.PI,      3.141592654, "MATH-001: PI",       1e-6);
assertClose(Math.LN2,     0.693147181, "MATH-001: LN2",      1e-6);
assertClose(Math.LN10,    2.302585093, "MATH-001: LN10",     1e-6);
assertClose(Math.LOG2E,   1.442695041, "MATH-001: LOG2E",    1e-6);
assertClose(Math.LOG10E,  0.434294482, "MATH-001: LOG10E",   1e-6);
assertClose(Math.SQRT2,   1.414213562, "MATH-001: SQRT2",    1e-6);
assertClose(Math.SQRT1_2, 0.707106781, "MATH-001: SQRT1_2",  1e-6);

// MATH-010: abs
assertEq(Math.abs(5),         5,        "MATH-010: abs positive");
assertEq(Math.abs(-5),        5,        "MATH-010: abs negative");
assertEq(Math.abs(0),         0,        "MATH-010: abs 0");
assertEq(Math.abs(-0),        0,        "MATH-010: abs -0");
assert(isNaN(Math.abs(NaN)),            "MATH-010: abs NaN");
assertEq(Math.abs(-Infinity), Infinity, "MATH-010: abs -Infinity");

// MATH-011: ceil / floor / round / trunc
assertEq(Math.ceil(4.1),    5,   "MATH-011: ceil 4.1");
assertEq(Math.ceil(-4.1),  -4,   "MATH-011: ceil -4.1");
assertEq(Math.floor(4.9),   4,   "MATH-011: floor 4.9");
assertEq(Math.floor(-4.1), -5,   "MATH-011: floor -4.1");
assertEq(Math.round(4.5),   5,   "MATH-011: round .5 up");
assertEq(Math.round(4.4),   4,   "MATH-011: round .4 down");
assertEq(Math.round(-4.5), -4,   "MATH-011: round negative .5");
assertEq(Math.trunc(4.9),   4,   "MATH-011: trunc positive");
assertEq(Math.trunc(-4.9), -4,   "MATH-011: trunc negative");
assertEq(Math.trunc(0),     0,   "MATH-011: trunc 0");

// MATH-012: sign
assertEq(Math.sign(5),      1,   "MATH-012: sign positive");
assertEq(Math.sign(-5),    -1,   "MATH-012: sign negative");
assertEq(Math.sign(0),      0,   "MATH-012: sign 0");
assertEq(Math.sign(-0),    -0,   "MATH-012: sign -0");
assert(isNaN(Math.sign(NaN)),    "MATH-012: sign NaN");

// MATH-013: max / min
assertEq(Math.max(1,2,3),   3,        "MATH-013: max");
assertEq(Math.min(1,2,3),   1,        "MATH-013: min");
assertEq(Math.max(),       -Infinity, "MATH-013: max no args");
assertEq(Math.min(),        Infinity, "MATH-013: min no args");
assert(isNaN(Math.max(1,NaN,3)),      "MATH-013: max NaN propagation");
assert(isNaN(Math.min(1,NaN,3)),      "MATH-013: min NaN propagation");

// MATH-014: pow / sqrt / cbrt
assertEq(Math.pow(2,10),    1024,     "MATH-014: pow 2^10");
assertEq(Math.pow(9,0.5),   3,        "MATH-014: pow 9^0.5 = 3");
assert(isNaN(Math.pow(-1, 0.5)),      "MATH-014: pow negative^fraction = NaN");
assertEq(Math.sqrt(9),      3,        "MATH-014: sqrt 9");
assertEq(Math.sqrt(0),      0,        "MATH-014: sqrt 0");
assert(isNaN(Math.sqrt(-1)),          "MATH-014: sqrt negative = NaN");
assertClose(Math.cbrt(27),  3,        "MATH-014: cbrt 27", 1e-9);
assertClose(Math.cbrt(-8), -2,        "MATH-014: cbrt -8",  1e-9);

// MATH-015: hypot
assertClose(Math.hypot(3, 4), 5,  "MATH-015: hypot 3-4-5 triangle", 1e-9);
assertClose(Math.hypot(1,1,1), Math.sqrt(3), "MATH-015: hypot 3 args", 1e-9);
assertEq(Math.hypot(Infinity), Infinity, "MATH-015: hypot Infinity");

// MATH-016: log / log2 / log10 / log1p
assertClose(Math.log(Math.E),  1,   "MATH-016: log(e) = 1", 1e-9);
assertEq(Math.log(1),          0,   "MATH-016: log(1) = 0");
assert(isNaN(Math.log(-1)),         "MATH-016: log(-1) = NaN");
assertClose(Math.log2(8),      3,   "MATH-016: log2(8) = 3", 1e-9);
assertClose(Math.log10(1000),  3,   "MATH-016: log10(1000) = 3", 1e-9);
assertClose(Math.log1p(0),     0,   "MATH-016: log1p(0) = 0", 1e-9);
assertClose(Math.log1p(Math.E-1), 1,"MATH-016: log1p(e-1) = 1", 1e-9);

// MATH-017: exp / expm1
assertClose(Math.exp(1),  Math.E,  "MATH-017: exp(1) = e", 1e-9);
assertEq(Math.exp(0),     1,        "MATH-017: exp(0) = 1");
assertEq(Math.exp(Infinity),  Infinity,  "MATH-017: exp(Infinity)");
assertEq(Math.exp(-Infinity), 0,         "MATH-017: exp(-Infinity) = 0");
assertClose(Math.expm1(0), 0,  "MATH-017: expm1(0) = 0", 1e-9);
assertClose(Math.expm1(1), Math.E - 1, "MATH-017: expm1(1) = e-1", 1e-9);

// MATH-018: trig functions
assertClose(Math.sin(0),         0,    "MATH-018: sin(0)");
assertClose(Math.sin(Math.PI/2), 1,    "MATH-018: sin(PI/2)=1", 1e-9);
assertClose(Math.cos(0),         1,    "MATH-018: cos(0)=1");
assertClose(Math.cos(Math.PI),  -1,    "MATH-018: cos(PI)=-1", 1e-9);
assertClose(Math.tan(Math.PI/4), 1,    "MATH-018: tan(PI/4)=1", 1e-9);
assertClose(Math.asin(1), Math.PI/2,   "MATH-018: asin(1)=PI/2", 1e-9);
assertClose(Math.acos(1), 0,           "MATH-018: acos(1)=0", 1e-9);
assertClose(Math.atan(1), Math.PI/4,   "MATH-018: atan(1)=PI/4", 1e-9);
assertClose(Math.atan2(1,1), Math.PI/4,"MATH-018: atan2(1,1)=PI/4", 1e-9);
assertClose(Math.atan2(1,0), Math.PI/2,"MATH-018: atan2(1,0)=PI/2", 1e-9);
assert(isNaN(Math.asin(2)),             "MATH-018: asin out-of-range = NaN");

// MATH-019: hyperbolic trig
assertClose(Math.sinh(0),  0,           "MATH-019: sinh(0)");
assertClose(Math.cosh(0),  1,           "MATH-019: cosh(0)=1");
assertClose(Math.tanh(0),  0,           "MATH-019: tanh(0)");
assertClose(Math.asinh(0), 0,           "MATH-019: asinh(0)");
assertClose(Math.acosh(1), 0,           "MATH-019: acosh(1)=0");
assertClose(Math.atanh(0), 0,           "MATH-019: atanh(0)");

// MATH-020: random
var r1 = Math.random();
var r2 = Math.random();
assert(r1 >= 0 && r1 < 1, "MATH-020: random in [0,1)");
assert(r2 >= 0 && r2 < 1, "MATH-020: second random in [0,1)");
// Very rarely equal; check multiple calls differ at least sometimes
var allSame = true;
for (var i = 0; i < 5; i++) {
    if (Math.random() !== r1) { allSame = false; break; }
}
assert(!allSame, "MATH-020: multiple calls differ");

// MATH-021: clz32 / imul / fround
assertEq(Math.clz32(1),         31, "MATH-021: clz32(1)=31");
assertEq(Math.clz32(0),         32, "MATH-021: clz32(0)=32");
assertEq(Math.clz32(0x80000000),0,  "MATH-021: clz32(MSB set)=0");
assertEq(Math.imul(3, 4),        12, "MATH-021: imul(3,4)=12");
assertEq(Math.imul(-1, 8),       -8, "MATH-021: imul(-1,8)=-8");
assertEq(Math.fround(1.337),     Math.fround(1.337), "MATH-021: fround returns float32");
assert(typeof Math.fround(1.5) === "number", "MATH-021: fround returns number");

__jacDone();
