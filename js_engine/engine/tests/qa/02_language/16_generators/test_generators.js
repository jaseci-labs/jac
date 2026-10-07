// GEN-001 through GEN-008: Generators
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/16_generators/test_generators.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// GEN-001: Basic generator — yields values, done flag, return value
function* basic() {
    yield 1;
    yield 2;
    return "final";
}
var gen = basic();
var g1 = gen.next(); assertEq(g1.value, 1,       "GEN-001: first yield"); assertEq(g1.done, false, "GEN-001: not done yet");
var g2 = gen.next(); assertEq(g2.value, 2,       "GEN-001: second yield");
var g3 = gen.next(); assertEq(g3.value, "final", "GEN-001: return value"); assertEq(g3.done, true,  "GEN-001: done after return");
var g4 = gen.next(); assertEq(g4.value, undefined, "GEN-001: undefined after done"); assertEq(g4.done, true, "GEN-001: still done");

// GEN-002: next() — {value, done} pairs, done=true after last yield
function* gen2() { yield "a"; yield "b"; }
var it2 = gen2();
assertEq(it2.next().value, "a",       "GEN-002: first value");
assertEq(it2.next().value, "b",       "GEN-002: second value");
var last2 = it2.next();
assertEq(last2.done,  true,           "GEN-002: done after last yield");
assertEq(last2.value, undefined,      "GEN-002: value undefined after all yields");

// GEN-003: next(value) — sent value becomes the result of yield expression
function* gen3() {
    var x = yield "first";
    var y = yield "second";
    return x + y;
}
var it3 = gen3();
assertEq(it3.next().value,    "first",  "GEN-003: initial next yields first");
assertEq(it3.next(10).value,  "second", "GEN-003: send 10, get second yield");
assertEq(it3.next(20).value,  30,       "GEN-003: send 20, return is 10+20");

// GEN-004: return(value) — forces generator to complete
function* gen4() { yield 1; yield 2; yield 3; }
var it4 = gen4();
assertEq(it4.next().value,     1,    "GEN-004: first yield");
var ret = it4.return("done");
assertEq(ret.value,  "done",         "GEN-004: return() returns given value");
assertEq(ret.done,   true,           "GEN-004: done after return()");
assertEq(it4.next().done, true,      "GEN-004: still done after return()");

// GEN-005: throw(error) — throws inside generator, can be caught
function* gen5() {
    try {
        yield "before";
    } catch(e) {
        yield "caught:" + e.message;
    }
    yield "after";
}
var it5 = gen5();
assertEq(it5.next().value,             "before",     "GEN-005: before throw");
assertEq(it5.throw(new Error("oops")).value, "caught:oops", "GEN-005: throw caught inside");
assertEq(it5.next().value,             "after",      "GEN-005: continues after catch");

// GEN-006: yield* delegation
function* inner() { yield "x"; yield "y"; }
function* outer() {
    yield "start";
    yield* inner();
    yield* [1, 2];
    yield* "ab";
    yield "end";
}
var vals6 = [...outer()];
assertEq(vals6.join(","), "start,x,y,1,2,a,b,end", "GEN-006: yield* delegates to generator, array, string");

// yield* return value = return value of delegated generator
function* returnsVal() { yield 1; return "retval"; }
function* delegator() {
    var result = yield* returnsVal();
    yield "got:" + result;
}
var it6b = delegator();
assertEq(it6b.next().value,  1,          "GEN-006: yield* passes through yields");
assertEq(it6b.next().value,  "got:retval","GEN-006: yield* return value captured");

// GEN-007: Generator as iterable — for-of, spread, destructuring
function* count(n) { for (var i = 1; i <= n; i++) yield i; }
// for-of
var forOfVals = [];
for (var v of count(4)) { forOfVals.push(v); }
assertEq(forOfVals.join(","), "1,2,3,4", "GEN-007: generator in for-of");
// spread
assertEq([...count(3)].join(","), "1,2,3", "GEN-007: generator in spread");
// destructuring
var [da, db, dc] = count(5);
assertEq(da, 1, "GEN-007: generator in destructuring [0]");
assertEq(db, 2, "GEN-007: generator in destructuring [1]");
assertEq(dc, 3, "GEN-007: generator in destructuring [2]");

// GEN-008: Infinite generator — lazy + for-of + break
function* naturals() { var n = 1; while(true) { yield n++; } }
var taken = [];
for (var nv of naturals()) {
    taken.push(nv);
    if (nv === 5) break;
}
assertEq(taken.join(","), "1,2,3,4,5", "GEN-008: infinite generator with break");

__jacDone();
