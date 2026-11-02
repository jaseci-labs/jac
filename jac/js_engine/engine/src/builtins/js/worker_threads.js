/**
 * worker_threads.js — Node.js `node:worker_threads` — production-grade
 * single-threaded implementation.
 *
 * Architecture
 * ------------
 * The engine is single-threaded (libuv event loop, no pthreads).
 * All of the worker_threads API surface is implemented without OS threads:
 *
 *  - MessagePort / MessageChannel: in-process FIFO queues; delivery via
 *    setImmediate so message handlers fire on the next event-loop turn,
 *    matching Node.js semantics.
 *
 *  - BroadcastChannel: global name-keyed registry; broadcast via
 *    setImmediate per recipient.
 *
 *  - Worker: cooperative coroutine. The worker script is executed on the
 *    same event loop (via setImmediate) in a fresh require() invocation.
 *    parentPort / workerData / isMainThread / threadId are injected by
 *    pushing a context frame onto _ctxStack before the require and popping
 *    it after. require('worker_threads') inside the worker script returns
 *    the same cached module.exports object whose identity constants are
 *    property getters that read from _ctxStack.
 *
 *  - locks: Web Locks API. Single-threaded => no contention; every lock
 *    request is granted synchronously inside the returned Promise.
 *
 * Node.js reference: https://nodejs.org/api/worker_threads.html
 */

"use strict";

// ============================================================================
// Worker Context Stack
// ============================================================================
// Each frame: { isMainThread, threadId, parentPort, workerData, threadName }
// Push on worker entry, pop on worker exit.
// Safe because the engine is single-threaded — no concurrent access.
var _ctxStack = [];

function _currentCtx() {
    return _ctxStack.length > 0 ? _ctxStack[_ctxStack.length - 1] : null;
}

// ============================================================================
// Identity Constants
// ============================================================================
// Exposed as getters on module.exports so they return the correct values both
// when required from the main thread and from inside a worker script.

var SHARE_ENV      = Symbol('nodejs.worker_threads.SHARE_ENV');
var resourceLimits = {};

// ============================================================================
// Environment Data
// ============================================================================
var _envData = new Map();

function setEnvironmentData(key, value) {
    if (value === undefined) {
        _envData.delete(key);
    } else {
        _envData.set(key, value);
    }
}

function getEnvironmentData(key) {
    return _envData.get(key);
}

// ============================================================================
// Transfer / Clone marks
// ============================================================================
var _untransferable = new WeakSet();
var _uncloneable    = new WeakSet();

function markAsUntransferable(obj) {
    if (obj !== null && typeof obj === 'object') _untransferable.add(obj);
}

function isMarkedAsUntransferable(obj) {
    if (obj === null || typeof obj !== 'object') return false;
    return _untransferable.has(obj);
}

function markAsUncloneable(obj) {
    if (obj !== null && typeof obj === 'object') _uncloneable.add(obj);
}

function moveMessagePortToContext(port /*, context */) {
    // No-op — single-threaded engine; every port lives in the one context.
    return port;
}

// ============================================================================
// MessagePort
// ============================================================================
var _portIdSeq = 0;

class MessagePort {
    constructor() {
        this._id             = ++_portIdSeq;
        this._twin           = null;
        this._queue          = [];
        this._listeners      = {};
        this._started        = false;
        this._closed         = false;
        this._refed          = true;
        this._drainScheduled = false;
    }

    // -- EventEmitter surface -------------------------------------------------

    _addListener(event, fn, once) {
        if (typeof fn !== 'function') throw new TypeError('listener must be a function');
        if (!this._listeners[event]) this._listeners[event] = [];
        this._listeners[event].push({ fn: fn, once: !!once });
        if (event === 'message') {
            this._started = true;
            if (this._queue.length > 0 && !this._drainScheduled) {
                this._scheduleDrain();
            }
        }
        return this;
    }

    on(event, fn)          { return this._addListener(event, fn, false); }
    addListener(event, fn) { return this._addListener(event, fn, false); }
    once(event, fn)        { return this._addListener(event, fn, true);  }

    // WHATWG EventTarget surface (tests call addEventListener directly)
    addEventListener(type, listener, options) {
        var once = options && typeof options === 'object' && options.once;
        if (typeof options === 'boolean') once = false;
        return this._addListener(type, listener, !!once);
    }
    removeEventListener(type, listener) { return this.off(type, listener); }
    dispatchEvent(event) {
        if (!event || typeof event.type !== 'string') return false;
        event.target = this;
        event.currentTarget = this;
        this.emit(event.type, event);
        return !(event.defaultPrevented);
    }

    off(event, fn) {
        var list = this._listeners[event];
        if (!list) return this;
        for (var i = list.length - 1; i >= 0; i--) {
            if (list[i].fn === fn) { list.splice(i, 1); break; }
        }
        if (list.length === 0) delete this._listeners[event];
        return this;
    }
    removeListener(event, fn) { return this.off(event, fn); }

    removeAllListeners(event) {
        if (event !== undefined) {
            delete this._listeners[event];
        } else {
            this._listeners = {};
        }
        return this;
    }

    emit(event /*, ...args */) {
        var args = Array.prototype.slice.call(arguments, 1);
        var list = this._listeners[event];
        if (!list || list.length === 0) return false;
        var snapshot = list.slice();
        for (var i = 0; i < snapshot.length; i++) {
            var entry = snapshot[i];
            if (entry.once) this.off(event, entry.fn);
            entry.fn.apply(this, args);
        }
        return true;
    }

    // -- Message delivery -----------------------------------------------------

    postMessage(value /*, transferList */) {
        if (this._closed) return;
        var twin = this._twin;
        if (!twin || twin._closed) return;
        if (value !== null && typeof value === 'object' && _untransferable.has(value)) {
            throw Object.assign(
                new Error('Cannot transfer an untransferable object'),
                { code: 'ERR_MISSING_TRANSFERABLE_IN_TRANSFER_LIST' }
            );
        }
        twin._queue.push(value);
        if (twin._started && !twin._drainScheduled) {
            twin._scheduleDrain();
        }
    }

    _scheduleDrain() {
        if (this._drainScheduled || this._closed) return;
        this._drainScheduled = true;
        var self = this;
        setImmediate(function() { self._drain(); });
    }

    _drain() {
        this._drainScheduled = false;
        if (this._closed || !this._started) return;
        while (this._queue.length > 0) {
            if (this._closed) break;
            var msg = this._queue.shift();
            this.emit('message', msg);
        }
    }

    // -- Lifecycle ------------------------------------------------------------

    start() {
        this._started = true;
        if (this._queue.length > 0 && !this._drainScheduled) this._scheduleDrain();
        return this;
    }

    close() {
        if (this._closed) return;
        this._closed = true;
        var self = this;
        setImmediate(function() {
            self.emit('close');
            if (self._twin && !self._twin._closed) self._twin.close();
        });
    }

    ref()    { this._refed = true;  return this; }
    unref()  { this._refed = false; return this; }
    hasRef() { return this._refed; }
}

// ============================================================================
// MessageChannel
// ============================================================================

class MessageChannel {
    constructor() {
        this.port1 = new MessagePort();
        this.port2 = new MessagePort();
        this.port1._twin = this.port2;
        this.port2._twin = this.port1;
    }
}

// ============================================================================
// receiveMessageOnPort — synchronous dequeue
// ============================================================================

function receiveMessageOnPort(port) {
    if (!(port instanceof MessagePort)) {
        throw new TypeError('receiveMessageOnPort: argument must be a MessagePort');
    }
    if (port._closed || port._queue.length === 0) return undefined;
    return { message: port._queue.shift() };
}

// ============================================================================
// BroadcastChannel
// ============================================================================
// Module-level registry: name -> Set<BroadcastChannel>.
// postMessage delivers to all other channels with the same name via setImmediate.

var _bcRegistry = new Map();

class BroadcastChannel {
    constructor(name) {
        if (typeof name !== 'string') {
            throw new TypeError('BroadcastChannel: name must be a string');
        }
        this.name            = name;
        this._closed         = false;
        this._onmessage      = null;
        this._onmessageerror = null;
        this._listeners      = {};
        this._refed          = true;

        if (!_bcRegistry.has(name)) _bcRegistry.set(name, new Set());
        _bcRegistry.get(name).add(this);
    }

    get onmessage()    { return this._onmessage; }
    set onmessage(fn)  { this._onmessage = typeof fn === 'function' ? fn : null; }

    get onmessageerror()   { return this._onmessageerror; }
    set onmessageerror(fn) {
        this._onmessageerror = typeof fn === 'function' ? fn : null;
    }

    addEventListener(type, listener, options) {
        if (typeof listener !== 'function') return;
        if (!this._listeners[type]) this._listeners[type] = [];
        var once = options && typeof options === 'object' && options.once;
        this._listeners[type].push({ fn: listener, once: !!once });
    }
    removeEventListener(type, listener) {
        var list = this._listeners[type];
        if (!list) return;
        for (var i = list.length - 1; i >= 0; i--) {
            if (list[i].fn === listener) { list.splice(i, 1); break; }
        }
    }
    dispatchEvent(event) {
        if (!event || typeof event.type !== 'string') return false;
        event.target = this;
        event.currentTarget = this;
        var list = this._listeners[event.type];
        if (list) {
            var snap = list.slice();
            for (var i = 0; i < snap.length; i++) {
                if (snap[i].once) this.removeEventListener(event.type, snap[i].fn);
                snap[i].fn.call(this, event);
            }
        }
        return !(event.defaultPrevented);
    }

    postMessage(message) {
        if (this._closed) {
            throw Object.assign(new Error('BroadcastChannel is closed'),
                                { code: 'ERR_INVALID_STATE' });
        }
        var siblings = _bcRegistry.get(this.name);
        if (!siblings) return;
        var self = this;
        siblings.forEach(function(bc) {
            if (bc === self || bc._closed) return;
            var target = bc;
            var msg    = message;
            setImmediate(function() {
                if (target._closed) return;
                var evt = { data: msg, target: target, type: 'message' };
                if (typeof target._onmessage === 'function') {
                    target._onmessage(evt);
                }
                var list = target._listeners && target._listeners['message'];
                if (list) {
                    var snap = list.slice();
                    for (var i = 0; i < snap.length; i++) {
                        if (snap[i].once) target.removeEventListener('message', snap[i].fn);
                        snap[i].fn.call(target, evt);
                    }
                }
            });
        });
    }

    close() {
        if (this._closed) return;
        this._closed = true;
        var siblings = _bcRegistry.get(this.name);
        if (siblings) {
            siblings.delete(this);
            if (siblings.size === 0) _bcRegistry.delete(this.name);
        }
    }

    ref()   { this._refed = true;  return this; }
    unref() { this._refed = false; return this; }
}

// ============================================================================
// Worker — cooperative coroutine
// ============================================================================
// Worker scripts are executed on the same event loop (via setImmediate).
//
// Port wiring:
//   main thread:  worker.postMessage(x)   -> enqueues into slot.workerPort._queue
//                 worker.on('message', f) -> listens on slot.parentPort
//   inside worker: parentPort = slot.workerPort
//                  parentPort.postMessage(y) -> twin = slot.parentPort -> main hears it
//
//   slot.parentPort._twin = slot.workerPort
//   slot.workerPort._twin = slot.parentPort

var _workerIdSeq = 0;
var _workerTable = {};

function _workerEmit(slot, event) {
    var args = Array.prototype.slice.call(arguments, 2);
    var list = slot && slot.listeners && slot.listeners[event];
    if (!list) return;
    var snapshot = list.slice();
    for (var i = 0; i < snapshot.length; i++) {
        var entry = snapshot[i];
        if (entry.once) {
            var idx = slot.listeners[event].indexOf(entry);
            if (idx >= 0) slot.listeners[event].splice(idx, 1);
        }
        entry.fn.apply(null, args);
    }
}

function _resolveWorkerFile(filename) {
    if (filename.length > 0 && filename[0] === '/') return filename;
    var path = require('path');
    return path.resolve(filename);
}

function _runWorker(workerId) {
    var slot = _workerTable[workerId];
    if (!slot || slot.state === 'terminated') return;

    slot.state = 'running';

    _ctxStack.push({
        isMainThread : false,
        threadId     : workerId,
        parentPort   : slot.workerPort,
        workerData   : slot.workerData,
        threadName   : slot.threadName,
    });

    try {
        // Clear from require.cache so the script re-executes fresh even if the
        // main thread already required the same path.
        if (require.cache && typeof require.cache === 'object') {
            delete require.cache[slot.filename];
        }
        require(slot.filename);
    } catch (err) {
        _ctxStack.pop();
        slot.state = 'errored';
        _workerEmit(slot, 'error', err);
        _workerEmit(slot, 'exit', 1);
        return;
    }

    _ctxStack.pop();
    slot.state = 'idle';
    _workerEmit(slot, 'online');
}

class Worker {
    constructor(filename, options) {
        if (typeof filename !== 'string') {
            throw new TypeError('Worker: filename must be a string');
        }
        options = options || {};

        this._id            = ++_workerIdSeq;
        this._terminated    = false;
        this.threadId       = this._id;
        this.threadName     = options.name || null;
        this.resourceLimits = {};

        var ch      = new MessageChannel();
        var parentP = ch.port1;
        var workerP = ch.port2;

        _workerTable[this._id] = {
            filename   : _resolveWorkerFile(filename),
            workerData : options.workerData !== undefined ? options.workerData : null,
            threadName : options.name || null,
            parentPort : parentP,
            workerPort : workerP,
            state      : 'created',
            listeners  : {},
        };

        var id = this._id;
        setImmediate(function() { _runWorker(id); });
    }

    postMessage(value /*, transferList */) {
        if (this._terminated) return;
        var slot = _workerTable[this._id];
        if (!slot) return;
        var wp = slot.workerPort;
        if (wp._closed) return;
        if (value !== null && typeof value === 'object' && _untransferable.has(value)) {
            throw Object.assign(
                new Error('Cannot transfer an untransferable object'),
                { code: 'ERR_MISSING_TRANSFERABLE_IN_TRANSFER_LIST' }
            );
        }
        wp._queue.push(value);
        if (wp._started && !wp._drainScheduled) wp._scheduleDrain();
    }

    _addWorkerListener(event, fn, once) {
        if (this._terminated && event !== 'exit') return this;
        var slot = _workerTable[this._id];
        if (!slot) return this;
        if (event === 'message') {
            slot.parentPort._addListener('message', fn, once);
        } else {
            if (!slot.listeners[event]) slot.listeners[event] = [];
            slot.listeners[event].push({ fn: fn, once: !!once });
        }
        return this;
    }

    on(event, fn)          { return this._addWorkerListener(event, fn, false); }
    addListener(event, fn) { return this._addWorkerListener(event, fn, false); }
    once(event, fn)        { return this._addWorkerListener(event, fn, true);  }

    off(event, fn) {
        var slot = _workerTable[this._id];
        if (!slot) return this;
        if (event === 'message') {
            slot.parentPort.off('message', fn);
        } else {
            var list = slot.listeners[event];
            if (!list) return this;
            for (var i = list.length - 1; i >= 0; i--) {
                if (list[i].fn === fn) { list.splice(i, 1); break; }
            }
        }
        return this;
    }
    removeListener(event, fn) { return this.off(event, fn); }

    terminate() {
        if (this._terminated) return Promise.resolve(0);
        this._terminated = true;
        var slot = _workerTable[this._id];
        if (slot) {
            slot.state = 'terminated';
            if (slot.workerPort) slot.workerPort.close();
            if (slot.parentPort) slot.parentPort.close();
        }
        _workerEmit(slot, 'exit', 1);
        return Promise.resolve(1);
    }

    ref()   { return this; }
    unref() { return this; }
}

// ============================================================================
// LockManager — Web Locks API
// ============================================================================
// Single-threaded => no contention. Every lock.request() is granted
// synchronously inside the returned Promise.

var locks = (function() {
    var _held = [];

    function _Lock(name, mode) {
        Object.defineProperties(this, {
            name: { value: name, enumerable: true },
            mode: { value: mode, enumerable: true },
        });
    }

    function request(name, optionsOrCb, cb) {
        var opts     = {};
        var callback = cb;
        if (typeof optionsOrCb === 'function') {
            callback = optionsOrCb;
        } else if (optionsOrCb && typeof optionsOrCb === 'object') {
            opts     = optionsOrCb;
            callback = cb;
        }
        if (typeof callback !== 'function') {
            return Promise.reject(
                new TypeError('LockManager.request: callback must be a function')
            );
        }

        var mode   = opts.mode || 'exclusive';
        var signal = opts.signal || null;

        return new Promise(function(resolve, reject) {
            if (signal && signal.aborted) {
                var abortErr = new Error('Lock request aborted');
                abortErr.name = 'AbortError';
                return reject(abortErr);
            }

            var lock = new _Lock(name, mode);
            _held.push(lock);

            var result;
            try {
                result = callback(lock);
            } catch (err) {
                _held.splice(_held.indexOf(lock), 1);
                return reject(err);
            }

            Promise.resolve(result).then(
                function(val) { _held.splice(_held.indexOf(lock), 1); resolve(val); },
                function(err) { _held.splice(_held.indexOf(lock), 1); reject(err); }
            );
        });
    }

    function query() {
        var snapshot = _held.map(function(l) {
            return { name: l.name, mode: l.mode, clientId: '' };
        });
        return Promise.resolve({ held: snapshot, pending: [] });
    }

    return { request: request, query: query };
})();

// ============================================================================
// Module exports — dynamic getters for identity constants
// ============================================================================
// isMainThread / threadId / parentPort / workerData / threadName are defined
// as property getters so they read from _ctxStack at access time:
//   require('worker_threads').isMainThread  in main thread -> true
//   Same call from inside a worker script                  -> false
//   const { isMainThread } = require('worker_threads')    -> correct value

var _exports = {
    SHARE_ENV               : SHARE_ENV,
    resourceLimits          : resourceLimits,
    isInternalThread        : false,
    Worker                  : Worker,
    MessageChannel          : MessageChannel,
    MessagePort             : MessagePort,
    BroadcastChannel        : BroadcastChannel,
    receiveMessageOnPort    : receiveMessageOnPort,
    moveMessagePortToContext: moveMessagePortToContext,
    markAsUntransferable    : markAsUntransferable,
    isMarkedAsUntransferable: isMarkedAsUntransferable,
    markAsUncloneable       : markAsUncloneable,
    setEnvironmentData      : setEnvironmentData,
    getEnvironmentData      : getEnvironmentData,
    locks                   : locks,
    postMessageToThread: function postMessageToThread(threadId) {
        throw Object.assign(
            new Error('postMessageToThread: no thread ' + threadId + ' (single-threaded)'),
            { code: 'ERR_WORKER_MESSAGING_FAILED' }
        );
    },
};

Object.defineProperty(_exports, 'isMainThread', {
    get: function() { var c = _currentCtx(); return c ? c.isMainThread : true; },
    enumerable: true, configurable: true,
});
Object.defineProperty(_exports, 'threadId', {
    get: function() { var c = _currentCtx(); return c ? c.threadId : 0; },
    enumerable: true, configurable: true,
});
Object.defineProperty(_exports, 'parentPort', {
    get: function() { var c = _currentCtx(); return c ? c.parentPort : null; },
    enumerable: true, configurable: true,
});
Object.defineProperty(_exports, 'workerData', {
    get: function() { var c = _currentCtx(); return c ? c.workerData : null; },
    enumerable: true, configurable: true,
});
Object.defineProperty(_exports, 'threadName', {
    get: function() { var c = _currentCtx(); return c ? (c.threadName || null) : null; },
    enumerable: true, configurable: true,
});

// Expose WHATWG messaging globals (Node installs these on globalThis).
globalThis.MessageChannel = MessageChannel;
globalThis.MessagePort = MessagePort;
globalThis.BroadcastChannel = BroadcastChannel;

module.exports = _exports;
