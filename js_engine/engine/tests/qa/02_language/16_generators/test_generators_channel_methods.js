// Plan: testing_plans/03_ecmascript_language/GENERATOR_FUNCTIONS_AND_YIELD_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: EC-GEN-3 (channel methods positives)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generators_channel_methods.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// GENF-C-001: return(value) forces completion
function* gRet() {
    yield 1;
    yield 2;
}
var it1 = gRet();
it1.next();
var r1 = it1.return("done");
assertEq(r1.value, "done", "GENF-C-001: return value in result");
assertEq(r1.done, true, "GENF-C-001: done true after return()");
assertEq(it1.next().done, true, "GENF-C-001: remains done");

// GENF-C-002: throw caught inside generator; execution continues
function* gCatch() {
    try {
        yield "a";
    } catch (e) {
        yield "b:" + e.message;
    }
    yield "c";
}
var it2 = gCatch();
assertEq(it2.next().value, "a", "GENF-C-002: before throw");
assertEq(it2.throw(new Error("x")).value, "b:x", "GENF-C-002: catch yields");
assertEq(it2.next().value, "c", "GENF-C-002: continues after catch");

// GENF-C-004: finally on return()
var finRet = 0;
function* gFinRet() {
    try {
        yield 1;
    } finally {
        finRet = 1;
    }
}
var it3 = gFinRet();
it3.next();
it3.return(9);
assertEq(finRet, 1, "GENF-C-004: finally runs on return()");

// GENF-C-004: finally on throw() that completes abruptly
var finThrow = 0;
function* gFinThrow() {
    try {
        yield 1;
    } finally {
        finThrow = 1;
    }
}
var it4 = gFinThrow();
it4.next();
try {
    it4.throw(new Error("abrupt"));
} catch (e) {}
assertEq(finThrow, 1, "GENF-C-004: finally runs when throw not caught in body");

// GENF-C-005: return() before first next()
function* gEarly() {
    yield 1;
}
var it5 = gEarly();
var r5 = it5.return(0);
assertEq(r5.done, true, "GENF-C-005: return before first next closes");
assertEq(r5.value, 0, "GENF-C-005: return value preserved");
assertEq(it5.next().done, true, "GENF-C-005: subsequent next still done");

__jacDone();
