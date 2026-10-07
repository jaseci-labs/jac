// ITERATION_COMPREHENSIVE_TEST_PLAN.md — ITR-* (iterables, iterators, for…of)
// Extended: ITR-N-006 (well-formed next result), ITR-F-007 (try/finally vs IteratorClose)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/15_iteration/test_iteration_language_generators_iterators.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

// --- §5 Generators as iterators (ITR-G-*) — light checks; depth in test_generators.js ---

// ITR-G-001: for…of drains generator
(function itrG001() {
    function* g() {
        yield 10;
        yield 20;
    }
    var acc = [];
    for (var v of g()) {
        acc.push(v);
    }
    assertEq(acc.join(","), "10,20", "ITR-G-001: for…of over generator");
})();

// ITR-G-002: return() completes iterator (see GEN-004)
(function itrG002() {
    function* g() {
        yield 1;
    }
    var it = g();
    assertEq(it.next().value, 1, "ITR-G-002: yield before return");
    var r = it.return(99);
    assertEq(r.done, true, "ITR-G-002: return sets done");
    assertEq(r.value, 99, "ITR-G-002: return value");
})();

// ITR-G-003: yield* delegates (see GEN-006)
(function itrG003() {
    function* inner() {
        yield "p";
        yield "q";
    }
    function* outer() {
        yield* inner();
    }
    assertEq([...outer()].join(""), "pq", "ITR-G-003: yield* delegates inner generator");
})();

__jacDone();
