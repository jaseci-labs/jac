// Plan: testing_plans/03_ecmascript_language/GENERATOR_FUNCTIONS_AND_YIELD_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: EC-GEN-1 (core syntax + lifecycle)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generators_core_lifecycle.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// GENF-S-001: function declaration generator
function* gDecl() {
    yield 1;
}
var d = gDecl();
assertEq(d.next().value, 1, "GENF-S-001: function* declaration yields");

// GENF-S-002: function expression
var gExpr = function* () {
    yield 2;
};
var e = gExpr();
assertEq(e.next().value, 2, "GENF-S-002: function* expression yields");

// GENF-S-003: object literal method
var obj = {
    *m() {
        yield 3;
    },
};
var om = obj.m();
assertEq(om.next().value, 3, "GENF-S-003: object literal *method yields");

// GENF-S-004: class method
var C = class {
    *m() {
        yield 4;
    }
};
var cm = new C().m();
assertEq(cm.next().value, 4, "GENF-S-004: class *method yields");

// GENF-S-007: parenthesized yield operand
function* gPrec() {
    yield 1 + 2;
}
assertEq(gPrec().next().value, 3, "GENF-S-007: yield (1+2) precedence / value");

// GENF-S-008: nested non-generator function uses return; inner generator yields
function* gNest() {
    function inner() {
        return 42;
    }
    function* h() {
        yield 1;
    }
    yield inner();
    yield* h();
}
var nestVals = [...gNest()];
assertEq(nestVals.join(","), "42,1", "GENF-S-008: nested plain return and inner generator");

// GENF-L-001: body does not run until first next
var ran = false;
function* gLazy() {
    ran = true;
    yield 1;
}
var gl = gLazy();
assertEq(ran, false, "GENF-L-001: body not run before first next");
gl.next();
assertEq(ran, true, "GENF-L-001: body runs after first next");

// GENF-L-002: successive next advances yields
function* gMulti() {
    yield "a";
    yield "b";
}
var gm = gMulti();
assertEq(gm.next().value, "a", "GENF-L-002: first yield");
assertEq(gm.next().value, "b", "GENF-L-002: second yield");
var gmLast = gm.next();
assertEq(gmLast.done, true, "GENF-L-002: done after exhaust");
assertEq(gmLast.value, undefined, "GENF-L-002: value undefined when done");

// GENF-L-003: return from body
function* gRet() {
    yield 0;
    return "end";
}
var gr = gRet();
gr.next();
var grEnd = gr.next();
assertEq(grEnd.done, true, "GENF-L-003: done true on return");
assertEq(grEnd.value, "end", "GENF-L-003: return value in result");
assertEq(gr.next().value, undefined, "GENF-L-003: subsequent next value undefined");
assertEq(gr.next().done, true, "GENF-L-003: stays done");

// GENF-L-004 / GENF-L-005: next(sent) and first next ignores arg
function* gSend() {
    var a = yield "first";
    var b = yield "second";
    return a + b;
}
var gs = gSend();
assertEq(gs.next(999).value, "first", "GENF-L-005: first next ignores sent value");
assertEq(gs.next(10).value, "second", "GENF-L-004: second next injects into yield");
assertEq(gs.next(20).value, 30, "GENF-L-004: third next completes with sum");

// GENF-L-007: lazy infinite — consumer stops
function* gInf() {
    var n = 0;
    while (true) yield n++;
}
var gi = gInf();
var acc = 0;
var k = 0;
for (var v of gi) {
    acc += v;
    k++;
    if (k === 3) break;
}
assertEq(acc, 3, "GENF-L-007: lazy only first three values (0+1+2)");

__jacDone();
