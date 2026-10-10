// ────────────────────────────────────────────────────────────────────────────
// builtins/js/stream.js — Node.js v24 `node:stream` public API
//
// Pure JavaScript implementation of Readable, Writable, Duplex, Transform,
// PassThrough, pipeline, finished, compose, duplexPair, and web interop.
// Loaded by `require("stream")` / `require("node:stream")`.
//
// Node.js reference: https://nodejs.org/docs/latest-v24.x/api/stream.html
// ────────────────────────────────────────────────────────────────────────────

var EventEmitter = require("events").EventEmitter;

// ── Utilities ───────────────────────────────────────────────────────────────

var defaultHighWaterMarkBytes = 16384;
var defaultHighWaterMarkObjects = 16;

function nextTick(fn) {
    if (typeof process !== "undefined" && typeof process.nextTick === "function") {
        process.nextTick(fn);
    } else {
        setTimeout(fn, 0);
    }
}

function getDefaultHighWaterMark(objectMode) {
    return objectMode ? defaultHighWaterMarkObjects : defaultHighWaterMarkBytes;
}

function setDefaultHighWaterMark(objectMode, value) {
    if (objectMode) {
        defaultHighWaterMarkObjects = value;
    } else {
        defaultHighWaterMarkBytes = value;
    }
}

function normalizeEncoding(enc) {
    if (enc == null || enc === "") { return null; }
    var e = String(enc).toLowerCase();
    if (e === "utf8" || e === "utf-8") { return "utf8"; }
    if (e === "ascii" || e === "latin1" || e === "binary") { return e; }
    if (e === "base64" || e === "hex" || e === "utf16le") { return e; }
    return "utf8";
}

function chunkByteLength(chunk, encoding) {
    if (chunk == null) { return 0; }
    if (typeof chunk === "string") {
        if (encoding === "utf8" || encoding == null) {
            // Approximate byte length for backpressure (Buffer may be absent).
            var len = 0;
            for (var i = 0; i < chunk.length; i = i + 1) {
                var c = chunk.charCodeAt(i);
                if (c <= 0x7f) { len = len + 1; }
                else if (c <= 0x7ff) { len = len + 2; }
                else if (c >= 0xd800 && c <= 0xdbff) { len = len + 4; i = i + 1; }
                else { len = len + 3; }
            }
            return len;
        }
        return chunk.length;
    }
    if (typeof chunk === "object" && chunk !== null) {
        if (typeof chunk.length === "number") { return chunk.length; }
        if (typeof chunk.byteLength === "number") { return chunk.byteLength; }
    }
    return 1;
}

function isIterable(obj) {
    return obj != null && typeof obj[Symbol.iterator] === "function";
}

function isAsyncIterable(obj) {
    return obj != null && typeof obj[Symbol.asyncIterator] === "function";
}

function callListener(stream, name, arg1, arg2) {
    if (typeof stream.emit === "function") {
        if (arg2 !== undefined) {
            stream.emit(name, arg1, arg2);
        } else if (arg1 !== undefined) {
            stream.emit(name, arg1);
        } else {
            stream.emit(name);
        }
    }
}

function destroyer(stream, err, callback) {
    if (!stream || stream.destroyed) {
        if (typeof callback === "function") { nextTick(callback); }
        return;
    }
    if (typeof stream.destroy === "function") {
        stream.destroy(err, callback);
    } else if (typeof callback === "function") {
        nextTick(callback);
    }
}

// ── Readable state ────────────────────────────────────────────────────────────

function ReadableState(options, stream) {
    this.objectMode = !!(options && options.objectMode);
    this.highWaterMark = options && options.highWaterMark != null
        ? options.highWaterMark
        : getDefaultHighWaterMark(this.objectMode);
    this.buffer = [];
    this.length = 0;
    this.ended = false;
    this.endEmitted = false;
    this.reading = false;
    this.sync = true;
    this.needReadable = false;
    this.emittedReadable = false;
    this.readableListening = false;
    this.resumeScheduled = false;
    this.paused = true;
    this.flowing = null;
    this.destroyed = false;
    this.closed = false;
    this.errored = null;
    this.defaultEncoding = (options && options.defaultEncoding) || "utf8";
    this.encoding = null;
    this.decoder = null;
    this.awaitDrainWriters = null;
    this.pipes = null;
    this.pipesCount = 0;
    this.stream = stream;
}

function computeNewLength(state, chunk) {
    if (state.objectMode) {
        return state.length + 1;
    }
    return state.length + chunkByteLength(chunk, state.encoding);
}

function readableAddChunk(stream, chunk, addToFront) {
    var state = stream._readableState;
    if (state.destroyed) { return false; }
    if (chunk === null) {
        onEofChunk(stream, state);
        return false;
    }
    if (state.objectMode || chunk != null) {
        if (!state.objectMode && typeof chunk !== "string" && !Bufferish(chunk)) {
            // Coerce to string-ish for non-objectMode when not buffer-like.
        }
        if (state.encoding && typeof chunk === "string" && state.decoder) {
            try {
                var StringDecoder = require("string_decoder").StringDecoder;
                if (!(state.decoder instanceof StringDecoder)) {
                    state.decoder = new StringDecoder(state.encoding);
                }
                chunk = state.decoder.write(chunk);
                if (chunk === "") { return true; }
            } catch (e) {
                errorOrDestroy(stream, e);
                return false;
            }
        }
        if (addToFront) {
            state.buffer.unshift(chunk);
        } else {
            state.buffer.push(chunk);
        }
        state.length = computeNewLength(state, chunk);
    }
    if (state.ended && !state.endEmitted) {
        onEofChunk(stream, state);
    }
    if (state.flowing) {
        flow(stream);
        // Node's maybeReadMore loop: an async _read implementation (fs
        // streams) pushes from a callback with reading=false; once flow()
        // drains the chunk nothing else re-arms _read, so push(null)/EOF is
        // never reached and 'end' never fires. Re-arm on next tick.
        if (!state.ended && !state.readMoreScheduled &&
            state.length < state.highWaterMark) {
            state.readMoreScheduled = true;
            nextTick(function() {
                state.readMoreScheduled = false;
                if (state.flowing && !state.ended && !state.destroyed &&
                    !state.reading) {
                    stream.read(0);
                }
            });
        }
    }
    return needMoreData(state);
}

function needMoreData(state) {
    return !state.ended && (state.length < state.highWaterMark || state.length === 0);
}

function onEofChunk(stream, state) {
    if (state.ended) { return; }
    state.ended = true;
    stream.readable = false;
    if (state.flowing) {
        flow(stream);
    } else if (state.length === 0) {
        emitReadable(stream);
    } else {
        state.needReadable = true;
    }
}

function emitReadable(stream) {
    var state = stream._readableState;
    if (!state.needReadable && !state.emittedReadable) { return; }
    state.needReadable = false;
    if (!state.emittedReadable) {
        state.emittedReadable = true;
        nextTick(function() { emitReadable_(stream); });
    }
}

function emitReadable_(stream) {
    var state = stream._readableState;
    if (!state.emittedReadable) { return; }
    state.emittedReadable = false;
    stream.emit("readable");
    maybeReadMore(stream, state);
}

function maybeReadMore(stream, state) {
    if (!state.reading && !state.ended && state.length < state.highWaterMark) {
        stream.read(0);
    }
}

function flow(stream) {
    var state = stream._readableState;
    while (state.flowing && state.buffer.length > 0) {
        var chunk = state.buffer.shift();
        state.length = state.objectMode ? Math.max(0, state.length - 1)
            : Math.max(0, state.length - chunkByteLength(chunk, state.encoding));
        stream.emit("data", chunk);
    }
    if (state.buffer.length === 0 && state.ended && !state.endEmitted) {
        state.endEmitted = true;
        nextTick(function() {
            if (state.destroyed) { return; }
            stream.emit("end");
            if (state.autoDestroy) {
                stream.destroy();
            }
        });
    }
}

function endReadable(stream) {
    var state = stream._readableState;
    state.ended = true;
    stream.readable = false;
    if (state.length === 0) {
        state.endEmitted = true;
        stream.emit("end");
    } else {
        emitReadable(stream);
    }
}

function errorOrDestroy(stream, err, sync) {
    var state = stream._readableState || stream._writableState;
    if (!err) { return; }
    if (state) { state.errored = err; }
    if (stream._writableState) { stream._writableState.errored = err; }
    if (stream._readableState) { stream._readableState.errored = err; }
    if (sync) {
        stream.emit("error", err);
    } else {
        nextTick(function() { stream.emit("error", err); });
    }
    destroy(stream, err);
}

function destroy(stream, err, cb) {
    var rState = stream._readableState;
    var wState = stream._writableState;
    if (stream.destroyed) {
        if (typeof cb === "function") { nextTick(cb, err); }
        return stream;
    }
    stream.destroyed = true;
    if (rState) {
        rState.destroyed = true;
        rState.closed = false;
        stream.readable = false;
    }
    if (wState) {
        wState.destroyed = true;
        wState.closed = false;
        stream.writable = false;
    }
    if (err) {
        if (rState) { rState.errored = err; }
        if (wState) { wState.errored = err; }
        nextTick(function() {
            var n = 0;
            if (typeof stream.listenerCount === "function") {
                n = stream.listenerCount("error");
            }
            if (n > 0) {
                stream.emit("error", err);
            }
        });
    }
    var closed = false;
    function onClose() {
        if (closed) { return; }
        closed = true;
        if (rState) { rState.closed = true; }
        if (wState) { wState.closed = true; }
        stream.emit("close");
        if (typeof cb === "function") { cb(err); }
    }
    nextTick(onClose);
    return stream;
}

function Bufferish(chunk) {
    return chunk != null && (
        (typeof Buffer !== "undefined" && Buffer.isBuffer && Buffer.isBuffer(chunk)) ||
        (typeof chunk === "object" && (typeof chunk.length === "number" || typeof chunk.byteLength === "number"))
    );
}

// ── Writable state ──────────────────────────────────────────────────────────────

function WritableState(options, stream) {
    this.objectMode = !!(options && options.objectMode);
    this.highWaterMark = options && options.highWaterMark != null
        ? options.highWaterMark
        : getDefaultHighWaterMark(this.objectMode);
    this.buffer = [];
    this.length = 0;
    this.ended = false;
    this.ending = false;
    this.finished = false;
    this.finalCalled = false;
    this.prefinished = false;
    this.errorEmitted = false;
    this.writelen = 0;
    this.corked = 0;
    this.sync = true;
    this.writelen = 0;
    this.pendingcb = 0;
    this.writing = false;
    this.destroyed = false;
    this.closed = false;
    this.errored = null;
    this.defaultEncoding = (options && options.defaultEncoding) || "utf8";
    this.decodeStrings = !(options && options.decodeStrings === false);
    this.stream = stream;
}

function writableNeedDrain(state) {
    return state.ending || state.finished || state.corked !== 0 ||
        (state.length >= state.highWaterMark && state.highWaterMark > 0);
}

function clearBuffer(stream, state) {
    while (state.buffer.length > 0 && !state.writing) {
        var entry = state.buffer.shift();
        var chunk = entry.chunk;
        var encoding = entry.encoding;
        var cb = entry.callback;
        state.length = state.objectMode
            ? Math.max(0, state.length - 1)
            : Math.max(0, state.length - chunkByteLength(chunk, encoding));
        doWrite(stream, state, false, chunk, encoding, cb);
    }
}

function doWrite(stream, state, writev, chunk, encoding, cb) {
    state.writing = true;
    state.sync = true;
    var ret = false;
    try {
        if (writev && typeof stream._writev === "function") {
            stream._writev(state.buffer, state.onwrite);
            state.buffer = [];
            state.length = 0;
        } else if (typeof stream._write === "function") {
            ret = stream._write(chunk, encoding, state.onwrite);
        } else {
            throw new Error("_write is not implemented");
        }
    } catch (err) {
        state.onwrite(err);
        return;
    }
    state.writelen = state.objectMode ? 1 : chunkByteLength(chunk, encoding);
    if (ret !== false) {
        state.pendingcb = state.pendingcb + 1;
    }
    state.sync = false;
    if (state.destroyed) { return; }
    if (ret === false) {
        state.buffer.unshift({ chunk: chunk, encoding: encoding, callback: cb });
        state.length = computeNewLength(state, chunk);
        onWriteDrain(stream, state);
    }
}

function onWriteDrain(stream, state) {
    if (writableNeedDrain(state)) {
        state.stream.emit("drain");
    }
}

function onwrite(stream, state, err) {
    var cb = state.writecb;
    state.writing = false;
    state.writecb = null;
    if (!state || !stream) { return; }
    if (err) {
        errorOrDestroy(stream, err);
        if (cb) { cb(err); }
        return;
    }
    state.pendingcb = state.pendingcb - 1;
    if (cb) { cb(); }
    finishMaybe(stream, state);
    clearBuffer(stream, state);
    if (!state.writing && !state.corked && !writableNeedDrain(state)) {
        stream.emit("drain");
    }
}

function finishMaybe(stream, state) {
    if (state.ending && state.pendingcb === 0 && state.buffer.length === 0 && !state.finished) {
        state.prefinished = true;
        stream.emit("prefinish");
        prefinish(stream, state);
    }
}

function prefinish(stream, state) {
    if (typeof stream._final === "function" && !state.finalCalled) {
        state.finalCalled = true;
        stream._final(function(err) {
            if (err) {
                errorOrDestroy(stream, err);
                return;
            }
            state.prefinished = true;
            stream.emit("prefinish");
            finish(stream, state);
        });
    } else {
        finish(stream, state);
    }
}

function finish(stream, state) {
    state.finished = true;
    state.closed = false;
    stream.emit("finish");
    if (state.errorEmitted || state.destroyed) { return; }
    state.closed = true;
    nextTick(function() {
        state.closed = true;
        stream.emit("close");
        if (state.autoDestroy) {
            destroy(stream);
        }
    });
}

// ── Readable ──────────────────────────────────────────────────────────────────

function Readable(options) {
    if (!(this instanceof Readable)) {
        return new Readable(options);
    }
    EventEmitter.init.call(this);
    options = options || {};
    this._readableState = new ReadableState(options, this);
    // Node sets these as own, assignable instance properties (not getters).
    this.readable = true;
    this.destroyed = false;
    // Stream hooks are own properties ONLY when passed as options (Node): an
    // unconditional own default shadowed the _read/_write/_final/... that a
    // subclass (ES class or util.inherits) defines on its prototype, so those
    // never ran — e.g. the `ws` library's Receiver._write dropped every frame.
    if (typeof options.read === "function") { this._read = options.read; }
    if (typeof options.destroy === "function") { this._destroy = options.destroy; }
    if (options && options.encoding) {
        this.setEncoding(options.encoding);
    }
    if (options && options.signal) {
        addAbortSignal(options.signal, this);
    }
}

Readable.prototype = Object.create(EventEmitter.prototype);
Readable.prototype.constructor = Readable;

Object.defineProperty(Readable.prototype, "readableEnded", {
    get: function() {
        var state = this._readableState;
        return !!(state && state.ended);
    }
});
Object.defineProperty(Readable.prototype, "readableFlowing", {
    get: function() {
        return this._readableState ? this._readableState.flowing : null;
    }
});
Object.defineProperty(Readable.prototype, "readableHighWaterMark", {
    get: function() {
        var state = this._readableState;
        return state ? state.highWaterMark : 0;
    }
});
Object.defineProperty(Readable.prototype, "readableLength", {
    get: function() {
        var state = this._readableState;
        return state ? state.length : 0;
    }
});
Object.defineProperty(Readable.prototype, "readableObjectMode", {
    get: function() {
        var state = this._readableState;
        return state ? state.objectMode : false;
    }
});
Object.defineProperty(Readable.prototype, "closed", {
    get: function() {
        var r = this._readableState;
        var w = this._writableState;
        if (r && r.closed) { return true; }
        if (w && w.closed) { return true; }
        return false;
    }
});

Readable.prototype.push = function(chunk, encoding) {
    return readableAddChunk(this, chunk, false);
};

Readable.prototype.read = function(n) {
    var state = this._readableState;
    if (state.destroyed) { return null; }
    n = parseInt(n, 10);
    if (isNaN(n) || n < 0) { n = NaN; }
    state.reading = true;
    var ret;
    if (state.buffer.length > 0) {
        if (n === 0 || isNaN(n)) {
            ret = state.buffer.shift();
            state.length = state.objectMode ? Math.max(0, state.length - 1)
                : Math.max(0, state.length - chunkByteLength(ret, state.encoding));
        } else {
            ret = concatBuffer(state, n);
        }
    } else {
        ret = null;
    }
    if (state.needReadable) {
        maybeReadMore(this, state);
    }
    // Node: _read is always asked for highWaterMark, whatever n read() got.
    // Passing n through meant read(0) — the call on('data'), resume() and the
    // read-more re-arm all make — asked _read for ZERO items, so an async
    // _read that honors its size (readdirp: `while (batch > 0)`, which Vite's
    // chokidar watcher scans every directory with) never produced anything
    // and never ended.
    if (!state.ended) {
        this._read(state.highWaterMark);
    }
    state.reading = false;
    if (state.flowing) {
        flow(this);
    }
    return ret;
};

function concatBuffer(state, n) {
    if (state.objectMode) {
        return state.buffer.shift();
    }
    var out = "";
    var got = 0;
    while (state.buffer.length > 0 && got < n) {
        var c = state.buffer[0];
        var len = chunkByteLength(c, state.encoding);
        if (got + len > n && typeof c === "string") {
            out = out + c.slice(0, n - got);
            state.buffer[0] = c.slice(n - got);
            state.length = state.length - (n - got);
            got = n;
        } else {
            state.buffer.shift();
            if (typeof c === "string") { out = out + c; }
            else { out = c; }
            got = got + len;
            state.length = Math.max(0, state.length - len);
        }
    }
    return out || null;
}

// Default _read: a no-op (what every Readable effectively had while the
// constructor installed an own no-op). Node throws ERR_METHOD_NOT_IMPLEMENTED.
Readable.prototype._read = function(n) {};

Readable.prototype.on = function(ev, fn) {
    var res = EventEmitter.prototype.on.call(this, ev, fn);
    if (ev === "data") {
        this._readableState.flowing = true;
        this._readableState.paused = false;
        this.read(0);
        flow(this);
    } else if (ev === "readable" && fn) {
        this._readableState.readableListening = true;
        emitReadable(this);
    }
    return res;
};

Readable.prototype.addListener = Readable.prototype.on;

Readable.prototype.removeListener = function(ev, fn) {
    EventEmitter.prototype.removeListener.call(this, ev, fn);
    if (ev === "readable") {
        this._readableState.readableListening = this.listenerCount("readable") > 0;
    }
    return this;
};

Readable.prototype.pause = function() {
    this._readableState.flowing = false;
    this._readableState.paused = true;
    return this;
};

Readable.prototype.resume = function() {
    var state = this._readableState;
    if (!state.flowing) {
        state.flowing = true;
        state.paused = false;
        flow(this);
        // Node's resume_: start pulling from _read on the next tick. Without
        // it a resume() with no 'data' listener never read anything.
        var self = this;
        nextTick(function() {
            if (state.flowing && !state.reading && !state.ended && !state.destroyed) {
                self.read(0);
            }
        });
    }
    return this;
};

Readable.prototype.isPaused = function() {
    return this._readableState.paused === true || this._readableState.flowing === false;
};

Readable.prototype.setEncoding = function(enc) {
    var state = this._readableState;
    state.encoding = normalizeEncoding(enc);
    try {
        var StringDecoder = require("string_decoder").StringDecoder;
        state.decoder = new StringDecoder(state.encoding);
    } catch (e) {
        state.decoder = null;
    }
    return this;
};

Readable.prototype.unpipe = function(dest) {
    var state = this._readableState;
    if (!state.pipes) { return this; }
    if (dest) {
        var pipes = state.pipes;
        var list = [];
        for (var i = 0; i < pipes.length; i = i + 1) {
            if (pipes[i] !== dest) { list.push(pipes[i]); }
        }
        state.pipes = list.length ? list : null;
        state.pipesCount = list.length;
    } else {
        state.pipes = null;
        state.pipesCount = 0;
    }
    dest = dest || state.pipes;
    if (dest && dest.emit) {
        dest.emit("unpipe", this);
    }
    return this;
};

Readable.prototype.pipe = function(dest, options) {
    var src = this;
    var state = this._readableState;
    if (state.pipes === null) {
        state.pipes = [dest];
    } else {
        state.pipes.push(dest);
    }
    state.pipesCount = state.pipesCount + 1;
    options = options || {};
    if (options.end !== false && dest.writable) {
        dest.on("finish", function() { src.emit("end"); });
    }
    function ondata(chunk) {
        var ret = dest.write(chunk);
        if (ret === false) {
            src.pause();
        }
    }
    function ondrain() {
        if (state.flowing === false) {
            src.resume();
        }
    }
    function onend() {
        if (options.end !== false) {
            dest.end();
        }
    }
    function onerror(err) {
        unpipe();
        dest.removeListener("error", onerror);
        if (dest.listenerCount("error") === 0) {
            dest.emit("error", err);
        }
    }
    function unpipe() {
        src.removeListener("data", ondata);
        src.removeListener("end", onend);
        dest.removeListener("drain", ondrain);
        src.removeListener("error", onerror);
        src.removeListener("close", onclose);
        src.unpipe(dest);
    }
    function onclose() {
        dest.end();
    }
    src.on("data", ondata);
    dest.on("drain", ondrain);
    src.on("end", onend);
    src.on("error", onerror);
    src.on("close", onclose);
    if (!dest._events || !dest._events.error) {
        dest.on("error", onerror);
    }
    dest.emit("pipe", src);
    return dest;
};

Readable.prototype.unshift = function(chunk) {
    return readableAddChunk(this, chunk, true);
};

Readable.prototype.wrap = function(old) {
    var self = this;
    old.on("data", function(chunk) { self.push(chunk); });
    old.on("end", function() { self.push(null); });
    old.on("error", function(err) { self.destroy(err); });
    if (old.readable) { this.read(0); }
    return this;
};

Readable.prototype.destroy = function(err, cb) {
    if (typeof err === "function") {
        cb = err;
        err = undefined;
    }
    if (this._destroy) {
        var self = this;
        this._destroy(err, function(destroyErr) {
            destroy(self, destroyErr || err, cb);
        });
    } else {
        destroy(this, err, cb);
    }
    return this;
};

Readable.prototype[Symbol.asyncIterator] = function() {
    var stream = this;
    var ended = false;
    var queue = [];
    var waitResolve = null;
    function pushValue(val) {
        if (waitResolve) {
            var r = waitResolve;
            waitResolve = null;
            r({ value: val, done: false });
        } else {
            queue.push(val);
        }
    }
    function pushEnd() {
        ended = true;
        if (waitResolve) {
            var r = waitResolve;
            waitResolve = null;
            r({ value: undefined, done: true });
        }
    }
    stream.on("data", pushValue);
    stream.on("end", pushEnd);
    stream.on("error", function(err) {
        if (waitResolve) { waitResolve(Promise.reject(err)); }
    });
    return {
        next: function() {
            if (queue.length > 0) {
                return Promise.resolve({ value: queue.shift(), done: false });
            }
            if (ended) {
                return Promise.resolve({ value: undefined, done: true });
            }
            return new Promise(function(resolve) {
                waitResolve = resolve;
            });
        },
        return: function() {
            stream.destroy();
            return Promise.resolve({ value: undefined, done: true });
        }
    };
};

// ── Writable ──────────────────────────────────────────────────────────────────

function Writable(options) {
    if (!(this instanceof Writable)) {
        return new Writable(options);
    }
    EventEmitter.init.call(this);
    options = options || {};
    this._writableState = new WritableState(options, this);
    // Node sets these as own, assignable instance properties (not getters).
    this.writable = true;
    this.destroyed = false;
    var self = this;
    this._writableState.onwrite = function(err) {
        onwrite(self, self._writableState, err);
    };
    // Stream hooks are own properties ONLY when passed as options (Node): an
    // unconditional own default shadowed the _read/_write/_final/... that a
    // subclass (ES class or util.inherits) defines on its prototype, so those
    // never ran — e.g. the `ws` library's Receiver._write dropped every frame.
    if (typeof options.write === "function") { this._write = options.write; }
    if (typeof options.writev === "function") { this._writev = options.writev; }
    if (typeof options.final === "function") { this._final = options.final; }
    if (typeof options.destroy === "function") { this._destroy = options.destroy; }
    if (options && options.signal) {
        addAbortSignal(options.signal, this);
    }
}

Writable.prototype = Object.create(EventEmitter.prototype);
Writable.prototype.constructor = Writable;

// Default _write: hand the chunk to _writev when only that is implemented
// (Node), else accept and drop it (the lenient no-op every Writable had while
// the constructor installed one). Node throws ERR_METHOD_NOT_IMPLEMENTED.
Writable.prototype._write = function(chunk, encoding, cb) {
    if (typeof this._writev === "function") {
        this._writev([{ chunk: chunk, encoding: encoding }], cb);
        return;
    }
    cb();
};

Object.defineProperty(Writable.prototype, "writableEnded", {
    get: function() {
        return !!(this._writableState && this._writableState.ended);
    }
});
Object.defineProperty(Writable.prototype, "writableFinished", {
    get: function() {
        return !!(this._writableState && this._writableState.finished);
    }
});
Object.defineProperty(Writable.prototype, "writableHighWaterMark", {
    get: function() {
        var state = this._writableState;
        return state ? state.highWaterMark : 0;
    }
});
Object.defineProperty(Writable.prototype, "writableLength", {
    get: function() {
        var state = this._writableState;
        return state ? state.length : 0;
    }
});
Object.defineProperty(Writable.prototype, "writableObjectMode", {
    get: function() {
        var state = this._writableState;
        return state ? state.objectMode : false;
    }
});
Object.defineProperty(Writable.prototype, "writableCorked", {
    get: function() {
        var state = this._writableState;
        return state ? state.corked : 0;
    }
});
Object.defineProperty(Writable.prototype, "closed", {
    get: function() {
        return !!(this._writableState && this._writableState.closed);
    }
});

Writable.prototype.write = function(chunk, encoding, cb) {
    var state = this._writableState;
    if (state.destroyed) { return false; }
    if (typeof encoding === "function") {
        cb = encoding;
        encoding = null;
    }
    if (chunk === null) {
        var nullErr = new TypeError("May not write null values to stream");
        nullErr.code = "ERR_STREAM_NULL_VALUES";
        throw nullErr;
    }
    // ES: non-objectMode Writables accept only string/Buffer/TypedArray/DataView.
    if (!state.objectMode && typeof chunk !== "string" && !Bufferish(chunk) &&
        !(typeof chunk === "object" && ArrayBuffer.isView(chunk))) {
        var chunkErr = new TypeError(
            'The "chunk" argument must be of type string or an instance of ' +
            "Buffer or Uint8Array. Received type " + typeof chunk +
            " (" + String(chunk) + ")");
        chunkErr.code = "ERR_INVALID_ARG_TYPE";
        throw chunkErr;
    }
    if (!encoding) { encoding = state.defaultEncoding; }
    if (typeof chunk === "string" && state.decodeStrings !== false) {
        chunk = Bufferish(chunk) ? chunk : chunk;
    }
    if (state.ended) {
        var er = new Error("write after end");
        var wstream = this;
        nextTick(function() { errorOrDestroy(wstream, er); });
        return false;
    }
    if (!state.objectMode && chunk === "") {
        if (cb) { nextTick(cb); }
        return true;
    }
    if (state.ending) {
        if (cb) { nextTick(cb); }
        return false;
    }
    if (!state.writing && state.corked === 0 && state.buffer.length === 0) {
        state.writecb = cb;
        doWrite(this, state, false, chunk, encoding, cb);
    } else {
        state.buffer.push({ chunk: chunk, encoding: encoding, callback: cb });
        state.length = computeNewLength(state, chunk);
    }
    if (state.writing) {
        return false;
    }
    return !writableNeedDrain(state);
};

Writable.prototype.cork = function() {
    this._writableState.corked = this._writableState.corked + 1;
};

Writable.prototype.uncork = function() {
    var state = this._writableState;
    if (state.corked) {
        state.corked = state.corked - 1;
    }
    if (!state.writing) {
        clearBuffer(this, state);
    }
};

Writable.prototype.setDefaultEncoding = function(enc) {
    if (typeof enc === "string") {
        this._writableState.defaultEncoding = normalizeEncoding(enc) || "utf8";
    }
    return this;
};

Writable.prototype.end = function(chunk, encoding, cb) {
    var state = this._writableState;
    if (typeof chunk === "function") {
        cb = chunk;
        chunk = null;
        encoding = null;
    } else if (typeof encoding === "function") {
        cb = encoding;
        encoding = null;
    }
    if (chunk != null) {
        this.write(chunk, encoding);
    }
    if (state.ending) {
        if (cb) { this.once("finish", cb); }
        return this;
    }
    state.ended = true;
    state.ending = true;
    this.writable = false;
    if (cb) {
        this.once("finish", function() { cb(); });
    }
    finishMaybe(this, state);
    return this;
};

Writable.prototype.destroy = function(err, cb) {
    if (typeof err === "function") {
        cb = err;
        err = undefined;
    }
    if (this._destroy) {
        var self = this;
        this._destroy(err, function(destroyErr) {
            destroy(self, destroyErr || err, cb);
        });
    } else {
        destroy(this, err, cb);
    }
    return this;
};

// ── Duplex ────────────────────────────────────────────────────────────────────

function Duplex(options) {
    if (!(this instanceof Duplex)) {
        return new Duplex(options);
    }
    options = options || {};
    EventEmitter.init.call(this);
    this._readableState = new ReadableState(options, this);
    this._writableState = new WritableState(options, this);
    this._writableState.sync = false;
    // Own assignable instance props (Node-compatible).
    this.readable = true;
    this.writable = true;
    this.destroyed = false;
    var self = this;
    this._writableState.onwrite = function(err) {
        onwrite(self, self._writableState, err);
    };
    // Stream hooks are own properties ONLY when passed as options (Node): an
    // unconditional own default shadowed the _read/_write/_final/... that a
    // subclass (ES class or util.inherits) defines on its prototype, so those
    // never ran — e.g. the `ws` library's Receiver._write dropped every frame.
    if (typeof options.read === "function") { this._read = options.read; }
    if (typeof options.write === "function") { this._write = options.write; }
    if (typeof options.writev === "function") { this._writev = options.writev; }
    if (typeof options.final === "function") { this._final = options.final; }
    if (typeof options.destroy === "function") { this._destroy = options.destroy; }
    if (options.encoding) { this.setEncoding(options.encoding); }
    if (options.signal) { addAbortSignal(options.signal, this); }
    this.allowHalfOpen = options.allowHalfOpen !== false;
}

Duplex.prototype = Object.create(Readable.prototype);
Duplex.prototype.constructor = Duplex;

Duplex.prototype.write = Writable.prototype.write;
Duplex.prototype._write = Writable.prototype._write;
Duplex.prototype.cork = Writable.prototype.cork;
Duplex.prototype.uncork = Writable.prototype.uncork;
Duplex.prototype.end = Writable.prototype.end;
Duplex.prototype.setDefaultEncoding = Writable.prototype.setDefaultEncoding;
Duplex.prototype.destroy = function(err, cb) {
    return Readable.prototype.destroy.call(this, err, cb);
};

Object.defineProperty(Duplex.prototype, "writableEnded", {
    get: function() {
        return !!(this._writableState && this._writableState.ended);
    }
});
Object.defineProperty(Duplex.prototype, "writableFinished", {
    get: function() {
        return !!(this._writableState && this._writableState.finished);
    }
});
Object.defineProperty(Duplex.prototype, "writableHighWaterMark", {
    get: function() {
        var state = this._writableState;
        return state ? state.highWaterMark : 0;
    }
});
Object.defineProperty(Duplex.prototype, "writableLength", {
    get: function() {
        var state = this._writableState;
        return state ? state.length : 0;
    }
});
Object.defineProperty(Duplex.prototype, "writableObjectMode", {
    get: function() {
        var state = this._writableState;
        return state ? state.objectMode : false;
    }
});
Object.defineProperty(Duplex.prototype, "writableCorked", {
    get: function() {
        var state = this._writableState;
        return state ? state.corked : 0;
    }
});

// ── Transform ─────────────────────────────────────────────────────────────────

function Transform(options) {
    if (!(this instanceof Transform)) {
        return new Transform(options);
    }
    if (!options) { options = {}; }
    Duplex.call(this, options);
    this._transformState = {
        afterTransform: afterTransform.bind(this),
        needTransform: false,
        transforming: false,
        writecb: null,
        writechunk: null,
        writeencoding: null
    };
    // Own only when passed as options (see Readable): Transform.prototype
    // _write/_final/_read are now reached through the prototype chain, and a
    // subclass's _transform/_flush are no longer shadowed.
    if (typeof options.transform === "function") { this._transform = options.transform; }
    if (typeof options.flush === "function") { this._flush = options.flush; }
}

Transform.prototype = Object.create(Duplex.prototype);
Transform.prototype.constructor = Transform;

function afterTransform(err, data) {
    var ts = this._transformState;
    ts.transforming = false;
    var cb = ts.writecb;
    ts.writecb = null;
    ts.writechunk = null;
    ts.writeencoding = null;
    if (err) {
        errorOrDestroy(this, err);
        if (cb) { cb(err); }
        return;
    }
    if (data != null) {
        this.push(data);
    }
    if (cb) { cb(); }
    var rs = this._readableState;
    var ws = this._writableState;
    if (ws && ws.length) {
        this._write(ws.buffer[0] && ws.buffer[0].chunk, ws.buffer[0] && ws.buffer[0].encoding, cb);
    } else if (rs && rs.needReadable) {
        this.read(0);
    }
}

// Default _transform: identity (PassThrough; the old own default).
Transform.prototype._transform = function(chunk, enc, cb) {
    cb(null, chunk);
};

Transform.prototype._write = function(chunk, encoding, cb) {
    var ts = this._transformState;
    ts.writecb = cb;
    ts.writechunk = chunk;
    ts.writeencoding = encoding;
    if (!ts.transforming) {
        ts.transforming = true;
        this._transform(chunk, encoding, ts.afterTransform);
    }
};

Transform.prototype._read = function(n) {
    var ts = this._transformState;
    if (ts.writechunk !== null && !ts.transforming) {
        ts.transforming = true;
        this._transform(ts.writechunk, ts.writeencoding, ts.afterTransform);
    }
};

Transform.prototype._final = function(cb) {
    var self = this;
    if (this._flush) {
        this._flush(function(err, data) {
            if (err) { cb(err); return; }
            if (data != null) { self.push(data); }
            self.push(null);
            cb();
        });
    } else {
        this.push(null);
        cb();
    }
};

// ── PassThrough ───────────────────────────────────────────────────────────────

function PassThrough(options) {
    if (!(this instanceof PassThrough)) {
        return new PassThrough(options);
    }
    Transform.call(this, options);
}

PassThrough.prototype = Object.create(Transform.prototype);
PassThrough.prototype.constructor = PassThrough;

PassThrough.prototype._transform = function(chunk, encoding, callback) {
    callback(null, chunk);
};

// ── Stream base alias ─────────────────────────────────────────────────────────

function Stream() {
    Duplex.apply(this, arguments);
}

Stream.prototype = Duplex.prototype;
Stream.Readable = Readable;
Stream.Writable = Writable;
Stream.Duplex = Duplex;
Stream.Transform = Transform;
Stream.PassThrough = PassThrough;

// ── Static helpers: Readable ──────────────────────────────────────────────────

Readable.from = function(iterable, options) {
    if (iterable == null) {
        throw new TypeError("iterable must not be null");
    }
    var readable = new Readable(Object.assign({ objectMode: true }, options, {
        read: function() {}
    }));
    nextTick(function() { pumpIterable(iterable, readable); });
    return readable;
};

function pumpIterable(iterable, readable) {
    if (isAsyncIterable(iterable)) {
        var iter = iterable[Symbol.asyncIterator]();
        function pump() {
            iter.next().then(function(result) {
                if (result.done) {
                    readable.push(null);
                    return;
                }
                if (readable.push(result.value) === false) {
                    readable.once("readable", pump);
                } else {
                    pump();
                }
            }).catch(function(err) {
                readable.destroy(err);
            });
        }
        pump();
        return;
    }
    if (isIterable(iterable)) {
        try {
            for (var it = iterable[Symbol.iterator](), step = it.next(); !step.done; step = it.next()) {
                readable.push(step.value);
            }
            readable.push(null);
        } catch (err) {
            readable.destroy(err);
        }
        return;
    }
    // array-like
    var arr = iterable;
    for (var i = 0; i < arr.length; i = i + 1) {
        readable.push(arr[i]);
    }
    readable.push(null);
}

function optionsFrom(fn, options) {
    return Object.assign({ read: fn }, options);
}

Readable.fromWeb = function(readableStream, options) {
    if (typeof globalThis.ReadableStream === "undefined") {
        throw new Error("ReadableStream is not available");
    }
    if (!(readableStream instanceof globalThis.ReadableStream)) {
        throw new TypeError("Invalid ReadableStream");
    }
    var readable = new Readable(Object.assign({}, options, {
        read: function() {}
    }));
    var reader = readableStream.getReader();
    function readMore() {
        reader.read().then(function(result) {
            if (result.done) {
                readable.push(null);
                return;
            }
            if (readable.push(result.value) === false) {
                readable.once("readable", readMore);
            } else {
                readMore();
            }
        }).catch(function(err) {
            readable.destroy(err);
        });
    }
    nextTick(readMore);
    return readable;
};

Readable.toWeb = function(streamReadable, options) {
    if (typeof globalThis.ReadableStream === "undefined") {
        throw new Error("ReadableStream is not available");
    }
    return new globalThis.ReadableStream({
        start: function(controller) {
            streamReadable.on("data", function(chunk) {
                try {
                    controller.enqueue(chunk);
                } catch (e) {
                    streamReadable.destroy(e);
                }
            });
            streamReadable.on("end", function() {
                controller.close();
            });
            streamReadable.on("error", function(err) {
                controller.error(err);
            });
        },
        cancel: function() {
            streamReadable.destroy();
        }
    }, options);
};

// ── Static helpers: Writable ──────────────────────────────────────────────────

Writable.fromWeb = function(writableStream, options) {
    if (typeof globalThis.WritableStream === "undefined") {
        throw new Error("WritableStream is not available");
    }
    if (!(writableStream instanceof globalThis.WritableStream)) {
        throw new TypeError("Invalid WritableStream");
    }
    var writer = writableStream.getWriter();
    return new Writable(Object.assign({}, options, {
        write: function(chunk, encoding, cb) {
            writer.write(chunk).then(function() { cb(); }).catch(cb);
        },
        final: function(cb) {
            writer.close().then(function() { cb(); }).catch(cb);
        },
        destroy: function(err, cb) {
            writer.abort(err).then(function() { cb(err); }).catch(function() { cb(err); });
        }
    }));
};

Writable.toWeb = function(streamWritable) {
    if (typeof globalThis.WritableStream === "undefined") {
        throw new Error("WritableStream is not available");
    }
    return new globalThis.WritableStream({
        write: function(chunk) {
            return new Promise(function(resolve, reject) {
                if (streamWritable.write(chunk, function(err) {
                    if (err) { reject(err); } else { resolve(); }
                }) === false) {
                    streamWritable.once("drain", resolve);
                } else {
                    resolve();
                }
            });
        },
        close: function() {
            return new Promise(function(resolve, reject) {
                streamWritable.end(function(err) {
                    if (err) { reject(err); } else { resolve(); }
                });
            });
        },
        abort: function(reason) {
            streamWritable.destroy(reason);
            return Promise.resolve();
        }
    });
};

// ── Static helpers: Duplex ────────────────────────────────────────────────────

Duplex.from = function(body) {
    if (isReadable(body) || (body && typeof body.pipe === "function")) {
        return body;
    }
    if (isIterable(body) || isAsyncIterable(body) || Array.isArray(body)) {
        return Readable.from(body);
    }
    return new PassThrough();
};

Duplex.fromWeb = function(pair, options) {
    var readable = Readable.fromWeb(pair.readable, options);
    var writable = Writable.fromWeb(pair.writable, options);
    var duplex = new Duplex(options);
    readable.on("data", function(c) { duplex.push(c); });
    readable.on("end", function() { duplex.push(null); });
    readable.on("error", function(e) { duplex.destroy(e); });
    duplex._write = writable._write.bind(writable);
    duplex._final = writable._final && writable._final.bind(writable);
    return duplex;
};

// ── pipeline / finished ───────────────────────────────────────────────────────

function popCallback(args) {
    var cb = args[args.length - 1];
    if (typeof cb !== "function") { return popOptions(args); }
    return { streams: args.slice(0, -1), callback: cb, options: {} };
}

function popOptions(args) {
    var last = args[args.length - 1];
    if (last && typeof last === "object" && !last.write && !last.read && !last.pipe) {
        return { streams: args.slice(0, -1), callback: null, options: last };
    }
    return { streams: args, callback: null, options: {} };
}

function pipeline() {
    var args = Array.prototype.slice.call(arguments);
    var popped = popCallback(args);
    if (!popped.callback && args.length > 0 && typeof args[args.length - 1] === "function") {
        popped = popCallback(args);
    }
    if (popped.streams.length === 0 && args.length > 0) {
        popped = popOptions(args);
        if (typeof args[args.length - 1] === "function") {
            popped.callback = args.pop();
            popped.streams = args;
        }
    }
    var streams = popped.streams;
    var callback = popped.callback;
    var options = popped.options || {};
    if (streams.length < 1) {
        if (callback) { nextTick(callback); }
        return streams[0];
    }
    var signal = options.signal;
    var error;
    var destroyed = false;
    function abort() {
        if (destroyed) { return; }
        destroyed = true;
        var err = signal.reason || new Error("Aborted");
        for (var i = 0; i < streams.length; i = i + 1) {
            destroyer(streams[i], err);
        }
        if (callback) { callback(err); }
    }
    if (signal) {
        if (signal.aborted) {
            abort();
            return streams[0];
        }
        signal.addEventListener("abort", abort, { once: true });
    }
    function onError(err) {
        if (destroyed) { return; }
        destroyed = true;
        error = err;
        for (var j = 0; j < streams.length; j = j + 1) {
            destroyer(streams[j], err);
        }
        if (callback) { callback(err); }
    }
    function pipe(from, to) {
        from.pipe(to);
        from.on("error", onError);
        to.on("error", onError);
    }
    for (var k = 0; k < streams.length - 1; k = k + 1) {
        pipe(streams[k], streams[k + 1]);
    }
    var last = streams[streams.length - 1];
    var finishedStream = last;
    if (last && last.writable) {
        eos(last, function(err) {
            if (destroyed) { return; }
            destroyed = true;
            if (callback) { callback(err || error); }
        });
    } else if (last && last.readable) {
        eos(last, function(err) {
            if (destroyed) { return; }
            destroyed = true;
            if (callback) { callback(err || error); }
        });
    } else if (callback) {
        nextTick(function() { callback(error); });
    }
    return finishedStream;
}

function finished(stream, options, callback) {
    if (typeof options === "function") {
        callback = options;
        options = {};
    }
    options = options || {};
    if (!stream || (typeof stream !== "object" && typeof stream !== "function")) {
        throw new TypeError("stream must be a Stream");
    }
    if (typeof callback !== "function") {
        throw new TypeError("callback must be a function");
    }
    var signal = options.signal;
    if (signal && signal.aborted) {
        return nextTick(function() {
            callback(signal.reason || new Error("Aborted"));
        });
    }
    eos(stream, function(err) {
        if (signal && signal.aborted) {
            callback(signal.reason || new Error("Aborted"));
        } else {
            callback(err);
        }
    });
    if (signal) {
        signal.addEventListener("abort", function() {
            destroyer(stream, signal.reason || new Error("Aborted"));
            callback(signal.reason || new Error("Aborted"));
        }, { once: true });
    }
}

function eos(stream, callback) {
    var called = false;
    function done(err) {
        if (called) { return; }
        called = true;
        callback(err);
    }
    if (stream.writable && !stream.writableEnded) {
        stream.on("finish", function() { done(); });
    } else if (stream.readable && !stream.readableEnded) {
        stream.on("end", function() { done(); });
    } else {
        nextTick(function() { done(); });
    }
    stream.on("error", done);
    stream.on("close", function() {
        if (!called) { done(); }
    });
}

function pipelinePromise(streams, options) {
    return new Promise(function(resolve, reject) {
        var args = streams.slice();
        args.push(function(err, value) {
            if (err) { reject(err); } else { resolve(value); }
        });
        if (options) {
            args.splice(args.length - 1, 0, options);
        }
        pipeline.apply(null, args);
    });
}

function finishedPromise(stream, options) {
    return new Promise(function(resolve, reject) {
        finished(stream, options || {}, function(err) {
            if (err) { reject(err); } else { resolve(); }
        });
    });
}

// ── compose / duplexPair ────────────────────────────────────────────────────────

function compose() {
    var streams = Array.prototype.slice.call(arguments);
    if (streams.length === 1 && Array.isArray(streams[0])) {
        streams = streams[0];
    }
    var head = streams[0];
    var tail = streams[streams.length - 1];
    var duplex = new Duplex({
        read: function() {
            if (head && head.read) { head.read(0); }
        },
        write: function(chunk, encoding, cb) {
            if (tail && tail.write) {
                tail.write(chunk, encoding, cb);
            } else if (cb) {
                cb();
            }
        }
    });
    for (var i = 0; i < streams.length - 1; i = i + 1) {
        streams[i].pipe(streams[i + 1]);
    }
    if (head && head.on) {
        head.on("data", function(c) { duplex.push(c); });
        head.on("end", function() { duplex.push(null); });
        head.on("error", function(e) { duplex.destroy(e); });
    }
    return duplex;
}

function duplexPair(options) {
    var s1 = new Duplex(options);
    var s2 = new Duplex(options);
    s1._write = function(chunk, enc, cb) {
        if (s2.push(chunk) === false) {
            s2.once("drain", cb);
        } else {
            cb();
        }
    };
    s2._write = function(chunk, enc, cb) {
        if (s1.push(chunk) === false) {
            s1.once("drain", cb);
        } else {
            cb();
        }
    };
    s1.on("end", function() { s2.push(null); });
    s2.on("end", function() { s1.push(null); });
    return [s1, s2];
}

// ── addAbortSignal / duck typing ──────────────────────────────────────────────

function addAbortSignal(signal, stream) {
    if (!signal || typeof signal.addEventListener !== "function") {
        throw new TypeError("signal must be an AbortSignal");
    }
    if (signal.aborted) {
        destroyer(stream, signal.reason || new Error("Aborted"));
        return stream;
    }
    signal.addEventListener("abort", function() {
        destroyer(stream, signal.reason || new Error("Aborted"));
    }, { once: true });
    return stream;
}

function isReadable(stream) {
    return stream != null && stream.readable !== false &&
        typeof stream.read === "function";
}

function isWritable(stream) {
    return stream != null && stream.writable !== false &&
        typeof stream.write === "function";
}

function isErrored(stream) {
    if (!stream) { return false; }
    var r = stream._readableState;
    var w = stream._writableState;
    if (r && r.errored) { return true; }
    if (w && w.errored) { return true; }
    return false;
}

// ── promises export ───────────────────────────────────────────────────────────

var promises = {
    pipeline: function(streams, options) {
        var list = Array.isArray(streams) ? streams : Array.prototype.slice.call(arguments, 0, -1);
        if (!Array.isArray(streams)) {
            var last = arguments[arguments.length - 1];
            if (last && typeof last === "object" && !last.write) {
                options = last;
            }
        }
        return pipelinePromise(list, options);
    },
    finished: finishedPromise
};

// ── Attach statics to constructors ────────────────────────────────────────────

Readable.Writable = Writable;
Readable.Readable = Readable;
Readable.Duplex = Duplex;
Readable.Transform = Transform;
Readable.PassThrough = PassThrough;
Readable.Stream = Stream;
Readable.pipeline = pipeline;
Readable.finished = finished;
Readable.duplexPair = duplexPair;
Readable.compose = compose;
Readable.addAbortSignal = addAbortSignal;
Readable.isErrored = isErrored;
Readable.isReadable = isReadable;
Readable.isWritable = isWritable;
Readable.getDefaultHighWaterMark = getDefaultHighWaterMark;
Readable.setDefaultHighWaterMark = setDefaultHighWaterMark;
Readable.promises = promises;
Readable.from = Readable.from;
Readable.fromWeb = Readable.fromWeb;
Readable.toWeb = Readable.toWeb;

Writable.Readable = Readable;
Writable.Writable = Writable;
Writable.Duplex = Duplex;
Writable.Transform = Transform;
Writable.PassThrough = PassThrough;
Writable.fromWeb = Writable.fromWeb;
Writable.toWeb = Writable.toWeb;

Duplex.Readable = Readable;
Duplex.Writable = Writable;
Duplex.Duplex = Duplex;
Duplex.Transform = Transform;
Duplex.PassThrough = PassThrough;
Duplex.from = Duplex.from;
Duplex.fromWeb = Duplex.fromWeb;

// ── Module exports ────────────────────────────────────────────────────────────

module.exports = {
    Stream: Stream,
    Readable: Readable,
    Writable: Writable,
    Duplex: Duplex,
    Transform: Transform,
    PassThrough: PassThrough,
    pipeline: pipeline,
    finished: finished,
    duplexPair: duplexPair,
    compose: compose,
    addAbortSignal: addAbortSignal,
    isErrored: isErrored,
    isReadable: isReadable,
    isWritable: isWritable,
    getDefaultHighWaterMark: getDefaultHighWaterMark,
    setDefaultHighWaterMark: setDefaultHighWaterMark,
    promises: promises
};

module.exports.default = module.exports;
