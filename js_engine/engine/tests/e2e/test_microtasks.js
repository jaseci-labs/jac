// Microtask & process.nextTick tests — js_engine engine (Phase 3.3)
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

// Accumulates execution order for ordering tests
var order = [];

// ── 1: queueMicrotask fires ─────────────────────────────────────────────
queueMicrotask(function() {
    order.push("microtask1");
    check(1, "queueMicrotask fires callback", true, true);
});

// ── 2: process.nextTick fires ───────────────────────────────────────────
process.nextTick(function() {
    order.push("nextTick1");
    check(2, "process.nextTick fires callback", true, true);
});

// ── 3: nextTick fires before queueMicrotask ─────────────────────────────
// Both are scheduled synchronously above. nextTick has higher priority.
// We check in a setTimeout to let both fire first.
setTimeout(function() {
    // nextTick1 should appear before microtask1 in the order array
    var ntIdx = -1;
    var mtIdx = -1;
    var k = 0;
    while (k < order.length) {
        if (order[k] === "nextTick1") { ntIdx = k; }
        if (order[k] === "microtask1") { mtIdx = k; }
        k = k + 1;
    }
    check(3, "nextTick fires before queueMicrotask", ntIdx < mtIdx, true);
}, 10);

// ── 4: nextTick fires before setTimeout(fn, 0) ─────────────────────────
var tickBeforeTimeout = false;
process.nextTick(function() {
    tickBeforeTimeout = true;
});
setTimeout(function() {
    check(4, "nextTick fires before setTimeout(fn, 0)", tickBeforeTimeout, true);
}, 0);

// ── 5: queueMicrotask fires before setTimeout(fn, 0) ───────────────────
var microBeforeTimeout = false;
queueMicrotask(function() {
    microBeforeTimeout = true;
});
setTimeout(function() {
    check(5, "queueMicrotask fires before setTimeout(fn, 0)", microBeforeTimeout, true);
}, 20);

// ── 6: process.nextTick passes extra args ───────────────────────────────
process.nextTick(function(a, b) {
    check(6, "process.nextTick passes extra args", a === 10 && b === "hi", true);
}, 10, "hi");

// ── 7: queueMicrotask within queueMicrotask ─────────────────────────────
queueMicrotask(function() {
    queueMicrotask(function() {
        check(7, "nested queueMicrotask fires", true, true);
    });
});

// ── 8: nextTick within nextTick ─────────────────────────────────────────
process.nextTick(function() {
    process.nextTick(function() {
        check(8, "nested nextTick fires", true, true);
    });
});

// ── 9: nextTick inside setTimeout ───────────────────────────────────────
setTimeout(function() {
    var innerTickFired = false;
    process.nextTick(function() {
        innerTickFired = true;
    });
    // The nextTick from inside setTimeout fires on the next tick drain.
    // We check it in a subsequent timer.
    setTimeout(function() {
        check(9, "nextTick inside setTimeout fires", innerTickFired, true);
    }, 30);
}, 40);

// ── 10: microtask from timer callback ───────────────────────────────────
setTimeout(function() {
    var microFromTimer = false;
    queueMicrotask(function() {
        microFromTimer = true;
    });
    setTimeout(function() {
        check(10, "queueMicrotask inside setTimeout fires", microFromTimer, true);
    }, 30);
}, 50);

// ── Summary (fires after all timers) ────────────────────────────────────
setTimeout(function() {
    console.log("\n=== Microtask tests: " + _passed + " passed, " + _failed + " failed ===");
}, 300);
