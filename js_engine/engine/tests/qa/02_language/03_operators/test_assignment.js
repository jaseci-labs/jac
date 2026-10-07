// OP-040 through OP-043: Assignment operators
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/03_operators/test_assignment.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// OP-040: = basic assignment
var x = 5; assertEq(x, 5, "OP-040: basic assignment");
var o = {}; o.p = 42; assertEq(o.p, 42, "OP-040: property assignment");
var [da, db] = [1, 2]; assertEq(da, 1, "OP-040: destructuring assignment");

// OP-041: compound arithmetic assignment
var n = 10;
n += 3;  assertEq(n, 13, "OP-041: +=");
n -= 5;  assertEq(n, 8,  "OP-041: -=");
n *= 2;  assertEq(n, 16, "OP-041: *=");
n /= 4;  assertEq(n, 4,  "OP-041: /=");
n %= 3;  assertEq(n, 1,  "OP-041: %=");
n = 2;
n **= 8; assertEq(n, 256,"OP-041: **=");

// OP-042: compound bitwise assignment
var b = 0b1111;
b &= 0b1010; assertEq(b, 0b1010, "OP-042: &=");
b |= 0b0001; assertEq(b, 0b1011, "OP-042: |=");
b ^= 0b0011; assertEq(b, 0b1000, "OP-042: ^=");
b = 1;
b <<= 3;  assertEq(b, 8,  "OP-042: <<=");
b >>= 1;  assertEq(b, 4,  "OP-042: >>=");
b = -8;
b >>>= 1; assertEq(b, 2147483644, "OP-042: >>>=");

// OP-043: logical assignment
var la = null;
la ||= "default"; assertEq(la, "default",  "OP-043: ||= with null (falsy)");
var lb = "existing";
lb ||= "other";   assertEq(lb, "existing", "OP-043: ||= with truthy (no overwrite)");

var lc = "truthy";
lc &&= "updated"; assertEq(lc, "updated",  "OP-043: &&= with truthy (update)");
var ld = null;
ld &&= "x";       assertEq(ld, null,       "OP-043: &&= with falsy (no update)");

var le = null;
le ??= "filled";  assertEq(le, "filled",   "OP-043: ??= with null");
var lf = 0;
lf ??= 99;        assertEq(lf, 0,          "OP-043: ??= with 0 (not null/undefined, no change)");

__jacDone();
