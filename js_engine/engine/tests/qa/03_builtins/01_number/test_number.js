// NUM-001 through NUM-034: Number built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/01_number/test_number.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertClose(a, e, msg, tol) {
    tol = tol || 1e-9;
    if (Math.abs(a - e) > tol) { console.error("FAIL: " + msg + " | expected ~" + e + " | actual: " + a); __reg.bump(); return; }
}

// NUM-001: Number() coercion
assertEq(Number("42"),       42,        "NUM-001: from string");
assertEq(Number("3.14"),     3.14,      "NUM-001: from float string");
assertEq(Number(""),         0,         "NUM-001: from empty string");
assertEq(Number(true),       1,         "NUM-001: from true");
assertEq(Number(false),      0,         "NUM-001: from false");
assertEq(Number(null),       0,         "NUM-001: from null");
assert(isNaN(Number(undefined)),        "NUM-001: from undefined is NaN");
assert(isNaN(Number("abc")),            "NUM-001: from invalid string is NaN");
assertEq(Number({valueOf: function(){return 7;}}), 7, "NUM-001: from object with valueOf");

// NUM-002: new Number() wrapper
var nObj = new Number(42);
assertEq(typeof nObj,        "object",  "NUM-002: typeof new Number() === 'object'");
assertEq(nObj.valueOf(),     42,        "NUM-002: valueOf extracts primitive");
assertEq(nObj + 1,           43,        "NUM-002: wrapper coerces in arithmetic");

// NUM-010: Static properties
assertEq(typeof Number.MAX_VALUE,         "number", "NUM-010: MAX_VALUE");
assertEq(typeof Number.MIN_VALUE,         "number", "NUM-010: MIN_VALUE");
assertEq(typeof Number.EPSILON,           "number", "NUM-010: EPSILON");
assertEq(Number.MAX_SAFE_INTEGER,         9007199254740991, "NUM-010: MAX_SAFE_INTEGER");
assertEq(Number.MIN_SAFE_INTEGER,        -9007199254740991, "NUM-010: MIN_SAFE_INTEGER");
assertEq(Number.POSITIVE_INFINITY,        Infinity,  "NUM-010: POSITIVE_INFINITY");
assertEq(Number.NEGATIVE_INFINITY,       -Infinity,  "NUM-010: NEGATIVE_INFINITY");
assert(isNaN(Number.NaN),                            "NUM-010: Number.NaN is NaN");
assert(Number.MAX_VALUE > 1e308,                     "NUM-010: MAX_VALUE > 1e308");

// NUM-020: Number.isNaN — strict (no coercion)
assertEq(Number.isNaN(NaN),       true,  "NUM-020: NaN is NaN");
assertEq(Number.isNaN(42),        false, "NUM-020: 42 is not NaN");
assertEq(Number.isNaN("NaN"),     false, "NUM-020: string 'NaN' is NOT NaN (strict)");
assertEq(Number.isNaN(undefined), false, "NUM-020: undefined is NOT NaN (strict)");

// NUM-021: Number.isFinite — strict
assertEq(Number.isFinite(42),        true,  "NUM-021: 42 is finite");
assertEq(Number.isFinite(Infinity),  false, "NUM-021: Infinity not finite");
assertEq(Number.isFinite(NaN),       false, "NUM-021: NaN not finite");
assertEq(Number.isFinite("42"),      false, "NUM-021: string '42' not finite (strict)");

// NUM-022: Number.isInteger
assertEq(Number.isInteger(0),     true,  "NUM-022: 0 is integer");
assertEq(Number.isInteger(1),     true,  "NUM-022: 1 is integer");
assertEq(Number.isInteger(3.14),  false, "NUM-022: 3.14 not integer");
assertEq(Number.isInteger(NaN),   false, "NUM-022: NaN not integer");
assertEq(Number.isInteger(Infinity), false, "NUM-022: Infinity not integer");

// NUM-023: Number.isSafeInteger
assertEq(Number.isSafeInteger(Number.MAX_SAFE_INTEGER),     true,  "NUM-023: MAX_SAFE_INTEGER is safe");
assertEq(Number.isSafeInteger(Number.MAX_SAFE_INTEGER + 1), false, "NUM-023: MAX+1 is not safe");
assertEq(Number.isSafeInteger(3.14),                        false, "NUM-023: float not safe integer");

// NUM-024: Number.parseFloat/parseInt same as globals
assertEq(Number.parseFloat("3.14"), parseFloat("3.14"), "NUM-024: Number.parseFloat === parseFloat");
assertEq(Number.parseInt("42"),     parseInt("42"),     "NUM-024: Number.parseInt === parseInt");

// NUM-030: toFixed
assertEq((3.14159).toFixed(2),   "3.14",   "NUM-030: toFixed 2 digits");
assertEq((3.14159).toFixed(0),   "3",      "NUM-030: toFixed 0 digits");
assertEq((1.005).toFixed(2),     "1.00",   "NUM-030: toFixed rounding (floating point)");
assertEq((-3.14).toFixed(1),     "-3.1",   "NUM-030: toFixed negative");
assertEq((1234).toFixed(2),      "1234.00","NUM-030: toFixed integer");

// NUM-031: toPrecision
assertEq((123.456).toPrecision(5), "123.46", "NUM-031: toPrecision 5");
assertEq((0.000123).toPrecision(2),"0.00012","NUM-031: toPrecision small number");
assertEq((123456).toPrecision(2),  "1.2e+5", "NUM-031: toPrecision large (scientific)");

// NUM-032: toExponential
assertEq((12345).toExponential(2),  "1.23e+4","NUM-032: toExponential 2 fraction digits");
assertEq((0.0012).toExponential(2), "1.20e-3","NUM-032: toExponential small");
assertEq(typeof (99).toExponential(), "string","NUM-032: toExponential auto returns string");

// NUM-033: toString with radix
assertEq((255).toString(16),  "ff",         "NUM-033: hex");
assertEq((255).toString(2),   "11111111",   "NUM-033: binary");
assertEq((255).toString(8),   "377",        "NUM-033: octal");
assertEq((36).toString(36),   "10",         "NUM-033: base 36");
assertEq((10).toString(10),   "10",         "NUM-033: base 10 default");
assertEq(NaN.toString(),      "NaN",        "NUM-033: NaN.toString()");
assertEq(Infinity.toString(), "Infinity",   "NUM-033: Infinity.toString()");

// NUM-034: valueOf
assertEq((42).valueOf(),      42,    "NUM-034: primitive valueOf");
assertEq(new Number(7).valueOf(), 7, "NUM-034: wrapper valueOf");

__jacDone();
