/**
 * webstreams.js — WHATWG WritableStream / TransformStream + queuing strategies
 *
 * ReadableStream lives in fetch.js (already a global). This module adds the
 * writable/transform side and registers them on globalThis.
 */
'use strict';

function CountQueuingStrategy(init) {
    if (init === undefined || init === null || typeof init !== 'object') {
        throw new TypeError("Failed to construct 'CountQueuingStrategy': parameter 1 is not of type 'object'.");
    }
    if (init.highWaterMark === undefined) {
        throw new TypeError("Failed to construct 'CountQueuingStrategy': highWaterMark is required.");
    }
    this.highWaterMark = Number(init.highWaterMark);
    this.size = function size() { return 1; };
}

function ByteLengthQueuingStrategy(init) {
    if (init === undefined || init === null || typeof init !== 'object') {
        throw new TypeError("Failed to construct 'ByteLengthQueuingStrategy': parameter 1 is not of type 'object'.");
    }
    if (init.highWaterMark === undefined) {
        throw new TypeError("Failed to construct 'ByteLengthQueuingStrategy': highWaterMark is required.");
    }
    this.highWaterMark = Number(init.highWaterMark);
    this.size = function size(chunk) {
        if (chunk && typeof chunk.byteLength === 'number') return chunk.byteLength;
        if (typeof chunk === 'string') return chunk.length;
        return 1;
    };
}

function WritableStreamDefaultController(stream) {
    this._stream = stream;
    this.signal = (typeof AbortSignal !== 'undefined' && typeof AbortController !== 'undefined')
        ? (new AbortController()).signal
        : { aborted: false };
}

WritableStreamDefaultController.prototype.error = function error(e) {
    this._stream._error(e);
};

function WritableStreamDefaultWriter(stream) {
    if (stream._locked) {
        throw new TypeError('WritableStream is already locked');
    }
    stream._locked = true;
    this._stream = stream;
    var self = this;
    this.closed = new Promise(function (resolve, reject) {
        self._closedResolve = resolve;
        self._closedReject = reject;
    });
    this.ready = Promise.resolve(undefined);
}

Object.defineProperty(WritableStreamDefaultWriter.prototype, 'desiredSize', {
    get: function () {
        return this._stream._desiredSize();
    },
    enumerable: true,
    configurable: true
});

WritableStreamDefaultWriter.prototype.write = function write(chunk) {
    return this._stream._write(chunk);
};

WritableStreamDefaultWriter.prototype.close = function close() {
    return this._stream._close();
};

WritableStreamDefaultWriter.prototype.abort = function abort(reason) {
    return this._stream._abort(reason);
};

WritableStreamDefaultWriter.prototype.releaseLock = function releaseLock() {
    if (this._stream) {
        this._stream._locked = false;
        this._stream = null;
    }
};

function WritableStream(underlyingSink, strategy) {
    if (!(this instanceof WritableStream)) {
        return new WritableStream(underlyingSink, strategy);
    }
    if (underlyingSink === undefined || underlyingSink === null) {
        underlyingSink = {};
    }
    strategy = strategy || {};
    this._underlyingSink = underlyingSink;
    this._strategySize = typeof strategy.size === 'function' ? strategy.size : function () { return 1; };
    this._highWaterMark = strategy.highWaterMark !== undefined ? Number(strategy.highWaterMark) : 1;
    this._locked = false;
    this._state = 'writable'; // writable | closing | closed | errored
    this._storedError = undefined;
    this._queueTotalSize = 0;
    this._writeQueue = [];
    this._writing = false;
    this._controller = new WritableStreamDefaultController(this);
    this._pendingClose = null;

    var self = this;
    if (typeof underlyingSink.start === 'function') {
        try {
            var startResult = underlyingSink.start(this._controller);
            Promise.resolve(startResult).catch(function (e) {
                self._error(e);
            });
        } catch (e) {
            this._error(e);
        }
    }
}

Object.defineProperty(WritableStream.prototype, 'locked', {
    get: function () { return this._locked; },
    enumerable: true,
    configurable: true
});

WritableStream.prototype.getWriter = function getWriter() {
    return new WritableStreamDefaultWriter(this);
};

WritableStream.prototype.abort = function abort(reason) {
    return this._abort(reason);
};

WritableStream.prototype.close = function close() {
    if (this._locked) {
        return Promise.reject(new TypeError('Cannot close a locked WritableStream'));
    }
    return this._close();
};

WritableStream.prototype._desiredSize = function _desiredSize() {
    if (this._state === 'errored') return null;
    if (this._state === 'closed') return 0;
    return this._highWaterMark - this._queueTotalSize;
};

WritableStream.prototype._error = function _error(e) {
    if (this._state === 'errored' || this._state === 'closed') return;
    this._state = 'errored';
    this._storedError = e;
    while (this._writeQueue.length > 0) {
        this._writeQueue.shift().reject(e);
    }
    if (this._pendingClose) {
        this._pendingClose.reject(e);
        this._pendingClose = null;
    }
};

WritableStream.prototype._abort = function _abort(reason) {
    if (this._state === 'closed') return Promise.resolve();
    if (this._state === 'errored') return Promise.reject(this._storedError);
    var sink = this._underlyingSink;
    var self = this;
    this._state = 'errored';
    this._storedError = reason;
    while (this._writeQueue.length > 0) {
        this._writeQueue.shift().reject(reason);
    }
    if (typeof sink.abort === 'function') {
        return Promise.resolve().then(function () {
            return sink.abort(reason);
        }).catch(function () { /* ignore */ });
    }
    return Promise.resolve();
};

WritableStream.prototype._write = function _write(chunk) {
    var self = this;
    if (this._state === 'errored') {
        return Promise.reject(this._storedError);
    }
    if (this._state === 'closed' || this._state === 'closing') {
        return Promise.reject(new TypeError('WritableStream is closed'));
    }
    var size = 1;
    try {
        size = this._strategySize(chunk);
    } catch (e) {
        this._error(e);
        return Promise.reject(e);
    }
    this._queueTotalSize += size;
    return new Promise(function (resolve, reject) {
        self._writeQueue.push({ chunk: chunk, size: size, resolve: resolve, reject: reject });
        self._processWriteQueue();
    });
};

WritableStream.prototype._processWriteQueue = function _processWriteQueue() {
    if (this._writing) return;
    if (this._writeQueue.length === 0) {
        if (this._state === 'closing' && this._pendingClose) {
            this._finishClose();
        }
        return;
    }
    var self = this;
    var entry = this._writeQueue.shift();
    this._writing = true;
    var sink = this._underlyingSink;
    Promise.resolve().then(function () {
        if (typeof sink.write === 'function') {
            return sink.write(entry.chunk, self._controller);
        }
    }).then(function () {
        self._queueTotalSize -= entry.size;
        if (self._queueTotalSize < 0) self._queueTotalSize = 0;
        self._writing = false;
        entry.resolve();
        self._processWriteQueue();
    }, function (err) {
        self._writing = false;
        self._error(err);
        entry.reject(err);
    });
};

WritableStream.prototype._close = function _close() {
    var self = this;
    if (this._state === 'closed') return Promise.resolve();
    if (this._state === 'errored') return Promise.reject(this._storedError);
    if (this._state === 'closing') {
        return this._pendingClose ? this._pendingClose.promise : Promise.resolve();
    }
    this._state = 'closing';
    var pending = {};
    pending.promise = new Promise(function (resolve, reject) {
        pending.resolve = resolve;
        pending.reject = reject;
    });
    this._pendingClose = pending;
    this._processWriteQueue();
    return pending.promise;
};

WritableStream.prototype._finishClose = function _finishClose() {
    var self = this;
    var sink = this._underlyingSink;
    var pending = this._pendingClose;
    Promise.resolve().then(function () {
        if (typeof sink.close === 'function') {
            return sink.close();
        }
    }).then(function () {
        self._state = 'closed';
        self._pendingClose = null;
        if (pending) pending.resolve();
    }, function (err) {
        self._error(err);
        if (pending) pending.reject(err);
    });
};

function TransformStreamDefaultController(stream) {
    this._stream = stream;
}

TransformStreamDefaultController.prototype.enqueue = function enqueue(chunk) {
    var rs = this._stream._readable;
    if (rs && rs._controller) {
        rs._controller.enqueue(chunk);
    }
};

TransformStreamDefaultController.prototype.error = function error(e) {
    var rs = this._stream._readable;
    var ws = this._stream._writable;
    if (rs && rs._controller) rs._controller.error(e);
    if (ws) ws._error(e);
};

TransformStreamDefaultController.prototype.terminate = function terminate() {
    var rs = this._stream._readable;
    var ws = this._stream._writable;
    if (rs && rs._controller) rs._controller.close();
    if (ws) ws._error(new TypeError('TransformStream terminated'));
};

Object.defineProperty(TransformStreamDefaultController.prototype, 'desiredSize', {
    get: function () {
        var rs = this._stream._readable;
        if (rs && rs._controller && typeof rs._controller.desiredSize === 'number') {
            return rs._controller.desiredSize;
        }
        return 1;
    },
    enumerable: true,
    configurable: true
});

function TransformStream(transformer, writableStrategy, readableStrategy) {
    if (!(this instanceof TransformStream)) {
        return new TransformStream(transformer, writableStrategy, readableStrategy);
    }
    if (transformer === undefined || transformer === null) {
        transformer = {};
    }
    var self = this;
    this._controller = new TransformStreamDefaultController(this);

    var ReadableStreamCtor = globalThis.ReadableStream;
    if (typeof ReadableStreamCtor !== 'function') {
        throw new Error('ReadableStream is not available');
    }

    this._readable = new ReadableStreamCtor({
        start: function (ctrl) {
            // readable controller already on stream; keep reference via enqueue path
        }
    }, readableStrategy);

    var transformerObj = transformer;
    var ctrl = this._controller;

    this._writable = new WritableStream({
        start: function (wctrl) {
            if (typeof transformerObj.start === 'function') {
                return transformerObj.start(ctrl);
            }
        },
        write: function (chunk) {
            if (typeof transformerObj.transform === 'function') {
                return Promise.resolve(transformerObj.transform(chunk, ctrl));
            }
            ctrl.enqueue(chunk);
        },
        close: function () {
            return Promise.resolve().then(function () {
                if (typeof transformerObj.flush === 'function') {
                    return transformerObj.flush(ctrl);
                }
            }).then(function () {
                if (self._readable && self._readable._controller) {
                    self._readable._controller.close();
                }
            });
        },
        abort: function (reason) {
            if (self._readable && self._readable._controller) {
                self._readable._controller.error(reason);
            }
            if (typeof transformerObj.cancel === 'function') {
                return transformerObj.cancel(reason);
            }
        }
    }, writableStrategy);
}

Object.defineProperty(TransformStream.prototype, 'readable', {
    get: function () { return this._readable; },
    enumerable: true,
    configurable: true
});

Object.defineProperty(TransformStream.prototype, 'writable', {
    get: function () { return this._writable; },
    enumerable: true,
    configurable: true
});

globalThis.WritableStream = WritableStream;
globalThis.WritableStreamDefaultWriter = WritableStreamDefaultWriter;
globalThis.WritableStreamDefaultController = WritableStreamDefaultController;
globalThis.TransformStream = TransformStream;
globalThis.TransformStreamDefaultController = TransformStreamDefaultController;
globalThis.CountQueuingStrategy = CountQueuingStrategy;
globalThis.ByteLengthQueuingStrategy = ByteLengthQueuingStrategy;

module.exports = {
    WritableStream: WritableStream,
    WritableStreamDefaultWriter: WritableStreamDefaultWriter,
    WritableStreamDefaultController: WritableStreamDefaultController,
    TransformStream: TransformStream,
    TransformStreamDefaultController: TransformStreamDefaultController,
    CountQueuingStrategy: CountQueuingStrategy,
    ByteLengthQueuingStrategy: ByteLengthQueuingStrategy,
    get ReadableStream() {
        return globalThis.ReadableStream;
    },
    get ReadableStreamDefaultReader() {
        return globalThis.ReadableStreamDefaultReader;
    }
};
