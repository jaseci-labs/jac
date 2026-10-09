// node:tls — TLS/SSL module
// Phase 6.7 — wraps the native __net TLS bridge with Node.js EventEmitter API.
//
// Reference: https://nodejs.org/api/tls.html
// Bun ref:   bun/src/js/node/tls.ts

var EventEmitter = require("events");
var netModule = require("net");
var _nb = __net; // native bridge
var _netInternals = netModule._internals;

// cert / key / ca options as the PEM text the native context loads: Node takes
// strings, Buffers or arrays of them (native treats a string starting with
// "-" as PEM content, anything else as a file path).
function _pemOption(v) {
    if (v === undefined || v === null || v === false) { return ""; }
    if (Array.isArray(v)) {
        var parts = [];
        for (var i = 0; i < v.length; i++) {
            var pv = _pemOption(v[i] && v[i].pem !== undefined ? v[i].pem : v[i]);
            if (pv) { parts.push(pv); }
        }
        return parts.join("\n");
    }
    if (typeof v === "string") { return v.replace(/^\s+/, ""); }
    if (typeof v === "object" && typeof v.byteLength === "number") {
        var B = globalThis.Buffer || require("buffer").Buffer;
        return B.from(v.buffer !== undefined ? v : new Uint8Array(v)).toString("utf8").replace(/^\s+/, "");
    }
    return String(v);
}

// ── Constants ────────────────────────────────────────────────────────────────

var DEFAULT_MIN_VERSION = "TLSv1.2";
var DEFAULT_MAX_VERSION = "TLSv1.3";

// ── Helper: parse "ip:port" ──────────────────────────────────────────────────

function _parseAddr(addrStr) {
    if (!addrStr || typeof addrStr !== "string") {
        return { address: "0.0.0.0", port: 0, family: "IPv4" };
    }
    var idx = addrStr.lastIndexOf(":");
    if (idx === -1) { return { address: addrStr, port: 0, family: "IPv4" }; }
    var addr = addrStr.substring(0, idx);
    var port = parseInt(addrStr.substring(idx + 1), 10) || 0;
    var family = (addr.indexOf(":") !== -1) ? "IPv6" : "IPv4";
    return { address: addr, port: port, family: family };
}

// ── TLSSocket ────────────────────────────────────────────────────────────────

/**
 * TLSSocket — a TLS connection wrapping either a new TCP connection
 * or an existing net.Socket.
 *
 * Events: all net.Socket events + 'secureConnect', 'OCSPResponse', 'keylog'
 *
 * The native bridge uses negative handle IDs for TLS sockets.
 */
class TLSSocket extends EventEmitter {
    constructor(socket, options) {
        super();
        options = options || {};

        this._handle = 0;               // native TLS handle (negative)
        this._destroyed = false;
        this._connecting = false;
        this._ended = false;
        this._writableEnded = false;
        this._reading = false;
        this._readPaused = false;
        this._timeoutMs = 0;
        this._timeoutTimer = null;
        this._servername = options.servername || "";

        this.readable = true;
        this.writable = true;
        this.encrypted = true;
        this.authorized = false;
        this.authorizationError = null;

        this.allowHalfOpen = options.allowHalfOpen || false;
        this.bytesRead = 0;
        this.bytesWritten = 0;

        this.remoteAddress = undefined;
        this.remotePort = undefined;
        this.remoteFamily = undefined;
        this.localAddress = undefined;
        this.localPort = undefined;
    }

    get destroyed() { return this._destroyed; }

    get readyState() {
        if (this._destroyed) { return "closed"; }
        if (this._connecting) { return "opening"; }
        if (this._handle === 0) { return "closed"; }
        if (this.readable && this.writable) { return "open"; }
        if (this.readable && !this.writable) { return "readOnly"; }
        if (!this.readable && this.writable) { return "writeOnly"; }
        return "closed";
    }

    // ── TLS-specific stubs ──────────────────────────────────────────────────

    /** getPeerCertificate(detailed) — stub */
    getPeerCertificate() { return {}; }

    /** getCipher() — stub */
    getCipher() { return { name: "unknown", standardName: "unknown", version: "TLSv1.3" }; }

    /** getProtocol() — stub */
    getProtocol() { return "TLSv1.3"; }

    // ── I/O ──────────────────────────────────────────────────────────────────

    /** Internal: start the async read loop using TLS read. */
    _startReading() {
        var self = this;
        if (this._reading || this._destroyed || this._handle === 0) { return; }
        this._reading = true;

        function readOne() {
            if (self._destroyed || self._handle === 0) { self._reading = false; return; }
            if (self._readPaused) { self._reading = false; return; }

            if (self._binaryReads) {
                // Buffers, byte-exact (the HTTP server and client switch to these).
                _nb.tlsReadBinaryNb(self._handle, 65536, function(ptr, len, isEOF) {
                    if (self._destroyed) {
                        if (ptr) { globalThis.__buf.free(ptr); }
                        return;
                    }
                    self._resetTimeout();
                    if (len > 0) {
                        var bchunk = _netInternals.bufferFromPtr(ptr, len);
                        globalThis.__buf.free(ptr);
                        self.bytesRead += len;
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
            _nb.tlsReadNb(self._handle, 65536, function(chunk, isEOF) {
                if (self._destroyed) { return; }
                self._resetTimeout();

                if (isEOF || chunk === "") {
                    self._onReadEOF();
                    return;
                }

                self.bytesRead += chunk.length;
                self.emit("data", chunk);
                readOne();
            });
        }

        readOne();
    }

    /** Peer closed (close_notify / EOF): shared by the text and Buffer reads. */
    _onReadEOF() {
        this._ended = true;
        this.readable = false;
        this._reading = false;
        if (this._readableState) {
            this._readableState.ended = true;
            this._readableState.endEmitted = true;
        }
        this.emit("end");
        if (!this.allowHalfOpen) {
            this.writable = false;
            this.destroy();
        }
    }

    /** Switch 'data' to Buffers (tlsReadBinaryNb) — see net.Socket. */
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

    /** destroy(err) */
    destroy(err) {
        if (this._destroyed) { return this; }
        this._destroyed = true;
        this._reading = false;
        this.readable = false;
        this.writable = false;
        this._wqDiscard(err);

        if (this._timeoutTimer !== null) {
            clearTimeout(this._timeoutTimer);
            this._timeoutTimer = null;
        }

        if (this._handle !== 0) {
            _nb.tlsClose(this._handle);
            this._handle = 0;
        }

        if (err) { this.emit("error", err); }
        this.emit("close", !!err);
        return this;
    }

    // ── Timeout ───────────────────────────────────────────────────────────────

    /** setTimeout(ms, cb) */
    setTimeout(ms, cb) {
        if (ms === 0 || ms === undefined) {
            this._timeoutMs = 0;
            if (this._timeoutTimer !== null) {
                clearTimeout(this._timeoutTimer);
                this._timeoutTimer = null;
            }
            return this;
        }
        this._timeoutMs = ms;
        if (cb) { this.once("timeout", cb); }
        this._resetTimeout();
        return this;
    }

    _resetTimeout() {
        var self = this;
        if (this._timeoutMs <= 0) { return; }
        if (this._timeoutTimer !== null) { clearTimeout(this._timeoutTimer); }
        this._timeoutTimer = setTimeout(function() {
            self.emit("timeout");
        }, this._timeoutMs);
    }

    // ── Stream-compat stubs ──────────────────────────────────────────────────

    setEncoding() { return this; }

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

    ref() { return this; }
    unref() { return this; }

    address() {
        return { address: this.localAddress, port: this.localPort, family: this.remoteFamily || "IPv4" };
    }
}

_netInternals.installWriteQueue(TLSSocket.prototype);

// ── tls.connect ──────────────────────────────────────────────────────────────

/**
 * tls.connect(options, cb) — creates a TLSSocket and performs handshake.
 *
 * Options:
 *   host / hostname — remote host (default "localhost")
 *   port — remote port (required)
 *   servername — the name SNI announces and the server certificate must match
 *                (default: host)
 *   rejectUnauthorized — false skips server certificate verification
 */
function tlsConnect(options, cb) {
    if (typeof options === "number") {
        // tls.connect(port, host, options, cb) — collapsed form
        var port = options;
        var host = "localhost";
        if (typeof arguments[1] === "string") {
            host = arguments[1];
            options = arguments[2] || {};
            cb = arguments[3];
        } else if (typeof arguments[1] === "object") {
            options = arguments[1];
            cb = arguments[2];
        } else {
            cb = arguments[1];
            options = {};
        }
        options.port = port;
        options.host = host;
    }

    var socket = new TLSSocket(null, options);
    var hostname = options.host || options.hostname || "localhost";
    var port = options.port;
    var servername = options.servername || hostname;

    socket._connecting = true;
    socket._servername = servername;

    if (cb) { socket.once("secureConnect", cb); }

    var rejectUnauthorized = options.rejectUnauthorized !== false;
    var alpnStr = "";
    if (options.ALPNProtocols && options.ALPNProtocols.length > 0) {
        alpnStr = options.ALPNProtocols.join(",");
    }

    _nb.tlsConnectNb(hostname, port, function(handle, errCode) {
        if (socket._destroyed) { return; }

        if (errCode !== 0 || handle === 0) {
            socket._connecting = false;
            socket._wqDiscard();
            var err;
            if (errCode === 1) { // SSL_ERROR_SSL — certificate verification or protocol error
                err = new Error("unable to verify the first certificate");
                err.code = "UNABLE_TO_VERIFY_LEAF_SIGNATURE";
            } else {
                err = new Error("connect ECONNREFUSED " + hostname + ":" + port);
                err.code = "ECONNREFUSED";
            }
            socket.emit("error", err);
            socket.emit("close", true);
            return;
        }

        socket._handle = handle;
        socket._connecting = false;
        socket.authorized = true; // TLS handshake succeeded

        // Read negotiated ALPN protocol
        var negotiated = _nb.tlsGetAlpn(handle);
        socket.alpnProtocol = negotiated || false;

        // Populate address fields via native tcpPeerAddr
        // (TLS handles are negative; peer/local addr not directly accessible — use defaults)
        socket.remoteAddress = hostname;
        socket.remotePort = port;
        socket.remoteFamily = "IPv4";

        socket.emit("secureConnect");
        socket.emit("connect");
        socket.emit("ready");

        // Start reading
        socket._startReading();
        // Send what was written during the handshake (and finish a pending end())
        socket._flushWrites();
    }, rejectUnauthorized, alpnStr, servername);

    return socket;
}

// ── createSecureContext ───────────────────────────────────────────────────────

function createSecureContext(options) {
    options = options || {};
    var ctx = { context: null, options: options };
    // If cert/key provided, create a native server context
    if (options.cert && options.key) {
        var handle = _nb.tlsCreateServerCtx(_pemOption(options.cert), _pemOption(options.key));
        if (handle > 0) { ctx.context = handle; }
    }
    return ctx;
}

// ── TLS Server ───────────────────────────────────────────────────────────────

/**
 * tls.Server — a TLS server that wraps a TCP listener.
 *
 * Options:
 *   cert — path to PEM certificate file (or string)
 *   key  — path to PEM private key file (or string)
 *   ALPNProtocols — array of ALPN protocol names
 *   requestCert, rejectUnauthorized — stubs
 *
 * Events: 'secureConnection', 'tlsClientError', 'listening', 'close', 'error'
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

    this._handle = 0;
    this._ctxHandle = 0;
    this._connections = 0;
    this._listening = false;
    this._closed = false;
    this.maxConnections = 0;

    this.allowHalfOpen = options.allowHalfOpen || false;
    this.pauseOnConnect = options.pauseOnConnect || false;

    this._cert = _pemOption(options.cert);
    this._key = _pemOption(options.key);
    this._alpn = options.ALPNProtocols || null;

    if (connectionListener) {
        this.on("secureConnection", connectionListener);
    }
}
Server.prototype = Object.create(EventEmitter.prototype);
Server.prototype.constructor = Server;
Server.prototype.listen = function() {
    var self = this;
    var port = 0, host = "0.0.0.0", backlog = 128, cb = null;

    if (typeof arguments[0] === "object") {
        var opts = arguments[0];
        port = opts.port || 0;
        host = opts.host || "0.0.0.0";
        backlog = opts.backlog || 128;
        cb = arguments[1];
    } else {
        port = arguments[0] || 0;
        if (typeof arguments[1] === "function") {
            cb = arguments[1];
        } else if (typeof arguments[1] === "string") {
            host = arguments[1];
            if (typeof arguments[2] === "function") {
                cb = arguments[2];
            } else if (typeof arguments[2] === "number") {
                backlog = arguments[2];
                cb = arguments[3];
            }
        } else if (typeof arguments[1] === "number") {
            backlog = arguments[1];
            cb = arguments[2];
        }
    }

    if (cb) { this.once("listening", cb); }

    if (!this._cert || !this._key) {
        var cerr = new Error("tls.createServer requires cert and key options");
        cerr.code = "ERR_TLS_CERT_KEY_REQUIRED";
        setTimeout(function() { self.emit("error", cerr); }, 0);
        return this;
    }

    var alpnStr = "";
    if (this._alpn && this._alpn.length > 0) {
        alpnStr = this._alpn.join(",");
    }

    var ctxH = _nb.tlsCreateServerCtx(this._cert, this._key, alpnStr);
    if (ctxH <= 0) {
        var ctxerr = new Error("Failed to create TLS context — check cert/key paths");
        ctxerr.code = "ERR_TLS_CONTEXT_CREATION";
        setTimeout(function() { self.emit("error", ctxerr); }, 0);
        return this;
    }
    this._ctxHandle = ctxH;

    var handle = _nb.tcpListen(host, port, backlog);
    if (handle === 0) {
        var err = new Error("listen EADDRINUSE: address already in use " + host + ":" + port);
        err.code = "EADDRINUSE";
        err.syscall = "listen";
        err.address = host;
        err.port = port;
        _nb.tlsFreeServerCtx(this._ctxHandle);
        this._ctxHandle = 0;
        setTimeout(function() { self.emit("error", err); }, 0);
        return this;
    }

    this._handle = handle;
    this._listening = true;
    this._host = host;

    setTimeout(function() { self.emit("listening"); }, 0);

    this._acceptLoop();
    return this;
};
Server.prototype._acceptLoop = function() {
    var self = this;
    if (!this._listening || this._closed || this._handle === 0) { return; }

    _nb.tcpAcceptNb(this._handle, function(clientHandle, errCode) {
        if (self._closed || !self._listening) { return; }

        if (errCode !== 0 || clientHandle === 0) {
            setTimeout(function() { self._acceptLoop(); }, 10);
            return;
        }

        _nb.tlsAcceptNb(clientHandle, self._ctxHandle, function(tlsHandle, tlsErr) {
            if (self._closed) {
                if (tlsHandle !== 0) { _nb.tlsClose(tlsHandle); }
                else { _nb.tcpClose(clientHandle); }
                return;
            }

            if (tlsErr !== 0 || tlsHandle === 0) {
                var hErr = new Error("TLS handshake failed");
                hErr.code = "ERR_TLS_HANDSHAKE";
                self.emit("tlsClientError", hErr, null);
                _nb.tcpClose(clientHandle);
                self._acceptLoop();
                return;
            }

            self._connections += 1;

            var socket = new TLSSocket(null, {
                allowHalfOpen: self.allowHalfOpen
            });
            socket._handle = tlsHandle;
            socket._connecting = false;
            socket.readable = true;
            socket.writable = true;
            socket.encrypted = true;
            socket.authorized = true;

            var peerStr = _nb.tcpPeerAddr(clientHandle);
            var peer = _parseAddr(peerStr);
            socket.remoteAddress = peer.address;
            socket.remotePort = peer.port;
            socket.remoteFamily = peer.family;

            if (self._alpn) {
                socket.alpnProtocol = _nb.tlsGetAlpn(tlsHandle) || false;
            } else {
                socket.alpnProtocol = false;
            }

            socket.on("close", function() {
                self._connections -= 1;
            });

            self.emit("secureConnection", socket);

            if (!self.pauseOnConnect) {
                socket._startReading();
            }

            self._acceptLoop();
        });
    });
};
Server.prototype.close = function(cb) {
    var self = this;
    if (cb) { this.once("close", cb); }

    if (!this._listening) {
        setTimeout(function() { self.emit("close"); }, 0);
        return this;
    }

    this._listening = false;
    this._closed = true;

    if (this._handle !== 0) {
        _nb.tcpListenerClose(this._handle);
        this._handle = 0;
    }

    if (this._ctxHandle !== 0) {
        _nb.tlsFreeServerCtx(this._ctxHandle);
        this._ctxHandle = 0;
    }

    setTimeout(function() { self.emit("close"); }, 0);
    return this;
};
Server.prototype.address = function() {
    if (this._handle === 0) { return null; }
    var port = _nb.tcpListenerPort(this._handle);
    var addr = this._host || "0.0.0.0";
    var fam = (addr.indexOf(":") !== -1) ? "IPv6" : "IPv4";
    return { address: addr, family: fam, port: port };
};
Server.prototype.getConnections = function(cb) {
    if (cb) { cb(null, this._connections); }
};
Server.prototype.ref = function() { return this; };
Server.prototype.unref = function() { return this; };
Object.defineProperty(Server.prototype, "listening", {
    get: function() { return this._listening; },
    configurable: true,
    enumerable: true
});

// ── tls.createServer ─────────────────────────────────────────────────────────

function createServer(options, connectionListener) {
    return new Server(options, connectionListener);
}

// ── rootCertificates (stub) ──────────────────────────────────────────────────

var rootCertificates = [];

/**
 * tls.getCACertificates(type) — Node 22+ CA introspection.
 * Returns the bundled root list for 'default'/'bundled'; empty for 'system'
 * until a system-store loader is wired.
 */
function getCACertificates(type) {
    var t = type === undefined || type === null ? "default" : String(type);
    if (t === "default" || t === "bundled") {
        return rootCertificates.slice();
    }
    if (t === "system") {
        return [];
    }
    var err = new TypeError(
        'The "type" argument must be one of: "default", "bundled", "system". Received ' + t
    );
    err.code = "ERR_INVALID_ARG_VALUE";
    throw err;
}

// ── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
    TLSSocket: TLSSocket,
    Server: Server,
    connect: tlsConnect,
    createSecureContext: createSecureContext,
    createServer: createServer,
    getCACertificates: getCACertificates,
    DEFAULT_MIN_VERSION: DEFAULT_MIN_VERSION,
    DEFAULT_MAX_VERSION: DEFAULT_MAX_VERSION,
    rootCertificates: rootCertificates
};
