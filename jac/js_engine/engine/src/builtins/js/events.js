// ────────────────────────────────────────────────────────────────────────────
// builtins/js/events.js — Node.js `events` module (EventEmitter)
//
// Pure JavaScript implementation of the EventEmitter API.
// Loaded by `require("events")` / `require("node:events")`.
//
// Node.js reference: https://nodejs.org/api/events.html
// Bun reference:     bun/src/js/node/events.ts
// ────────────────────────────────────────────────────────────────────────────

// Default maximum listeners per emitter (mirrors Node.js default of 10).
var _defaultMaxListeners = 10;

function _checkMaxListeners(emitter, event, list) {
    var max = emitter.getMaxListeners();
    if (max <= 0 || max === Infinity) {
        return;
    }
    if (list.length > max && !list.warned) {
        list.warned = true;
        if (typeof process !== "undefined" && typeof process.emitWarning === "function") {
            var msg =
                "Possible EventEmitter memory leak detected. " +
                list.length +
                " " +
                event +
                " listeners added. Use emitter.setMaxListeners() to increase limit";
            var w = new Error(msg);
            w.name = "MaxListenersExceededWarning";
            w.emitter = emitter;
            w.type = event;
            w.count = list.length;
            process.emitWarning(w);
        }
    }
}

// ── EventEmitter class ──────────────────────────────────────────────────────

class EventEmitter {
    constructor(options) {
        EventEmitter.init.call(this, options);
    }

    // Node.js exposes EventEmitter.init so ES5-style subclasses can run the
    // base initializer via `EventEmitter.init.call(this)` — an ES6 class
    // constructor cannot be invoked with `.call()`. Keep the re-init guard so
    // it is safe to call even when a subclass already set up `_events`.
    static init(options) {
        // _events: plain object mapping eventName → array of listener wrappers
        // Each wrapper is { fn: <function>, once: <boolean> }
        if (this._events === undefined) {
            this._events = {};
        }
        this._maxListeners = undefined; // use default when undefined
        this._captureRejections = false;
        if (options !== undefined && options !== null && typeof options === "object") {
            if (options.captureRejections === true) {
                this._captureRejections = true;
            }
        }
        return this;
    }

    on(event, listener) {
        if (typeof listener !== "function") {
            throw new TypeError("listener must be a function");
        }

        // Emit "newListener" before adding (per Node.js spec)
        if (this._events["newListener"] !== undefined) {
            this.emit("newListener", event, listener);
        }

        if (this._events[event] === undefined) {
            this._events[event] = [];
        }
        this._events[event].push({ fn: listener, once: false });
        _checkMaxListeners(this, event, this._events[event]);
        return this;
    }

    addListener(event, listener) {
        return this.on(event, listener);
    }

    once(event, listener) {
        if (typeof listener !== "function") {
            throw new TypeError("listener must be a function");
        }

        if (this._events["newListener"] !== undefined) {
            this.emit("newListener", event, listener);
        }

        if (this._events[event] === undefined) {
            this._events[event] = [];
        }
        this._events[event].push({ fn: listener, once: true });
        _checkMaxListeners(this, event, this._events[event]);
        return this;
    }

    off(event, listener) {
        if (this._events[event] === undefined) {
            return this;
        }
        var list = this._events[event];
        var i = list.length - 1;
        // Remove last matching listener (Node.js removes the most recently added)
        while (i >= 0) {
            if (list[i].fn === listener) {
                list.splice(i, 1);
                // Emit "removeListener" after removal
                if (this._events["removeListener"] !== undefined) {
                    this.emit("removeListener", event, listener);
                }
                break;
            }
            i = i - 1;
        }
        // Clean up empty arrays
        if (list.length === 0) {
            delete this._events[event];
        }
        return this;
    }

    removeListener(event, listener) {
        return this.off(event, listener);
    }

    removeAllListeners(event) {
        if (event !== undefined) {
            if (this._events[event] !== undefined) {
                // Emit "removeListener" for each removed listener if handler exists
                if (this._events["removeListener"] !== undefined) {
                    var list = this._events[event];
                    var i = 0;
                    while (i < list.length) {
                        this.emit("removeListener", event, list[i].fn);
                        i = i + 1;
                    }
                }
                delete this._events[event];
            }
        } else {
            // Remove all events (except "removeListener" itself, per Node.js spec)
            var names = Object.keys(this._events);
            if (typeof Object.getOwnPropertySymbols === "function") {
                var syms = Object.getOwnPropertySymbols(this._events);
                var si = 0;
                while (si < syms.length) {
                    names.push(syms[si]);
                    si = si + 1;
                }
            }
            var j = 0;
            while (j < names.length) {
                if (names[j] !== "removeListener") {
                    this.removeAllListeners(names[j]);
                }
                j = j + 1;
            }
            delete this._events["removeListener"];
        }
        return this;
    }

    emit(event) {
        if (this._events[event] === undefined) {
            // Special case: unhandled "error" event → domain or throw
            if (event === "error") {
                var err = arguments.length > 1 ? arguments[1] : new Error("Unhandled error.");
                var dom = this.domain;
                if (!dom && typeof process !== "undefined") {
                    try { dom = process.domain; } catch (_e) { dom = null; }
                }
                if (dom && typeof dom.emit === "function" && dom !== this) {
                    dom.emit("error", err);
                    return false;
                }
                throw err;
            }
            return false;
        }

        // Collect args (skip first arg which is the event name)
        var args = [];
        var a = 1;
        while (a < arguments.length) {
            args.push(arguments[a]);
            a = a + 1;
        }

        // Copy listener list to allow mutations during emit
        var list = this._events[event];
        var copy = [];
        var c = 0;
        while (c < list.length) {
            copy.push(list[c]);
            c = c + 1;
        }

        // Track which once-listeners to remove after calling them
        var toRemove = [];
        var i = 0;
        while (i < copy.length) {
            var wrapper = copy[i];
            var result;
            try {
                // Call listener with correct this + args
                if (args.length === 0) {
                    result = wrapper.fn.call(this);
                } else if (args.length === 1) {
                    result = wrapper.fn.call(this, args[0]);
                } else if (args.length === 2) {
                    result = wrapper.fn.call(this, args[0], args[1]);
                } else if (args.length === 3) {
                    result = wrapper.fn.call(this, args[0], args[1], args[2]);
                } else {
                    result = wrapper.fn.apply(this, args);
                }
            } catch (listenerErr) {
                if (this._captureRejections || EventEmitter.captureRejections) {
                    this.emit("error", listenerErr);
                    if (wrapper.once) {
                        toRemove.push(wrapper);
                    }
                    i = i + 1;
                    continue;
                }
                throw listenerErr;
            }
            if (result !== null && typeof result === "object" && typeof result.then === "function") {
                if (this._captureRejections || EventEmitter.captureRejections) {
                    var self = this;
                    result.then(null, function (err) {
                        self.emit("error", err);
                    });
                }
            }
            if (wrapper.once) {
                toRemove.push(wrapper);
            }
            i = i + 1;
        }

        // Remove once-listeners
        var r = 0;
        while (r < toRemove.length) {
            var idx = -1;
            var k = 0;
            while (k < list.length) {
                if (list[k] === toRemove[r]) {
                    idx = k;
                    break;
                }
                k = k + 1;
            }
            if (idx >= 0) {
                list.splice(idx, 1);
            }
            r = r + 1;
        }

        // Clean up empty arrays
        if (list.length === 0) {
            delete this._events[event];
        }

        return true;
    }

    listeners(event) {
        if (this._events[event] === undefined) {
            return [];
        }
        var result = [];
        var list = this._events[event];
        var i = 0;
        while (i < list.length) {
            result.push(list[i].fn);
            i = i + 1;
        }
        return result;
    }

    listenerCount(event) {
        if (this._events[event] === undefined) {
            return 0;
        }
        return this._events[event].length;
    }

    rawListeners(event) {
        if (this._events[event] === undefined) {
            return [];
        }
        var result = [];
        var list = this._events[event];
        var i = 0;
        while (i < list.length) {
            if (list[i].once) {
                // Return a stable wrapper distinct from the user function.
                // wrapper.listener === userFn (Node.js contract).
                var w = list[i];
                var onceFn = function() { return w.fn.apply(this, arguments); };
                onceFn.listener = w.fn;
                result.push(onceFn);
            } else {
                result.push(list[i].fn);
            }
            i = i + 1;
        }
        return result;
    }

    prependListener(event, listener) {
        if (typeof listener !== "function") {
            throw new TypeError("listener must be a function");
        }

        if (this._events["newListener"] !== undefined) {
            this.emit("newListener", event, listener);
        }

        if (this._events[event] === undefined) {
            this._events[event] = [];
        }
        this._events[event].unshift({ fn: listener, once: false });
        _checkMaxListeners(this, event, this._events[event]);
        return this;
    }

    prependOnceListener(event, listener) {
        if (typeof listener !== "function") {
            throw new TypeError("listener must be a function");
        }

        if (this._events["newListener"] !== undefined) {
            this.emit("newListener", event, listener);
        }

        if (this._events[event] === undefined) {
            this._events[event] = [];
        }
        this._events[event].unshift({ fn: listener, once: true });
        _checkMaxListeners(this, event, this._events[event]);
        return this;
    }

    eventNames() {
        var names = Object.keys(this._events);
        if (typeof Object.getOwnPropertySymbols === "function") {
            var syms = Object.getOwnPropertySymbols(this._events);
            var i = 0;
            while (i < syms.length) {
                names.push(syms[i]);
                i = i + 1;
            }
        }
        return names;
    }

    setMaxListeners(n) {
        if (typeof n !== 'number' || n < 0 || n !== n) {
            throw new RangeError(
                'The value of "n" is out of range. It must be a non-negative number. Received ' + n
            );
        }
        this._maxListeners = n;
        return this;
    }

    getMaxListeners() {
        if (this._maxListeners === undefined) {
            return EventEmitter.defaultMaxListeners;
        }
        return this._maxListeners;
    }
}

// ── Static property ─────────────────────────────────────────────────────────

Object.defineProperty(EventEmitter, 'defaultMaxListeners', {
    get: function() { return _defaultMaxListeners; },
    set: function(n) {
        if (typeof n !== 'number' || n < 0 || n !== n) {
            throw new RangeError(
                'The value of "n" is out of range. It must be a non-negative number. Received ' + n
            );
        }
        _defaultMaxListeners = n;
    },
    enumerable: true,
    configurable: false  // Node: non-configurable accessor on EventEmitter
});

EventEmitter.captureRejections = false;

// ── Static helper: events.once(emitter, name) → Promise ─────────────────────

function once(emitter, name) {
    return new Promise(function (resolve, reject) {
        function onEvent() {
            // Remove error listener if we were listening for a non-error event
            if (name !== "error") {
                emitter.off("error", onError);
            }
            // Resolve with the single value if only one arg, otherwise an array.
            // This matches common Node.js usage where once() resolves with the
            // emitted value directly for single-argument events.
            var args = [];
            var i = 0;
            while (i < arguments.length) {
                args.push(arguments[i]);
                i = i + 1;
            }
            resolve(args.length === 1 ? args[0] : args);
        }
        function onError(err) {
            emitter.off(name, onEvent);
            reject(err);
        }
        emitter.once(name, onEvent);
        if (name !== "error") {
            emitter.once("error", onError);
        }
    });
}

// ── Static helper: events.listenerCount(emitter, event) ─────────────────────

function listenerCount(emitter, event) {
    if (typeof emitter.listenerCount === "function") {
        return emitter.listenerCount(event);
    }
    return 0;
}

// ── Static helper: events.on(emitter, event) → AsyncIterator ────────────────
// Deferred — requires async iteration support

// ── exports ─────────────────────────────────────────────────────────────────

module.exports = EventEmitter;
module.exports.EventEmitter = EventEmitter;
module.exports.once = once;
module.exports.listenerCount = listenerCount;
// defaultMaxListeners is the non-configurable accessor on EventEmitter above;
// do not overwrite it with a plain data property.
