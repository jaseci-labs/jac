// Int32 arithmetic overflow / boundary cases for the VM fast path.
// Fast path must fall through to float64 on overflow (IEEE-754 Number semantics).

function assert(cond, msg) {
  if (!cond) throw new Error(msg || "assert failed");
}

const MAX = 2147483647;
const MIN = -2147483648;

assert(MAX + 1 === 2147483648, "MAX+1 must not wrap");
assert(MIN - 1 === -2147483649, "MIN-1 must not wrap");
assert(1073741824 * 4 === 4294967296, "1073741824*4 must not wrap");
assert((-1073741824) * 4 === -4294967296, "neg mul overflow");
assert(MAX + 0 === MAX, "MAX+0 stays int");
assert(MIN + 0 === MIN, "MIN+0 stays int");
assert(3 + 4 === 7, "small add");
assert(10 - 3 === 7, "small sub");
assert(6 * 7 === 42, "small mul");

// Mixed int/float must stay on float path
assert(1 + 0.5 === 1.5, "int+float");
assert(2 * 1.5 === 3, "int*float");

console.log("REGRESSION_TESTCASE_FINISHED name=\"regression/02_language/01_basics/test_int32_arith_boundaries.js\" failures=0");
