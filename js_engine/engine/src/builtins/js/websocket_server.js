// WebSocket Server — server-side WebSocket upgrade handler
// Phase 6.9 — integrates with Bun.serve() via `websocket` option.
// Phase B  — adds WebSocketServer class (Node.js `ws` library compatible).
//
// Uses binary-safe native recv buf for frame I/O.  Server receives masked
// frames from clients — the mask key and XOR'd payload can contain null bytes.
// The recv buf reads raw bytes via recv() and decodes using read_byte(),
// avoiding null-terminated string truncation.
//
// Server→client frames are unmasked.  __ws.sendFrame() builds the frame
// in a native buffer and writes it with explicit byte count.
//
// Reference: https://bun.sh/docs/api/websockets
//            https://github.com/websockets/ws (WebSocketServer API)
// RFC 6455 §4.2 — Server-Side Requirements

var EventEmitter = require("events");
var _wb = __ws;  // native WebSocket bridge
var _nb = __net; // native net bridge
var CRLF = String.fromCharCode(13) + "\n";

// ── Constants ────────────────────────────────────────────────────────────────
var OPEN    = 1;
var CLOSING = 2;
var CLOSED  = 3;

var OP_TEXT   = 1;
var OP_BINARY = 2;
var OP_CLOSE  = 8;
var OP_PING   = 9;
var OP_PONG   = 10;

// ── ServerWebSocket ─────────────────────────────────────────────────────────
// Node.js `ws` compatible: extends EventEmitter so users can do
//   ws.on("message", fn), ws.on("close", fn), etc.
// Also keeps _handlers for backward compat with Bun.serve({ websocket: {} }).

class ServerWebSocket extends EventEmitter {
    constructor(handle, data, handlers) {
        super();
        this._handle = handle;
        this.data = data || {};
        this.readyState = OPEN;
        this.remoteAddress = "";
        this._handlers = handlers || {};
        this._closed = false;
        this._recvBuf = _wb.createRecvBuf();

        try {
            var addrStr = _nb.tcpPeerAddr(handle);
            if (addrStr) {
                this.remoteAddress = addrStr;
            }
        } catch (e) {}
    }

    send(data) {
        if (this.readyState !== OPEN) { return; }

        var opcode = OP_TEXT;
        if (typeof data !== "string") {
            opcode = OP_BINARY;
            data = String(data);
        }

        _wb.sendFrame(this._handle, opcode, data, false, false);
    }

    close(code, reason) {
        if (this.readyState >= CLOSING) { return; }
        this.readyState = CLOSING;

        if (code === undefined) { code = 1000; }
        if (reason === undefined) { reason = ""; }

        var closePayload = _wb.makeClosePayload(code, reason);
        _wb.sendFrame(this._handle, OP_CLOSE, closePayload, false, false);

        this._doClose(code, reason);
    }

    ping(data) {
        if (this.readyState !== OPEN) { return; }
        if (data === undefined) { data = ""; }
        _wb.sendFrame(this._handle, OP_PING, data, false, false);
    }

    pong(data) {
        if (this.readyState !== OPEN) { return; }
        if (data === undefined) { data = ""; }
        _wb.sendFrame(this._handle, OP_PONG, data, false, false);
    }

    terminate() {
        if (this.readyState >= CLOSED) { return; }
        this._doClose(1006, "");
    }

    _doClose(code, reason) {
        if (this._closed) { return; }
        this._closed = true;
        this.readyState = CLOSED;

        if (this._handle !== 0) {
            _nb.tcpClose(this._handle);
            this._handle = 0;
        }

        // Emit 'close' event (Node ws style)
        this.emit("close", code, reason);

        // Legacy _handlers callback (Bun.serve style)
        if (this._handlers && this._handlers.close) {
            try {
                this._handlers.close(this, code, reason);
            } catch (e) {}
        }
    }

    _processRecvBuf() {
        while (true) {
            var result = _wb.recvBufDecode(this._recvBuf);
            var opcode = result[0];
            if (opcode === -1) { break; }

            var payloadStart = result[1];
            var payloadLen = result[2];
            var frameLen = result[3];
            var fin = result[4];
            var maskOff = result[5];

            if (opcode === OP_TEXT || opcode === OP_BINARY) {
                var payload = _wb.recvBufExtract(this._recvBuf, payloadStart, payloadLen, maskOff);
                _wb.recvBufConsume(this._recvBuf, frameLen);

                // Emit 'message' event (Node ws style) — data, isBinary
                var isBinary = opcode === OP_BINARY;
                this.emit("message", payload, isBinary);

                // Legacy _handlers callback (Bun.serve style)
                if (this._handlers && this._handlers.message) {
                    try {
                        this._handlers.message(this, payload);
                    } catch (e) {
                        this.emit("error", e);
                        if (this._handlers.error) {
                            try { this._handlers.error(this, e); } catch (e2) {}
                        }
                    }
                }
            } else if (opcode === OP_CLOSE) {
                var closeInfo = _wb.recvBufParseClose(this._recvBuf, payloadStart, payloadLen, maskOff);
                _wb.recvBufConsume(this._recvBuf, frameLen);
                var code = closeInfo[0];
                var reason = closeInfo[1];
                if (this.readyState === OPEN) {
                    this.readyState = CLOSING;
                    var cp = _wb.makeClosePayload(code, reason);
                    _wb.sendFrame(this._handle, OP_CLOSE, cp, false, false);
                }
                this._doClose(code, reason);
            } else if (opcode === OP_PING) {
                var pingData = _wb.recvBufExtract(this._recvBuf, payloadStart, payloadLen, maskOff);
                _wb.recvBufConsume(this._recvBuf, frameLen);
                _wb.sendFrame(this._handle, OP_PONG, pingData, false, false);
                this.emit("ping", pingData);
                if (this._handlers && this._handlers.ping) {
                    try { this._handlers.ping(this, pingData); } catch (e) {}
                }
            } else if (opcode === OP_PONG) {
                var pongData = _wb.recvBufExtract(this._recvBuf, payloadStart, payloadLen, maskOff);
                _wb.recvBufConsume(this._recvBuf, frameLen);
                this.emit("pong", pongData);
                if (this._handlers && this._handlers.pong) {
                    try { this._handlers.pong(this, pongData); } catch (e) {}
                }
            } else {
                _wb.recvBufConsume(this._recvBuf, frameLen);
            }
        }
    }
}

// ── Upgrade Logic ────────────────────────────────────────────────────────────

function _doUpgrade(clientHandle, headers, wsHandlers, data) {
    var upgradeHeader = headers["upgrade"] || "";
    if (upgradeHeader.toLowerCase() !== "websocket") {
        return null;
    }

    var connectionHeader = headers["connection"] || "";
    if (connectionHeader.toLowerCase().indexOf("upgrade") < 0) {
        return null;
    }

    var wsKey = headers["sec-websocket-key"] || "";
    if (wsKey === "") {
        return null;
    }

    var wsVersion = headers["sec-websocket-version"] || "";
    if (wsVersion !== "13") {
        var reject = "HTTP/1.1 426 Upgrade Required" + CRLF +
            "Sec-WebSocket-Version: 13" + CRLF +
            "Content-Length: 0" + CRLF + CRLF;
        _nb.tcpWrite(clientHandle, reject);
        return null;
    }

    var acceptKey = _wb.acceptKey(wsKey);

    var response = "HTTP/1.1 101 Switching Protocols" + CRLF +
        "Upgrade: websocket" + CRLF +
        "Connection: Upgrade" + CRLF +
        "Sec-WebSocket-Accept: " + acceptKey + CRLF;

    var wsProtocol = headers["sec-websocket-protocol"] || "";
    if (wsProtocol !== "") {
        var protoComma = wsProtocol.indexOf(",");
        var selectedProto = protoComma >= 0 ? wsProtocol.substring(0, protoComma) : wsProtocol;
        while (selectedProto.length > 0 && selectedProto.charAt(0) === " ") {
            selectedProto = selectedProto.substring(1);
        }
        while (selectedProto.length > 0 && selectedProto.charAt(selectedProto.length - 1) === " ") {
            selectedProto = selectedProto.substring(0, selectedProto.length - 1);
        }
        response += "Sec-WebSocket-Protocol: " + selectedProto + CRLF;
    }

    response += CRLF;
    _nb.tcpWrite(clientHandle, response);

    var ws = new ServerWebSocket(clientHandle, data, wsHandlers);

    if (wsHandlers && wsHandlers.open) {
        try {
            wsHandlers.open(ws);
        } catch (e) {}
    }

    return ws;
}

// ── Read loops ───────────────────────────────────────────────────────────────

function _wsReadLoop(ws) {
    while (ws.readyState < CLOSED) {
        var nr = _wb.recvBufRead(ws._handle, ws._recvBuf, false);
        if (nr <= 0) {
            ws._doClose(1006, "");
            break;
        }
        ws._processRecvBuf();
    }
}

function _wsReadLoopNb(ws) {
    if (ws.readyState >= CLOSED || ws._handle === 0) { return; }

    var nr = _wb.recvBufRead(ws._handle, ws._recvBuf, false);
    if (nr > 0) {
        ws._processRecvBuf();
        if (ws.readyState < CLOSED && ws._handle !== 0) {
            _wsReadLoopNb(ws);
        }
    } else if (nr === 0) {
        ws._doClose(1006, "");
    } else {
        setTimeout(function() {
            _wsReadLoopNb(ws);
        }, 1);
    }
}

// ── Module exports ───────────────────────────────────────────────────────────

// ── WebSocketServer (Node.js `ws` compatible) ───────────────────────────────

class WebSocketServer extends EventEmitter {
    constructor(options) {
        super();

        if (!options) { options = {}; }

        this.options = options;
        this._running = false;
        this._listenerHandle = 0;
        this._httpServer = null;
        this._noServer = !!options.noServer;
        this._path = options.path || null;
        this._verifyClient = options.verifyClient || null;
        this._handleProtocols = options.handleProtocols || null;
        this._maxPayload = options.maxPayload || 0;

        // Client tracking (default: true per ws library)
        var tracking = options.clientTracking !== undefined ? options.clientTracking : true;
        this.clients = tracking ? new Set() : null;

        if (options.server) {
            // Attach to existing http.Server — listen for its 'upgrade' event
            this._httpServer = options.server;
            var self = this;
            this._httpServer.on("upgrade", function(req, socket, head) {
                self._onHttpUpgrade(req, socket, head);
            });
        } else if (options.port !== undefined && !this._noServer) {
            // Create our own TCP listener
            var host = options.host || "0.0.0.0";
            var backlog = options.backlog || 128;
            this._listenerHandle = _nb.tcpListen(host, options.port, backlog);
            if (this._listenerHandle === 0) {
                var err = new Error("WebSocketServer: failed to listen on " + host + ":" + options.port);
                this.emit("error", err);
                return;
            }
            this._running = true;
            this.emit("listening");

            // Start accept loop (non-blocking via setTimeout)
            this._acceptLoop();
        }
        // else: noServer mode — user calls handleUpgrade() manually
    }

    address() {
        if (this._listenerHandle !== 0) {
            var port = _nb.tcpListenerPort(this._listenerHandle);
            return { port: port, family: "IPv4", address: this.options.host || "0.0.0.0" };
        }
        return null;
    }

    close(cb) {
        if (this._listenerHandle !== 0) {
            _nb.tcpListenerClose(this._listenerHandle);
            this._listenerHandle = 0;
        }
        this._running = false;

        // Close all tracked clients
        if (this.clients) {
            this.clients.forEach(function(ws) {
                ws.terminate();
            });
        }

        this.emit("close");
        if (cb) { cb(); }
    }

    handleUpgrade(request, socket, head, cb) {
        // Extract headers from request
        var headers = {};
        if (request.headers) {
            if (typeof request.headers.forEach === "function") {
                request.headers.forEach(function(value, key) {
                    headers[key.toLowerCase()] = value;
                });
            } else {
                var keys = Object.keys(request.headers);
                for (var i = 0; i < keys.length; i++) {
                    headers[keys[i].toLowerCase()] = request.headers[keys[i]];
                }
            }
        }

        // Path check
        if (this._path) {
            var reqPath = request.url || "/";
            var qIdx = reqPath.indexOf("?");
            if (qIdx >= 0) { reqPath = reqPath.substring(0, qIdx); }
            if (reqPath !== this._path) { return; }
        }

        // Verify client (synchronous form)
        if (this._verifyClient) {
            var info = { origin: headers["origin"] || "", req: request, secure: false };
            var allowed = this._verifyClient(info);
            if (!allowed) {
                // Send 401 and close
                var reject = "HTTP/1.1 401 Unauthorized" + CRLF +
                    "Content-Length: 0" + CRLF + CRLF;
                if (socket && typeof socket === "number") {
                    _nb.tcpWrite(socket, reject);
                }
                return;
            }
        }

        // socket is a native TCP handle (number)
        var clientHandle = socket;
        if (typeof socket === "object" && socket._handle) {
            clientHandle = socket._handle;
        }

        // Build handler callbacks for ServerWebSocket (legacy Bun.serve compat)
        // Client tracking is handled via EventEmitter in handleUpgrade below.
        var self = this;
        var handlers = {};

        // Emit 'headers' event before sending response (allows mutation)
        var responseHeaders = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: " + _wb.acceptKey(headers["sec-websocket-key"] || "")
        ];

        // Protocol negotiation
        var wsProtocol = headers["sec-websocket-protocol"] || "";
        if (wsProtocol !== "") {
            var selectedProto = wsProtocol;
            var protoComma = wsProtocol.indexOf(",");
            if (protoComma >= 0) { selectedProto = wsProtocol.substring(0, protoComma); }
            selectedProto = selectedProto.replace(/^\s+|\s+$/g, "") || selectedProto;
            if (this._handleProtocols) {
                var protocols = new Set();
                var parts = wsProtocol.split(",");
                for (var p = 0; p < parts.length; p++) {
                    var trimmed = parts[p].replace(/^\s+|\s+$/g, "") || parts[p];
                    if (trimmed !== "") { protocols.add(trimmed); }
                }
                var chosen = this._handleProtocols(protocols, request);
                if (chosen === false) {
                    // Reject
                    return;
                }
                if (chosen) { selectedProto = chosen; }
            }
            responseHeaders.push("Sec-WebSocket-Protocol: " + selectedProto);
        }

        this.emit("headers", responseHeaders, request);

        // Send the 101 response
        var responseStr = responseHeaders.join(CRLF) + CRLF + CRLF;
        _nb.tcpWrite(clientHandle, responseStr);

        // Create the ServerWebSocket
        var ws = new ServerWebSocket(clientHandle, {}, handlers);

        // Wire up client tracking via EventEmitter
        if (self.clients) {
            self.clients.add(ws);
            ws.on("close", function() {
                self.clients.delete(ws);
            });
        }

        // Fire the open handler (legacy Bun.serve callback)
        if (handlers.open) { handlers.open(ws); }

        // Emit 'open' event on the ws itself (Node ws style)
        ws.emit("open");

        // Invoke callback with (ws, request)
        if (cb) { cb(ws, request); }
    }

    // Accept loop for standalone server mode (port given)
    _acceptLoop() {
        if (!this._running || this._listenerHandle === 0) { return; }
        var self = this;

        _nb.tcpAcceptNb(this._listenerHandle, function(clientHandle) {
            if (clientHandle <= 0) {
                if (self._running) {
                    setTimeout(function() { self._acceptLoop(); }, 1);
                }
                return;
            }

            // Read the HTTP upgrade request
            self._readUpgradeRequest(clientHandle);

            // Continue accepting
            if (self._running) {
                self._acceptLoop();
            }
        });
    }

    _readUpgradeRequest(clientHandle) {
        var self = this;
        var buffer = "";

        _nb.tcpReadNb(clientHandle, 65536, function(data) {
            if (!data || data.length === 0) {
                _nb.tcpClose(clientHandle);
                return;
            }

            buffer += data;

            var doubleCRLF = CRLF + CRLF;
            var headerEnd = buffer.indexOf(doubleCRLF);
            if (headerEnd < 0) {
                // Need more data
                _nb.tcpReadNb(clientHandle, 65536, arguments.callee);
                return;
            }

            // Parse headers
            var headerSection = buffer.substring(0, headerEnd);
            var lines = headerSection.split(CRLF);
            if (lines.length === 0) {
                _nb.tcpClose(clientHandle);
                return;
            }

            // Parse request line
            var requestLine = lines[0];
            var sp1 = requestLine.indexOf(" ");
            var sp2 = sp1 >= 0 ? requestLine.indexOf(" ", sp1 + 1) : -1;
            var method = sp1 >= 0 ? requestLine.substring(0, sp1) : "";
            var url = sp2 >= 0 ? requestLine.substring(sp1 + 1, sp2) : "/";

            var headers = {};
            for (var i = 1; i < lines.length; i++) {
                var colon = lines[i].indexOf(":");
                if (colon > 0) {
                    var key = lines[i].substring(0, colon).toLowerCase();
                    var val = lines[i].substring(colon + 1);
                    while (val.length > 0 && val.charAt(0) === " ") {
                        val = val.substring(1);
                    }
                    headers[key] = val;
                }
            }

            // Build a minimal request object
            var req = { method: method, url: url, headers: headers };

            // Check if it's a WebSocket upgrade
            var upgradeVal = (headers["upgrade"] || "").toLowerCase();
            if (upgradeVal !== "websocket") {
                // Not a WS request — send 400 and close
                var bad = "HTTP/1.1 400 Bad Request" + CRLF +
                    "Content-Length: 0" + CRLF + CRLF;
                _nb.tcpWrite(clientHandle, bad);
                _nb.tcpClose(clientHandle);
                return;
            }

            // Perform upgrade
            self.handleUpgrade(req, clientHandle, "", function(ws, request) {
                self.emit("connection", ws, request);

                // Start read loop
                _wsReadLoopNb(ws);
            });
        });
    }

    _onHttpUpgrade(req, socket, head) {
        // Called when attached to an http.Server via options.server
        var self = this;
        var clientHandle = socket;
        if (typeof socket === "object" && socket._handle) {
            clientHandle = socket._handle;
        }

        this.handleUpgrade(req, clientHandle, head, function(ws, request) {
            self.emit("connection", ws, request);
            _wsReadLoopNb(ws);
        });
    }
}

module.exports = {
    ServerWebSocket: ServerWebSocket,
    WebSocketServer: WebSocketServer,
    _doUpgrade: _doUpgrade,
    _wsReadLoop: _wsReadLoop,
    _wsReadLoopNb: _wsReadLoopNb
};
