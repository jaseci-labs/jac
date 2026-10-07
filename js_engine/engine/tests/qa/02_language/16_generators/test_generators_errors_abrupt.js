// Plan: testing_plans/03_ecmascript_language/GENERATOR_FUNCTIONS_AND_YIELD_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: EC-GEN-2 (errors + abrupt control) + negatives from EC-GEN-3
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generators_errors_abrupt.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// GENF-S-005: yield outside generator body — parse error (strict Function body so `yield` is reserved)
assertThrows(
    function () {
        new Function("'use strict'; yield 1;");
    },
    SyntaxError,
    "GENF-S-005: yield in non-generator dynamic function is SyntaxError"
);

// GENF-S-006: yield in generator parameter default — early error
assertThrows(
    function () {
        new Function("function* g(a = yield 1) {}");
    },
    SyntaxError,
    "GENF-S-006: yield in generator parameter initializer is SyntaxError"
);

// GENF-S-008: yield illegal inside nested non-generator (arrow) in generator — parse error for inner
assertThrows(
    function () {
        new Function(
            "function* outer() { var f = () => { yield 1; }; f(); }"
        );
    },
    SyntaxError,
    "GENF-S-008: yield inside nested non-generator is SyntaxError"
);

// GENF-L-006: re-entrant next while generator running
var gRe;
function* genReentrant() {
    gRe.next();
    yield 1;
}
gRe = genReentrant();
assertThrows(
    function () {
        gRe.next();
    },
    TypeError,
    "GENF-L-006: re-entrant generator resume throws TypeError"
);

// GENF-C-003: uncaught throw from iterator — propagates to caller; iterator done
function* genUncaught() {
    yield 1;
    yield 2;
}
var gu = genUncaught();
gu.next();
var threw = false;
try {
    gu.throw(new Error("boom"));
} catch (e) {
    threw = e.message === "boom";
}
assert(threw, "GENF-C-003: throw propagates to caller when not caught in generator");
assertEq(gu.next().done, true, "GENF-C-003: iterator closed after uncaught throw");

// GENF-C-006: wrong receiver for prototype methods (use %GeneratorPrototype%, not global Generator)
var genProto = Object.getPrototypeOf(
    (function* () {
        yield 1;
    })()
);
assertThrows(
    function () {
        genProto.next.call({}, 1);
    },
    TypeError,
    "GENF-C-006: Generator.prototype.next on non-generator throws TypeError"
);
assertThrows(
    function () {
        genProto.return.call({}, 1);
    },
    TypeError,
    "GENF-C-006: Generator.prototype.return on non-generator throws TypeError"
);
assertThrows(
    function () {
        genProto.throw.call({}, new Error("x"));
    },
    TypeError,
    "GENF-C-006: Generator.prototype.throw on non-generator throws TypeError"
);

__jacDone();
