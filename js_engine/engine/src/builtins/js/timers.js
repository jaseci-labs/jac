// ────────────────────────────────────────────────────────────────────────────
// builtins/js/timers.js — Node.js `timers` and `timers/promises` module
//
// Wraps the already-existing global timer functions (Phase 3) into
// a proper Node.js module shape.
//
// require("timers")          → { setTimeout, setInterval, setImmediate,
//                                clearTimeout, clearInterval, clearImmediate }
// require("timers/promises") → { setTimeout, setInterval, setImmediate,
//                                scheduler }
//
// Node.js reference: https://nodejs.org/api/timers.html
// ────────────────────────────────────────────────────────────────────────────

// ── timers (sync) ───────────────────────────────────────────────────────────

var timers = {};

// Always dispatch through globalThis so async_hooks (and other) wrappers apply
// even if this module was cached before instrumentation.
timers.setTimeout = function() {
    return globalThis.setTimeout.apply(globalThis, arguments);
};
timers.clearTimeout = function() {
    return globalThis.clearTimeout.apply(globalThis, arguments);
};
timers.setInterval = function() {
    return globalThis.setInterval.apply(globalThis, arguments);
};
timers.clearInterval = function() {
    return globalThis.clearInterval.apply(globalThis, arguments);
};
timers.setImmediate = function() {
    return globalThis.setImmediate.apply(globalThis, arguments);
};
timers.clearImmediate = function() {
    return globalThis.clearImmediate.apply(globalThis, arguments);
};

// ── timers/promises ─────────────────────────────────────────────────────────

var promises = {};

/**
 * timers.promises.setTimeout(delay, value?, options?)
 * Returns a Promise that resolves with `value` after `delay` ms.
 *
 * Node.js ref: https://nodejs.org/api/timers.html#timerspromisessettimeoutdelay-value-options
 */
promises.setTimeout = function(delay, value) {
    return new Promise(function(resolve) {
        globalThis.setTimeout(function() {
            resolve(value);
        }, delay);
    });
};

/**
 * timers.promises.setImmediate(value?, options?)
 * Returns a Promise that resolves with `value` on the next event loop iteration.
 *
 * Node.js ref: https://nodejs.org/api/timers.html#timerspromisessetimmediatevalue-options
 */
promises.setImmediate = function(value) {
    return new Promise(function(resolve) {
        globalThis.setImmediate(function() {
            resolve(value);
        });
    });
};

/**
 * timers.promises.setInterval(delay, value?, options?)
 * Returns an async iterable that yields `value` every `delay` ms.
 *
 * For now, returns a simplified version that yields once (full async
 * iterator support deferred until Symbol.asyncIterator is implemented).
 *
 * Node.js ref: https://nodejs.org/api/timers.html#timerspromisessetintervaldelay-value-options
 */
promises.setInterval = function(delay, value) {
    // Simplified: return a promise that resolves after `delay` ms
    // Full async iterator support requires Symbol.asyncIterator
    return new Promise(function(resolve) {
        globalThis.setTimeout(function() {
            resolve(value);
        }, delay);
    });
};

/**
 * timers.promises.scheduler — Scheduler API
 *
 * scheduler.wait(delay)  → Promise resolving after delay ms
 * scheduler.yield()      → Promise resolving on next microtask
 *
 * Node.js ref: https://nodejs.org/api/timers.html#timerspromisesschedulerwaitdelay-options
 */
var scheduler = {};

scheduler.wait = function(delay) {
    return new Promise(function(resolve) {
        globalThis.setTimeout(function() {
            resolve(undefined);
        }, delay);
    });
};

scheduler.yield = function() {
    return new Promise(function(resolve) {
        // Use queueMicrotask if available, else setImmediate
        if (typeof globalThis.queueMicrotask === "function") {
            globalThis.queueMicrotask(function() { resolve(undefined); });
        } else {
            globalThis.setImmediate(function() { resolve(undefined); });
        }
    });
};

promises.scheduler = scheduler;

timers.promises = promises;

module.exports = timers;
