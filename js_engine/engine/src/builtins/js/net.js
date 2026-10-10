// node:net — TCP networking module
// Phase 6.7 — wraps the native __net bridge with Node.js EventEmitter API.
//
// Reference: https://nodejs.org/api/net.html
// Bun ref:   bun/src/js/node/net.ts
var EventEmitter = require("events");
var _nb = __net; // native bridge

// ── Byte-exact socket I/O ───────────────────────────────────────────────────
// Writes are always bytes (strings are encoded by write(), see the write queue
// below): a Buffer turned into String(buf) is UTF-8-decoded, so every byte
// >= 0x80 went out as U+FFFD (a WebSocket frame header 0x81 … never survived).
// Reads deliver text (tcpReadNb) unless _useBinaryReads() switched the socket
// to Buffers (tcpReadBinaryNb) — the HTTP server and client always do.
function _bufCtor() {
    return globalThis.Buffer || require("buffer").Buffer;
}
// Copy the bytes of an ArrayBufferView / ArrayBuffer into a fresh __buf block
// with one trailing zero byte: the native write reinterprets the pointer as a
// C string, and the terminator keeps that strlen inside the block. The caller
// frees the block.
function _bytesToPtr(view, len) {
    var p = globalThis.__buf.alloc(len + 1);
    var ab = view.buffer !== undefined ? view.buffer : view;
    var off = view.byteOffset || 0;
    if (ab && typeof ab._ptr === "number" && ab._ptr > 0) {
        globalThis.__buf.copy(p, 0, ab._ptr, off, len);
    } else {
        var u8 = new Uint8Array(ab, off, len);
        for (var i = 0; i < len; i++) { globalThis.__buf.setByte(p, i, u8[i]); }
    }
    return p;
}
// A Buffer holding the `len` bytes at native `ptr` (a tcpReadBinaryNb chunk).
function _bufferFromPtr(ptr, len) {
    var b = _bufCtor().allocUnsafe(len);
    var ab = b.buffer;
    if (ab && typeof ab._ptr === "number" && ab._ptr > 0) {
        globalThis.__buf.copy(ab._ptr, b.byteOffset, ptr, 0, len);
    } else {
        for (var i = 0; i < len; i++) { b[i] = globalThis.__buf.getByte(ptr, i); }
    }
    return b;
}
function _isBinaryData(d) {
    return d !== null && typeof d === "object" && typeof d.byteLength === "number";
}

// ── Write queue (net.Socket and tls.TLSSocket) ──────────────────────────────
// write() queues the bytes and _flushWrites pushes the queue through
// __net.tcpTryWrite / tlsTryWrite — one non-blocking send each. When the kernel
// send buffer is full the socket parks on __net.waitIo until the fd is
// writable again, so a slow reader gets every byte instead of the tail being
// dropped. A chunk's callback fires once all of its bytes have left, 'drain'
// fires when the queue empties after write() returned false, and end()
// finishes — then destroys a non-half-open socket — only after the queue drains.
var _UV_READABLE = 1;
var _UV_WRITABLE = 2;
var _TLS_WANT_READ = -1000; // __net.tlsTryWrite: SSL needs the fd readable first
var _DEFAULT_WRITABLE_HWM = 16384;

function _nextTick(fn) {
    if (typeof process !== "undefined" && process && typeof process.nextTick === "function") {
        process.nextTick(fn);
    } else {
        Promise.resolve().then(fn);
    }
}
// The bytes a write() hands over: strings are encoded once, binary data is
// queued as-is (like Node, write(buf) keeps a reference rather than a copy).
function _toWriteView(data, encoding) {
    if (typeof data === "string") {
        return _bufCtor().from(data, encoding || "utf8");
    }
    if (_isBinaryData(data)) {
        return data;
    }
    return _bufCtor().from(String(data));
}
// Native address of a view's bytes, or 0 when the backing store has none.
function _viewPtr(view) {
    var ab = view.buffer !== undefined ? view.buffer : view;
    if (ab && typeof ab._ptr === "number" && ab._ptr > 0) {
        return ab._ptr + (view.byteOffset || 0);
    }
    return 0;
}
function _writeError(rc) {
    var code = rc === -104 ? "ECONNRESET" : "EPIPE";
    var err = new Error("write " + code);
    err.code = code;
    err.errno = rc < 0 ? rc : -32;
    err.syscall = "write";
    return err;
}
function _destroyedError() {
    var err = new Error("Cannot call write after a stream was destroyed");
    err.code = "ERR_STREAM_DESTROYED";
    return err;
}

var _writeQueueMethods = {
    _wqInit: function () {
        if (!this._wq) {
            this._wq = [];
            this._wqBytes = 0;
            this._wqWaiting = false;
            this._wqNeedDrain = false;
        }
    },
    /** Queue `view` (an ArrayBufferView / ArrayBuffer) and start flushing. */
    _enqueueWrite: function (view, cb) {
        this._wqInit();
        var len = view.byteLength;
        var p = 0;
        var owned = false;
        if (len > 0) {
            p = _viewPtr(view);
            if (p === 0) {
                p = _bytesToPtr(view, len);
                owned = true;
            }
        }
        this._wq.push({ view: view, p: p, owned: owned, len: len, off: 0, cb: cb || null });
        this._wqBytes = this._wqBytes + len;
        this._flushWrites();
        var ok = this._wqBytes < this.writableHighWaterMark;
        if (!ok) {
            this._wqNeedDrain = true;
        }
        return ok;
    },
    _flushWrites: function () {
        var self = this;
        self._wqInit();
        if (self._wqWaiting || self._wqFlushing || self._destroyed || self._handle === 0) {
            return;
        }
        self._wqFlushing = true;
        var done = [];
        while (self._wq.length > 0) {
            var e = self._wq[0];
            if (e.off < e.len) {
                var n = e.len - e.off;
                var rc = self._handle < 0
                    ? _nb.tlsTryWrite(self._handle, e.p + e.off, n)
                    : _nb.tcpTryWrite(self._handle, e.p + e.off, n);
                if (rc > 0) {
                    e.off = e.off + rc;
                    self._wqBytes = self._wqBytes - rc;
                    self.bytesWritten = self.bytesWritten + rc;
                    self._resetTimeout();
                    continue;
                }
                if (rc === 0 || rc === _TLS_WANT_READ) {
                    // Kernel buffer full (or TLS needs a read first): resume once
                    // the fd is ready. The poll is shared with the read loop.
                    self._wqWaiting = true;
                    _nb.waitIo(self._handle, rc === 0 ? _UV_WRITABLE : _UV_READABLE, function (status) {
                        self._wqWaiting = false;
                        if (status < 0) {
                            if (!self._destroyed) { self.destroy(_writeError(-32)); }
                            return;
                        }
                        self._flushWrites();
                    });
                    break;
                }
                self._wqFlushing = false;
                self.destroy(_writeError(rc));
                return;
            }
            self._wq.shift();
            if (e.owned) {
                globalThis.__buf.free(e.p);
            }
            if (e.cb) {
                done.push(e.cb);
            }
        }
        self._wqFlushing = false;
        if (done.length > 0 || self._wq.length === 0) {
            _nextTick(function () {
                // Node's order: 'drain' (never once end() was called), then
                // the write callbacks, then 'finish'.
                var empty = self._wq.length === 0 && !self._destroyed;
                if (empty && self._wqNeedDrain && !self._wqEnding) {
                    self._wqNeedDrain = false;
                    self.emit("drain");
                }
                for (var i = 0; i < done.length; i++) {
                    done[i](null);
                }
                if (empty && self._wqEnding && self._wq.length === 0) {
                    self._wqFinish();
                }
            });
        }
    },
    /** All queued bytes are in the kernel after end(): FIN, 'finish', close. */
    _wqFinish: function () {
        if (this._wqFinished) {
            return;
        }
        this._wqFinished = true;
        this._wqEnding = false;
        if (this._handle > 0 && !this._destroyed) {
            _nb.tcpShutdown(this._handle);
        }
        this.emit("finish");
        if (this._ended || !this.allowHalfOpen) {
            this.destroy();
        }
    },
    /** destroy(): drop what was never sent; its callbacks get an error. */
    _wqDiscard: function (err) {
        if (!this._wq || this._wq.length === 0) {
            return;
        }
        var q = this._wq;
        this._wq = [];
        this._wqBytes = 0;
        this._wqNeedDrain = false;
        var cbs = [];
        for (var i = 0; i < q.length; i++) {
            if (q[i].owned) {
                globalThis.__buf.free(q[i].p);
            }
            if (q[i].cb) {
                cbs.push(q[i].cb);
            }
        }
        if (cbs.length > 0) {
            var e = err || _destroyedError();
            _nextTick(function () {
                for (var j = 0; j < cbs.length; j++) {
                    cbs[j](e);
                }
            });
        }
    },
    /** write(data, encoding, cb) — queue; false once over the high-water mark. */
    write: function (data, encoding, cb) {
        if (typeof encoding === "function") {
            cb = encoding;
            encoding = undefined;
        }
        if (this._destroyed || this._writableEnded || (this._handle === 0 && !this._connecting)) {
            var err = new Error("This socket has been ended by the other party");
            err.code = "EPIPE";
            if (cb) {
                _nextTick(function () { cb(err); });
            }
            return false;
        }
        return this._enqueueWrite(_toWriteView(data, encoding), cb);
    },
    /** end(data, encoding, cb) — no more writes; finish once flushed. */
    end: function (data, encoding, cb) {
        var self = this;
        if (typeof data === "function") {
            cb = data;
            data = undefined;
        }
        if (typeof encoding === "function") {
            cb = encoding;
            encoding = undefined;
        }
        if (self._writableEnded) {
            if (cb) {
                if (self._wqFinished) { _nextTick(cb); } else { self.once("finish", cb); }
            }
            return self;
        }
        if (data !== undefined && data !== null) {
            self.write(data, encoding);
        }
        self._writableEnded = true;
        self.writable = false;
        if (cb) {
            self.once("finish", cb);
        }
        self._wqInit();
        self._wqEnding = true;
        if (self._wq.length === 0 && !self._connecting) {
            _nextTick(function () {
                if (!self._destroyed && self._wq.length === 0) { self._wqFinish(); }
            });
        }
        return self;
    }
};
var _writeQueueGetters = {
    writableLength: function () { return this._wqBytes || 0; },
    bufferSize: function () { return this._wqBytes || 0; },
    writableNeedDrain: function () { return !!this._wqNeedDrain; },
    writableFinished: function () { return !!this._wqFinished; },
    writableEnded: function () { return !!this._writableEnded; }
};
function _installWriteQueue(proto) {
    var names = Object.keys(_writeQueueMethods);
    for (var i = 0; i < names.length; i++) {
        Object.defineProperty(proto, names[i], {
            value: _writeQueueMethods[names[i]], writable: true, configurable: true
        });
    }
    var gnames = Object.keys(_writeQueueGetters);
    for (var g = 0; g < gnames.length; g++) {
        Object.defineProperty(proto, gnames[g], { get: _writeQueueGetters[gnames[g]], configurable: true });
    }
    Object.defineProperty(proto, "writableHighWaterMark", {
        get: function () { return this._writableHWM || _DEFAULT_WRITABLE_HWM; },
        set: function (v) { this._writableHWM = v; },
        configurable: true
    });
}

function _errSocketBadPort(name, port, allowZero) {
    var msg = (allowZero
        ? 'Port should be >= 0 and < 65536. Received ' + port + '.'
        : 'Port should be > 0 and < 65536. Received ' + port + '.');
    var err = new RangeError(msg);
    err.code = "ERR_SOCKET_BAD_PORT";
    return err;
}

/**
 * Node-compatible port validation (mirrors internal/validators validatePort).
 * allowZero defaults to true (listen + connect both allow 0; connect(0) fails async).
 */
function _validatePort(port, name, allowZero) {
    name = name || "Port";
    if (allowZero === undefined) allowZero = true;
    if (typeof port !== "number" && typeof port !== "string") {
        var te = new TypeError(
            'The "' + name + '" argument must be of type number. Received type ' +
            typeof port
        );
        te.code = "ERR_INVALID_ARG_TYPE";
        throw te;
    }
    // parseInt without radix so hex forms like "0xaa9b" match Number().
    if (typeof port === "string" &&
        String(parseInt(port)) !== String(Number(port))) {
        throw _errSocketBadPort(name, port, allowZero);
    }
    var n = +port;
    var min = allowZero ? 0 : 1;
    if (Number.isNaN(n) || n < min || n > 65535 || !Number.isInteger(n)) {
        throw _errSocketBadPort(name, port, allowZero);
    }
    return n >>> 0;
}

function _validateHost(host, name) {
    name = name || "host";
    if (host === undefined || host === null) return host;
    if (typeof host !== "string") {
        var te = new TypeError(
            'The "' + name + '" argument must be of type string. Received type ' +
            typeof host
        );
        te.code = "ERR_INVALID_ARG_TYPE";
        throw te;
    }
    if (host.indexOf("\0") !== -1) {
        var ve = new TypeError(
            "The property 'options.host' must be a string without null bytes. Received '" +
            host + "'"
        );
        ve.code = "ERR_INVALID_ARG_VALUE";
        throw ve;
    }
    return host;
}

// ── Utilities ────────────────────────────────────────────────────────────────
/**
 * net.isIP(input) — returns 4 for IPv4, 6 for IPv6, 0 otherwise.
 * Uses pure string parsing (no RegExp — engine has no regex support).
 */
function _isDigit(ch) {
    return ch === "0" || ch === "1" || ch === "2" || ch === "3" || ch === "4" || ch === "5" || ch === "6" || ch === "7" || ch === "8" || ch === "9";
}

function _isHexChar(ch) {
    return _isDigit(ch) || ch === "a" || ch === "b" || ch === "c" || ch === "d" || ch === "e" || ch === "f" || ch === "A" || ch === "B" || ch === "C" || ch === "D" || ch === "E" || ch === "F";
}

function isIP(input) {
    if (typeof input !== "string" || input === "") {
        return 0;
    }
    // IPv4: exactly four decimal octets 0-255 separated by dots
    var parts = input.split(".");
    if (parts.length === 4) {
        var valid = true;
        for (var i = 0; i < 4; i++) {
            var p = parts[i];
            if (p.length === 0 || p.length > 3) {
                valid = false;
                break;
            }
            for (var j = 0; j < p.length; j++) {
                if (!_isDigit(p.charAt(j))) {
                    valid = false;
                    break;
                }
            }
            if (!valid) {
                break;
            }
            var n = Number(p);
            if (n < 0 || n > 255) {
                valid = false;
                break;
            }
        }
        if (valid) {
            return 4;
        }
    }
    // IPv6 (incl. IPv4-mapped ::ffff:a.b.c.d): at least one colon
    if (input.indexOf(":") >= 0) {
        // Allow dotted IPv4 tail for mapped form
        var lastColon = input.lastIndexOf(":");
        var core = input;
        if (lastColon !== -1 && input.indexOf(".", lastColon) !== -1) {
            var v4tail = input.substring(lastColon + 1);
            if (isIPv4(v4tail)) {
                core = input.substring(0, lastColon);
            } else {
                return 0;
            }
        }
        var colons = 0;
        var allValid = true;
        for (var k = 0; k < core.length; k++) {
            var c = core.charAt(k);
            if (c === ":") {
                colons = colons + 1;
            } else if (!_isHexChar(c)) {
                allValid = false;
                break;
            }
        }
        // Normal IPv6 has 2–7 colons with ::, or exactly 7 without
        if (allValid && colons >= 2) {
            return 6;
        }
    }
    return 0;
}

function isIPv4(input) {
    return isIP(input) === 4;
}

function isIPv6(input) {
    return isIP(input) === 6;
}
/**
 * Parse "ip:port" string from native bridge into { address, port, family }.
 */
function _parseAddr(addrStr) {
    if (!addrStr || addrStr === "") {
        return {
            address: "",
            port: 0,
            family: "IPv4"
        };
    }
    // Handle IPv6 [::1]:port
    var lastColon = addrStr.lastIndexOf(":");
    var host = addrStr.substring(0, lastColon);
    var port = Number(addrStr.substring(lastColon + 1));
    var family = isIP(host) === 6 ? "IPv6" : "IPv4";
    return {
        address: host,
        port: port,
        family: family
    };
}
// ── Socket ───────────────────────────────────────────────────────────────────
/**
 * net.Socket — wraps a native TCP handle with EventEmitter API.
 *
 * Events: 'connect', 'data', 'end', 'close', 'error', 'drain',
 *         'timeout', 'lookup', 'ready'
 */
class Socket extends EventEmitter {
    constructor(options) {
        super();
        options = options || {};
        this._handle = 0; // native TCP handle ID (> 0 when connected)
        this._connecting = false;
        this._destroyed = false;
        this._ended = false; // remote sent FIN
        this._writableEnded = false; // we called end()
        this._reading = false; // read loop active
        this._readPaused = false;
        this._timeoutMs = 0;
        this._timeoutTimer = null;
        this.allowHalfOpen = options.allowHalfOpen || false;
        this.readable = false;
        this.writable = false;
        this.bytesRead = 0;
        this.bytesWritten = 0;
        this.remoteAddress = undefined;
        this.remotePort = undefined;
        this.remoteFamily = undefined;
        this.localAddress = undefined;
        this.localPort = undefined;
        this._readyState = "closed"; // 'opening', 'open', 'readOnly', 'writeOnly', 'closed'
    }
    get readyState() {
        if (this._connecting) {
            return "opening";
        }
        if (this.readable && this.writable) {
            return "open";
        }
        if (this.readable && !this.writable) {
            return "readOnly";
        }
        if (!this.readable && this.writable) {
            return "writeOnly";
        }
        return "closed";
    }
    /**
     * connect(options, cb) or connect(port, host, cb)
     */
    connect() {
        var self = this;
        var port, host, cb;
        if (typeof arguments[0] === "object" && arguments[0] !== null) {
            // connect({ port, host }, cb)
            var opts = arguments[0];
            var badOptKeys = ["objectMode", "readableObjectMode", "writableObjectMode"];
            var bki = 0;
            while (bki < badOptKeys.length) {
                var bk = badOptKeys[bki];
                if (opts[bk] !== undefined) {
                    var boe = new TypeError(
                        "The property 'options." + bk + "' is not supported. Received " +
                        String(opts[bk])
                    );
                    boe.code = "ERR_INVALID_ARG_VALUE";
                    throw boe;
                }
                bki += 1;
            }
            if (opts.hints !== undefined) {
                var hintsVal = opts.hints;
                if (typeof hintsVal !== "number" || !Number.isInteger(hintsVal)) {
                    var hte = new TypeError(
                        "The argument 'hints' is invalid. Received " + String(hintsVal)
                    );
                    hte.code = "ERR_INVALID_ARG_VALUE";
                    throw hte;
                }
                try {
                    var dnsMod = require("dns");
                    var allowed = (dnsMod.ADDRCONFIG | dnsMod.V4MAPPED | dnsMod.ALL) >>> 0;
                    if ((hintsVal & ~allowed) !== 0) {
                        var hie = new TypeError(
                            "The argument 'hints' is invalid. Received " + String(hintsVal)
                        );
                        hie.code = "ERR_INVALID_ARG_VALUE";
                        throw hie;
                    }
                } catch (he) {
                    if (he && he.code === "ERR_INVALID_ARG_VALUE") throw he;
                    // dns module unavailable — still reject obviously-wrong bits
                    if (hintsVal < 0 || hintsVal > 0xffff) {
                        var hie2 = new TypeError(
                            "The argument 'hints' is invalid. Received " + String(hintsVal)
                        );
                        hie2.code = "ERR_INVALID_ARG_VALUE";
                        throw hie2;
                    }
                }
            }
            port = opts.port;
            host = opts.host !== undefined ? opts.host : "127.0.0.1";
            host = _validateHost(host, "options.host");
            port = _validatePort(port, "options.port", true);
            cb = arguments[1];
        } else {
            // connect(port, host, cb)
            port = arguments[0];
            host = arguments[1] || "127.0.0.1";
            if (typeof host === "function") {
                cb = host;
                host = "127.0.0.1";
            }
            if (typeof arguments[2] === "function") {
                cb = arguments[2];
            }
            host = _validateHost(host, "host");
            port = _validatePort(port, "port", true);
        }
        if (cb) {
            self.once("connect", cb);
        }
        self._connecting = true;
        self._destroyed = false;
        self.readable = true;
        self.writable = true;
        // Emit 'lookup' for compatibility (we do sync DNS)
        self.emit("lookup", null, host, isIP(host) === 6 ? 6 : 4, host);
        _nb.tcpConnectNb(host, port, function(handle, errCode) {
            if (self._destroyed) {
                return;
            }
            if (errCode !== 0 || handle === 0) {
                self._connecting = false;
                self._wqDiscard();
                var err = new Error("connect ECONNREFUSED " + host + ":" + port);
                err.code = "ECONNREFUSED";
                err.syscall = "connect";
                err.address = host;
                err.port = port;
                self.emit("error", err);
                self.emit("close", true);
                return;
            }
            self._handle = handle;
            self._connecting = false;
            // Populate address info
            var peerStr = _nb.tcpPeerAddr(handle);
            var peer = _parseAddr(peerStr);
            self.remoteAddress = peer.address;
            self.remotePort = peer.port;
            self.remoteFamily = peer.family;
            var localStr = _nb.tcpLocalAddr(handle);
            var local = _parseAddr(localStr);
            self.localAddress = local.address;
            self.localPort = local.port;
            self.emit("connect");
            self.emit("ready");
            // Start reading
            self._startReading();
            // Send what was written while connecting (and finish a pending end())
            self._flushWrites();
        });
        return self;
    }
    /**
     * Internal: start the async read loop.
     */
    _startReading() {
        var self = this;
        if (self._reading || self._destroyed || self._handle === 0) {
            return;
        }
        self._reading = true;

        function readOne() {
            if (self._destroyed || self._handle === 0) {
                self._reading = false;
                return;
            }
            if (self._readPaused) {
                self._reading = false;
                return;
            }
            if (self._binaryReads) {
                // Buffers, byte-exact (Node's default 'data' type). Chosen per
                // read, so a switch made inside a 'data' handler (HTTP upgrade)
                // applies from the very next chunk.
                _nb.tcpReadBinaryNb(self._handle, 65536, function(ptr, len, isEOF) {
                    if (self._destroyed) {
                        if (ptr) { globalThis.__buf.free(ptr); }
                        return;
                    }
                    self._resetTimeout();
                    if (len > 0) {
                        var bchunk = _bufferFromPtr(ptr, len);
                        globalThis.__buf.free(ptr);
                        self.bytesRead = self.bytesRead + len;
                        self.emit("data", bchunk);
                    } else if (ptr) {
                        globalThis.__buf.free(ptr);
                    }
                    if (isEOF) {
                        self._onReadEOF();
                        return;
                    }
                    readOne();
                });
                return;
            }
            _nb.tcpReadNb(self._handle, 65536, function(chunk, isEOF) {
                if (self._destroyed) {
                    return;
                }
                self._resetTimeout();
                if (isEOF || chunk === "") {
                    self._onReadEOF();
                    return;
                }
                self.bytesRead = self.bytesRead + chunk.length;
                self.emit("data", chunk);
                // Continue reading
                readOne();
            });
        }
        readOne();
    }
    /** Remote closed its side (FIN): shared by the string and binary read loops. */
    _onReadEOF() {
        this._ended = true;
        this.readable = false;
        this._reading = false;
        if (this._readableState) {
            this._readableState.ended = true;
            this._readableState.endEmitted = true;  // Node sets it before 'end'
        }
        this.emit("end");
        if (!this.allowHalfOpen) {
            this.writable = false;
            this.destroy();
        }
    }
    /**
     * Switch 'data' to Buffers (tcpReadBinaryNb) — used by the HTTP server when
     * it hands a socket to an 'upgrade' listener (WebSocket libraries parse
     * binary frames). Also exposes the bits of Readable state those libraries
     * read (`ws` checks _readableState.endEmitted and calls read() on close).
     */
    _useBinaryReads() {
        this._binaryReads = true;
        if (!this._readableState) {
            this._readableState = {
                ended: this._ended, endEmitted: this._ended,
                flowing: true, length: 0, destroyed: this._destroyed
            };
        }
        return this;
    }
    /** read() — nothing is buffered here ('data' delivers every chunk). */
    read() {
        return null;
    }
    /** unshift(chunk) — re-deliver bytes read ahead of a protocol switch. */
    unshift(chunk) {
        var self = this;
        if (chunk && chunk.length > 0) {
            setTimeout(function () { self.emit("data", chunk); }, 0);
        }
    }
    /**
     * destroy(err) — forcefully closes the socket.
     */
    destroy(err) {
        var self = this;
        if (self._destroyed) {
            return self;
        }
        self._destroyed = true;
        self._reading = false;
        self.readable = false;
        self.writable = false;
        self._wqDiscard(err);
        if (self._timeoutTimer !== null) {
            clearTimeout(self._timeoutTimer);
            self._timeoutTimer = null;
        }
        if (self._handle !== 0) {
            _nb.tcpClose(self._handle);
            self._handle = 0;
        }
        if (err) {
            self.emit("error", err);
        }
        self.emit("close", !!err);
        return self;
    }
    /**
     * setTimeout(ms, cb) — set idle timeout. Emits 'timeout' but does NOT close.
     */
    setTimeout(ms, cb) {
        var self = this;
        if (ms === 0 || ms === undefined) {
            self._timeoutMs = 0;
            if (self._timeoutTimer !== null) {
                clearTimeout(self._timeoutTimer);
                self._timeoutTimer = null;
            }
            return self;
        }
        self._timeoutMs = ms;
        if (cb) {
            self.once("timeout", cb);
        }
        self._resetTimeout();
        return self;
    }
    _resetTimeout() {
        var self = this;
        if (self._timeoutMs <= 0) {
            return;
        }
        if (self._timeoutTimer !== null) {
            clearTimeout(self._timeoutTimer);
        }
        self._timeoutTimer = setTimeout(function() {
            self.emit("timeout");
        }, self._timeoutMs);
    }
    /**
     * setNoDelay(enable) — enables/disables Nagle's algorithm.
     */
    setNoDelay(enable) {
        if (enable === undefined) {
            enable = true;
        }
        if (this._handle !== 0) {
            _nb.tcpSetNodelay(this._handle, enable ? true : false);
        }
        return this;
    }
    /**
     * setKeepAlive(enable, initialDelay) — enables/disables TCP keepalive.
     */
    setKeepAlive(enable, initialDelay) {
        if (this._handle !== 0) {
            var delay = initialDelay ? Math.floor(initialDelay / 1000) : 0;
            _nb.tcpSetKeepalive(this._handle, enable ? true : false, delay);
        }
        return this;
    }
    /**
     * address() — returns the bound address.
     */
    address() {
        if (this._handle === 0) {
            return {};
        }
        var localStr = _nb.tcpLocalAddr(this._handle);
        return _parseAddr(localStr);
    }
    /**
     * pause() / resume() — flow control.
     */
    pause() {
        this._readPaused = true;
        return this;
    }
    resume() {
        this._readPaused = false;
        if (!this._reading && !this._destroyed && this._handle !== 0 && !this._ended) {
            this._startReading();
        }
        return this;
    }
    /**
     * setEncoding(encoding) — no-op (we always return UTF-8 strings).
     */
    setEncoding() {
        return this;
    }
    /**
     * ref() / unref() — no-op stubs (event loop ref counting not applicable here).
     */
    ref() {
        return this;
    }
    unref() {
        return this;
    }
    /**
     * cork() / uncork() — Writable write batching (the `ws` library wraps every
     * frame write in them; a Node socket inherits them from Writable). write()
     * hands data to the native handle immediately, so there is nothing to hold
     * back: only the nesting count is kept, for writableCorked.
     */
    cork() {
        this._corked = (this._corked || 0) + 1;
    }
    uncork() {
        if (this._corked) {
            this._corked = this._corked - 1;
        }
    }
    get writableCorked() {
        return this._corked || 0;
    }
} // class Socket
_installWriteQueue(Socket.prototype);
// ── Server ───────────────────────────────────────────────────────────────────
/**
 * net.Server — a TCP server that accepts incoming connections.
 *
 * Events: 'listening', 'connection', 'close', 'error'
 */
function Server(options, connectionListener) {
    if (!(this instanceof Server)) {
        return new Server(options, connectionListener);
    }
    EventEmitter.init.call(this);
    if (typeof options === "function") {
        connectionListener = options;
        options = {};
    }
    options = options || {};
    this._handle = 0; // listener handle from tcpListen
    this._connections = 0;
    this._sockets = []; // keep accepted socket JS objects alive (GC root)
    this._listening = false;
    this._closed = false;
    this.maxConnections = 0; // 0 = unlimited
    this.allowHalfOpen = options.allowHalfOpen || false;
    this.pauseOnConnect = options.pauseOnConnect || false;
    if (connectionListener) {
        this.on("connection", connectionListener);
    }
}
Server.prototype = Object.create(EventEmitter.prototype);
Server.prototype.constructor = Server;
/**
 * listen(port, host, backlog, cb) — start listening.
 * Supports multiple signatures:
 *   listen(port)
 *   listen(port, cb)
 *   listen(port, host, cb)
 *   listen(port, host, backlog, cb)
 *   listen({ port, host, backlog }, cb)
 */
Server.prototype.listen = function() {
    var self = this;
    var port = 0,
        host = "0.0.0.0",
        backlog = 128,
        cb = null;
    var pathListen = null;
    if (typeof arguments[0] === "object" && arguments[0] !== null) {
        var opts = arguments[0];
        if (typeof opts.path === "string") {
            pathListen = opts.path;
            backlog = opts.backlog || 128;
        } else {
            port = opts.port !== undefined && opts.port !== null ? opts.port : 0;
            host = opts.host || "0.0.0.0";
            backlog = opts.backlog || 128;
            _validateHost(host, "host");
            port = _validatePort(port, "port", true);
        }
        cb = arguments[1];
    } else if (typeof arguments[0] === "string") {
        // Unix domain socket: server.listen(path[, backlog][, cb])
        pathListen = arguments[0];
        if (typeof arguments[1] === "function") {
            cb = arguments[1];
        } else if (typeof arguments[1] === "number") {
            backlog = arguments[1];
            cb = arguments[2];
        }
    } else {
        port = arguments[0] !== undefined && arguments[0] !== null ? arguments[0] : 0;
        // Node (normalizeArgs): the callback is the LAST argument when it is a
        // function, and host/backlog before it may be undefined/null. Vite's dev
        // server calls listen(port, undefined, cb) when no host is configured;
        // positional matching dropped that callback, so `vite` never printed
        // "ready" although the socket was listening.
        var nargs = arguments.length;
        if (nargs > 1 && typeof arguments[nargs - 1] === "function") {
            cb = arguments[nargs - 1];
            nargs = nargs - 1;
        }
        if (nargs > 1) {
            if (typeof arguments[1] === "string") {
                host = arguments[1];
                if (nargs > 2 && typeof arguments[2] === "number") {
                    backlog = arguments[2];
                }
            } else if (typeof arguments[1] === "number") {
                backlog = arguments[1];
            }
        }
        _validateHost(host, "host");
        port = _validatePort(port, "port", true);
    }
    if (cb) {
        self.once("listening", cb);
    }
    if (pathListen !== null) {
        try {
            var fsMod = require("fs");
            try { fsMod.unlinkSync(pathListen); } catch (_u) { /* ignore */ }
        } catch (_fs) { /* ignore */ }
        var uhandle = _nb.unixListen(pathListen, backlog);
        if (!uhandle) {
            var uerr = new Error("listen ENOENT: unix listen failed " + pathListen);
            uerr.code = "ENOENT";
            uerr.syscall = "listen";
            uerr.address = pathListen;
            setTimeout(function () { self.emit("error", uerr); }, 0);
            return self;
        }
        self._handle = uhandle;
        self._listening = true;
        self._unixPath = pathListen;
        setTimeout(function () { self.emit("listening"); }, 0);
        // Do not start TCP accept polling on AF_UNIX listeners.
        return self;
    }
    var handle = _nb.tcpListen(host, port, backlog);
    if (handle === 0) {
        var err = new Error("listen EADDRINUSE: address already in use " + host + ":" + port);
        err.code = "EADDRINUSE";
        err.syscall = "listen";
        err.address = host;
        err.port = port;
        // Defer error emission so listeners can be attached
        setTimeout(function() {
            self.emit("error", err);
        }, 0);
        return self;
    }
    self._handle = handle;
    self._listening = true;
    self._host = host;
    try {
        var addrInfo = self.address();
        if (addrInfo && addrInfo.family != null) {
            var famKey = String(addrInfo.family);
            self._connectionKey = famKey.slice(-1) + ":" + addrInfo.address + ":0";
        }
    } catch (_ak) { /* ignore */ }
    // Emit listening asynchronously (like Node.js — nextTick semantics)
    setTimeout(function() {
        self.emit("listening");
    }, 0);
    // Start the accept loop
    self._acceptLoop();
    return self;
};
/**
 * Internal: continuously poll for new connections.
 */
Server.prototype._acceptLoop = function() {
    var self = this;
    if (!self._listening || self._closed || self._handle === 0) {
        return;
    }
    _nb.tcpAcceptNb(self._handle, function(clientHandle, errCode) {
        if (self._closed || !self._listening) {
            return;
        }
        if (errCode !== 0 || clientHandle === 0) {
            // Accept failed — retry after a short delay
            setTimeout(function() {
                self._acceptLoop();
            }, 10);
            return;
        }
        self._connections = self._connections + 1;
        // Wrap the raw handle in a Socket
        var socket = new Socket({
            allowHalfOpen: self.allowHalfOpen
        });
        socket._handle = clientHandle;
        socket._connecting = false;
        socket.readable = true;
        socket.writable = true;
        // Populate address info
        var peerStr = _nb.tcpPeerAddr(clientHandle);
        var peer = _parseAddr(peerStr);
        socket.remoteAddress = peer.address;
        socket.remotePort = peer.port;
        socket.remoteFamily = peer.family;
        var localStr = _nb.tcpLocalAddr(clientHandle);
        var local = _parseAddr(localStr);
        socket.localAddress = local.address;
        socket.localPort = local.port;
        // Keep the socket object alive (GC root) for the duration of the connection
        self._sockets.push(socket);
        // Track close
        socket.on("close", function() {
            self._connections = self._connections - 1;
            // Remove from _sockets so GC can collect it
            var _si = self._sockets.indexOf(socket);
            if (_si >= 0) { self._sockets.splice(_si, 1); }
        });
        self.emit("connection", socket);
        // Start reading on the socket unless pauseOnConnect
        if (!self.pauseOnConnect) {
            socket._startReading();
        }
        // Continue accepting
        self._acceptLoop();
    });
};
/**
 * close(cb) — stops the server from accepting new connections.
 */
Server.prototype.close = function(cb) {
    var self = this;
    if (cb) {
        self.once("close", cb);
    }
    if (!self._listening) {
        // Already closed — emit 'close' on next tick
        setTimeout(function() {
            self.emit("close");
        }, 0);
        return self;
    }
    self._listening = false;
    self._closed = true;
    if (self._handle !== 0) {
        _nb.tcpListenerClose(self._handle);
        self._handle = 0;
    }
    if (self._unixPath) {
        try { require("fs").unlinkSync(self._unixPath); } catch (_u) { /* ignore */ }
        self._unixPath = undefined;
    }
    // Emit close asynchronously
    setTimeout(function() {
        self.emit("close");
    }, 0);
    return self;
};
/**
 * address() — returns { port, family, address } of the listener.
 */
Server.prototype.address = function() {
    if (this._handle === 0) {
        return null;
    }
    var port = _nb.tcpListenerPort(this._handle);
    var addr = this._host || "0.0.0.0";
    var fam = (addr.indexOf(":") !== -1) ? "IPv6" : "IPv4";
    return {
        address: addr,
        family: fam,
        port: port
    };
};
/**
 * getConnections(cb) — get the number of active connections.
 */
Server.prototype.getConnections = function(cb) {
    var self = this;
    if (cb) {
        cb(null, self._connections);
    }
};
/**
 * ref() / unref() — stubs.
 */
Server.prototype.ref = function() {
    return this;
};
Server.prototype.unref = function() {
    return this;
};
// ── Factory functions ────────────────────────────────────────────────────────
function createServer(options, connectionListener) {
    return new Server(options, connectionListener);
}

function connect() {
    var socket = new Socket();
    return socket.connect.apply(socket, arguments);
}
var createConnection = connect;

// Happy Eyeballs / auto-select-family defaults (Node net.js).
// Stubs so test/common can scale timeouts without a full dual-stack impl.
var _autoSelectFamilyDefault = true;
var _autoSelectFamilyAttemptTimeoutDefault = 250;

function getDefaultAutoSelectFamily() {
    return _autoSelectFamilyDefault;
}
function setDefaultAutoSelectFamily(value) {
    _autoSelectFamilyDefault = Boolean(value);
}
function getDefaultAutoSelectFamilyAttemptTimeout() {
    return _autoSelectFamilyAttemptTimeoutDefault;
}
function setDefaultAutoSelectFamilyAttemptTimeout(value) {
    var n = Number(value);
    if (!(n >= 1)) n = 1;
    if (n < 10) n = 10;
    _autoSelectFamilyAttemptTimeoutDefault = n | 0;
}

// ── SocketAddress (minimal) ──────────────────────────────────────────────────
function SocketAddress(options) {
    options = options || {};
    if (typeof options === "string") {
        this.address = options;
        this.family = isIPv6(options) ? "ipv6" : "ipv4";
        this.port = 0;
        this.flowlabel = 0;
        return;
    }
    this.address = options.address !== undefined ? String(options.address) : "127.0.0.1";
    var fam = options.family !== undefined ? String(options.family).toLowerCase() : "ipv4";
    this.family = fam === "ipv6" || fam === "6" ? "ipv6" : "ipv4";
    this.port = options.port !== undefined ? (options.port >>> 0) : 0;
    this.flowlabel = options.flowlabel !== undefined ? (options.flowlabel >>> 0) : 0;
}

SocketAddress.prototype.toString = function () {
    return this.address;
};

// ── BlockList ────────────────────────────────────────────────────────────────
function _errInvalidArgType(name, expected, actual) {
    var suffix;
    if (actual === null || actual === undefined) suffix = " Received " + actual;
    else if (typeof actual === "object") {
        var ctor = actual.constructor && actual.constructor.name;
        suffix = ctor ? (" Received an instance of " + ctor) : " Received [Object]";
    } else suffix = " Received type " + typeof actual + " (" + String(actual) + ")";
    var err = new TypeError('The "' + name + '" argument must be of type ' + expected + "." + suffix);
    err.code = "ERR_INVALID_ARG_TYPE";
    return err;
}

function _errInvalidArgValue(name, value, reason) {
    var err = new TypeError("The argument '" + name + "' " + (reason || "is invalid") +
        ". Received " + String(value));
    err.code = "ERR_INVALID_ARG_VALUE";
    return err;
}

function _errOutOfRange(name, range, actual) {
    var err = new RangeError('The value of "' + name + '" is out of range. It must be ' +
        range + ". Received " + String(actual));
    err.code = "ERR_OUT_OF_RANGE";
    return err;
}

function _normalizeIPType(ipType, def) {
    // Node: omitted type defaults; explicit null is invalid
    if (ipType === undefined) return def || "ipv4";
    if (typeof ipType !== "string") {
        throw _errInvalidArgType("type", "string", ipType);
    }
    var t = ipType.toLowerCase();
    if (t !== "ipv4" && t !== "ipv6") {
        throw _errInvalidArgValue("type", ipType, "must be 'ipv4' or 'ipv6'");
    }
    return t;
}

function _ipv4ToInt(addr) {
    var parts = String(addr).split(".");
    if (parts.length !== 4) return null;
    var n = 0;
    for (var i = 0; i < 4; i++) {
        if (parts[i] === "" || !_isDigit(parts[i].charAt(0))) return null;
        var o = Number(parts[i]);
        if (!Number.isInteger(o) || o < 0 || o > 255) return null;
        n = ((n << 8) >>> 0) + o;
    }
    return n >>> 0;
}

function _intToIpv4(n) {
    n = n >>> 0;
    return ((n >>> 24) & 255) + "." + ((n >>> 16) & 255) + "." +
        ((n >>> 8) & 255) + "." + (n & 255);
}

function _parseIpv6Parts(addr) {
    addr = String(addr).toLowerCase();
    // IPv4-mapped: ::ffff:a.b.c.d
    var lastColon = addr.lastIndexOf(":");
    var mappedV4 = null;
    if (lastColon !== -1 && addr.indexOf(".", lastColon) !== -1) {
        var v4part = addr.substring(lastColon + 1);
        var v4 = _ipv4ToInt(v4part);
        if (v4 === null) return null;
        mappedV4 = v4;
        addr = addr.substring(0, lastColon + 1) +
            ((v4 >>> 16) & 0xffff).toString(16) + ":" + (v4 & 0xffff).toString(16);
    }
    var halves = addr.split("::");
    if (halves.length > 2) return null;
    var head = halves[0] === "" ? [] : halves[0].split(":");
    var tail = halves.length === 2 ? (halves[1] === "" ? [] : halves[1].split(":")) : [];
    if (halves.length === 1) {
        if (head.length !== 8) return null;
    } else {
        var missing = 8 - head.length - tail.length;
        if (missing < 0) return null;
        var mid = [];
        for (var m = 0; m < missing; m++) mid.push("0");
        head = head.concat(mid, tail);
    }
    if (head.length !== 8) return null;
    var parts = [];
    for (var i = 0; i < 8; i++) {
        if (head[i] === "" || head[i].length > 4) return null;
        for (var j = 0; j < head[i].length; j++) {
            if (!_isHexChar(head[i].charAt(j))) return null;
        }
        parts.push(parseInt(head[i] || "0", 16));
    }
    return { parts: parts, mappedV4: mappedV4 };
}

function _ipv6ToBytes(addr) {
    var p = _parseIpv6Parts(addr);
    if (!p) return null;
    var bytes = [];
    for (var i = 0; i < 8; i++) {
        bytes.push((p.parts[i] >> 8) & 0xff);
        bytes.push(p.parts[i] & 0xff);
    }
    return bytes;
}

function _ipv6Compare(a, b) {
    for (var i = 0; i < 16; i++) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
    }
    return 0;
}

function _formatIpv6(parts) {
    // Compress longest run of zeros to :: (Node rules label style)
    var bestStart = -1;
    var bestLen = 0;
    var i = 0;
    while (i < 8) {
        if (parts[i] === 0) {
            var j = i;
            while (j < 8 && parts[j] === 0) j++;
            var len = j - i;
            if (len > bestLen) {
                bestStart = i;
                bestLen = len;
            }
            i = j;
        } else {
            i++;
        }
    }
    if (bestLen < 2) {
        var hextets = [];
        for (var h = 0; h < 8; h++) hextets.push(parts[h].toString(16));
        return hextets.join(":");
    }
    var head = [];
    for (var a = 0; a < bestStart; a++) head.push(parts[a].toString(16));
    var tail = [];
    for (var b = bestStart + bestLen; b < 8; b++) tail.push(parts[b].toString(16));
    if (head.length === 0 && tail.length === 0) return "::";
    if (head.length === 0) return "::" + tail.join(":");
    if (tail.length === 0) return head.join(":") + "::";
    return head.join(":") + "::" + tail.join(":");
}

function _isSocketAddress(v) {
    return v instanceof SocketAddress ||
        (v && typeof v === "object" && typeof v.address === "string" &&
         (v.family === "ipv4" || v.family === "ipv6" || v.family === "IPv4" || v.family === "IPv6"));
}

function _addrAndType(address, ipType) {
    if (_isSocketAddress(address)) {
        var fam = String(address.family).toLowerCase();
        return {
            address: address.address,
            type: fam === "ipv6" ? "ipv6" : "ipv4"
        };
    }
    if (typeof address !== "string") {
        throw _errInvalidArgType("address", "string", address);
    }
    return { address: address, type: _normalizeIPType(ipType, "ipv4") };
}

function BlockList() {
    this._rules = [];
}

Object.defineProperty(BlockList.prototype, "rules", {
    get: function () {
        var out = [];
        for (var i = this._rules.length - 1; i >= 0; i--) {
            out.push(this._rules[i].label);
        }
        return out;
    }
});

BlockList.prototype.addAddress = function (address, ipType) {
    var at = _addrAndType(address, ipType);
    var addType = at.type;
    var addAddr = at.address;
    if (addType === "ipv4") {
        var n = _ipv4ToInt(addAddr);
        if (n === null) throw _errInvalidArgValue("address", addAddr, "is invalid");
        this._rules.push({
            kind: "address",
            type: "ipv4",
            start: n,
            end: n,
            label: "Address: IPv4 " + addAddr
        });
    } else {
        var bytes = _ipv6ToBytes(addAddr);
        if (!bytes) throw _errInvalidArgValue("address", addAddr, "is invalid");
        var parsed = _parseIpv6Parts(addAddr);
        this._rules.push({
            kind: "address",
            type: "ipv6",
            startBytes: bytes,
            endBytes: bytes,
            mappedV4: parsed ? parsed.mappedV4 : null,
            label: "Address: IPv6 " + addAddr
        });
    }
};

BlockList.prototype.addRange = function (start, end, ipType) {
    var sAt = _addrAndType(start, ipType);
    var eAt;
    if (_isSocketAddress(end)) {
        eAt = _addrAndType(end, ipType);
    } else if (typeof end !== "string") {
        throw _errInvalidArgType("end", "string", end);
    } else {
        eAt = { address: end, type: sAt.type };
    }
    var rangeType = sAt.type;
    if (rangeType === "ipv4") {
        var s = _ipv4ToInt(sAt.address);
        var e = _ipv4ToInt(eAt.address);
        if (s === null || e === null) throw _errInvalidArgValue("address", start, "is invalid");
        if (e < s) throw _errInvalidArgValue("end", end, "must be greater than or equal to start");
        this._rules.push({
            kind: "range",
            type: "ipv4",
            start: s,
            end: e,
            label: "Range: IPv4 " + sAt.address + "-" + eAt.address
        });
    } else {
        var sb = _ipv6ToBytes(sAt.address);
        var eb = _ipv6ToBytes(eAt.address);
        if (!sb || !eb) throw _errInvalidArgValue("address", start, "is invalid");
        if (_ipv6Compare(eb, sb) < 0) {
            throw _errInvalidArgValue("end", end, "must be greater than or equal to start");
        }
        this._rules.push({
            kind: "range",
            type: "ipv6",
            startBytes: sb,
            endBytes: eb,
            label: "Range: IPv6 " + sAt.address + "-" + eAt.address
        });
    }
};

BlockList.prototype.addSubnet = function (network, prefix, ipType) {
    var at = _addrAndType(network, ipType);
    var subType = at.type;
    var netAddr = at.address;
    if (typeof prefix !== "number") {
        throw _errInvalidArgType("prefix", "number", prefix);
    }
    if (!Number.isInteger(prefix) || Number.isNaN(prefix)) {
        throw _errOutOfRange("prefix", "an integer", prefix);
    }
    if (subType === "ipv4") {
        if (prefix < 0 || prefix > 32) throw _errOutOfRange("prefix", ">= 0 && <= 32", prefix);
        var n = _ipv4ToInt(netAddr);
        if (n === null) throw _errInvalidArgValue("network", netAddr, "is invalid");
        var mask = prefix === 0 ? 0 : ((0xffffffff << (32 - prefix)) >>> 0);
        var base = (n & mask) >>> 0;
        var end = (base | (~mask >>> 0)) >>> 0;
        this._rules.push({
            kind: "subnet",
            type: "ipv4",
            start: base,
            end: end,
            label: "Subnet: IPv4 " + _intToIpv4(base) + "/" + prefix
        });
    } else {
        if (prefix < 0 || prefix > 128) throw _errOutOfRange("prefix", ">= 0 && <= 128", prefix);
        var bytes = _ipv6ToBytes(netAddr);
        if (!bytes) throw _errInvalidArgValue("network", netAddr, "is invalid");
        var startBytes = bytes.slice();
        var endBytes = bytes.slice();
        for (var i = 0; i < 16; i++) {
            var bitStart = i * 8;
            if (bitStart + 8 <= prefix) {
                // keep network bits
            } else if (bitStart >= prefix) {
                startBytes[i] = 0;
                endBytes[i] = 0xff;
            } else {
                var keep = prefix - bitStart;
                var bmask = (0xff << (8 - keep)) & 0xff;
                startBytes[i] = bytes[i] & bmask;
                endBytes[i] = startBytes[i] | (~bmask & 0xff);
            }
        }
        var parts = [];
        for (var p = 0; p < 8; p++) {
            parts.push((startBytes[p * 2] << 8) | startBytes[p * 2 + 1]);
        }
        this._rules.push({
            kind: "subnet",
            type: "ipv6",
            startBytes: startBytes,
            endBytes: endBytes,
            label: "Subnet: IPv6 " + _formatIpv6(parts) + "/" + prefix
        });
    }
};

BlockList.prototype.check = function (address, ipType) {
    var checkAddr;
    var checkType;
    if (_isSocketAddress(address)) {
        var at = _addrAndType(address, ipType);
        checkAddr = at.address;
        checkType = at.type;
    } else {
        if (typeof address !== "string") {
            throw _errInvalidArgType("address", "string", address);
        }
        if (ipType !== undefined && ipType !== null && typeof ipType !== "string") {
            throw _errInvalidArgType("type", "string", ipType);
        }
        checkAddr = address;
        // Node defaults omitted type to ipv4 (do not auto-detect from address).
        if (ipType !== undefined && ipType !== null) {
            checkType = _normalizeIPType(ipType, "ipv4");
        } else {
            checkType = "ipv4";
        }
    }

    // Cross-family: IPv4-mapped IPv6 (::ffff:x.x.x.x) checks against IPv4 rules
    var v4 = null;
    var v6bytes = null;
    if (checkType === "ipv4") {
        v4 = _ipv4ToInt(checkAddr);
        if (v4 === null) return false;
    } else {
        v6bytes = _ipv6ToBytes(checkAddr);
        if (!v6bytes) return false;
        // Detect ::ffff:IPv4
        var mapped = true;
        for (var mi = 0; mi < 10; mi++) {
            if (v6bytes[mi] !== 0) { mapped = false; break; }
        }
        if (mapped && v6bytes[10] === 0xff && v6bytes[11] === 0xff) {
            v4 = ((v6bytes[12] << 24) | (v6bytes[13] << 16) | (v6bytes[14] << 8) | v6bytes[15]) >>> 0;
        }
    }

    for (var i = 0; i < this._rules.length; i++) {
        var rule = this._rules[i];
        if (rule.type === "ipv4") {
            if (v4 !== null && v4 >= rule.start && v4 <= rule.end) return true;
        } else if (checkType === "ipv6" && v6bytes) {
            if (_ipv6Compare(v6bytes, rule.startBytes) >= 0 &&
                _ipv6Compare(v6bytes, rule.endBytes) <= 0) {
                return true;
            }
        }
    }

    // When checking IPv4 against IPv6-mapped address rules (addAddress ::ffff:1.1.1.2)
    if (checkType === "ipv4" && v4 !== null) {
        for (var j = 0; j < this._rules.length; j++) {
            var r = this._rules[j];
            if (r.type === "ipv6" && r.mappedV4 !== null && r.mappedV4 !== undefined) {
                if (r.kind === "address" && r.mappedV4 === v4) return true;
            }
        }
    }

    return false;
};

BlockList.prototype[Symbol.for("nodejs.util.inspect.custom")] = function (depth, options) {
    if (depth !== null && depth !== undefined && depth < 0) {
        return "[BlockList]";
    }
    return "BlockList { rules: " + JSON.stringify(this.rules) + " }";
};

BlockList.isBlockList = function (obj) {
    return obj instanceof BlockList;
};

BlockList.prototype.toJSON = function () {
    return this.rules.slice().reverse();
};

BlockList.prototype.fromJSON = function (data) {
    var rules;
    if (typeof data === "string") {
        try { rules = JSON.parse(data); } catch (_e) {
            throw _errInvalidArgType("data", "Array", data);
        }
    } else {
        rules = data;
    }
    if (!Array.isArray(rules)) {
        throw _errInvalidArgType("data", "Array", data);
    }
    for (var i = 0; i < rules.length; i++) {
        if (typeof rules[i] !== "string") {
            throw _errInvalidArgType("data[" + i + "]", "string", rules[i]);
        }
    }
    // Append rules (Node fromJSON accumulates across calls).
    for (var r = 0; r < rules.length; r++) {
        var line = rules[r];
        // "Address: IPv4 1.2.3.4" / "Range: IPv4 a-b" / "Subnet: IPv6 x::/64"
        if (line.indexOf("Address: ") === 0) {
            var arest = line.slice("Address: ".length);
            var aParts = arest.split(" ");
            if (aParts.length >= 2) {
                var aType = aParts[0].toLowerCase() === "ipv6" ? "ipv6" : "ipv4";
                try { this.addAddress(aParts[1], aType); } catch (_ae) { /* ignore bad */ }
            }
        } else if (line.indexOf("Range: ") === 0) {
            var rrest = line.slice("Range: ".length);
            var rParts = rrest.split(" ");
            if (rParts.length >= 2) {
                var rType = rParts[0].toLowerCase() === "ipv6" ? "ipv6" : "ipv4";
                var ends = rParts[1].split("-");
                if (ends.length === 2) {
                    try { this.addRange(ends[0], ends[1], rType); } catch (_re) { /* ignore */ }
                }
            }
        } else if (line.indexOf("Subnet: ") === 0) {
            var srest = line.slice("Subnet: ".length);
            var sParts = srest.split(" ");
            if (sParts.length >= 2) {
                var sType = sParts[0].toLowerCase() === "ipv6" ? "ipv6" : "ipv4";
                var cidr = sParts[1].split("/");
                if (cidr.length === 2) {
                    try { this.addSubnet(cidr[0], Number(cidr[1]), sType); } catch (_se) { /* ignore */ }
                }
            }
        }
        // else ignore invalid rule strings
    }
};

// ── Exports ──────────────────────────────────────────────────────────────────
module.exports = {
    Socket: Socket,
    Server: Server,
    SocketAddress: SocketAddress,
    BlockList: BlockList,
    createServer: createServer,
    connect: connect,
    createConnection: createConnection,
    isIP: isIP,
    isIPv4: isIPv4,
    isIPv6: isIPv6,
    getDefaultAutoSelectFamily: getDefaultAutoSelectFamily,
    setDefaultAutoSelectFamily: setDefaultAutoSelectFamily,
    getDefaultAutoSelectFamilyAttemptTimeout: getDefaultAutoSelectFamilyAttemptTimeout,
    setDefaultAutoSelectFamilyAttemptTimeout: setDefaultAutoSelectFamilyAttemptTimeout
};
// For tls.js (TLSSocket shares the write queue and the Buffer reads); kept off
// the enumerable surface of require("net").
Object.defineProperty(module.exports, "_internals", {
    value: { installWriteQueue: _installWriteQueue, bufferFromPtr: _bufferFromPtr }
});