// ────────────────────────────────────────────────────────────────────────────
// test_events.js — Node.js EventEmitter tests
//
// Tests:
//   1-3:   require("events") / require("node:events") basics
//   4-8:   .on() / .emit() / .once()
//   9-12:  .off() / .removeAllListeners()
//   13-15: .listenerCount() / .eventNames() / .listeners()
//   16-17: .prependListener() ordering
//   18:    chaining
//   19:    .emit() returns boolean
//   20:    multi-arg emit
//   21:    once auto-removes
//   22:    events.once() → Promise
//   23:    EventEmitter as constructor function
//   24:    removeAllListeners() with no args
//   25:    rawListeners returns functions
//   26:    setMaxListeners / getMaxListeners
//   27:    multiple listeners same event
//   28:    prependOnceListener
// ────────────────────────────────────────────────────────────────────────────

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        _passed = _passed + 1;
        console.log("OK " + id + " " + desc);
    } else {
        _failed = _failed + 1;
        console.log("FAIL " + id + " " + desc + "  got=" + actual + "  expected=" + expected);
    }
}

// ── 1: require("events") returns a function (constructor) ────────────────────
var events = require("events");
check(1, "require('events') typeof === function", typeof events, "function");

// ── 2: require("node:events") returns same thing ─────────────────────────────
var events2 = require("node:events");
check(2, "require('node:events') cached same ref", events === events2, true);

// ── 3: EventEmitter property exists ──────────────────────────────────────────
check(3, "events.EventEmitter === events", events.EventEmitter === events, true);

// ── 4: new EventEmitter() creates instance ───────────────────────────────────
var ee = new events();
check(4, "new EventEmitter() typeof === object", typeof ee, "object");

// ── 5: .on() + .emit() calls listener ───────────────────────────────────────
var got5 = 0;
ee.on("data", function (val) { got5 = val; });
ee.emit("data", 42);
check(5, ".on('data',fn) + .emit('data',42) → fn called with 42", got5, 42);

// ── 6: .once() fires once then auto-removes ─────────────────────────────────
var count6 = 0;
var ee6 = new events.EventEmitter();
ee6.once("tick", function () { count6 = count6 + 1; });
ee6.emit("tick");
ee6.emit("tick");
ee6.emit("tick");
check(6, ".once fires only once", count6, 1);

// ── 7: .off() removes specific listener ─────────────────────────────────────
var count7 = 0;
var ee7 = new events.EventEmitter();
function handler7() { count7 = count7 + 1; }
ee7.on("ev", handler7);
ee7.emit("ev");
ee7.off("ev", handler7);
ee7.emit("ev");
check(7, ".off removes listener (count stays 1)", count7, 1);

// ── 8: .emit() returns true when listeners exist ─────────────────────────────
var ee8 = new events.EventEmitter();
ee8.on("a", function () {});
var ret8a = ee8.emit("a");
var ret8b = ee8.emit("nolisteners");
check(8, ".emit returns true/false", ret8a === true && ret8b === false, true);

// ── 9: .removeAllListeners(event) clears specific event ──────────────────────
var ee9 = new events.EventEmitter();
var count9 = 0;
ee9.on("x", function () { count9 = count9 + 1; });
ee9.on("x", function () { count9 = count9 + 1; });
ee9.on("y", function () { count9 = count9 + 100; });
ee9.removeAllListeners("x");
ee9.emit("x");
ee9.emit("y");
check(9, "removeAllListeners('x') clears x, keeps y", count9, 100);

// ── 10: .listenerCount() ────────────────────────────────────────────────────
var ee10 = new events.EventEmitter();
ee10.on("a", function () {});
ee10.on("a", function () {});
ee10.on("b", function () {});
check(10, "listenerCount('a') === 2", ee10.listenerCount("a"), 2);

// ── 11: .eventNames() ───────────────────────────────────────────────────────
var ee11 = new events.EventEmitter();
ee11.on("foo", function () {});
ee11.on("bar", function () {});
var names = ee11.eventNames();
check(11, "eventNames().length === 2", names.length, 2);

// ── 12: .listeners(event) returns array of functions ─────────────────────────
var ee12 = new events.EventEmitter();
function h12a() {}
function h12b() {}
ee12.on("ev", h12a);
ee12.on("ev", h12b);
var lsnrs = ee12.listeners("ev");
check(12, "listeners() returns array of 2", lsnrs.length, 2);

// ── 13: .prependListener fires before earlier-added ──────────────────────────
var order13 = "";
var ee13 = new events.EventEmitter();
ee13.on("x", function () { order13 = order13 + "A"; });
ee13.prependListener("x", function () { order13 = order13 + "B"; });
ee13.emit("x");
check(13, "prependListener fires first (BA)", order13, "BA");

// ── 14: chaining .on().on() ─────────────────────────────────────────────────
var ee14 = new events.EventEmitter();
var chain14 = ee14.on("a", function () {}).on("b", function () {});
check(14, "chaining .on().on() returns emitter", chain14 === ee14, true);

// ── 15: multi-arg emit ──────────────────────────────────────────────────────
var sum15 = 0;
var ee15 = new events.EventEmitter();
ee15.on("add", function (a, b, c) { sum15 = a + b + c; });
ee15.emit("add", 10, 20, 30);
check(15, "emit with 3 args: 10+20+30=60", sum15, 60);

// ── 16: .addListener alias ──────────────────────────────────────────────────
var got16 = false;
var ee16 = new events.EventEmitter();
ee16.addListener("x", function () { got16 = true; });
ee16.emit("x");
check(16, "addListener alias works", got16, true);

// ── 17: .removeListener alias ───────────────────────────────────────────────
var count17 = 0;
var ee17 = new events.EventEmitter();
function h17() { count17 = count17 + 1; }
ee17.on("x", h17);
ee17.emit("x");
ee17.removeListener("x", h17);
ee17.emit("x");
check(17, "removeListener alias works", count17, 1);

// ── 18: removeAllListeners() no args clears everything ───────────────────────
var ee18 = new events.EventEmitter();
var c18 = 0;
ee18.on("a", function () { c18 = c18 + 1; });
ee18.on("b", function () { c18 = c18 + 1; });
ee18.removeAllListeners();
ee18.emit("a");
ee18.emit("b");
check(18, "removeAllListeners() clears all", c18, 0);

// ── 19: .listeners() on non-existent event ──────────────────────────────────
var ee19 = new events.EventEmitter();
check(19, "listeners('none') returns empty array", ee19.listeners("none").length, 0);

// ── 20: listenerCount on non-existent event ─────────────────────────────────
var ee20 = new events.EventEmitter();
check(20, "listenerCount('none') === 0", ee20.listenerCount("none"), 0);

// ── 21: setMaxListeners / getMaxListeners ───────────────────────────────────
var ee21 = new events.EventEmitter();
check(21, "getMaxListeners() default 10", ee21.getMaxListeners(), 10);

// ── 22: setMaxListeners changes value ───────────────────────────────────────
var ee22 = new events.EventEmitter();
ee22.setMaxListeners(25);
check(22, "setMaxListeners(25) → getMaxListeners()===25", ee22.getMaxListeners(), 25);

// ── 23: multiple listeners same event fire in order ─────────────────────────
var order23 = "";
var ee23 = new events.EventEmitter();
ee23.on("seq", function () { order23 = order23 + "1"; });
ee23.on("seq", function () { order23 = order23 + "2"; });
ee23.on("seq", function () { order23 = order23 + "3"; });
ee23.emit("seq");
check(23, "multiple listeners fire in order (123)", order23, "123");

// ── 24: prependOnceListener ─────────────────────────────────────────────────
var order24 = "";
var ee24 = new events.EventEmitter();
ee24.on("x", function () { order24 = order24 + "A"; });
ee24.prependOnceListener("x", function () { order24 = order24 + "B"; });
ee24.emit("x");
ee24.emit("x");
check(24, "prependOnceListener fires first, only once", order24, "BAA");

// ── 25: events.once() returns a Promise ─────────────────────────────────────
// This is async — we use setTimeout to emit after the promise is set up
var ee25 = new events.EventEmitter();
var result25 = "pending";
events.once(ee25, "done").then(function (val) {
    result25 = val;
});
// Emit in next tick so the promise handler is registered
setTimeout(function () {
    ee25.emit("done", "resolved");
    // Check after another tick
    setTimeout(function () {
        check(25, "events.once() Promise resolves", result25, "resolved");

        // ── 26: events.listenerCount static ─────────────────────────────
        var ee26 = new events.EventEmitter();
        ee26.on("a", function () {});
        ee26.on("a", function () {});
        check(26, "events.listenerCount(ee, 'a') === 2", events.listenerCount(ee26, "a"), 2);

        // ── 27: once listener receives multiple args as array ───────────
        var ee27 = new events.EventEmitter();
        var r27 = null;
        events.once(ee27, "multi").then(function (val) {
            r27 = val;
        });
        setTimeout(function () {
            ee27.emit("multi", "x", "y");
            setTimeout(function () {
                // Should receive ["x", "y"] array
                check(27, "events.once multi-arg returns array", Array.isArray(r27), true);

                // ── Summary ─────────────────────────────────────────────
                console.log("\n=== Events tests: " + _passed + " passed, " + _failed + " failed ===");
            }, 10);
        }, 1);
    }, 10);
}, 1);
