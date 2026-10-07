// test_generators.js — Phase 2.6 Generator Functions
// Done criteria from PHASE2.md

var passed = 0;
var failed = 0;

function assert(condition, label) {
    if (condition) {
        console.log("PASS: " + label);
        passed++;
    } else {
        console.log("FAIL: " + label);
        failed++;
    }
}

function assertEq(a, b, label) {
    if (a === b) {
        console.log("PASS: " + label);
        passed++;
    } else {
        console.log("FAIL: " + label + " (got " + a + ", expected " + b + ")");
        failed++;
    }
}

function assertDeepEq(a, b, label) {
    var as = JSON.stringify(a);
    var bs = JSON.stringify(b);
    if (as === bs) {
        console.log("PASS: " + label);
        passed++;
    } else {
        console.log("FAIL: " + label + " (got " + as + ", expected " + bs + ")");
        failed++;
    }
}

// ── Test 1: Basic generator creation ─────────────────────────────────────────
function* simple() {
    yield 1;
    yield 2;
    yield 3;
}

var g1 = simple();
assert(g1 !== undefined && g1 !== null, "generator object created");

// ── Test 2: .next() returns {value, done} ─────────────────────────────────────
var r1 = g1.next();
assertEq(r1.value, 1, "first next() value === 1");
assertEq(r1.done, false, "first next() done === false");

var r2 = g1.next();
assertEq(r2.value, 2, "second next() value === 2");
assertEq(r2.done, false, "second next() done === false");

var r3 = g1.next();
assertEq(r3.value, 3, "third next() value === 3");
assertEq(r3.done, false, "third next() done === false");

var r4 = g1.next();
assertEq(r4.value, undefined, "exhausted next() value === undefined");
assertEq(r4.done, true, "exhausted next() done === true");

// ── Test 3: Spread operator with generator ─────────────────────────────────────
// Done criterion 1: [...g()][1] === 2
function* g() { yield 1; yield 2; }
var arr1 = [...g()];
assertEq(arr1[1], 2, "[...g()][1] === 2");
assertEq(arr1.length, 2, "[...g()].length === 2");

// ── Test 4: range generator ─────────────────────────────────────────────────────
// Done criterion 2: [...range(3)] → [0,1,2]
function* range(n) {
    var i = 0;
    while (i < n) {
        yield i++;
    }
}
var arr2 = [...range(3)];
assertDeepEq(arr2, [0, 1, 2], "[...range(3)] === [0,1,2]");
assertEq(arr2[0], 0, "range(3)[0] === 0");
assertEq(arr2[1], 1, "range(3)[1] === 1");
assertEq(arr2[2], 2, "range(3)[2] === 2");
assertEq(arr2.length, 3, "range(3).length === 3");

// ── Test 5: Generator is iterable via [Symbol.iterator] ────────────────────────
function* iGen() { yield 10; yield 20; }
var ig = iGen();
var iterFn = ig[Symbol.iterator];
assert(iterFn !== undefined && iterFn !== null, "generator has [Symbol.iterator]");
// [Symbol.iterator]() should return the generator itself
var ig2 = ig[Symbol.iterator]();
assert(ig2 === ig, "generator[Symbol.iterator]() returns itself");

// ── Test 6: for-of with generator ───────────────────────────────────────────────
function* nums() { yield 100; yield 200; yield 300; }
var sum = 0;
for (var x of nums()) {
    sum += x;
}
assertEq(sum, 600, "for-of generator sum === 600");

// ── Test 7: send value via .next(val) ───────────────────────────────────────────
function* echo() {
    var a = yield "first";
    var b = yield "second";
    yield a + b;
}
var eg = echo();
var e1 = eg.next();        // start: runs until first yield
assertEq(e1.value, "first", "echo first yield value");
var e2 = eg.next(10);      // sends 10 → a=10, runs to second yield
assertEq(e2.value, "second", "echo second yield value");
var e3 = eg.next(20);      // sends 20 → b=20, yields a+b=30
assertEq(e3.value, 30, "echo a+b yield value === 30");

// ── Test 8: .return() force-closes the generator ───────────────────────────────
function* gRet() { yield 1; yield 2; yield 3; }
var gr = gRet();
gr.next(); // yield 1
var retResult = gr.return(99);
assertEq(retResult.value, 99, ".return(99).value === 99");
assertEq(retResult.done, true, ".return() done === true");
// After .return(), generator is done
var afterRet = gr.next();
assertEq(afterRet.done, true, "after .return(), generator done");

// ── Test 9: .throw() injects exception ──────────────────────────────────────────
function* gThrow() {
    try {
        yield 1;
    } catch (e) {
        yield "caught: " + e;
    }
}
var gt = gThrow();
gt.next(); // yield 1
var throwResult = gt.throw("err!");
assertEq(throwResult.value, "caught: err!", ".throw() caught by generator try/catch");
assertEq(throwResult.done, false, ".throw() result not done (yielded catch value)");

// ── Test 10: yield* delegation ───────────────────────────────────────────────────
function* inner() { yield "a"; yield "b"; }
function* outer() {
    yield "start";
    yield* inner();
    yield "end";
}
var delegated = [...outer()];
assertDeepEq(delegated, ["start", "a", "b", "end"], "yield* delegation works");

// ── Test 11: generator with return value ────────────────────────────────────────
function* withReturn() {
    yield 1;
    return 42;
}
var wr = withReturn();
var wr1 = wr.next();
assertEq(wr1.value, 1, "withReturn first yield");
assertEq(wr1.done, false, "withReturn first not done");
var wr2 = wr.next();
assertEq(wr2.value, 42, "withReturn return value === 42");
assertEq(wr2.done, true, "withReturn done after return");

// ── Test 12: infinite generator (take first N) ──────────────────────────────────
function* naturals() {
    var n = 1;
    while (true) {
        yield n++;
    }
}
var nat = naturals();
assertEq(nat.next().value, 1, "naturals: 1st is 1");
assertEq(nat.next().value, 2, "naturals: 2nd is 2");
assertEq(nat.next().value, 3, "naturals: 3rd is 3");

// ── Test 13: nested generator iteration ─────────────────────────────────────────
function* fibonacci() {
    var a = 0;
    var b = 1;
    while (true) {
        yield a;
        var t = a + b;
        a = b;
        b = t;
    }
}
var fib = fibonacci();
var fibResult = [];
var i = 0;
while (i < 7) {
    fibResult.push(fib.next().value);
    i++;
}
assertDeepEq(fibResult, [0, 1, 1, 2, 3, 5, 8], "fibonacci generator first 7 values");

// ── Summary ───────────────────────────────────────────────────────────────────
console.log("\n=== Generator Tests: " + passed + " passed, " + failed + " failed ===");
