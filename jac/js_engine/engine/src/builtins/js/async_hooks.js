/**
 * async_hooks.js — Node.js `async_hooks` / `node:async_hooks` (Waves 11/20)
 *
 * JS layer with:
 *   - createHook / AsyncResource / AsyncLocalStorage
 *   - executionAsyncId / triggerAsyncId / executionAsyncResource
 *   - asyncWrapProviders constants
 *   - Timer instrumentation via wrapped globalThis.setTimeout/setInterval/setImmediate
 *   - Promise chain instrumentation via Promise.prototype.then/catch/finally
 *
 * Wave 20: when hooks/ALS are active, native PromiseHook (`__asyncHooks`) assigns
 * async ids at promise create/settle and queues init/promiseResolve events.
 * JS drains those queues (no double-fire) and still wraps `.then` for before/after.
 * When inactive, the native gate stays off (near-zero create/settle cost).
 *
 * Note: this engine currently skips `finally` when `return` is used inside the
 * corresponding `try`; cleanup paths below avoid that pattern.
 */
'use strict';

var _nextAsyncId = 1;
var _executionAsyncId = 1;
var _triggerAsyncId = 0;
var _bootstrapResource = Object.create(null);
var _executionAsyncResource = _bootstrapResource;

var _hooks = [];
var _initCount = 0;
var _beforeCount = 0;
var _afterCount = 0;
var _destroyCount = 0;
var _promiseResolveCount = 0;

var _idStack = [];
var _triggerStack = [];
var _resourceStack = [];

var _timersInstrumented = false;
var _nativeSetTimeout = null;
var _nativeSetInterval = null;
var _nativeSetImmediate = null;
var _nativeClearTimeout = null;
var _nativeClearInterval = null;
var _nativeClearImmediate = null;
var _timerMeta = Object.create(null); // tid -> { asyncId, triggerAsyncId, resource, type, destroyed }

var _promisesInstrumented = false;
var _nativePromiseThen = null;
var _nativePromiseResolve = null;
var _nativePromiseReject = null;
var _NativePromise = null;
var _promiseWrapDepth = 0;
var _promiseAsyncIds = typeof WeakMap === 'function' ? new WeakMap() : null;
var _ahDrainDepth = 0;

function _ah() {
    return typeof __asyncHooks !== 'undefined' && __asyncHooks !== null ? __asyncHooks : null;
}

function _nativePromiseHooksOn() {
    var ah = _ah();
    return !!(ah && ah.enabled && ah.enabled());
}

function _syncNativePromiseHookGate() {
    var ah = _ah();
    if (!ah || typeof ah.enable !== 'function') return;
    var on = _hooksOrAlsActive() ? 1 : 0;
    ah.enable(on);
    if (typeof ah.setExecutionAsyncId === 'function') {
        ah.setExecutionAsyncId(_executionAsyncId);
    }
    if (on && typeof ah.peekNextAsyncId === 'function') {
        var peek = ah.peekNextAsyncId();
        if (peek > _nextAsyncId) _nextAsyncId = peek - 1;
    }
}

function _syncNativeExecId() {
    var ah = _ah();
    if (ah && typeof ah.setExecutionAsyncId === 'function') {
        ah.setExecutionAsyncId(_executionAsyncId);
    }
}

function _nativePromiseAsyncId(p) {
    var ah = _ah();
    if (!ah || typeof ah.promiseAsyncId !== 'function') return 0;
    var id = ah.promiseAsyncId(p);
    return id | 0;
}

function _drainNativePromiseHooks() {
    var ah = _ah();
    if (!ah || !_nativePromiseHooksOn()) return;
    if (_ahDrainDepth > 0) return;
    _ahDrainDepth += 1;
    try {
        if (typeof ah.drainInit === 'function') {
            var initEv = ah.drainInit();
            var i = 0;
            while (initEv && i + 2 < initEv.length) {
                var aid = initEv[i] | 0;
                var tid = initEv[i + 1] | 0;
                var prom = initEv[i + 2];
                i += 3;
                if (aid > _nextAsyncId) _nextAsyncId = aid;
                // JS `.then` may already have tracked with the correct parent
                // triggerId; skip native init to avoid wrong trigger / double-fire.
                if (_promiseAsyncIds && _promiseAsyncIds.has(prom)) {
                    continue;
                }
                _trackPromise(prom, aid);
                var parentResource = _executionAsyncResource;
                var ai = 0;
                while (ai < _alsList.length) {
                    try {
                        _alsList[ai]._propagate(prom, parentResource, 'PROMISE');
                    } catch (_e) { /* ignore */ }
                    ai += 1;
                }
                emitInit(aid, 'PROMISE', tid, prom);
            }
        }
        if (typeof ah.drainResolve === 'function') {
            var resEv = ah.drainResolve();
            var ri = 0;
            while (resEv && ri < resEv.length) {
                emitPromiseResolve(resEv[ri] | 0);
                ri += 1;
            }
        }
    } finally {
        _ahDrainDepth -= 1;
    }
}

// Provider type integers (Node.js async_wrap.Providers; Node ≥20 values)
var asyncWrapProviders = Object.freeze({
    __proto__: null,
    NONE: 0,
    DIRHANDLE: 1,
    DNSCHANNEL: 2,
    ELDHISTOGRAM: 3,
    FILEHANDLE: 4,
    FILEHANDLECLOSEREQ: 5,
    BLOBREADER: 6,
    FSEVENTWRAP: 7,
    FSREQCALLBACK: 8,
    FSREQPROMISE: 9,
    GETADDRINFOREQWRAP: 10,
    GETNAMEINFOREQWRAP: 11,
    HEAPSNAPSHOT: 12,
    HTTP2SESSION: 13,
    HTTP2STREAM: 14,
    HTTP2PING: 15,
    HTTP2SETTINGS: 16,
    HTTPINCOMINGMESSAGE: 17,
    HTTPCLIENTREQUEST: 18,
    LOCKS: 19,
    JSSTREAM: 20,
    JSUDPWRAP: 21,
    MESSAGEPORT: 22,
    PIPECONNECTWRAP: 23,
    PIPESERVERWRAP: 24,
    PIPEWRAP: 25,
    PROCESSWRAP: 26,
    PROMISE: 27,
    QUERYWRAP: 28,
    QUIC_ENDPOINT: 29,
    QUIC_LOGSTREAM: 30,
    QUIC_PACKET: 31,
    QUIC_SESSION: 32,
    QUIC_STREAM: 33,
    QUIC_UDP: 34,
    SHUTDOWNWRAP: 35,
    SIGNALWRAP: 36,
    STATWATCHER: 37,
    STREAMPIPE: 38,
    TCPCONNECTWRAP: 39,
    TCPSERVERWRAP: 40,
    TCPWRAP: 41,
    TTYWRAP: 42,
    UDPSENDWRAP: 43,
    UDPWRAP: 44,
    SIGINTWATCHDOG: 45,
    WORKER: 46,
    WORKERCPUPROFILE: 47,
    WORKERCPUUSAGE: 48,
    WORKERHEAPPROFILE: 49,
    WORKERHEAPSNAPSHOT: 50,
    WORKERHEAPSTATISTICS: 51,
    WRITEWRAP: 52,
    ZLIB: 53,
    CHECKPRIMEREQUEST: 54,
    PBKDF2REQUEST: 55,
    KEYPAIRGENREQUEST: 56,
    KEYGENREQUEST: 57,
    KEYEXPORTREQUEST: 58,
    ARGON2REQUEST: 59,
    CIPHERREQUEST: 60,
    DERIVEBITSREQUEST: 61,
    HASHREQUEST: 62,
    RANDOMBYTESREQUEST: 63,
    RANDOMPRIMEREQUEST: 64,
    SCRYPTREQUEST: 65,
    SIGNREQUEST: 66,
    TLSWRAP: 67,
    VERIFYREQUEST: 68,
    // Legacy aliases still referenced by older docs/tests
    TIMERWRAP: 69,
    Timeout: 70,
    Immediate: 71
});

function _errAsyncCallback(name) {
    var err = new TypeError('hook.' + name + ' must be a function');
    err.code = 'ERR_ASYNC_CALLBACK';
    return err;
}

function _errAsyncType(type) {
    var err = new TypeError('Invalid async type: ' + type);
    err.code = 'ERR_ASYNC_TYPE';
    return err;
}

function _errInvalidAsyncId(name, value) {
    var err = new RangeError('Invalid ' + name + ' value: ' + value);
    err.code = 'ERR_INVALID_ASYNC_ID';
    return err;
}

function _errInvalidArgType(name, expected, actual) {
    var err = new TypeError(
        'The "' + name + '" argument must be of type ' + expected +
        '. Received ' + actual
    );
    err.code = 'ERR_INVALID_ARG_TYPE';
    return err;
}

function newAsyncId() {
    var ah = _ah();
    if (ah && typeof ah.peekNextAsyncId === 'function' && _nativePromiseHooksOn()) {
        var peek = ah.peekNextAsyncId();
        if (peek > _nextAsyncId) _nextAsyncId = peek - 1;
    }
    _nextAsyncId += 1;
    return _nextAsyncId;
}

function executionAsyncId() {
    return _executionAsyncId;
}

function triggerAsyncId() {
    return _triggerAsyncId;
}

function executionAsyncResource() {
    return _executionAsyncResource;
}

function initHooksExist() {
    return _initCount > 0;
}

function destroyHooksExist() {
    return _destroyCount > 0;
}

function emitInit(asyncId, type, triggerId, resource) {
    if (_initCount === 0) return;
    var i = 0;
    while (i < _hooks.length) {
        var h = _hooks[i];
        if (typeof h._init === 'function') {
            h._init(asyncId, type, triggerId, resource);
        }
        i += 1;
    }
}

function emitBefore(asyncId, triggerId, resource) {
    _drainNativePromiseHooks();
    _idStack.push(_executionAsyncId);
    _triggerStack.push(_triggerAsyncId);
    _resourceStack.push(_executionAsyncResource);
    _executionAsyncId = asyncId;
    _triggerAsyncId = triggerId;
    if (resource !== undefined && resource !== null) {
        _executionAsyncResource = resource;
    }
    _syncNativeExecId();
    if (_beforeCount === 0) return;
    var i = 0;
    while (i < _hooks.length) {
        var h = _hooks[i];
        if (typeof h._before === 'function') {
            h._before(asyncId);
        }
        i += 1;
    }
}

function emitAfter(asyncId) {
    _drainNativePromiseHooks();
    if (_afterCount > 0) {
        var i = 0;
        while (i < _hooks.length) {
            var h = _hooks[i];
            if (typeof h._after === 'function') {
                h._after(asyncId);
            }
            i += 1;
        }
    }
    if (_idStack.length > 0) {
        _executionAsyncId = _idStack.pop();
        _triggerAsyncId = _triggerStack.pop();
        _executionAsyncResource = _resourceStack.pop();
    }
    _syncNativeExecId();
}

function emitDestroy(asyncId) {
    if (_destroyCount === 0) return;
    var i = 0;
    while (i < _hooks.length) {
        var h = _hooks[i];
        if (typeof h._destroy === 'function') {
            h._destroy(asyncId);
        }
        i += 1;
    }
}

function emitPromiseResolve(asyncId) {
    if (_promiseResolveCount === 0) return;
    var i = 0;
    while (i < _hooks.length) {
        var h = _hooks[i];
        if (typeof h._promiseResolve === 'function') {
            h._promiseResolve(asyncId);
        }
        i += 1;
    }
}

function createHook(callbacks) {
    if (callbacks === undefined || callbacks === null || typeof callbacks !== 'object') {
        throw _errInvalidArgType('callbacks', 'object', callbacks);
    }
    var init = callbacks.init;
    var before = callbacks.before;
    var after = callbacks.after;
    var destroy = callbacks.destroy;
    var promiseResolve = callbacks.promiseResolve;

    if (init !== undefined && typeof init !== 'function') {
        throw _errAsyncCallback('init');
    }
    if (before !== undefined && typeof before !== 'function') {
        throw _errAsyncCallback('before');
    }
    if (after !== undefined && typeof after !== 'function') {
        throw _errAsyncCallback('after');
    }
    if (destroy !== undefined && typeof destroy !== 'function') {
        throw _errAsyncCallback('destroy');
    }
    if (promiseResolve !== undefined && typeof promiseResolve !== 'function') {
        throw _errAsyncCallback('promiseResolve');
    }

    var hook = {
        _init: init,
        _before: before,
        _after: after,
        _destroy: destroy,
        _promiseResolve: promiseResolve,
        _enabled: false
    };

    hook.enable = function enable() {
        if (hook._enabled) return hook;
        hook._enabled = true;
        _hooks.push(hook);
        if (init) _initCount += 1;
        if (before) _beforeCount += 1;
        if (after) _afterCount += 1;
        if (destroy) _destroyCount += 1;
        if (promiseResolve) _promiseResolveCount += 1;
        _ensureTimersInstrumented();
        _ensurePromisesInstrumented();
        _syncNativePromiseHookGate();
        _drainNativePromiseHooks();
        return hook;
    };

    hook.disable = function disable() {
        if (!hook._enabled) return hook;
        hook._enabled = false;
        var idx = _hooks.indexOf(hook);
        if (idx !== -1) _hooks.splice(idx, 1);
        if (init) _initCount -= 1;
        if (before) _beforeCount -= 1;
        if (after) _afterCount -= 1;
        if (destroy) _destroyCount -= 1;
        if (promiseResolve) _promiseResolveCount -= 1;
        _syncNativePromiseHookGate();
        return hook;
    };

    return hook;
}

function AsyncResource(type, opts) {
    if (!(this instanceof AsyncResource)) {
        return new AsyncResource(type, opts);
    }
    if (typeof type !== 'string') {
        throw _errInvalidArgType('type', 'string', type);
    }

    var triggerId;
    var requireManualDestroy = false;
    if (opts === undefined || opts === null) {
        triggerId = _executionAsyncId;
    } else if (typeof opts === 'number') {
        triggerId = opts;
    } else if (typeof opts === 'object') {
        triggerId = opts.triggerAsyncId === undefined ? _executionAsyncId : opts.triggerAsyncId;
        requireManualDestroy = !!opts.requireManualDestroy;
    } else {
        triggerId = opts;
    }

    if (typeof triggerId !== 'number' || !isFinite(triggerId) ||
        Math.floor(triggerId) !== triggerId || triggerId < -1) {
        throw _errInvalidAsyncId('triggerAsyncId', triggerId);
    }

    var asyncId = newAsyncId();
    this._asyncId = asyncId;
    this._triggerAsyncId = triggerId;
    this._destroyed = false;
    this._requireManualDestroy = requireManualDestroy;

    if (initHooksExist()) {
        if (type.length === 0) {
            throw _errAsyncType(type);
        }
        emitInit(asyncId, type, triggerId, this);
    }
}

AsyncResource.prototype.runInAsyncScope = function runInAsyncScope(fn, thisArg) {
    if (typeof fn !== 'function') {
        throw _errInvalidArgType('fn', 'function', fn);
    }
    var args = [];
    var i = 2;
    while (i < arguments.length) {
        args.push(arguments[i]);
        i += 1;
    }
    var asyncId = this._asyncId;
    emitBefore(asyncId, this._triggerAsyncId, this);
    var result;
    var err = null;
    try {
        if (args.length === 0) result = fn.call(thisArg);
        else if (args.length === 1) result = fn.call(thisArg, args[0]);
        else if (args.length === 2) result = fn.call(thisArg, args[0], args[1]);
        else if (args.length === 3) result = fn.call(thisArg, args[0], args[1], args[2]);
        else result = fn.apply(thisArg, args);
    } catch (e) {
        err = e;
    }
    emitAfter(asyncId);
    if (err !== null) throw err;
    return result;
};

AsyncResource.prototype.emitDestroy = function emitDestroyFn() {
    if (this._destroyed) return this;
    this._destroyed = true;
    emitDestroy(this._asyncId);
    return this;
};

AsyncResource.prototype.asyncId = function asyncId() {
    return this._asyncId;
};

AsyncResource.prototype.triggerAsyncId = function triggerAsyncIdFn() {
    return this._triggerAsyncId;
};

AsyncResource.prototype.bind = function bind(fn, thisArg) {
    if (typeof fn !== 'function') {
        throw _errInvalidArgType('fn', 'function', fn);
    }
    var resource = this;
    var bound;
    if (thisArg === undefined) {
        bound = function () {
            var args = [fn, this];
            var i = 0;
            while (i < arguments.length) {
                args.push(arguments[i]);
                i += 1;
            }
            return resource.runInAsyncScope.apply(resource, args);
        };
    } else {
        bound = function () {
            var args = [fn, thisArg];
            var i = 0;
            while (i < arguments.length) {
                args.push(arguments[i]);
                i += 1;
            }
            return resource.runInAsyncScope.apply(resource, args);
        };
    }
    bound.asyncResource = resource;
    return bound;
};

AsyncResource.bind = function staticBind(fn, type, thisArg) {
    if (typeof fn !== 'function') {
        throw _errInvalidArgType('fn', 'function', fn);
    }
    var t = type;
    if (t === undefined || t === null || t === '') {
        t = fn.name || 'bound-anonymous-fn';
    }
    return (new AsyncResource(t)).bind(fn, thisArg);
};

// ── AsyncLocalStorage (resource-store CLS, Node-compatible shape) ───────────

var _alsList = [];
var _alsHook = null;

function AsyncLocalStorage(options) {
    if (!(this instanceof AsyncLocalStorage)) {
        return new AsyncLocalStorage(options);
    }
    this.kResourceStore = Symbol('kResourceStore');
    this.enabled = false;
    this._defaultValue = undefined;
    this._name = undefined;
    if (options !== undefined && options !== null && typeof options === 'object') {
        if (options.defaultValue !== undefined) {
            this._defaultValue = options.defaultValue;
        }
        if (options.name !== undefined) {
            this._name = String(options.name);
        }
    }
    this._enable();
}

Object.defineProperty(AsyncLocalStorage.prototype, 'name', {
    get: function () {
        return this._name || '';
    },
    enumerable: true,
    configurable: true
});

AsyncLocalStorage.bind = function (fn) {
    return AsyncResource.bind(fn);
};

AsyncLocalStorage.snapshot = function () {
    return AsyncLocalStorage.bind(function (cb) {
        var args = [];
        var i = 1;
        while (i < arguments.length) {
            args.push(arguments[i]);
            i += 1;
        }
        return cb.apply(null, args);
    });
};

AsyncLocalStorage.prototype.disable = function disable() {
    if (!this.enabled) return;
    this.enabled = false;
    var idx = _alsList.indexOf(this);
    if (idx !== -1) _alsList.splice(idx, 1);
    if (_alsList.length === 0 && _alsHook) {
        _alsHook.disable();
    }
    _syncNativePromiseHookGate();
};

AsyncLocalStorage.prototype._enable = function _enable() {
    if (this.enabled) return;
    this.enabled = true;
    _alsList.push(this);
    if (!_alsHook) {
        _alsHook = createHook({
            init: function (asyncId, type, triggerAsyncId, resource) {
                var current = executionAsyncResource();
                var i = 0;
                while (i < _alsList.length) {
                    _alsList[i]._propagate(resource, current, type);
                    i += 1;
                }
            }
        });
    }
    _alsHook.enable();
    _ensurePromisesInstrumented();
    _syncNativePromiseHookGate();
    _drainNativePromiseHooks();
};

AsyncLocalStorage.prototype._propagate = function _propagate(resource, triggerResource) {
    if (!this.enabled) return;
    if (triggerResource && (this.kResourceStore in triggerResource)) {
        resource[this.kResourceStore] = triggerResource[this.kResourceStore];
    }
};

AsyncLocalStorage.prototype.enterWith = function enterWith(store) {
    this._enable();
    var resource = executionAsyncResource();
    resource[this.kResourceStore] = store;
};

AsyncLocalStorage.prototype.run = function run(store, callback) {
    if (typeof callback !== 'function') {
        throw _errInvalidArgType('callback', 'function', callback);
    }
    var args = [];
    var i = 2;
    while (i < arguments.length) {
        args.push(arguments[i]);
        i += 1;
    }
    if (store === this.getStore()) {
        return callback.apply(null, args);
    }
    this._enable();
    var resource = executionAsyncResource();
    var oldStore = resource[this.kResourceStore];
    var had = (this.kResourceStore in resource);
    resource[this.kResourceStore] = store;
    var result;
    var err = null;
    try {
        result = callback.apply(null, args);
    } catch (e) {
        err = e;
    }
    if (had) {
        resource[this.kResourceStore] = oldStore;
    } else {
        delete resource[this.kResourceStore];
    }
    if (err !== null) throw err;
    return result;
};

AsyncLocalStorage.prototype.exit = function exit(callback) {
    if (typeof callback !== 'function') {
        throw _errInvalidArgType('callback', 'function', callback);
    }
    var args = [];
    var i = 1;
    while (i < arguments.length) {
        args.push(arguments[i]);
        i += 1;
    }
    if (!this.enabled) {
        return callback.apply(null, args);
    }
    this.disable();
    var result;
    var err = null;
    try {
        result = callback.apply(null, args);
    } catch (e) {
        err = e;
    }
    this._enable();
    if (err !== null) throw err;
    return result;
};

AsyncLocalStorage.prototype.getStore = function getStore() {
    if (!this.enabled) return this._defaultValue;
    var resource = executionAsyncResource();
    if (!(this.kResourceStore in resource)) {
        return this._defaultValue;
    }
    return resource[this.kResourceStore];
};

// ── Timer instrumentation ───────────────────────────────────────────────────

function _wrapTimerCallback(meta, originalFn, args) {
    return function timerFire() {
        if (meta.destroyed) {
            if (typeof originalFn === 'function') {
                return originalFn.apply(null, args);
            }
            return;
        }
        emitBefore(meta.asyncId, meta.triggerAsyncId, meta.resource);
        var result;
        var err = null;
        try {
            if (typeof originalFn === 'function') {
                result = originalFn.apply(null, args);
            }
        } catch (e) {
            err = e;
        }
        emitAfter(meta.asyncId);
        if (meta.type !== 'TimeoutInterval') {
            meta.destroyed = true;
            emitDestroy(meta.asyncId);
            if (meta.tid !== undefined) {
                delete _timerMeta[meta.tid];
            }
        }
        if (err !== null) throw err;
        return result;
    };
}

function _hooksOrAlsActive() {
    return _alsList.length > 0 ||
        _initCount > 0 || _beforeCount > 0 || _afterCount > 0 ||
        _destroyCount > 0 || _promiseResolveCount > 0;
}

function _promiseTriggerId(parentPromise) {
    if (_promiseAsyncIds && parentPromise && _promiseAsyncIds.has(parentPromise)) {
        return _promiseAsyncIds.get(parentPromise);
    }
    return _executionAsyncId;
}

function _trackPromise(promise, asyncId) {
    if (_promiseAsyncIds && promise && (typeof promise === 'object' || typeof promise === 'function')) {
        _promiseAsyncIds.set(promise, asyncId);
    }
}

function _initPromiseResource(promise, triggerId) {
    // Prefer native PromiseHook id when present (init emitted via drain).
    // Do NOT track before drain — drain skips already-tracked promises so that
    // `.then` can emit init with the parent triggerId instead of executionAsyncId.
    _syncNativeExecId();
    var nativeId = _nativePromiseAsyncId(promise);
    if (nativeId) {
        if (nativeId > _nextAsyncId) _nextAsyncId = nativeId;
        _drainNativePromiseHooks();
        if (!(_promiseAsyncIds && _promiseAsyncIds.has(promise))) {
            var parentResource = _executionAsyncResource;
            var ai0 = 0;
            while (ai0 < _alsList.length) {
                try {
                    _alsList[ai0]._propagate(promise, parentResource, 'PROMISE');
                } catch (_e0) { /* ignore */ }
                ai0 += 1;
            }
            _trackPromise(promise, nativeId);
            emitInit(nativeId, 'PROMISE', triggerId, promise);
        }
        return nativeId;
    }
    var parentResource = _executionAsyncResource;
    var ai = 0;
    while (ai < _alsList.length) {
        try {
            _alsList[ai]._propagate(promise, parentResource, 'PROMISE');
        } catch (_e) {
            // ignore non-extensible promises
        }
        ai += 1;
    }
    var asyncId = newAsyncId();
    _trackPromise(promise, asyncId);
    emitInit(asyncId, 'PROMISE', triggerId, promise);
    return asyncId;
}

function _ensurePromisesInstrumented() {
    if (_promisesInstrumented) return;
    // Patch the realm Promise in place. Replacing globalThis.Promise alone does
    // not update this engine's global `Promise` binding used by scripts.
    var P = typeof Promise !== 'undefined' ? Promise : globalThis.Promise;
    if (!P || !P.prototype) return;
    _promisesInstrumented = true;
    _NativePromise = P;
    _nativePromiseThen = P.prototype.then;
    _nativePromiseResolve = P.resolve.bind(P);
    _nativePromiseReject = P.reject.bind(P);

    P.resolve = function resolve(value) {
        if (_promiseWrapDepth > 0 || !_hooksOrAlsActive()) {
            return _nativePromiseResolve(value);
        }
        if (value instanceof _NativePromise) {
            return _nativePromiseResolve(value);
        }
        _promiseWrapDepth += 1;
        var p;
        var err = null;
        try {
            p = _nativePromiseResolve(value);
            // Only emit init for a freshly created promise.
            if (!(_promiseAsyncIds && _promiseAsyncIds.has(p))) {
                var asyncId = _initPromiseResource(p, _executionAsyncId);
                if (_nativePromiseHooksOn()) _drainNativePromiseHooks();
                else emitPromiseResolve(asyncId);
            }
        } catch (e) {
            err = e;
        }
        _promiseWrapDepth -= 1;
        if (err !== null) throw err;
        return p;
    };

    P.reject = function reject(reason) {
        if (_promiseWrapDepth > 0 || !_hooksOrAlsActive()) {
            return _nativePromiseReject(reason);
        }
        _promiseWrapDepth += 1;
        var p;
        var err = null;
        try {
            p = _nativePromiseReject(reason);
            var asyncId = _initPromiseResource(p, _executionAsyncId);
            if (_nativePromiseHooksOn()) _drainNativePromiseHooks();
            else emitPromiseResolve(asyncId);
        } catch (e) {
            err = e;
        }
        _promiseWrapDepth -= 1;
        if (err !== null) throw err;
        return p;
    };

    // Best-effort constructor wrap: install on globalThis; also try updating
    // the global binding when the engine allows it.
    function InstrumentedPromise(executor) {
        if (_promiseWrapDepth > 0 || !_hooksOrAlsActive()) {
            return new _NativePromise(executor);
        }
        _promiseWrapDepth += 1;
        var triggerId = _executionAsyncId;
        var asyncId = 0;
        var settled = false;
        var syncSettled = false;
        var p;
        var err = null;
        try {
            p = new _NativePromise(function (resolve, reject) {
                if (typeof executor !== 'function') {
                    executor();
                    return;
                }
                executor(function (value) {
                    if (!settled) {
                        settled = true;
                        if (asyncId) {
                            if (_nativePromiseHooksOn()) _drainNativePromiseHooks();
                            else emitPromiseResolve(asyncId);
                        } else syncSettled = true;
                    }
                    return resolve(value);
                }, function (reason) {
                    if (!settled) {
                        settled = true;
                        if (asyncId) {
                            if (_nativePromiseHooksOn()) _drainNativePromiseHooks();
                            else emitPromiseResolve(asyncId);
                        } else syncSettled = true;
                    }
                    return reject(reason);
                });
            });
            asyncId = _initPromiseResource(p, triggerId);
            if (syncSettled) {
                if (_nativePromiseHooksOn()) _drainNativePromiseHooks();
                else emitPromiseResolve(asyncId);
            }
        } catch (e) {
            err = e;
        }
        _promiseWrapDepth -= 1;
        if (err !== null) throw err;
        return p;
    }
    InstrumentedPromise.prototype = _NativePromise.prototype;
    try { Object.setPrototypeOf(InstrumentedPromise, _NativePromise); } catch (_e) { /* ignore */ }
    InstrumentedPromise.resolve = P.resolve;
    InstrumentedPromise.reject = P.reject;
    var staticNames = ['all', 'race', 'allSettled', 'any', 'withResolvers', 'try'];
    var si = 0;
    while (si < staticNames.length) {
        var sn = staticNames[si];
        if (typeof _NativePromise[sn] === 'function') {
            InstrumentedPromise[sn] = _NativePromise[sn].bind(_NativePromise);
        }
        si += 1;
    }
    globalThis.Promise = InstrumentedPromise;
    try {
        // Some hosts keep a distinct global binding from globalThis.Promise.
        Promise = InstrumentedPromise; // eslint-disable-line no-global-assign
    } catch (_e2) { /* strict / non-configurable */ }

    P.prototype.then = function then(onFulfilled, onRejected) {
        if (_promiseWrapDepth > 0 || !_hooksOrAlsActive()) {
            return _nativePromiseThen.call(this, onFulfilled, onRejected);
        }
        _promiseWrapDepth += 1;
        var result;
        var err = null;
        var triggerId = _promiseTriggerId(this);
        var parentResource = _executionAsyncResource;
        var asyncId = 0;
        var box = { resource: null };
        function wrap(fn) {
            if (typeof fn !== 'function') return fn;
            return function promiseReaction(value) {
                emitBefore(asyncId, triggerId, box.resource);
                var out;
                var e2 = null;
                try {
                    out = fn.call(undefined, value);
                } catch (e) {
                    e2 = e;
                }
                emitAfter(asyncId);
                if (_nativePromiseHooksOn()) _drainNativePromiseHooks();
                else emitPromiseResolve(asyncId);
                if (e2 !== null) throw e2;
                return out;
            };
        }
        try {
            _syncNativeExecId();
            result = _nativePromiseThen.call(this, wrap(onFulfilled), wrap(onRejected));
            box.resource = result;
            // Prefer native async id, but always emit init with the parent
            // promise as trigger (native queue uses executionAsyncId).
            var nativeId = _nativePromiseAsyncId(result);
            asyncId = nativeId || newAsyncId();
            if (nativeId > _nextAsyncId) _nextAsyncId = nativeId;
            var ai = 0;
            while (ai < _alsList.length) {
                try {
                    _alsList[ai]._propagate(result, parentResource, 'PROMISE');
                } catch (_e) { /* ignore */ }
                ai += 1;
            }
            _trackPromise(result, asyncId);
            emitInit(asyncId, 'PROMISE', triggerId, result);
            _drainNativePromiseHooks();
        } catch (e) {
            err = e;
        }
        _promiseWrapDepth -= 1;
        if (err !== null) throw err;
        return result;
    };

    P.prototype.catch = function (onRejected) {
        return this.then(undefined, onRejected);
    };

    P.prototype.finally = function (onFinally) {
        if (typeof onFinally !== 'function') {
            return this.then(onFinally, onFinally);
        }
        return this.then(
            function (value) {
                return P.resolve(onFinally()).then(function () { return value; });
            },
            function (reason) {
                return P.resolve(onFinally()).then(function () {
                    throw reason;
                });
            }
        );
    };
}

function _ensureTimersInstrumented() {
    if (_timersInstrumented) return;
    _timersInstrumented = true;

    _nativeSetTimeout = globalThis.setTimeout;
    _nativeSetInterval = globalThis.setInterval;
    _nativeSetImmediate = globalThis.setImmediate;
    _nativeClearTimeout = globalThis.clearTimeout;
    _nativeClearInterval = globalThis.clearInterval;
    _nativeClearImmediate = globalThis.clearImmediate;

    globalThis.setTimeout = function setTimeout(fn, delay) {
        var extras = [];
        var i = 2;
        while (i < arguments.length) {
            extras.push(arguments[i]);
            i += 1;
        }
        if (!initHooksExist() && !destroyHooksExist() && _beforeCount === 0 && _afterCount === 0) {
            return _nativeSetTimeout.apply(globalThis, arguments);
        }
        var resource = Object.create(null);
        var asyncId = newAsyncId();
        var triggerId = _executionAsyncId;
        // Propagate ALS
        var current = _executionAsyncResource;
        var ai = 0;
        while (ai < _alsList.length) {
            _alsList[ai]._propagate(resource, current, 'Timeout');
            ai += 1;
        }
        emitInit(asyncId, 'Timeout', triggerId, resource);
        var meta = {
            asyncId: asyncId,
            triggerAsyncId: triggerId,
            resource: resource,
            type: 'Timeout',
            destroyed: false
        };
        var wrapped = _wrapTimerCallback(meta, fn, extras);
        var tid = _nativeSetTimeout(wrapped, delay);
        meta.tid = tid;
        _timerMeta[tid] = meta;
        return tid;
    };

    globalThis.setInterval = function setInterval(fn, delay) {
        var extras = [];
        var i = 2;
        while (i < arguments.length) {
            extras.push(arguments[i]);
            i += 1;
        }
        if (!initHooksExist() && !destroyHooksExist() && _beforeCount === 0 && _afterCount === 0) {
            return _nativeSetInterval.apply(globalThis, arguments);
        }
        var resource = Object.create(null);
        var asyncId = newAsyncId();
        var triggerId = _executionAsyncId;
        var current = _executionAsyncResource;
        var ai = 0;
        while (ai < _alsList.length) {
            _alsList[ai]._propagate(resource, current, 'Timeout');
            ai += 1;
        }
        emitInit(asyncId, 'Timeout', triggerId, resource);
        var meta = {
            asyncId: asyncId,
            triggerAsyncId: triggerId,
            resource: resource,
            type: 'TimeoutInterval',
            destroyed: false
        };
        var wrapped = _wrapTimerCallback(meta, fn, extras);
        var tid = _nativeSetInterval(wrapped, delay);
        meta.tid = tid;
        _timerMeta[tid] = meta;
        return tid;
    };

    globalThis.setImmediate = function setImmediate(fn) {
        var extras = [];
        var i = 1;
        while (i < arguments.length) {
            extras.push(arguments[i]);
            i += 1;
        }
        if (!initHooksExist() && !destroyHooksExist() && _beforeCount === 0 && _afterCount === 0) {
            return _nativeSetImmediate.apply(globalThis, arguments);
        }
        var resource = Object.create(null);
        var asyncId = newAsyncId();
        var triggerId = _executionAsyncId;
        var current = _executionAsyncResource;
        var ai = 0;
        while (ai < _alsList.length) {
            _alsList[ai]._propagate(resource, current, 'Immediate');
            ai += 1;
        }
        emitInit(asyncId, 'Immediate', triggerId, resource);
        var meta = {
            asyncId: asyncId,
            triggerAsyncId: triggerId,
            resource: resource,
            type: 'Immediate',
            destroyed: false
        };
        var wrapped = _wrapTimerCallback(meta, fn, extras);
        var tid = _nativeSetImmediate(wrapped);
        meta.tid = tid;
        _timerMeta[tid] = meta;
        return tid;
    };

    function _clearWithDestroy(nativeClear, id) {
        var meta = _timerMeta[id];
        if (meta && !meta.destroyed) {
            meta.destroyed = true;
            emitDestroy(meta.asyncId);
            delete _timerMeta[id];
        }
        return nativeClear(id);
    }

    globalThis.clearTimeout = function clearTimeout(id) {
        return _clearWithDestroy(_nativeClearTimeout, id);
    };
    globalThis.clearInterval = function clearInterval(id) {
        return _clearWithDestroy(_nativeClearInterval, id);
    };
    globalThis.clearImmediate = function clearImmediate(id) {
        return _clearWithDestroy(_nativeClearImmediate, id);
    };
}

// Eagerly wrap timers/promises so require order doesn't matter once loaded.
_ensureTimersInstrumented();
_ensurePromisesInstrumented();

module.exports = {
    createHook: createHook,
    executionAsyncId: executionAsyncId,
    triggerAsyncId: triggerAsyncId,
    executionAsyncResource: executionAsyncResource,
    asyncWrapProviders: asyncWrapProviders,
    constants: asyncWrapProviders,
    AsyncResource: AsyncResource,
    AsyncLocalStorage: AsyncLocalStorage,
    // Internal helpers (tests / embedders)
    newAsyncId: newAsyncId,
    emitInit: emitInit,
    emitBefore: emitBefore,
    emitAfter: emitAfter,
    emitDestroy: emitDestroy,
    emitPromiseResolve: emitPromiseResolve
};
