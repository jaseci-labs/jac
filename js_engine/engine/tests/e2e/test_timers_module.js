// ────────────────────────────────────────────────────────────────────────────
// js_tests/test_timers_module.js — Phase 5.11: timers module tests
//
// Tests: require("timers"), require("timers/promises"),
//        require("node:timers"), require("node:timers/promises"),
//        timers.promises.setTimeout, timers.promises.setImmediate,
//        timers.promises.scheduler.wait, timers.promises.scheduler.yield
// ────────────────────────────────────────────────────────────────────────────

var pass = 0;
var fail = 0;
var t = 0;

function ok(cond, desc) {
    t = t + 1;
    if (cond) {
        pass = pass + 1;
        console.log("ok " + t + " - " + desc);
    } else {
        fail = fail + 1;
        console.log("FAIL " + t + " - " + desc);
    }
}

// ═══════════════════════════════════════════════════════════════
// 1. require("timers") — basic shape
// ═══════════════════════════════════════════════════════════════

var timers = require("timers");
ok(typeof timers === "object", "require('timers') returns object");
ok(typeof timers.setTimeout === "function", "timers.setTimeout is a function");
ok(typeof timers.clearTimeout === "function", "timers.clearTimeout is a function");
ok(typeof timers.setInterval === "function", "timers.setInterval is a function");
ok(typeof timers.clearInterval === "function", "timers.clearInterval is a function");
ok(typeof timers.setImmediate === "function", "timers.setImmediate is a function");
ok(typeof timers.clearImmediate === "function", "timers.clearImmediate is a function");

// ═══════════════════════════════════════════════════════════════
// 2. timers functions are the same as globals
// ═══════════════════════════════════════════════════════════════

ok(timers.setTimeout === globalThis.setTimeout, "timers.setTimeout === globalThis.setTimeout");
ok(timers.clearTimeout === globalThis.clearTimeout, "timers.clearTimeout === globalThis.clearTimeout");
ok(timers.setInterval === globalThis.setInterval, "timers.setInterval === globalThis.setInterval");
ok(timers.clearInterval === globalThis.clearInterval, "timers.clearInterval === globalThis.clearInterval");
ok(timers.setImmediate === globalThis.setImmediate, "timers.setImmediate === globalThis.setImmediate");
ok(timers.clearImmediate === globalThis.clearImmediate, "timers.clearImmediate === globalThis.clearImmediate");

// ═══════════════════════════════════════════════════════════════
// 3. timers.promises exists
// ═══════════════════════════════════════════════════════════════

ok(typeof timers.promises === "object", "timers.promises is an object");
ok(typeof timers.promises.setTimeout === "function", "timers.promises.setTimeout is a function");
ok(typeof timers.promises.setImmediate === "function", "timers.promises.setImmediate is a function");
ok(typeof timers.promises.setInterval === "function", "timers.promises.setInterval is a function");
ok(typeof timers.promises.scheduler === "object", "timers.promises.scheduler is an object");
ok(typeof timers.promises.scheduler.wait === "function", "timers.promises.scheduler.wait is a function");
ok(typeof timers.promises.scheduler.yield === "function", "timers.promises.scheduler.yield is a function");

// ═══════════════════════════════════════════════════════════════
// 4. require("timers/promises") — returns the promises sub-module
// ═══════════════════════════════════════════════════════════════

var tp = require("timers/promises");
ok(typeof tp === "object", "require('timers/promises') returns object");
ok(typeof tp.setTimeout === "function", "timers/promises.setTimeout is a function");
ok(typeof tp.setImmediate === "function", "timers/promises.setImmediate is a function");
ok(typeof tp.setInterval === "function", "timers/promises.setInterval is a function");
ok(typeof tp.scheduler === "object", "timers/promises.scheduler is an object");
ok(typeof tp.scheduler.wait === "function", "timers/promises.scheduler.wait is a function");
ok(typeof tp.scheduler.yield === "function", "timers/promises.scheduler.yield is a function");

// ═══════════════════════════════════════════════════════════════
// 5. require("node:timers") — node: prefix
// ═══════════════════════════════════════════════════════════════

var nodeTimers = require("node:timers");
ok(typeof nodeTimers === "object", "require('node:timers') returns object");
ok(typeof nodeTimers.setTimeout === "function", "node:timers.setTimeout");
ok(typeof nodeTimers.promises === "object", "node:timers.promises exists");

// ═══════════════════════════════════════════════════════════════
// 6. require("node:timers/promises")
// ═══════════════════════════════════════════════════════════════

var ntp = require("node:timers/promises");
ok(typeof ntp === "object", "require('node:timers/promises') returns object");
ok(typeof ntp.setTimeout === "function", "node:timers/promises.setTimeout");
ok(typeof ntp.scheduler === "object", "node:timers/promises.scheduler");

// ═══════════════════════════════════════════════════════════════
// 7. timers.setTimeout works (functional test)
// ═══════════════════════════════════════════════════════════════

var timerFired = false;
timers.setTimeout(function() {
    timerFired = true;
    ok(timerFired === true, "timers.setTimeout fires callback");
}, 10);

// ═══════════════════════════════════════════════════════════════
// 8. timers.clearTimeout works
// ═══════════════════════════════════════════════════════════════

var cancelledFired = false;
var cancelId = timers.setTimeout(function() {
    cancelledFired = true;
}, 10);
timers.clearTimeout(cancelId);

// ═══════════════════════════════════════════════════════════════
// 9. timers.promises.setTimeout resolves with value after delay
// ═══════════════════════════════════════════════════════════════

var pstStart = performance.now();
tp.setTimeout(50, "hello").then(function(val) {
    var pstElapsed = performance.now() - pstStart;
    ok(val === "hello", "timers.promises.setTimeout resolves with value");
    ok(pstElapsed >= 30, "timers.promises.setTimeout(50) waited >=30ms (got " + Math.floor(pstElapsed) + "ms)");
});

// ═══════════════════════════════════════════════════════════════
// 10. timers.promises.setTimeout resolves with undefined when no value
// ═══════════════════════════════════════════════════════════════

tp.setTimeout(10).then(function(val) {
    ok(val === undefined, "timers.promises.setTimeout resolves with undefined");
});

// ═══════════════════════════════════════════════════════════════
// 11. timers.promises.setImmediate resolves with value
// ═══════════════════════════════════════════════════════════════

tp.setImmediate("immediate-val").then(function(val) {
    ok(val === "immediate-val", "timers.promises.setImmediate resolves with value");
});

// ═══════════════════════════════════════════════════════════════
// 12. timers.promises.setImmediate resolves with undefined
// ═══════════════════════════════════════════════════════════════

tp.setImmediate().then(function(val) {
    ok(val === undefined, "timers.promises.setImmediate resolves with undefined");
});

// ═══════════════════════════════════════════════════════════════
// 13. scheduler.wait resolves after delay (timing check)
// ═══════════════════════════════════════════════════════════════

var waitStart = performance.now();
tp.scheduler.wait(50).then(function() {
    var waitElapsed = performance.now() - waitStart;
    ok(waitElapsed >= 30, "scheduler.wait(50) actually waited >=30ms (got " + Math.floor(waitElapsed) + "ms)");
    ok(waitElapsed < 500, "scheduler.wait(50) didn't take too long (got " + Math.floor(waitElapsed) + "ms)");
});

// ═══════════════════════════════════════════════════════════════
// 14. scheduler.yield resolves
// ═══════════════════════════════════════════════════════════════

var yieldResolved = false;
tp.scheduler.yield().then(function() {
    yieldResolved = true;
    ok(yieldResolved === true, "scheduler.yield() resolves");
});

// ═══════════════════════════════════════════════════════════════
// 15. Check cancelled timer didn't fire + print summary
// ═══════════════════════════════════════════════════════════════

setTimeout(function() {
    ok(cancelledFired === false, "clearTimeout prevents callback from firing");

    console.log("=== timers_module tests: " + pass + " passed, " + fail + " failed ===");
}, 300);
