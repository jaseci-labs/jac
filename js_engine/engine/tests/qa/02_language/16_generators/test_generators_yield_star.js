// Plan: testing_plans/03_ecmascript_language/GENERATOR_FUNCTIONS_AND_YIELD_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: EC-GEN-4 (yield* delegation)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generators_yield_star.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// GENF-D-001: yield* inner generator
function* inner1() {
    yield "a";
    yield "b";
}
function* outer1() {
    yield "z";
    yield* inner1();
    yield "y";
}
assertEq(
    [...outer1()].join(","),
    "z,a,b,y",
    "GENF-D-001: yield* delegates inner generator yields"
);

// GENF-D-002: non-generator iterables (array, string, Set, custom @@iterator)
function* outer2() {
    yield* [10, 20];
    yield* "hi";
    yield* new Set([1]);
    var custom = {
        [Symbol.iterator]: function () {
            var n = 0;
            return {
                next: function () {
                    if (n++ === 0) return { value: 7, done: false };
                    return { value: undefined, done: true };
                },
            };
        },
    };
    yield* custom;
}
assertEq(
    [...outer2()].join(","),
    "10,20,h,i,1,7",
    "GENF-D-002: yield* delegates array, string, Set, custom iterable"
);

// GENF-D-003: completion value of delegated generator
function* returnsSeven() {
    yield 1;
    return 7;
}
function* captureRet() {
    var r = yield* returnsSeven();
    yield "got:" + r;
}
var it3 = captureRet();
assertEq(it3.next().value, 1, "GENF-D-003: pass-through yield");
assertEq(it3.next().value, "got:7", "GENF-D-003: yield* expression is delegate return value");

// GENF-D-004: outer throw forwards to inner generator
function* innerThrow() {
    try {
        yield 1;
    } catch (e) {
        yield "caught:" + e.message;
    }
}
function* outerThrow() {
    yield* innerThrow();
}
var it4 = outerThrow();
assertEq(it4.next().value, 1, "GENF-D-004: first delegated yield");
var r4 = it4.throw(new Error("deleg"));
assertEq(r4.done, false, "GENF-D-004: iterator stays active");
assertEq(r4.value, "caught:deleg", "GENF-D-004: throw forwarded to delegate");

// GENF-D-005: outer return invokes close on delegate (finally in inner)
var closedInner = false;
function* innerReturn() {
    try {
        yield 1;
        yield 2;
    } finally {
        closedInner = true;
    }
}
function* outerReturn() {
    yield* innerReturn();
}
var it5 = outerReturn();
it5.next();
var r5 = it5.return("bye");
assert(closedInner, "GENF-D-005: delegate finally ran on outer return()");
assertEq(r5.done, true, "GENF-D-005: outer return completes iterator");
assertEq(r5.value, "bye", "GENF-D-005: return value");

// GENF-D-006: non-iterable / malformed iterator
function* badNoIter() {
    yield* {};
}
assertThrows(
    function () {
        [...badNoIter()];
    },
    TypeError,
    "GENF-D-006: yield* non-iterable throws TypeError"
);
function* badNext() {
    yield* {
        [Symbol.iterator]: function () {
            return { next: "not-fn" };
        },
    };
}
assertThrows(
    function () {
        [...badNext()];
    },
    TypeError,
    "GENF-D-006: yield* iterator with non-callable next throws TypeError"
);

// GENF-D-007: try/finally around yield* on normal completion
var d7 = [];
function* inner7() {
    yield 1;
}
function* outer7() {
    try {
        d7.push("try");
        yield* inner7();
        d7.push("after");
    } finally {
        d7.push("finally");
    }
}
[...outer7()];
assertEq(d7.join(","), "try,after,finally", "GENF-D-007: finally runs after yield* completes");

__jacDone();
