// HTTP/1.1 Server — js_engine engine (Phase 6.5)
//
// Provides Bun.serve()-compatible API plus Node.js createServer() compat.
// Uses the native __net bridge for TCP socket I/O (listen/accept/read/write/close).
//
// Architecture: JS owns HTTP protocol logic; native owns socket I/O.
// Current limitation: blocking I/O — accept() blocks until a client connects.

var net = globalThis.__net;
var CRLF = String.fromCharCode(13) + "\n";

// ─── HTTP status text table ─────────────────────────────────────────────────

var STATUS_TEXT = {};
STATUS_TEXT[100] = "Continue";
STATUS_TEXT[101] = "Switching Protocols";
STATUS_TEXT[200] = "OK";
STATUS_TEXT[201] = "Created";
STATUS_TEXT[202] = "Accepted";
STATUS_TEXT[204] = "No Content";
STATUS_TEXT[206] = "Partial Content";
STATUS_TEXT[301] = "Moved Permanently";
STATUS_TEXT[302] = "Found";
STATUS_TEXT[303] = "See Other";
STATUS_TEXT[304] = "Not Modified";
STATUS_TEXT[307] = "Temporary Redirect";
STATUS_TEXT[308] = "Permanent Redirect";
STATUS_TEXT[400] = "Bad Request";
STATUS_TEXT[401] = "Unauthorized";
STATUS_TEXT[403] = "Forbidden";
STATUS_TEXT[404] = "Not Found";
STATUS_TEXT[405] = "Method Not Allowed";
STATUS_TEXT[408] = "Request Timeout";
STATUS_TEXT[409] = "Conflict";
STATUS_TEXT[411] = "Length Required";
STATUS_TEXT[413] = "Payload Too Large";
STATUS_TEXT[414] = "URI Too Long";
STATUS_TEXT[415] = "Unsupported Media Type";
STATUS_TEXT[429] = "Too Many Requests";
STATUS_TEXT[500] = "Internal Server Error";
STATUS_TEXT[501] = "Not Implemented";
STATUS_TEXT[502] = "Bad Gateway";
STATUS_TEXT[503] = "Service Unavailable";
STATUS_TEXT[504] = "Gateway Timeout";

function _statusText(code) {
    var t = STATUS_TEXT[code];
    if (t === undefined) { return "Unknown"; }
    return t;
}

// ─── HTTP request parser ────────────────────────────────────────────────────

/**
 * Convert a raw "field: value\r\n" header string (as returned by
 * __net.readHTTPRequest) into a Headers object.
 *
 * Each line in rawStr is "name: value"; lines are separated by CRLF.
 * Handles multi-value headers correctly via Headers.append().
 */
function _headersStrToHeaders(rawStr) {
    var headers = new Headers();
    if (!rawStr || rawStr.length === 0) { return headers; }
    var pos = 0;
    while (pos < rawStr.length) {
        var nl = rawStr.indexOf(CRLF, pos);
        var line;
        if (nl === -1) {
            line = rawStr.substring(pos);
            pos = rawStr.length;
        } else {
            line = rawStr.substring(pos, nl);
            pos = nl + 2;
        }
        if (line.length === 0) { continue; }
        var colon = line.indexOf(": ");
        if (colon > 0) {
            var name  = line.substring(0, colon);
            var value = line.substring(colon + 2);
            headers.append(name, value);
        }
    }
    return headers;
}

/**
 * Parse a raw HTTP/1.1 request string into a request object.
 *
 * Returns: { method, url, httpVersion, headers (Headers), body, raw }
 * or null if the request is incomplete (no \r\n\r\n found yet).
 *
 * Note: this fallback is kept for Node.js compatibility and unit tests.
 * The js_engine engine uses __net.readHTTPRequest (native llhttp path).
 */
function _parseHTTPRequest(raw) {
    // Need at least the header terminator
    var headerEnd = raw.indexOf(CRLF + CRLF);
    if (headerEnd === -1) { return null; }

    var headerSection = raw.substring(0, headerEnd);
    var bodyStart = headerEnd + 4; // skip \r\n\r\n

    var lines = [];
    var pos = 0;
    while (pos < headerSection.length) {
        var nl = headerSection.indexOf(CRLF, pos);
        if (nl === -1) {
            lines.push(headerSection.substring(pos));
            break;
        }
        lines.push(headerSection.substring(pos, nl));
        pos = nl + 2;
    }

    if (lines.length === 0) { return null; }

    // Parse request line: "GET /path HTTP/1.1"
    var requestLine = lines[0];
    var sp1 = requestLine.indexOf(" ");
    if (sp1 === -1) { return null; }
    var sp2 = requestLine.indexOf(" ", sp1 + 1);
    if (sp2 === -1) { return null; }

    var method = requestLine.substring(0, sp1);
    var url = requestLine.substring(sp1 + 1, sp2);
    var httpVersion = requestLine.substring(sp2 + 1);

    // Parse headers
    var headers = new Headers();
    var i = 1;
    while (i < lines.length) {
        var line = lines[i];
        var colon = line.indexOf(":");
        if (colon > 0) {
            var name = line.substring(0, colon);
            var value = line.substring(colon + 1);
            // Trim leading whitespace from value
            while (value.length > 0 && value[0] === " ") {
                value = value.substring(1);
            }
            headers.append(name, value);
        }
        i = i + 1;
    }

    // Extract body based on Content-Length
    var body = "";
    var cl = headers.get("content-length");
    if (cl !== null) {
        var contentLength = parseInt(cl, 10);
        if (contentLength > 0) {
            body = raw.substring(bodyStart, bodyStart + contentLength);
            // Check if we have enough data
            if (body.length < contentLength) {
                return null; // incomplete, need more data
            }
        }
    } else {
        // Check for Transfer-Encoding: chunked
        var te = headers.get("transfer-encoding");
        if (te !== null && te.indexOf("chunked") !== -1) {
            // Decode chunked body
            var chunkResult = _decodeChunked(raw.substring(bodyStart));
            if (chunkResult === null) { return null; } // incomplete
            body = chunkResult;
        }
        // else: no body (GET, HEAD, etc.) — body stays ""
    }

    return {
        method: method,
        url: url,
        httpVersion: httpVersion,
        headers: headers,
        body: body,
        raw: raw
    };
}

/**
 * Decode chunked Transfer-Encoding body.
 * Returns decoded body string or null if incomplete.
 */
function _decodeChunked(data) {
    var result = "";
    var pos = 0;
    while (pos < data.length) {
        var nl = data.indexOf(CRLF, pos);
        if (nl === -1) { return null; }
        var sizeHex = data.substring(pos, nl);
        var chunkSize = parseInt(sizeHex, 16);
        if (chunkSize === 0) { return result; } // final chunk
        var chunkStart = nl + 2;
        var chunkEnd = chunkStart + chunkSize;
        if (chunkEnd + 2 > data.length) { return null; } // incomplete
        result = result + data.substring(chunkStart, chunkEnd);
        pos = chunkEnd + 2; // skip trailing \r\n
    }
    return null; // incomplete
}

// ─── HTTP response serializer ───────────────────────────────────────────────

/**
 * Serialize a Response object to HTTP/1.1 wire format.
 *
 * @param {Response} response - Standard Response object
 * @param {boolean} keepAlive - Whether to send Connection: keep-alive
 * @returns {string} HTTP response bytes
 */
function _serializeResponse(response, keepAlive) {
    var status = response.status || 200;
    var statusText = response.statusText || _statusText(status);
    var body = response._body || "";
    var headers = response.headers;

    var result = "HTTP/1.1 " + status + " " + statusText + CRLF;

    // Collect header entries using entries() (avoids closure capture issues)
    var hasContentLength = false;
    var hasConnection = false;
    if (headers) {
        var entries = headers.entries();
        var idx = 0;
        while (idx < entries.length) {
            var entry = entries[idx];
            var hname = entry[0];
            var hval = entry[1];
            var hnLower = hname.toLowerCase();
            if (hnLower === "content-length") { hasContentLength = true; }
            if (hnLower === "connection") { hasConnection = true; }
            result = result + hname + ": " + hval + CRLF;
            idx = idx + 1;
        }
    }

    // Add Content-Length if not set
    if (!hasContentLength) {
        result = result + "Content-Length: " + body.length + CRLF;
    }

    // Add Connection header if not set
    if (!hasConnection) {
        if (keepAlive) {
            result = result + "Connection: keep-alive" + CRLF;
        } else {
            result = result + "Connection: close" + CRLF;
        }
    }

    // Add Date header
    result = result + "Date: " + new Date().toUTCString() + CRLF;

    result = result + CRLF;
    result = result + body;

    return result;
}

// ─── Server class ───────────────────────────────────────────────────────────

/**
 * HTTP Server — Bun.serve() compatible API.
 *
 * Usage:
 *   var server = Bun.serve({
 *     port: 3000,
 *     fetch: function(req) { return new Response("Hello"); }
 *   });
 *   server.stop();
 *
 * The `fetch` handler receives a Request object and must return a Response.
 */
function Server(options) {
    this.port = options.port || 0;
    this.hostname = options.hostname || "0.0.0.0";
    this.fetch = options.fetch;
    this.error = options.error || null;
    this.development = options.development !== undefined ? options.development : true;
    this._listenerHandle = 0;
    this._running = false;
    this._requestCount = 0;
    this._actualPort = 0;
    this._wsHandlers = options.websocket || null;
    this._pendingUpgrade = null; // { clientHandle, headers }
    this._activeWS = [];         // active ServerWebSocket connections

    // Start listening
    var backlog = options.backlog || 128;
    this._listenerHandle = net.tcpListen(this.hostname, this.port, backlog);
    if (this._listenerHandle === 0) {
        throw new Error("Failed to listen on " + this.hostname + ":" + this.port);
    }
    this._running = true;

    // Get the actual bound port (important when port=0 for OS-assigned port)
    this._actualPort = net.tcpListenerPort(this._listenerHandle);
    this.port = this._actualPort;
}

/**
 * Accept and handle one incoming HTTP connection (single request, then close).
 * Blocks until a client connects.
 * Returns true if a request was handled, false if the server is stopped.
 *
 * Forces Connection: close — in blocking mode, keep-alive across accept loops
 * is not yet supported (requires async I/O in Phase 6.9).
 */
Server.prototype._handleOne = function() {
    if (!this._running) { return false; }

    // Accept one connection (blocking)
    var clientHandle = net.tcpAccept(this._listenerHandle);
    if (clientHandle === 0) { return false; }

    try {
        // Phase C: use native llhttp-based request reader when available,
        // falling back to the JS parser for Node.js compatibility.
        var parsed;
        if (net.readHTTPRequest) {
            parsed = net.readHTTPRequest(clientHandle, 10485760);
        } else {
            // Node.js fallback: accumulate with tcpRead + JS parser
            var buffer = "";
            var attempts = 0;
            while (attempts < 50) {
                var chunk = net.tcpRead(clientHandle, 65536);
                if (chunk === "") { break; }
                buffer = buffer + chunk;
                if (buffer.indexOf(CRLF + CRLF) !== -1) {
                    var p = _parseHTTPRequest(buffer);
                    if (p !== null) { parsed = p; break; }
                }
                attempts = attempts + 1;
            }
            if (!parsed) { parsed = _parseHTTPRequest(buffer); }
        }

        if (!parsed) {
            // Malformed / incomplete request → 400
            var bad = "HTTP/1.1 400 Bad Request" + CRLF +
                "Content-Length: 11" + CRLF +
                "Connection: close" + CRLF + CRLF +
                "Bad Request";
            net.tcpWrite(clientHandle, bad);
            net.tcpClose(clientHandle);
            return true;
        }

        // Convert headers: native returns raw string; JS parser returns Headers.
        var hdrs;
        if (typeof parsed.headers === "string") {
            hdrs = _headersStrToHeaders(parsed.headers);
        } else {
            hdrs = parsed.headers || new Headers();
        }

        // Build Request object
        var reqUrl = "http://" + this.hostname + ":" + this.port + parsed.url;
        var reqInit = { method: parsed.method, headers: hdrs };
        if (parsed.body !== "" && parsed.method !== "GET" && parsed.method !== "HEAD") {
            reqInit.body = parsed.body;
        }
        var request = new Request(reqUrl, reqInit);

        // Check for WebSocket upgrade — set pending before calling fetch
        var isUpgrade = false;
        if (this._wsHandlers) {
            var upgradeVal = hdrs.get("upgrade") || "";
            if (upgradeVal.toLowerCase() === "websocket") {
                var rawHeaders = {};
                hdrs.forEach(function(value, key) {
                    rawHeaders[key.toLowerCase()] = value;
                });
                this._pendingUpgrade = {
                    clientHandle: clientHandle,
                    headers: rawHeaders
                };
                isUpgrade = true;
            }
        }

        // Call fetch handler (pass server as second arg for Bun compat)
        var response;
        try {
            response = this.fetch(request, this);
        } catch (fetchErr) {
            if (this.error) {
                response = this.error(fetchErr);
            }
            if (!response) {
                response = new Response("Internal Server Error", { status: 500 });
            }
        }

        // If upgrade was performed, the connection is now a WebSocket — skip HTTP response
        if (isUpgrade && !this._pendingUpgrade) {
            // upgrade consumed the pending — do not close the handle
            this._requestCount = this._requestCount + 1;
            return true;
        }
        // Clear any unconsumed pending upgrade
        this._pendingUpgrade = null;

        // Handle Promise responses
        if (response && typeof response.then === "function") {
            var resolved = null;
            response.then(function(val) { resolved = val; });
            if (resolved !== null) { response = resolved; }
        }

        // Serialize and send (always Connection: close in blocking mode)
        var responseBytes = _serializeResponse(response, false);
        net.tcpWrite(clientHandle, responseBytes);
    } catch (e) {
        if (this.error) {
            try {
                var errResponse = this.error(e);
                if (errResponse) {
                    var errBytes = _serializeResponse(errResponse, false);
                    net.tcpWrite(clientHandle, errBytes);
                }
            } catch (e2) {
                var fallback = "HTTP/1.1 500 Internal Server Error" + CRLF +
                    "Content-Length: 21" + CRLF +
                    "Connection: close" + CRLF + CRLF +
                    "Internal Server Error";
                net.tcpWrite(clientHandle, fallback);
            }
        } else {
            var fallback500 = "HTTP/1.1 500 Internal Server Error" + CRLF +
                "Content-Length: 21" + CRLF +
                "Connection: close" + CRLF + CRLF +
                "Internal Server Error";
            net.tcpWrite(clientHandle, fallback500);
        }
    }

    net.tcpClose(clientHandle);
    this._requestCount = this._requestCount + 1;
    return true;
};

/**
 * Handle a single TCP connection — may serve multiple requests (keep-alive).
 */
Server.prototype._handleConnection = function(clientHandle) {
    var keepAlive = true;
    var maxRequests = 100;
    var requestsOnConn = 0;

    while (keepAlive && requestsOnConn < maxRequests) {
        // Phase C: native llhttp request reader handles all buffering internally.
        var parsed = net.readHTTPRequest(clientHandle, 10485760);
        if (parsed === undefined || parsed === null) { break; } // EOF or error

        // Convert raw headers string to a Headers object
        var hdrs = _headersStrToHeaders(parsed.headers);

        // Build a Request object for the fetch handler
        var reqUrl = "http://" + this.hostname + ":" + this.port + parsed.url;
        var reqInit = { method: parsed.method, headers: hdrs };
        if (parsed.body !== "" && parsed.method !== "GET" && parsed.method !== "HEAD") {
            reqInit.body = parsed.body;
        }
        var request = new Request(reqUrl, reqInit);

        // Check Connection header for keep-alive negotiation
        var connHeader = hdrs.get("connection");
        if (connHeader !== null && connHeader.toLowerCase() === "close") {
            keepAlive = false;
        }
        if (parsed.httpVersion === "1.0") {
            // HTTP/1.0 defaults to close
            keepAlive = (connHeader !== null && connHeader.toLowerCase() === "keep-alive");
        }

        // Call the user's fetch handler
        var response;
        try {
            response = this.fetch(request);
        } catch (fetchErr) {
            if (this.error) {
                response = this.error(fetchErr);
            }
            if (!response) {
                response = new Response("Internal Server Error", { status: 500 });
            }
        }

        // Handle Promise responses (resolve synchronously since we're blocking)
        if (response && typeof response.then === "function") {
            var resolved = null;
            response.then(function(val) { resolved = val; });
            if (resolved !== null) { response = resolved; }
        }

        // Serialize and send response
        var responseBytes = _serializeResponse(response, keepAlive);
        net.tcpWrite(clientHandle, responseBytes);

        requestsOnConn = requestsOnConn + 1;
    }
};

/**
 * Serve exactly N requests then return.
 * Useful for testing — avoids infinite accept loop.
 */
Server.prototype.handleN = function(n) {
    var handled = 0;
    while (handled < n && this._running) {
        if (this._handleOne()) {
            handled = handled + 1;
        } else {
            break;
        }
    }
    return handled;
};

/**
 * Stop the server — close the listening socket.
 */
Server.prototype.stop = function() {
    if (!this._running) { return; }
    this._running = false;
    if (this._listenerHandle !== 0) {
        net.tcpListenerClose(this._listenerHandle);
        this._listenerHandle = 0;
    }
    // Close all active WebSocket connections
    for (var i = 0; i < this._activeWS.length; i++) {
        if (this._activeWS[i].readyState < 3) {
            this._activeWS[i]._doClose(1001, "server shutdown");
        }
    }
    this._activeWS = [];
};

/**
 * Upgrade an HTTP request to a WebSocket connection (Bun.serve() API).
 *
 * Call from inside the fetch handler:
 *   fetch(req, server) {
 *     if (server.upgrade(req, { data: { user: "alice" } })) return;
 *     return new Response("Not a WebSocket request");
 *   }
 *
 * @param {Request} req — the HTTP request
 * @param {object} [opts] — { data: any } user context attached to ws.data
 * @returns {boolean} — true if upgrade succeeded, false otherwise
 */
Server.prototype.upgrade = function(req, opts) {
    if (!this._wsHandlers) { return false; }
    if (!this._pendingUpgrade) { return false; }

    var headers = this._pendingUpgrade.headers;
    var clientHandle = this._pendingUpgrade.clientHandle;
    this._pendingUpgrade = null;

    var wsServer = require("websocket_server");
    var userData = (opts && opts.data !== undefined) ? opts.data : {};

    var ws = wsServer._doUpgrade(clientHandle, headers, this._wsHandlers, userData);
    if (!ws) { return false; }

    this._activeWS.push(ws);

    // Start non-blocking read loop for this WS connection
    wsServer._wsReadLoopNb(ws);

    return true;
};

Object.defineProperty(Server.prototype, "requestCount", {
    get: function() { return this._requestCount; }
});

// ─── Bun.serve() factory ────────────────────────────────────────────────────

function serve(options) {
    if (!options || typeof options.fetch !== "function") {
        throw new TypeError("Bun.serve() requires a fetch handler function");
    }
    return new Server(options);
}

// ─── createServer() — Node.js compat ────────────────────────────────────────

/**
 * Minimal Node.js http.createServer() compatibility.
 *
 * Usage:
 *   var server = createServer(function(req, res) {
 *     res.writeHead(200, { "Content-Type": "text/plain" });
 *     res.end("Hello");
 *   });
 *   server.listen(3000);
 *
 * Note: This wraps the Bun-style server internally.
 */
function IncomingMessage(parsed, socket) {
    this.method = parsed.method;
    this.url = parsed.url;
    this.httpVersion = parsed.httpVersion.replace("HTTP/", "");
    this.headers = {};
    // Convert Headers to plain object (lowercased keys per Node.js convention)
    parsed.headers.forEach(function(value, name) {
        this.headers[name.toLowerCase()] = value;
    }.bind(this));
    this.body = parsed.body;
    this._socket = socket;
}

function ServerResponse(socket) {
    this._socket = socket;
    this._statusCode = 200;
    this._statusMessage = "";
    this._headers = {};
    this._headersSent = false;
    this._body = "";
    this._ended = false;
}

ServerResponse.prototype.writeHead = function(statusCode, headers) {
    this._statusCode = statusCode;
    if (headers) {
        var keys = Object.keys(headers);
        var i = 0;
        while (i < keys.length) {
            this._headers[keys[i]] = headers[keys[i]];
            i = i + 1;
        }
    }
    return this;
};

ServerResponse.prototype.setHeader = function(name, value) {
    this._headers[name] = value;
};

ServerResponse.prototype.getHeader = function(name) {
    return this._headers[name];
};

ServerResponse.prototype.write = function(chunk) {
    this._body = this._body + chunk;
    return true;
};

ServerResponse.prototype.end = function(data) {
    if (data !== undefined) {
        this._body = this._body + data;
    }
    this._ended = true;
};

Object.defineProperty(ServerResponse.prototype, "statusCode", {
    get: function() { return this._statusCode; },
    set: function(v) { this._statusCode = v; }
});

/**
 * Node.js-style HTTP server.
 */
function NodeServer(handler) {
    this._handler = handler;
    this._listening = false;
    this._server = null;
}

NodeServer.prototype.listen = function(port, hostname, callback) {
    if (typeof hostname === "function") {
        callback = hostname;
        hostname = "0.0.0.0";
    }
    if (!hostname) { hostname = "0.0.0.0"; }

    var self = this;
    this._server = new Server({
        port: port || 0,
        hostname: hostname,
        fetch: function(request) {
            // Build Node.js-style req/res from the Request
            var parsed = {
                method: request.method,
                url: new URL(request.url).pathname + (new URL(request.url).search || ""),
                httpVersion: "HTTP/1.1",
                headers: request.headers,
                body: request._body || ""
            };
            var req = new IncomingMessage(parsed, null);
            var res = new ServerResponse(null);

            // Call the user handler
            self._handler(req, res);

            // Build a Response from the ServerResponse
            var responseHeaders = new Headers();
            var hkeys = Object.keys(res._headers);
            var hi = 0;
            while (hi < hkeys.length) {
                responseHeaders.set(hkeys[hi], String(res._headers[hkeys[hi]]));
                hi = hi + 1;
            }

            return new Response(res._body, {
                status: res._statusCode,
                statusText: res._statusMessage || _statusText(res._statusCode),
                headers: responseHeaders
            });
        }
    });

    this._listening = true;
    this.port = this._server.port;

    if (typeof callback === "function") {
        callback();
    }

    return this;
};

NodeServer.prototype.close = function(callback) {
    if (this._server) {
        this._server.stop();
        this._server = null;
    }
    this._listening = false;
    if (typeof callback === "function") { callback(); }
};

NodeServer.prototype._handleInsternal = function() {
    if (this._server) { return this._server._handleOne(); }
    return false;
};

NodeServer.prototype.handleN = function(n) {
    if (this._server) { return this._server.handleN(n); }
    return 0;
};

function createServer(handler) {
    return new NodeServer(handler);
}

// ─── Exports ────────────────────────────────────────────────────────────────

// Set on globalThis for direct access
globalThis.Server = Server;

// Bun compat object
if (!globalThis.Bun) { globalThis.Bun = {}; }
globalThis.Bun.serve = serve;

// Module exports for require("http_server") or require("http")
module.exports = {
    Server: Server,
    serve: serve,
    createServer: createServer,
    STATUS_CODES: STATUS_TEXT,
    _parseHTTPRequest: _parseHTTPRequest,
    _serializeResponse: _serializeResponse
};
