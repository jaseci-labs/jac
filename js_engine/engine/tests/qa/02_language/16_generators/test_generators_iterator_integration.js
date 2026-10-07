// Plan: testing_plans/03_ecmascript_language/GENERATOR_FUNCTIONS_AND_YIELD_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: EC-GEN-5 (iterator protocol + consumer interactions)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generators_iterator_integration.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// GENF-P-001 / GENF-P-002
function* gProto() {
    yield 1;
}
var gp = gProto();
assertEq(typeof gp.next, "function", "GENF-P-001: generator has next");
assertEq(typeof gp.return, "function", "GENF-P-001: generator has return");
assertEq(typeof gp.throw, "function", "GENF-P-001: generator has throw");
assertEq(typeof gp[Symbol.iterator], "function", "GENF-P-001: generator has @@iterator");
var gpIt = gp[Symbol.iterator]();
assert(gpIt === gp, "GENF-P-002: @@iterator returns same object");

// GENF-P-003: for-of, spread, destructuring
function* seq(n) {
    for (var i = 1; i <= n; i++) yield i;
}
var fo = [];
for (var v of seq(3)) fo.push(v);
assertEq(fo.join(","), "1,2,3", "GENF-P-003: for-of over generator");
assertEq([...seq(2)].join(","), "1,2", "GENF-P-003: spread over generator");
function* countUpTo(n) {
    var i;
    for (i = 1; i <= n; i++) {
        yield i;
    }
}
var d1, d2, d3;
var gDestr = countUpTo(5);
d1 = gDestr.next().value;
d2 = gDestr.next().value;
d3 = gDestr.next().value;
assertEq(d1, 1, "GENF-P-003: destructuring-style [0] from iterator");
assertEq(d2, 2, "GENF-P-003: destructuring-style [1] from iterator");
assertEq(d3, 3, "GENF-P-003: destructuring-style [2] from iterator");

// GENF-P-004: result shape uses boolean done
function* gDone() {
    yield 9;
}
var gd = gDone();
var r0 = gd.next();
assertEq(typeof r0.done, "boolean", "GENF-P-004: done is boolean");
assertEq(r0.done, false, "GENF-P-004: not done");
assertEq(r0.value, 9, "GENF-P-004: value");
var r1 = gd.next();
assertEq(r1.done, true, "GENF-P-004: terminal done boolean");

// GENF-P-005: standard object tag / prototype not plain Object
assertEq(
    Object.prototype.toString.call(gp),
    "[object Generator]",
    "GENF-P-005: generator object string tag"
);

// GENF-X-001: break from for-of runs generator finally
var x1 = false;
function* gBreak() {
    try {
        while (true) yield 1;
    } finally {
        x1 = true;
    }
}
for (var vb of gBreak()) {
    if (vb === 1) break;
}
assert(x1, "GENF-X-001: finally after for-of break");

// GENF-X-002: throw from consumer body runs generator finally
var x2 = false;
function* gConsThrow() {
    try {
        yield 1;
        yield 2;
    } finally {
        x2 = true;
    }
}
try {
    for (var vc of gConsThrow()) {
        if (vc === 1) throw new Error("consumer");
    }
} catch (e) {
    assertEq(e.message, "consumer", "GENF-X-002: consumer error");
}
assert(x2, "GENF-X-002: generator finally after throw from for-of body");

// GENF-X-003: yield* inner + break closes delegate
var x3log = [];
function* innerX3() {
    try {
        yield 1;
        yield 2;
    } finally {
        x3log.push("inner-fin");
    }
}
function* outerX3() {
    yield* innerX3();
}
for (var vx of outerX3()) {
    x3log.push("v" + vx);
    break;
}
assert(x3log.indexOf("inner-fin") >= 0, "GENF-X-003: delegate finally on break during yield*");

// GENF-X-004: exhausted generator yields nothing to second consumer pass
function* gOnce() {
    yield 10;
}
var go = gOnce();
assertEq(go.next().value, 10, "GENF-X-004: first pass");
assertEq(go.next().done, true, "GENF-X-004: exhausted");
var count2 = 0;
for (var _x of go) {
    count2++;
}
assertEq(count2, 0, "GENF-X-004: second for-of over same iterator yields no values");

__jacDone();
