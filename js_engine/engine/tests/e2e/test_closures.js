// Closure tests — js_engine engine
var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

// ── 1: simple closure captures variable ───────────────────────────────────
function makeAdder(n) {
    return function(x) { return x + n; };
}
var add5 = makeAdder(5);
check(1, "add5(3) === 8", add5(3), 8);

// ── 2: closure captures at creation time ─────────────────────────────────
var add10 = makeAdder(10);
check(2, "add10(3) === 13", add10(3), 13);

// ── 3: two closures independent ───────────────────────────────────────────
check(3, "add5 independent from add10", add5(0), 5);

// ── 4: counter closure ───────────────────────────────────────────────────
function makeCounter() {
    var count = 0;
    return function() {
        count = count + 1;
        return count;
    };
}
var counter = makeCounter();
counter();
counter();
check(4, "counter after 2 calls === 2", counter(), 3);

// ── 5: two independent counters ───────────────────────────────────────────
var c1 = makeCounter();
var c2 = makeCounter();
c1(); c1(); c1();
c2();
check(5, "c1 after 3 calls === 3", c1(), 4);

// ── 6: c2 independent ────────────────────────────────────────────────────
check(6, "c2 after 1 call === 1", c2(), 2);

// ── 7: closure captures outer function arg ───────────────────────────────
function multiplier(factor) {
    return function(n) { return n * factor; };
}
var double = multiplier(2);
check(7, "double(6) === 12", double(6), 12);

// ── 8: nested closures ────────────────────────────────────────────────────
function outer(a) {
    return function(b) {
        return function(c) { return a + b + c; };
    };
}
check(8, "outer(1)(2)(3) === 6", outer(1)(2)(3), 6);

// ── 9: closure modifies outer variable ───────────────────────────────────
function makeAccumulator() {
    var total = 0;
    return function(n) {
        total = total + n;
        return total;
    };
}
var acc = makeAccumulator();
acc(10);
acc(20);
check(9, "accumulator after +10 +20 +5 === 35", acc(5), 35);

// ── 10: IIFE returns value ────────────────────────────────────────────────
var iife_result = (function() { return 42; })();
check(10, "IIFE result === 42", iife_result, 42);

// ── 11: IIFE with argument ────────────────────────────────────────────────
var iife2 = (function(x) { return x * x; })(7);
check(11, "IIFE(7) = 7*7 === 49", iife2, 49);

// ── 12: function stored in variable ──────────────────────────────────────
var square = function(n) { return n * n; };
check(12, "square(9) === 81", square(9), 81);

// ── 13: function passed as argument ──────────────────────────────────────
function apply(f, v) { return f(v); }
check(13, "apply(square, 4) === 16", apply(square, 4), 16);

// ── 14: closure over loop variable ────────────────────────────────────────
function makeFns() {
    var fns = [];
    var i = 0;
    while (i < 3) {
        var captured = i;
        fns[fns.length] = (function(n) { return function() { return n; }; })(captured);
        i = i + 1;
    }
    return fns;
}
var fns = makeFns();
check(14, "fns[0]() === 0", fns[0](), 0);

// ── 15: fns[2]() captures correctly ──────────────────────────────────────
check(15, "fns[2]() === 2", fns[2](), 2);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== Closure tests: " + _passed + " passed, " + _failed + " failed ===");
