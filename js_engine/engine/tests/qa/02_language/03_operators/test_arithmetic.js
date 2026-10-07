// OP-001 through OP-005: Arithmetic operators
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_operators/test_arithmetic.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// OP-001: + and -
assertEq(3 + 4,   7,   "OP-001: addition");
assertEq(10 - 3,  7,   "OP-001: subtraction");
assertEq(+"5",    5,   "OP-001: unary + (ToNumber)");
assertEq(-"3",   -3,   "OP-001: unary - (negation)");
assertEq(-(-5),   5,   "OP-001: double negation");

// OP-002: * and /
assertEq(3 * 4,    12,       "OP-002: multiplication");
assertEq(10 / 4,   2.5,      "OP-002: division");
assertEq(1 / 0,    Infinity,  "OP-002: divide by zero = Infinity");
assertEq(-1 / 0, -Infinity,   "OP-002: neg divide by zero = -Infinity");
assert(isNaN(0 / 0),          "OP-002: 0/0 = NaN");

// OP-003: % modulo
assertEq(10 % 3,   1,    "OP-003: positive modulo");
assertEq(-10 % 3, -1,    "OP-003: sign follows dividend (negative)");
assertEq(10 % -3,  1,    "OP-003: sign follows dividend (pos%neg)");

// OP-004: ** exponentiation
assertEq(2 ** 10,   1024, "OP-004: integer exponentiation");
assertEq(4 ** 0.5,  2,    "OP-004: fractional exponent (sqrt)");
assertEq(0 ** 0,    1,    "OP-004: 0**0 === 1");
assertEq(2 ** -1,   0.5,  "OP-004: negative exponent");

// OP-005: ++ and --
var n = 5;
assertEq(n++, 5, "OP-005: postfix++ returns old value");
assertEq(n,   6, "OP-005: postfix++ increments");
assertEq(++n, 7, "OP-005: prefix++ returns new value");
assertEq(n--,  7, "OP-005: postfix-- returns old value");
assertEq(n,    6, "OP-005: postfix-- decrements");
assertEq(--n,  5, "OP-005: prefix-- returns new value");

var obj = { p: 10 };
obj.p++;
assertEq(obj.p, 11, "OP-005: ++ on object property");

__jacDone();
