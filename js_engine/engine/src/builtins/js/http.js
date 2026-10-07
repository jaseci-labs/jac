// node:http — HTTP client and server module
// Phase 6.8 — wraps net.Socket with HTTP/1.1 request/response parsing.
//
// Reference: https://nodejs.org/api/http.html
// Bun ref:   bun/src/js/node/http.ts

var EventEmitter = require("events");
var netModule = require("net");
var core = require("http_core");
var proxyMod = require("http_proxy");

var CRLF = core.CRLF;
var _maxIdleHTTPParsers = core.getMaxIdleHTTPParsers();

// Symbol used by Node's _http_server / connections-checking interval.
var kConnectionsCheckingInterval = Symbol("http.server.connectionsCheckingInterval");

// ── STATUS_CODES ─────────────────────────────────────────────────────────────

var STATUS_CODES = {};
STATUS_CODES[100] = "Continue";
STATUS_CODES[101] = "Switching Protocols";
STATUS_CODES[200] = "OK";
STATUS_CODES[201] = "Created";
STATUS_CODES[202] = "Accepted";
STATUS_CODES[204] = "No Content";
STATUS_CODES[206] = "Partial Content";
STATUS_CODES[301] = "Moved Permanently";
STATUS_CODES[302] = "Found";
STATUS_CODES[303] = "See Other";
STATUS_CODES[304] = "Not Modified";
STATUS_CODES[307] = "Temporary Redirect";
STATUS_CODES[308] = "Permanent Redirect";
STATUS_CODES[400] = "Bad Request";
STATUS_CODES[401] = "Unauthorized";
STATUS_CODES[403] = "Forbidden";
STATUS_CODES[404] = "Not Found";
STATUS_CODES[405] = "Method Not Allowed";
STATUS_CODES[408] = "Request Timeout";
STATUS_CODES[409] = "Conflict";
STATUS_CODES[411] = "Length Required";
STATUS_CODES[413] = "Payload Too Large";
STATUS_CODES[414] = "URI Too Long";
STATUS_CODES[415] = "Unsupported Media Type";
STATUS_CODES[429] = "Too Many Requests";
STATUS_CODES[500] = "Internal Server Error";
STATUS_CODES[501] = "Not Implemented";
STATUS_CODES[502] = "Bad Gateway";
STATUS_CODES[503] = "Service Unavailable";
STATUS_CODES[504] = "Gateway Timeout";

// ── METHODS ──────────────────────────────────────────────────────────────────

var METHODS = [
    "ACL", "BIND", "CHECKOUT", "CONNECT", "COPY", "DELETE", "GET", "HEAD",
    "LINK", "LOCK", "M-SEARCH", "MERGE", "MKACTIVITY", "MKCALENDAR",
    "MKCOL", "MOVE", "NOTIFY", "OPTIONS", "PATCH", "POST", "PRI",
    "PROPFIND", "PROPPATCH", "PURGE", "PUT", "REBIND", "REPORT", "SEARCH",
    "SOURCE", "SUBSCRIBE", "TRACE", "UNBIND", "UNLINK", "UNLOCK",
    "UNSUBSCRIBE"
];

var maxHeaderSize = 16384;
var _defaultHighWaterMark = 16384;
var _defaultHighWaterMarkObjectMode = 16;

function getDefaultHighWaterMark(objectMode) {
    if (objectMode) { return _defaultHighWaterMarkObjectMode; }
    return _defaultHighWaterMark;
}

function setDefaultHighWaterMark(value, objectMode) {
    var n = Number(value);
    if (isNaN(n) || n < 0) { return; }
    if (objectMode) {
        _defaultHighWaterMarkObjectMode = n;
    } else {
        _defaultHighWaterMark = n;
    }
}

// ── Internal: HTTP parser helpers ────────────────────────────────────────────

var _defaultJoinDuplicateHeaders = false;

function _findCRLF(data, from) {
    return core.findCRLF(data, from);
}

function _parseRequestHead(raw, joinDuplicateHeaders) {
    return core.parseRequestHead(raw, joinDuplicateHeaders !== undefined ?
        joinDuplicateHeaders : _defaultJoinDuplicateHeaders);
}

function _parseResponseHead(raw, joinDuplicateHeaders) {
    return core.parseResponseHead(raw, joinDuplicateHeaders !== undefined ?
        joinDuplicateHeaders : _defaultJoinDuplicateHeaders);
}

// ── OutgoingMessage (base for ClientRequest / ServerResponse) ────────────────

class OutgoingMessage extends EventEmitter {
    constructor() {
        super();
        this._headers = {};
        this._headerNames = {};
        this.headersSent = false;
        this._corked = 0;
        this._timeout = 0;
        this._timeoutTimer = null;
        this.strictContentLength = false;
        this._uniqueHeaders = null;
    }

    setHeader(name, value) {
        core.validateHeaderName(name);
        core.validateHeaderValue(name, value);
        var lower = name.toLowerCase();
        if (this._uniqueHeaders) {
            var ui = 0;
            while (ui < this._uniqueHeaders.length) {
                if (this._uniqueHeaders[ui].toLowerCase() === lower) {
                    if (this._headers[lower] !== undefined) {
                        var uerr = new TypeError("Header \"" + name + "\" already set");
                        uerr.code = "ERR_HTTP_HEADERS_SENT";
                        throw uerr;
                    }
                    break;
                }
                ui = ui + 1;
            }
        }
        this._headers[lower] = value;
        this._headerNames[lower] = name;
        return this;
    }

    appendHeader(name, value) {
        core.validateHeaderName(name);
        core.validateHeaderValue(name, value);
        var lower = name.toLowerCase();
        if (this._headers[lower] !== undefined) {
            this._headers[lower] = this._headers[lower] + ", " + value;
        } else {
            this._headers[lower] = value;
            this._headerNames[lower] = name;
        }
        return this;
    }

    getHeader(name) {
        return this._headers[name.toLowerCase()];
    }

    removeHeader(name) {
        var lower = name.toLowerCase();
        delete this._headers[lower];
        delete this._headerNames[lower];
    }

    hasHeader(name) {
        return this._headers[name.toLowerCase()] !== undefined;
    }

    getHeaderNames() {
        return Object.keys(this._headers);
    }

    getHeaders() {
        var result = {};
        var keys = Object.keys(this._headers);
        for (var i = 0; i < keys.length; i++) {
            result[keys[i]] = this._headers[keys[i]];
        }
        return result;
    }

    getRawHeaderNames() {
        var keys = Object.keys(this._headerNames);
        var out = [];
        for (var i = 0; i < keys.length; i++) {
            out.push(this._headerNames[keys[i]]);
        }
        return out;
    }

    setHeaders(headers) {
        if (!headers) { return this; }
        if (typeof headers.entries === "function") {
            var it = headers.entries();
            var step = it.next();
            while (!step.done) {
                this.setHeader(step.value[0], step.value[1]);
                step = it.next();
            }
            return this;
        }
        var keys = Object.keys(headers);
        for (var j = 0; j < keys.length; j++) {
            this.setHeader(keys[j], headers[keys[j]]);
        }
        return this;
    }

    setTimeout(msecs, callback) {
        var self = this;
        this._timeout = msecs;
        if (callback) { this.once("timeout", callback); }
        if (msecs > 0 && this.socket) {
            this._timeoutTimer = setTimeout(function() {
                self.emit("timeout");
            }, msecs);
        }
        return this;
    }

    cork() { this._corked = this._corked + 1; }
    uncork() {
        if (this._corked > 0) { this._corked = this._corked - 1; }
    }

    get writableCorked() { return this._corked; }
    get writableEnded() { return this._ended === true; }
    get writableFinished() { return this.finished === true; }

    pipe() {
        throw new Error("OutgoingMessage.pipe is not implemented");
    }

    destroy(err) {
        if (this.socket) { this.socket.destroy(err); }
        if (err) { this.emit("error", err); }
    }
}

// ── IncomingMessage ──────────────────────────────────────────────────────────

/**
 * http.IncomingMessage — represents a received HTTP request (server) or
 * response (client).  Emits 'data', 'end', 'close' events.
 */
class IncomingMessage extends EventEmitter {
    constructor(socket) {
        super();

        this.socket = socket;
        this.httpVersion = "1.1";
        this._headersCache = undefined;
        this._headersDistinctCache = undefined;
        this.rawHeaders = [];
        this.trailers = {};
        this.rawTrailers = [];
        this.trailersDistinct = {};

        this.method = null;
        this.url = null;
        this.statusCode = null;
        this.statusMessage = null;

        this.complete = false;
        this.readable = true;
        this._encoding = null;
        this._paused = false;
        this._aborted = false;
        this._destroyed = false;
    }

    get headers() {
        if (this._headersCache !== undefined) { return this._headersCache; }
        return {};
    }

    set headers(v) {
        this._headersCache = v;
    }

    get headersDistinct() {
        if (this._headersDistinctCache !== undefined) { return this._headersDistinctCache; }
        if (this._headersCache && this.rawHeaders.length > 0) {
            var fin = core.finalizeHeaders(this.rawHeaders, false);
            this._headersDistinctCache = fin.headersDistinct;
            return this._headersDistinctCache;
        }
        return {};
    }

    get httpVersionMajor() {
        var p = String(this.httpVersion).split(".");
        return Number(p[0]) || 1;
    }

    get httpVersionMinor() {
        var p2 = String(this.httpVersion).split(".");
        return Number(p2[1]) || 1;
    }

    get connection() { return this.socket; }
    get aborted() { return this._aborted; }

    setEncoding(enc) {
        this._encoding = enc;
        return this;
    }

    setTimeout(ms, cb) {
        if (this.socket) { this.socket.setTimeout(ms, cb); }
        return this;
    }

    destroy(err) {
        this._destroyed = true;
        if (this.socket) { this.socket.destroy(err); }
        if (err) { this.emit("error", err); }
    }

    pause() {
        this._paused = true;
        if (this.socket && this.socket.pause) { this.socket.pause(); }
        return this;
    }

    resume() {
        this._paused = false;
        if (this.socket && this.socket.resume) { this.socket.resume(); }
        return this;
    }
}

// ── ServerResponse ───────────────────────────────────────────────────────────

/**
 * http.ServerResponse — writable response object passed to request handler.
 *
 * Reference: https://nodejs.org/api/http.html#class-httpserverresponse
 */
class ServerResponse extends OutgoingMessage {
    constructor(socket, req) {
        super();

        this.socket = socket;
        this.req = req || null;
        this.statusCode = 200;
        this.statusMessage = undefined;
        this.sendDate = true;
        this.finished = false;
        this.strictContentLength = false;
        this._body = "";
        this._ended = false;
        this._uniqueHeaders = null;
    }

    get connection() { return this.socket; }

    writeHead(statusCode, statusMessage, headers) {
        if (typeof statusMessage === "object") {
            headers = statusMessage;
            statusMessage = undefined;
        }
        this.statusCode = statusCode;
        if (statusMessage !== undefined) {
            this.statusMessage = statusMessage;
        }
        if (headers) {
            var keys = Object.keys(headers);
            for (var i = 0; i < keys.length; i++) {
                this.setHeader(keys[i], headers[keys[i]]);
            }
        }
        return this;
    }

    flushHeaders() {
        if (this.headersSent) { return; }
        this._sendHeaders();
    }

    _sendHeaders() {
        if (this.headersSent) { return; }
        this.headersSent = true;

        var statusMsg = this.statusMessage;
        if (statusMsg === undefined) {
            statusMsg = STATUS_CODES[this.statusCode] || "Unknown";
        }

        var head = "HTTP/1.1 " + this.statusCode + " " + statusMsg + CRLF;

        var keys = Object.keys(this._headers);
        for (var i = 0; i < keys.length; i++) {
            var originalName = this._headerNames[keys[i]] || keys[i];
            head = head + originalName + ": " + this._headers[keys[i]] + CRLF;
        }

        // Add Date header if sendDate is true and not already set
        if (this.sendDate && !this._headers["date"]) {
            head = head + "Date: " + new Date().toUTCString() + CRLF;
        }

        this._headerBuf = head;
    }

    write(chunk, encoding, cb) {
        if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
        if (typeof chunk !== "string") { chunk = String(chunk); }

        if (this.rejectNonStandardBodyWrites) {
            var noBody = this.statusCode === 204 || this.statusCode === 304 ||
                (this.statusCode >= 100 && this.statusCode < 200);
            if (noBody && chunk.length > 0) {
                var err = new Error("write after end");
                err.code = "ERR_HTTP_BODY_NOT_ALLOWED";
                throw err;
            }
        }

        if (!this.headersSent) {
            // Streaming — send headers first without Content-Length
            if (!this._headers["transfer-encoding"] && !this._headers["content-length"]) {
                this.setHeader("Transfer-Encoding", "chunked");
            }
            this._sendHeaders();
            this.socket.write(this._headerBuf + CRLF);
        }

        if (this._headers["transfer-encoding"] === "chunked") {
            // Send as chunked
            var hexLen = chunk.length.toString(16);
            this.socket.write(hexLen + CRLF + chunk + CRLF);
        } else {
            this.socket.write(chunk);
        }

        if (cb) { cb(); }
        return true;
    }

    writeContinue() {
        this.socket.write("HTTP/1.1 100 Continue" + CRLF + CRLF);
    }

    writeProcessing() {
        this.socket.write("HTTP/1.1 102 Processing" + CRLF + CRLF);
    }

    writeEarlyHints(hints, callback) {
        var lines = "HTTP/1.1 103 Early Hints" + CRLF;
        if (hints && typeof hints === "object") {
            var keys = Object.keys(hints);
            for (var ei = 0; ei < keys.length; ei++) {
                var hval = hints[keys[ei]];
                if (Array.isArray(hval)) {
                    var vi = 0;
                    while (vi < hval.length) {
                        lines = lines + keys[ei] + ": " + hval[vi] + CRLF;
                        vi = vi + 1;
                    }
                } else {
                    lines = lines + keys[ei] + ": " + hval + CRLF;
                }
            }
        }
        lines = lines + CRLF;
        this.socket.write(lines);
        if (callback) { callback(); }
    }

    addTrailers(headers) {
        if (!headers) { return; }
        var tkeys = Object.keys(headers);
        for (var ti = 0; ti < tkeys.length; ti++) {
            var tl = tkeys[ti].toLowerCase();
            this._trailers = this._trailers || {};
            this._trailers[tl] = headers[tkeys[ti]];
        }
    }

    end(data, encoding, cb) {
        if (typeof data === "function") { cb = data; data = undefined; encoding = undefined; }
        if (typeof encoding === "function") { cb = encoding; encoding = undefined; }

        if (this._ended) { return; }
        this._ended = true;

        if (!this.headersSent) {
            // Non-streaming: send headers + body at once
            var bodyStr = "";
            if (data !== undefined && data !== null) {
                bodyStr = typeof data === "string" ? data : String(data);
            }

            if (!this._headers["content-length"]) {
                this.setHeader("Content-Length", String(bodyStr.length));
            }

            this._sendHeaders();
            var full = this._headerBuf + CRLF + bodyStr;
            this.socket.write(full);
        } else {
            // Headers already sent (streaming mode)
            if (data !== undefined && data !== null) {
                this.write(data);
            }
            if (this._headers["transfer-encoding"] === "chunked") {
                // Send final chunk
                this.socket.write("0" + CRLF + CRLF);
            }
        }

        this.finished = true;
        var self = this;
        // Emit finish asynchronously
        setTimeout(function() {
            self.emit("finish");
            self.emit("close");
        }, 0);

        if (cb) { cb(); }
    }

    get writableEnded() { return this._ended; }
    get writableFinished() { return this.finished; }
}

// ── Server ───────────────────────────────────────────────────────────────────

/**
 * http.Server — an HTTP server built on top of net.Server.
 *
 * Parses incoming HTTP requests from net.Socket data events and provides
 * (req, res) pairs to the request listener.
 *
 * Reference: https://nodejs.org/api/http.html#class-httpserver
 */
function Server(options, requestListener) {
    if (!(this instanceof Server)) {
        return new Server(options, requestListener);
    }
    if (typeof options === "function") {
        requestListener = options;
        options = {};
    }
    options = options || {};

    EventEmitter.init.call(this);

    this.timeout = options.timeout !== undefined ? options.timeout : 0;
    this.keepAliveTimeout = options.keepAliveTimeout !== undefined ? options.keepAliveTimeout : 5000;
    this.keepAliveTimeoutBuffer = options.keepAliveTimeoutBuffer !== undefined ? options.keepAliveTimeoutBuffer : 1000;
    this.maxHeadersCount = options.maxHeadersCount !== undefined ? options.maxHeadersCount : 2000;
    this.headersTimeout = options.headersTimeout !== undefined ? options.headersTimeout : 60000;
    this.requestTimeout = options.requestTimeout !== undefined ? options.requestTimeout : 300000;
    this.connectionsCheckingInterval = options.connectionsCheckingInterval !== undefined ?
        options.connectionsCheckingInterval : 30000;
    this.maxHeaderSize = options.maxHeaderSize !== undefined ? options.maxHeaderSize : maxHeaderSize;
    this.joinDuplicateHeaders = options.joinDuplicateHeaders === true;
    this.requireHostHeader = options.requireHostHeader !== false;
    this.rejectNonStandardBodyWrites = options.rejectNonStandardBodyWrites === true;
    this.optimizeEmptyRequests = options.optimizeEmptyRequests === true;
    this.uniqueHeaders = options.uniqueHeaders || null;
    this.insecureHTTPParser = options.insecureHTTPParser === true;
    this.highWaterMark = options.highWaterMark;
    this.IncomingMessage = options.IncomingMessage || IncomingMessage;
    this.ServerResponse = options.ServerResponse || ServerResponse;
    var self = this;
    this.shouldUpgradeCallback = options.shouldUpgradeCallback || function(req) {
        return self.listenerCount("upgrade") > 0;
    };
    this._activeSockets = [];
    this._connections = 0;
    this._listening = false;
    this._connectionsCheckTimer = null;

    if (requestListener) {
        this.on("request", requestListener);
    }

    // Create net.Server for TCP
    this._server = netModule.createServer(function(socket) {
        self._onConnection(socket);
    });

    // Forward events from net.Server
    this._server.on("error", function(err) { self.emit("error", err); });
    this._server.on("listening", function() {
        self._listening = true;
        self._startConnectionsChecking();
        self.emit("listening");
    });
    this._server.on("close", function() {
        self._listening = false;
        self._stopConnectionsChecking();
        self.emit("close");
    });
}
Server.prototype = Object.create(EventEmitter.prototype);
Server.prototype.constructor = Server;
Server.prototype._startConnectionsChecking = function() {
    if (this.connectionsCheckingInterval <= 0) { return; }
    if (this._connectionsCheckTimer !== null) { return; }
    var self = this;
    var interval = this.connectionsCheckingInterval;
    var timer = setInterval(function() {
        self.closeIdleConnections();
    }, interval);
    this._connectionsCheckTimer = timer;
    this[kConnectionsCheckingInterval] = timer;
};
Server.prototype._stopConnectionsChecking = function() {
    if (this._connectionsCheckTimer !== null) {
        clearInterval(this._connectionsCheckTimer);
        // Node tests assert timer._destroyed after close/asyncDispose.
        if (this._connectionsCheckTimer &&
            typeof this._connectionsCheckTimer === "object") {
            this._connectionsCheckTimer._destroyed = true;
        }
        this._connectionsCheckTimer = null;
    }
};
Server.prototype.listen = function() {
    this._server.listen.apply(this._server, arguments);
    return this;
};
Server.prototype.close = function(cb) {
    this._stopConnectionsChecking();
    // Drain keep-alive sockets so close callbacks run (Node parity).
    this.closeAllConnections();
    this._server.close();
    if (cb) {
        if (typeof cb === "function") {
            cb();
        }
    }
    this.emit("close");
    return this;
};
if (typeof Symbol !== "undefined" && Symbol.asyncDispose) {
    Server.prototype[Symbol.asyncDispose] = function() {
        var self = this;
        return new Promise(function(resolve) {
            self.close(function() { resolve(); });
        });
    };
}
Server.prototype.closeAllConnections = function() {
    var i = 0;
    while (i < this._activeSockets.length) {
        this._activeSockets[i].destroy();
        i = i + 1;
    }
    this._activeSockets = [];
    return this;
};
Server.prototype.closeIdleConnections = function() {
    var j = 0;
    while (j < this._activeSockets.length) {
        var s = this._activeSockets[j];
        if (s && s._httpIdle) {
            s.destroy();
        }
        j = j + 1;
    }
    return this;
};
Server.prototype.setTimeout = function(msecs, callback) {
    this.timeout = msecs;
    if (callback) { this.on("timeout", callback); }
    return this;
};
Server.prototype.address = function() {
    return this._server.address();
};
Server.prototype.ref = function() { return this; };
Server.prototype.unref = function() { return this; };
/**
 * Internal: handle a new TCP connection.
 * Accumulates data, parses HTTP requests, emits 'request' events.
 */
Server.prototype._onConnection = function(socket) {
    var self = this;
    self._connections = self._connections + 1;
    self._activeSockets.push(socket);

    self.emit("connection", socket);

    var buffer = "";
    var currentRes = null;
    var requestHandled = false;
    var headersTimer = null;
    var requestTimer = null;

    function _clearHeaderTimer() {
        if (headersTimer !== null) {
            clearTimeout(headersTimer);
            headersTimer = null;
        }
    }

    function _clearRequestTimer() {
        if (requestTimer !== null) {
            clearTimeout(requestTimer);
            requestTimer = null;
        }
    }

    function _clearKeepAliveTimer(sock) {
        if (sock._keepAliveTimer) {
            clearTimeout(sock._keepAliveTimer);
            sock._keepAliveTimer = null;
        }
    }

    function _scheduleKeepAliveTimer(sock) {
        if (self.keepAliveTimeout <= 0) { return; }
        _clearKeepAliveTimer(sock);
        var ms = self.keepAliveTimeout;
        if (self.keepAliveTimeoutBuffer > 0) {
            ms = ms + self.keepAliveTimeoutBuffer;
        }
        sock._httpIdle = true;
        sock._keepAliveTimer = setTimeout(function() {
            sock.destroy();
        }, ms);
    }

    if (self.headersTimeout > 0) {
        headersTimer = setTimeout(function() {
            var terr = new Error("Headers timeout");
            terr.code = "ERR_HTTP_HEADERS_TIMEOUT";
            socket.destroy(terr);
            self.emit("clientError", terr, socket);
        }, self.headersTimeout);
    }

    socket.on("data", function(chunk) {
        if (socket._httpUpgraded) { return; }
        _clearKeepAliveTimer(socket);
        socket._httpIdle = false;
        buffer = buffer + chunk;

        // Try to parse a request from the buffer
        while (buffer.length > 0) {
            if (buffer.length > self.maxHeaderSize) {
                socket.destroy();
                self.emit("clientError", new Error("Parse Error: Header overflow"), socket);
                return;
            }

            var parsed = _parseRequestHead(buffer, self.joinDuplicateHeaders);
            if (parsed === null) { break; } // need more data

            _clearHeaderTimer();
            if (self.requestTimeout > 0 && requestTimer === null) {
                requestTimer = setTimeout(function() {
                    var rerr = new Error("Request timeout");
                    rerr.code = "ERR_HTTP_REQUEST_TIMEOUT";
                    socket.destroy(rerr);
                    self.emit("clientError", rerr, socket);
                }, self.requestTimeout);
            }

            if (self.requireHostHeader && !self.insecureHTTPParser &&
                parsed.httpVersion !== "1.0" &&
                parsed.headers["host"] === undefined) {
                socket.write("HTTP/1.1 400 Bad Request" + CRLF + CRLF);
                socket.end();
                return;
            }

            var expectVal = parsed.headers["expect"];
            if (expectVal && expectVal.toLowerCase() === "100-continue") {
                socket.write("HTTP/1.1 100 Continue" + CRLF + CRLF);
            }

            var headerCount = parsed.rawHeaders.length / 2;
            if (headerCount > self.maxHeadersCount) {
                var herr = new Error("Parse Error: too many headers");
                herr.code = "HPE_HEADER_OVERFLOW";
                socket.destroy(herr);
                self.emit("clientError", herr, socket);
                return;
            }

            var bodyInfo = core.consumeIncomingBody(buffer, parsed);
            if (bodyInfo === null) { break; }

            var body = bodyInfo.body;
            var msgEnd = bodyInfo.consumed;
            var head = buffer.substring(msgEnd);
            buffer = "";

            var ReqClass = self.IncomingMessage || IncomingMessage;
            var ResClass = self.ServerResponse || ServerResponse;

            var req = new ReqClass(socket);
            req.method = parsed.method;
            req.url = parsed.url;
            req.httpVersion = parsed.httpVersion;
            req._headersDistinctCache = parsed.headersDistinct;
            req.headers = parsed.headers;
            req.rawHeaders = parsed.rawHeaders;
            req.complete = true;
            if (self.highWaterMark !== undefined) {
                req.readableHighWaterMark = self.highWaterMark;
            } else {
                req.readableHighWaterMark = getDefaultHighWaterMark(false);
            }

            _clearHeaderTimer();

            if (self.shouldUpgradeCallback(req) && core.isUpgradeRequest(parsed.headers)) {
                _clearRequestTimer();
                socket._httpUpgraded = true;
                // The upgraded protocol (WebSocket) is binary: from here on the
                // socket delivers Buffers, and `head` is one too (Node passes
                // a Buffer). This runs inside the socket's 'data' handler, so
                // no read is in flight yet — the next chunk is already binary.
                if (typeof socket._useBinaryReads === "function") {
                    socket._useBinaryReads();
                }
                var headBuf = typeof head === "string"
                    ? (globalThis.Buffer || require("buffer").Buffer).from(head) : head;
                self.emit("upgrade", req, socket, headBuf);
                return;
            }

            if (self.requestTimeout > 0 && requestTimer === null) {
                requestTimer = setTimeout(function() {
                    var rerr = new Error("Request timeout");
                    rerr.code = "ERR_HTTP_REQUEST_TIMEOUT";
                    socket.destroy(rerr);
                    self.emit("clientError", rerr, socket);
                }, self.requestTimeout);
            }

            if (body.length > 0) {
                setTimeout(function() {
                    req.emit("data", body);
                    req.emit("end");
                }, 0);
            } else {
                setTimeout(function() {
                    req.emit("end");
                }, 0);
            }

            var res = new ResClass(socket, req);
            res.rejectNonStandardBodyWrites = self.rejectNonStandardBodyWrites;
            if (self.uniqueHeaders) { res._uniqueHeaders = self.uniqueHeaders; }
            if (self.highWaterMark !== undefined) {
                res.writableHighWaterMark = self.highWaterMark;
            }
            currentRes = res;

            if (self.optimizeEmptyRequests && body.length === 0 &&
                parsed.headers["transfer-encoding"] === undefined) {
                req.readableEnded = true;
            }

            res.on("finish", function() {
                _clearRequestTimer();
                var connHeader = parsed.headers["connection"];
                var isHttp10 = parsed.httpVersion === "1.0";
                var keepAlive = true;
                if (isHttp10) {
                    keepAlive = connHeader !== undefined && connHeader.toLowerCase() === "keep-alive";
                } else {
                    keepAlive = connHeader === undefined || connHeader.toLowerCase() !== "close";
                }
                if (!keepAlive) {
                    socket.end();
                } else {
                    _scheduleKeepAliveTimer(socket);
                }
            });

            self.emit("request", req, res);

            if (head.length > 0) {
                buffer = head;
            }
        }
    });

    socket.on("close", function() {
        _clearHeaderTimer();
        _clearRequestTimer();
        self._connections = self._connections - 1;
        var idx = self._activeSockets.indexOf(socket);
        if (idx !== -1) { self._activeSockets.splice(idx, 1); }
    });

    socket.on("error", function(err) {
        self.emit("clientError", err, socket);
    });
};
Server.prototype.getConnections = function(cb) {
    if (cb) { cb(null, this._connections); }
};
Object.defineProperty(Server.prototype, "listening", {
    get: function() { return this._listening; },
    configurable: true,
    enumerable: true
});

// ── ClientRequest ────────────────────────────────────────────────────────────

/**
 * http.ClientRequest — writable stream representing an outgoing HTTP request.
 * Connects via net.Socket, writes HTTP request, parses response into
 * IncomingMessage.
 *
 * Reference: https://nodejs.org/api/http.html#class-httpclientrequest
 */
class ClientRequest extends OutgoingMessage {
    constructor(options, cb) {
        super();

        if (typeof options === "string") {
            options = _parseUrl(options);
        }
        if (options && options.href && typeof URL !== "undefined") {
            try {
                options = _mergeOptions(_parseUrl(options.href), options);
            } catch (e) { /* keep options */ }
        }

        this.method = (options.method || "GET").toUpperCase();
        this.path = options.path || options.pathname || "/";
        if (options.search && this.path.indexOf("?") === -1) { this.path = this.path + options.search; }
        this.host = options.hostname || options.host || "localhost";
        this.port = Number(options.port) || 80;
        this.protocol = options.protocol || "http:";

        this._body = "";
        this._ended = false;
        this._aborted = false;
        this._socket = null;
        this._response = null;
        this._timeoutTimer = null;
        this._finishedFlag = false;
        this.maxHeadersCount = options.maxHeadersCount;
        this.agent = options.agent !== undefined ? options.agent : globalAgent;
        if (this.agent === false) {
            this.agent = new Agent({ keepAlive: false });
        }
        this._connectOptions = options._connectOptions || {
            host: this.host,
            port: this.port
        };
        if (options.localAddress) {
            this._connectOptions.localAddress = options.localAddress;
        }
        if (options.family !== undefined) {
            this._connectOptions.family = options.family;
        }
        this.maxRedirects = options.maxRedirects !== undefined ? options.maxRedirects : 0;
        this._redirectCount = 0;
        this._drainCallback = null;
        if (options.createConnection) {
            this._createConnection = options.createConnection;
        } else if (options._createConnection) {
            this._createConnection = options._createConnection;
        }

        // Set default Host header (omit default port for protocol)
        this.setHeader("Host", _formatHostHeader(this.host, this.port, this.protocol));

        // Apply headers from options
        if (options.headers) {
            var keys = Object.keys(options.headers);
            for (var i = 0; i < keys.length; i++) {
                this.setHeader(keys[i], options.headers[keys[i]]);
            }
        }

        if (cb) {
            this.once("response", cb);
        }

        if (options.timeout !== undefined && options.timeout > 0) {
            this.setTimeout(options.timeout);
        }

        // Connect to the server — use agent if available
        var self = this;
        if (this.agent) {
            this.agent.addRequest(this, this._connectOptions);
        } else {
            proxyMod.prepareClientProxy(self, self._connectOptions);
            var connectFn = self._createConnection || function(opts, cb) {
                return proxyMod.createProxiedConnection(opts, cb);
            };
            var sock = connectFn(self._connectOptions, function() {
                self.emit("socket", self._socket);
                self._tryFlush();
            });
            self._socket = sock;

            this._socket.on("error", function(err) {
                self.emit("error", err);
            });

            this._socket.on("close", function() {
                if (self._timeoutTimer !== null) {
                    clearTimeout(self._timeoutTimer);
                    self._timeoutTimer = null;
                }
            });
        }
    }

    get connection() { return this._socket; }
    get socket() { return this._socket; }
    get aborted() { return this._aborted; }
    get destroyed() { return this._aborted; }
    get reusedSocket() {
        return this._socket && this._socket._reusedByAgent === true;
    }
    get writableEnded() { return this._ended; }
    get writableFinished() { return this._finishedFlag; }
    get finished() { return this.writableFinished; }

    flushHeaders() {
        if (!this._ended) { this._ended = true; }
        this._tryFlush();
    }

    setNoDelay(noDelay) {
        if (this._socket && this._socket.setNoDelay) {
            this._socket.setNoDelay(noDelay !== false);
        }
        return this;
    }

    setSocketKeepAlive(enable, initialDelay) {
        if (this._socket && this._socket.setKeepAlive) {
            this._socket.setKeepAlive(enable !== false, initialDelay || 0);
        }
        return this;
    }

    cork() { super.cork(); return this; }
    uncork() { super.uncork(); return this; }

    setTimeout(ms, cb) {
        var self = this;
        this._timeout = ms;
        if (cb) { self.once("timeout", cb); }
        if (ms > 0) {
            if (this._timeoutTimer) { clearTimeout(this._timeoutTimer); }
            this._timeoutTimer = setTimeout(function() {
                self.emit("timeout");
            }, ms);
        }
        return this;
    }

    write(chunk, encoding, cb) {
        if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
        if (typeof chunk !== "string") { chunk = String(chunk); }
        this._body = this._body + chunk;
        if (cb) { cb(); }
        return true;
    }

    end(data, encoding, cb) {
        if (typeof data === "function") { cb = data; data = undefined; encoding = undefined; }
        if (typeof encoding === "function") { cb = encoding; encoding = undefined; }

        if (data !== undefined && data !== null) {
            this._body = this._body + (typeof data === "string" ? data : String(data));
        }

        this._ended = true;
        if (cb) { this.once("finish", cb); }
        this._tryFlush();
    }

    _tryFlush() {
        if (!this._ended || this.headersSent || this._aborted) { return; }
        if (!this._socket) { return; }
        if (this._socket._connecting) { return; }
        if (this._socket._handle === 0 || this._socket._destroyed || this._socket._ended) {
            if (this.agent && this._connectOptions) {
                var deadSock = this._socket;
                var agentRef = this.agent;
                var optsRef = this._connectOptions;
                this._socket = null;
                agentRef._removeSocket(deadSock, agentRef.getName(optsRef));
                agentRef.addRequest(this, optsRef);
                return;
            }
            return;
        }
        this._flushRequest();
    }

    _resetForReuse() {
        this.headersSent = false;
        this._body = "";
        this._aborted = false;
        this._finishedFlag = false;
        this._response = null;
        if (this._socket) {
            this._socket.removeAllListeners("data");
            this._socket.removeAllListeners("end");
            // Preserve "close"/"error" listeners — agent uses them for pool bookkeeping.
        }
    }

    abort() {
        this._aborted = true;
        this.destroy();
        this.emit("abort");
        this.emit("close");
    }

    destroy(err) {
        this._aborted = true;
        if (this._socket) { this._socket.destroy(err); }
        if (err) { this.emit("error", err); }
        this.emit("close");
    }

    _reissueAfterRedirect(location, statusCode) {
        var self = this;
        var loc = core.resolveRedirectLocation(
            location, self.protocol, self.host, self.port, self.path);
        if (!loc) {
            var perr = new Error("Invalid redirect URL");
            perr.code = "ERR_INVALID_URL";
            self.emit("error", perr);
            return;
        }
        self.protocol = loc.protocol || self.protocol;
        self.host = loc.hostname || loc.host;
        self.port = Number(loc.port) || core.defaultPortForProtocol(self.protocol);
        self.path = loc.path || "/";
        if (statusCode === 301 || statusCode === 302 || statusCode === 303) {
            self.method = "GET";
            self._body = "";
            self.removeHeader("content-length");
            self.removeHeader("transfer-encoding");
        }
        self.removeHeader("host");
        self.setHeader("Host", _formatHostHeader(self.host, self.port, self.protocol));
        self.headersSent = false;
        self._finishedFlag = false;
        self._response = null;
        self._drainCallback = null;
        if (self._socket) {
            var prevConnect = {
                host: self._connectOptions.host || self.host,
                port: self._connectOptions.port || self.port
            };
            self._socket.removeAllListeners("data");
            self._socket.removeAllListeners("end");
            self._socket.removeAllListeners("close");
            if (self.agent) {
                self.agent._removeSocket(self._socket, self.agent.getName(prevConnect));
            }
            self._socket.destroy();
            self._socket = null;
        }
        self._redirectCount = self._redirectCount + 1;
        self._connectOptions = {
            host: self.host,
            port: self.port
        };
        if (self.agent) {
            proxyMod.prepareClientProxy(self, self._connectOptions);
            self.agent.addRequest(self, self._connectOptions);
        } else {
            proxyMod.prepareClientProxy(self, self._connectOptions);
            var connectFn = self._createConnection || function(opts, cb) {
                return proxyMod.createProxiedConnection(opts, cb);
            };
            var sock = connectFn(self._connectOptions, function() {
                self.emit("socket", self._socket);
                self._tryFlush();
            });
            self._socket = sock;
            sock.on("error", function(err) { self.emit("error", err); });
        }
    }

    /**
     * Internal: serialize and send the HTTP request, then set up response reading.
     */
    _flushRequest() {
    var self = this;
    if (self._aborted || self.headersSent) { return; }
    if (!self._ended) { return; } // wait for end() to be called
    self.headersSent = true;

    // Build request line (absolute URI when using an HTTP forward proxy)
    var uri = self._useProxyAbsoluteUri ? self._proxyAbsoluteUri : self.path;
    var requestLine = self.method + " " + uri + " HTTP/1.1" + CRLF;

    // Build headers
    var headerStr = "";
    var keys = Object.keys(self._headers);
    for (var i = 0; i < keys.length; i++) {
        var originalName = self._headerNames[keys[i]] || keys[i];
        headerStr = headerStr + originalName + ": " + self._headers[keys[i]] + CRLF;
    }

    // Add Content-Length for bodies
    if (self._body.length > 0 && !self._headers["content-length"]) {
        headerStr = headerStr + "Content-Length: " + self._body.length + CRLF;
    }

    // Add Connection header based on agent keepAlive setting
    if (!self._headers["connection"]) {
        if (self.agent && self.agent.keepAlive) {
            headerStr = headerStr + "Connection: keep-alive" + CRLF;
        } else {
            headerStr = headerStr + "Connection: close" + CRLF;
        }
    }

    var raw = requestLine + headerStr + CRLF + self._body;
    self._socket.write(raw);
    self._finishedFlag = true;
    self.emit("finish");

    // Read response
    var responseBuf = "";
    var headParsed = false;
    var responseHead = null;
    var res = null;
    var bodyReceived = 0;
    var expectedLength = -1;
    var isChunked = false;
    var bodyBuf = "";

    self._socket.on("data", function(chunk) {
        responseBuf = responseBuf + chunk;

        if (!headParsed) {
            while (true) {
                responseHead = _parseResponseHead(responseBuf);
                if (responseHead === null) { return; }
                if (responseHead.statusCode >= 100 && responseHead.statusCode < 200) {
                    var interim = core.consumeIncomingBody(responseBuf, responseHead);
                    if (interim === null) { return; }
                    responseBuf = responseBuf.substring(interim.consumed);
                    continue;
                }
                break;
            }
            headParsed = true;

            // Create IncomingMessage
            res = new IncomingMessage(self._socket);
            res.statusCode = responseHead.statusCode;
            res.statusMessage = responseHead.statusMessage;
            res.httpVersion = responseHead.httpVersion;
            res.headers = responseHead.headers;
            res._headersDistinctCache = responseHead.headersDistinct;
            res.rawHeaders = responseHead.rawHeaders;

            self._response = res;

            // Determine body length
            var cl = responseHead.headers["content-length"];
            var te = responseHead.headers["transfer-encoding"];
            if (cl !== undefined) {
                expectedLength = Number(cl);
            } else if (te !== undefined && te.indexOf("chunked") !== -1) {
                isChunked = true;
            }

            bodyBuf = responseBuf.substring(responseHead.headerSize);
            responseBuf = "";

            if (self.maxRedirects > 0 && self._redirectCount < self.maxRedirects &&
                core.isRedirectStatus(responseHead.statusCode)) {
                var loc = responseHead.headers["location"];
                if (loc) {
                    var redirStatus = responseHead.statusCode;
                    self._drainCallback = function() {
                        self._reissueAfterRedirect(loc, redirStatus);
                    };
                    if (self.method === "HEAD" || (expectedLength === 0 && !isChunked)) {
                        self._drainCallback();
                        self._drainCallback = null;
                    } else {
                        _processBody();
                    }
                    return;
                }
            }

            if (self.method === "HEAD") {
                self.emit("response", res);
                res.complete = true;
                res.emit("end");
                _maybeReleaseSocket();
                return;
            }

            self.emit("response", res);
            _processBody();
        } else {
            bodyBuf = bodyBuf + chunk;
            _processBody();
        }
    });

    function _processBody() {
        if (!res) { return; }

        if (expectedLength >= 0) {
            // Content-Length mode
            if (bodyBuf.length > 0) {
                res.emit("data", bodyBuf);
                bodyReceived = bodyReceived + bodyBuf.length;
                bodyBuf = "";
            }
            if (bodyReceived >= expectedLength) {
                if (self._drainCallback) {
                    var drainDone = self._drainCallback;
                    self._drainCallback = null;
                    drainDone();
                    return;
                }
                res.complete = true;
                res.emit("end");
                _maybeReleaseSocket();
            }
        } else if (isChunked) {
            // Try to decode chunks
            _processChunked();
        } else {
            // Connection-close mode: emit data as it arrives
            if (bodyBuf.length > 0) {
                res.emit("data", bodyBuf);
                bodyBuf = "";
            }
        }
    }

    function _processChunked() {
        while (true) {
            var nl = _findCRLF(bodyBuf, 0);
            if (nl === -1) { break; }
            var sizeHex = bodyBuf.substring(0, nl);
            var chunkSize = parseInt(sizeHex, 16);
            if (isNaN(chunkSize)) { break; }

            if (chunkSize === 0) {
                if (self._drainCallback) {
                    var drainDone2 = self._drainCallback;
                    self._drainCallback = null;
                    drainDone2();
                    return;
                }
                res.complete = true;
                res.emit("end");
                _maybeReleaseSocket();
                return;
            }

            var chunkStart = nl + 2;
            var chunkEnd = chunkStart + chunkSize;
            if (chunkEnd + 2 > bodyBuf.length) { break; } // incomplete

            var chunkData = bodyBuf.substring(chunkStart, chunkEnd);
            res.emit("data", chunkData);
            bodyBuf = bodyBuf.substring(chunkEnd + 2);
        }
    }

    var _socketReleased = false;
    function _maybeReleaseSocket() {
        if (_socketReleased) { return; }
        _socketReleased = true;
        if (self.agent && self.agent.keepAlive && res) {
            // Check if server sent Connection: close
            var conn = res.headers ? res.headers["connection"] : undefined;
            if (conn && conn.toLowerCase() === "close") {
                // Server wants to close — destroy socket
                self._socket.destroy();
            } else {
                // Remove all current data/end/close listeners for reuse
                self._socket.removeAllListeners("data");
                self._socket.removeAllListeners("end");
                self.agent.keepSocketAlive(self._socket);
            }
        }
    }

    self._socket.on("end", function() {
        if (res && !res.complete) {
            res.complete = true;
            res.emit("end");
            _maybeReleaseSocket();
        }
    });

    self._socket.on("close", function() {
        if (res && !res.complete) {
            res.complete = true;
            res.emit("end");
        }
    });
    }
}

// ── URL parser helper ────────────────────────────────────────────────────────

function _formatHostHeader(host, port, protocol) {
    var def = core.defaultPortForProtocol(protocol || "http:");
    if (Number(port) === def) { return host; }
    return host + ":" + port;
}

function _parseUrl(urlStr) {
    // Try using URL constructor if available
    if (typeof URL !== "undefined") {
        try {
            var u = new URL(urlStr);
            return {
                protocol: u.protocol,
                hostname: u.hostname,
                port: u.port || (u.protocol === "https:" ? 443 : 80),
                path: u.pathname + (u.search || ""),
                pathname: u.pathname,
                search: u.search || ""
            };
        } catch (e) { /* fall through */ }
    }

    // Manual parse
    var result = { protocol: "http:", hostname: "localhost", port: 80, path: "/", pathname: "/", search: "" };
    var str = urlStr;
    var protoEnd = str.indexOf("://");
    if (protoEnd !== -1) {
        result.protocol = str.substring(0, protoEnd + 1);
        str = str.substring(protoEnd + 3);
    }
    var pathStart = str.indexOf("/");
    if (pathStart === -1) {
        result.hostname = str;
        result.path = "/";
    } else {
        result.hostname = str.substring(0, pathStart);
        result.path = str.substring(pathStart);
        result.pathname = result.path;
        var qIdx = result.path.indexOf("?");
        if (qIdx !== -1) {
            result.pathname = result.path.substring(0, qIdx);
            result.search = result.path.substring(qIdx);
        }
    }
    // Extract port from hostname
    var colonIdx = result.hostname.indexOf(":");
    if (colonIdx !== -1) {
        result.port = Number(result.hostname.substring(colonIdx + 1));
        result.hostname = result.hostname.substring(0, colonIdx);
    } else if (result.protocol === "https:") {
        result.port = 443;
    }
    return result;
}

// ── Agent — connection pool (Phase 6.10) ─────────────────────────────────────

/**
 * http.Agent — per-origin connection pooling with keep-alive.
 *
 * Maintains a pool of idle sockets keyed by "host:port". When keepAlive is
 * enabled, sockets are returned to the pool after a response completes and
 * reused by subsequent requests to the same origin.
 */
class Agent extends EventEmitter {
    constructor(options) {
        super();
        options = options || {};
        this.keepAlive = options.keepAlive !== undefined ? options.keepAlive : false;
        this.keepAliveMsecs = options.keepAliveMsecs || 1000;
        this.maxSockets = options.maxSockets || Infinity;
        this.maxFreeSockets = options.maxFreeSockets || 256;
        this.maxTotalSockets = options.maxTotalSockets || Infinity;
        this.timeout = options.timeout || undefined;
        this.scheduling = options.scheduling || "lifo";
        this.proxyEnv = options.proxyEnv;
        this.defaultPort = options.defaultPort;
        this.protocol = options.protocol;

        this.requests = {};      // key → [pending ClientRequest]
        this.sockets = {};       // key → [active sockets]
        this.freeSockets = {};   // key → [idle sockets]
        this.totalSocketCount = 0;
    }

    getName(options) {
        if (options._proxyConfig) {
            var p = options._proxyConfig;
            if (p.isHttps) {
                return p.proxyHost + ":" + p.proxyPort + "->" + p.targetHost + ":" + p.targetPort;
            }
            return p.proxyHost + ":" + p.proxyPort;
        }
        var name = (options.host || options.hostname || "localhost") + ":" +
                   (options.port || 80);
        if (options.localAddress) { name = name + ":" + options.localAddress; }
        return name;
    }

    createConnection(options, cb) {
        return proxyMod.createProxiedConnection(options, cb);
    }

    addRequest(req, options) {
        if (req._createConnection) {
            options._createConnection = req._createConnection;
        }
        proxyMod.prepareClientProxy(req, options);
        var name = this.getName(options);

        // Try to reuse a free socket (skip stale sockets closed by server idle sweep).
        if (this.keepAlive && this.freeSockets[name] && this.freeSockets[name].length > 0) {
            var free = this.freeSockets[name];
            while (free.length > 0) {
                var socket = (this.scheduling === "fifo") ? free.shift() : free.pop();
                if (socket._destroyed || socket._handle === 0 || socket._ended) {
                    continue;
                }
                if (free.length === 0) { delete this.freeSockets[name]; }

                if (socket._agentIdleTimer) {
                    clearTimeout(socket._agentIdleTimer);
                    socket._agentIdleTimer = null;
                }

                if (!this.sockets[name]) { this.sockets[name] = []; }
                this.sockets[name].push(socket);

                socket._reusedByAgent = true;
                this.reuseSocket(socket, req);
                req._tryFlush();
                return;
            }
            delete this.freeSockets[name];
        }

        // Check per-origin active limit
        var activeCount = this.sockets[name] ? this.sockets[name].length : 0;
        if (activeCount >= this.maxSockets) {
            // Queue the request
            if (!this.requests[name]) { this.requests[name] = []; }
            this.requests[name].push(req);
            return;
        }

        // Check total limit
        if (this.totalSocketCount >= this.maxTotalSockets) {
            if (!this.requests[name]) { this.requests[name] = []; }
            this.requests[name].push(req);
            return;
        }

        // Create a new socket
        this._createSocket(req, options, name);
    }

    _createSocket(req, options, name) {
        var self = this;
        var socket = this.createConnection(options, function() {
            req.emit("socket", socket);
            req._tryFlush();
        });

        socket.on("error", function(err) {
            req.emit("error", err);
        });

        socket.on("close", function() {
            self._removeSocket(socket, name);
        });

        // Track as active
        if (!this.sockets[name]) { this.sockets[name] = []; }
        this.sockets[name].push(socket);
        this.totalSocketCount = this.totalSocketCount + 1;

        req._socket = socket;
    }

    _removeSocket(socket, name) {
        if (this._destroying) {
            return;
        }
        // Remove from active
        if (this.sockets[name]) {
            var idx = this.sockets[name].indexOf(socket);
            if (idx !== -1) { this.sockets[name].splice(idx, 1); }
            if (this.sockets[name].length === 0) { delete this.sockets[name]; }
        }
        // Remove from free
        if (this.freeSockets[name]) {
            var fidx = this.freeSockets[name].indexOf(socket);
            if (fidx !== -1) { this.freeSockets[name].splice(fidx, 1); }
            if (this.freeSockets[name].length === 0) { delete this.freeSockets[name]; }
        }
        this.totalSocketCount = this.totalSocketCount - 1;
        if (this.totalSocketCount < 0) { this.totalSocketCount = 0; }

        // Process queued requests for this origin
        if (this.requests[name] && this.requests[name].length > 0) {
            var nextReq = this.requests[name].shift();
            if (this.requests[name].length === 0) { delete this.requests[name]; }
            var options = { host: nextReq.host, port: nextReq.port };
            this._createSocket(nextReq, options, name);
        }
    }

    keepSocketAlive(socket) {
        // Return socket to free pool
        var name = (socket.remoteAddress || socket._host || "localhost") + ":" +
                   (socket.remotePort || 80);

        // Remove from active
        if (this.sockets[name]) {
            var idx = this.sockets[name].indexOf(socket);
            if (idx !== -1) { this.sockets[name].splice(idx, 1); }
            if (this.sockets[name].length === 0) { delete this.sockets[name]; }
        }

        // Check free limit
        var freeCount = this.freeSockets[name] ? this.freeSockets[name].length : 0;
        if (freeCount >= this.maxFreeSockets) {
            socket.destroy();
            return false;
        }

        if (!this.freeSockets[name]) { this.freeSockets[name] = []; }
        this.freeSockets[name].push(socket);

        // Resume reading so a server-side idle close (closeIdleConnections) is observed.
        if (typeof socket._startReading === "function") {
            socket._startReading();
        }

        // Set idle timeout
        var self = this;
        socket._agentIdleTimer = setTimeout(function() {
            socket._agentIdleTimer = null;
            socket.destroy();
        }, this.keepAliveMsecs);

        // Process queued requests
        if (this.requests[name] && this.requests[name].length > 0) {
            var nextReq = this.requests[name].shift();
            if (this.requests[name].length === 0) { delete this.requests[name]; }
            // Re-grab the socket from freeSockets
            var free = this.freeSockets[name];
            var fidx = free.indexOf(socket);
            if (fidx !== -1) {
                free.splice(fidx, 1);
                if (free.length === 0) { delete this.freeSockets[name]; }
                if (socket._agentIdleTimer) {
                    clearTimeout(socket._agentIdleTimer);
                    socket._agentIdleTimer = null;
                }
                if (!this.sockets[name]) { this.sockets[name] = []; }
                this.sockets[name].push(socket);
                nextReq._socket = socket;
                nextReq.emit("socket", socket);
                nextReq._resetForReuse();
                nextReq._tryFlush();
            }
        }

        return true;
    }

    reuseSocket(socket, req) {
        req._socket = socket;
        req._resetForReuse();
        req.emit("socket", socket);
    }

    destroy() {
        this._destroying = true;
        this.requests = {};

        var freeKeys = Object.keys(this.freeSockets);
        for (var fi = 0; fi < freeKeys.length; fi++) {
            var fk = freeKeys[fi];
            var freeList = this.freeSockets[fk];
            var fj = 0;
            while (fj < freeList.length) {
                var fsock = freeList[fj];
                if (fsock._agentIdleTimer) {
                    clearTimeout(fsock._agentIdleTimer);
                    fsock._agentIdleTimer = null;
                }
                fsock.removeAllListeners("close");
                if (!fsock._destroyed) {
                    fsock.destroy();
                }
                fj = fj + 1;
            }
        }
        this.freeSockets = {};

        var actKeys = Object.keys(this.sockets);
        for (var ai = 0; ai < actKeys.length; ai++) {
            var ak = actKeys[ai];
            var actList = this.sockets[ak];
            var aj = 0;
            while (aj < actList.length) {
                var asock = actList[aj];
                asock.removeAllListeners("close");
                if (!asock._destroyed) {
                    asock.destroy();
                }
                aj = aj + 1;
            }
        }
        this.sockets = {};
        this.totalSocketCount = 0;
        this._destroying = false;
    }
}

var globalAgent = new Agent({ keepAlive: false });

function validateHeaderName(name, label) {
    return core.validateHeaderName(name, label);
}

function validateHeaderValue(name, value) {
    return core.validateHeaderValue(name, value);
}

function checkHeaderName(name, label) {
    return validateHeaderName(name, label);
}

function checkHeaderValue(name, value) {
    return validateHeaderValue(name, value);
}

function setMaxIdleHTTPParsers(max) {
    core.setMaxIdleHTTPParsers(max);
    _maxIdleHTTPParsers = core.getMaxIdleHTTPParsers();
}

function setGlobalProxyFromEnv(proxyEnv) {
    if (core.getGlobalProxyRestore()) {
        core.getGlobalProxyRestore()();
    }
    var env = proxyEnv;
    if (env === undefined && typeof process !== "undefined" && process.env) {
        env = process.env;
    }
    var normalized = core.normalizeProxyEnv(env || {});
    core.setGlobalProxyEnv(normalized);
    globalAgent.proxyEnv = normalized;
    var prevKeepAlive = globalAgent.keepAlive;
    var restore = function() {
        core.setGlobalProxyEnv(null);
        globalAgent.proxyEnv = undefined;
        core.setGlobalProxyRestore(null);
    };
    core.setGlobalProxyRestore(restore);
    return restore;
}

// ── Factory functions ────────────────────────────────────────────────────────

function _mergeOptions(base, over) {
    var merged = {};
    var bk = Object.keys(base);
    for (var i = 0; i < bk.length; i++) { merged[bk[i]] = base[bk[i]]; }
    if (over) {
        var ok = Object.keys(over);
        for (var j = 0; j < ok.length; j++) { merged[ok[j]] = over[ok[j]]; }
    }
    return merged;
}

function createServer(options, requestListener) {
    return new Server(options, requestListener);
}

function request(url, options, cb) {
    if (typeof url === "string" && (options === undefined || typeof options === "function")) {
        cb = options;
        options = _parseUrl(url);
    } else if (typeof url === "string") {
        options = _mergeOptions(_parseUrl(url), options);
    } else if (url && typeof url === "object") {
        if (typeof options === "function") {
            cb = options;
            options = url;
        } else {
            options = _mergeOptions(url, options || {});
        }
        if (options && options.href) {
            options = _mergeOptions(_parseUrl(options.href), options);
        }
    }
    if (typeof options === "function") {
        cb = options;
        options = {};
    }
    return new ClientRequest(options, cb);
}

function get(url, options, cb) {
    if (typeof options === "function") {
        cb = options;
        options = {};
    }
    if (typeof url === "string") {
        var parsed = _parseUrl(url);
        if (options) {
            var keys = Object.keys(options);
            for (var i = 0; i < keys.length; i++) {
                parsed[keys[i]] = options[keys[i]];
            }
        }
        options = parsed;
    } else if (url && typeof url === "object") {
        options = _mergeOptions(url, options || {});
    }
    options.method = "GET";
    var req = new ClientRequest(options, cb);
    req.end();
    return req;
}

// ── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
    Server: Server,
    IncomingMessage: IncomingMessage,
    ServerResponse: ServerResponse,
    OutgoingMessage: OutgoingMessage,
    ClientRequest: ClientRequest,
    Agent: Agent,
    globalAgent: globalAgent,
    createServer: createServer,
    request: request,
    get: get,
    METHODS: METHODS,
    STATUS_CODES: STATUS_CODES,
    maxHeaderSize: maxHeaderSize,
    validateHeaderName: validateHeaderName,
    validateHeaderValue: validateHeaderValue,
    checkHeaderName: checkHeaderName,
    checkHeaderValue: checkHeaderValue,
    setMaxIdleHTTPParsers: setMaxIdleHTTPParsers,
    setGlobalProxyFromEnv: setGlobalProxyFromEnv,
    getDefaultHighWaterMark: getDefaultHighWaterMark,
    setDefaultHighWaterMark: setDefaultHighWaterMark,
    kConnectionsCheckingInterval: kConnectionsCheckingInterval
};
