// Timer tests — js_engine engine (Phase 3.2)
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

// ── 1: setTimeout basic ──────────────────────────────────────────────────
setTimeout(function() {
    check(1, "setTimeout fires callback", true, true);
}, 10);

// ── 2: setTimeout with extra args ────────────────────────────────────────
setTimeout(function(a, b) {
    check(2, "setTimeout passes extra args", a === 42 && b === "hello", true);
}, 10, 42, "hello");

// ── 3: setTimeout ordering (longer delay fires later) ───────────────────
var order = [];
setTimeout(function() {
    order.push("first");
}, 10);
setTimeout(function() {
    order.push("second");
    check(3, "setTimeout ordering correct", order[0] === "first" && order[1] === "second", true);
}, 30);

// ── 4: clearTimeout cancels a pending timer ─────────────────────────────
var cancelMe = setTimeout(function() {
    check(4, "clearTimeout cancels timer", "cancelled", "not cancelled");
}, 20);
clearTimeout(cancelMe);
setTimeout(function() {
    check(4, "clearTimeout cancels timer", true, true);
}, 50);

// ── 5: setInterval fires multiple times ─────────────────────────────────
var count = 0;
var iv = setInterval(function() {
    count = count + 1;
    if (count === 3) {
        clearInterval(iv);
        check(5, "setInterval fired 3 times then cleared", count, 3);
    }
}, 15);

// ── 6: setImmediate fires callback ──────────────────────────────────────
setImmediate(function() {
    check(6, "setImmediate fires callback", true, true);
});

// ── 7: clearImmediate cancels ───────────────────────────────────────────
var imm = setImmediate(function() {
    check(7, "clearImmediate cancels", "cancelled", "not cancelled");
});
clearImmediate(imm);
setTimeout(function() {
    check(7, "clearImmediate cancels", true, true);
}, 60);

// ── 8: performance.now() returns positive number ────────────────────────
var t0 = performance.now();
check(8, "performance.now() returns positive number", typeof t0 === "number" && t0 > 0, true);

// ── 9: performance.now() increases monotonically ────────────────────────
setTimeout(function() {
    var t1 = performance.now();
    check(9, "performance.now() increases over time", t1 > t0, true);
}, 70);

// ── 10: setTimeout with delay 0 fires ───────────────────────────────────
setTimeout(function() {
    check(10, "setTimeout(fn, 0) fires", true, true);
}, 0);

// ── Summary (fires after all timers) ────────────────────────────────────
setTimeout(function() {
    console.log("\n=== Timer tests: " + _passed + " passed, " + _failed + " failed ===");
}, 200);