// WebSocket — WHATWG WebSocket API
// Phase 6.9 — implements RFC 6455 client using native frame codec bridge.
//
// Send path: uses __ws.sendFrame() which builds the frame in a native buffer
// and writes it with explicit byte count — binary-safe (handles null bytes in
// mask keys and XOR'd payloads).
//
// Receive path: uses string-based async I/O (tcpReadNb / tlsReadNb).  Works
// correctly for unmasked TEXT frames from the server (no null bytes in UTF-8).
// Pure-JS frame decoding avoids the removed string-based native decoder.
//
// Reference: https://websockets.spec.whatwg.org/
// Bun ref:   bun/src/http/websocket_client.zig

var EventEmitter = require("events");
var _wb = __ws;  // native WebSocket bridge
var _nb = __net; // native net bridge
var CRLF = String.fromCharCode(13) + "\n";

// ── Constants ────────────────────────────────────────────────────────────────
var CONNECTING = 0;
var OPEN       = 1;
var CLOSING    = 2;
var CLOSED     = 3;

var OP_TEXT   = 1;
var OP_BINARY = 2;
var OP_CLOSE  = 8;
var OP_PING   = 9;
var OP_PONG   = 10;

// ── Pure-JS frame decoder (for unmasked server→client frames) ────────────────

function _decodeFrameJS(data, offset) {
    var avail = data.length - offset;
    if (avail < 2) { return [-1, 0, 0, 0, 0]; }
    var b0 = data.charCodeAt(offset);
    var b1 = data.charCodeAt(offset + 1);
    var fin = (b0 & 128) ? 1 : 0;
    var opcode = b0 & 15;
    var masked = (b1 & 128) ? 1 : 0;
    var plen = b1 & 127;
    var hoff = offset + 2;
    if (plen === 126) {
        if (avail < 4) { return [-1, 0, 0, 0, 0]; }
        plen = data.charCodeAt(hoff) * 256 + data.charCodeAt(hoff + 1);
        hoff = hoff + 2;
    } else if (plen === 127) {
        if (avail < 10) { return [-1, 0, 0, 0, 0]; }
        plen = 0;
        for (var i = 0; i < 8; i++) {
            plen = plen * 256 + data.charCodeAt(hoff + i);
        }
        hoff = hoff + 8;
    }
    if (masked) { hoff = hoff + 4; }
    var totalLen = (hoff - offset) + plen;
    if (avail < totalLen) { return [-1, 0, 0, 0, 0]; }
    return [opcode, hoff, plen, totalLen, fin];
}

function _parseCloseJS(data, start, plen) {
    if (plen < 2) { return [1005, ""]; }
    var code = data.charCodeAt(start) * 256 + data.charCodeAt(start + 1);
    var reason = plen > 2 ? data.substring(start + 2, start + plen) : "";
    return [code, reason];
}

// ── URL parser (ws:// and wss://) ────────────────────────────────────────────
function _parseWsUrl(url) {
    var secure = false;
    var rest = url;

    if (rest.indexOf("wss://") === 0) {
        secure = true;
        rest = rest.substring(6);
    } else if (rest.indexOf("ws://") === 0) {
        rest = rest.substring(5);
    } else {
        throw new Error("WebSocket: invalid URL scheme (expected ws:// or wss://)");
    }

    var pathStart = rest.indexOf("/");
    var hostPort = pathStart >= 0 ? rest.substring(0, pathStart) : rest;
    var path = pathStart >= 0 ? rest.substring(pathStart) : "/";

    var host = hostPort;
    var port = secure ? 443 : 80;

    var colonIdx = hostPort.lastIndexOf(":");
    if (colonIdx > 0) {
        var portStr = hostPort.substring(colonIdx + 1);
        var parsedPort = parseInt(portStr, 10);
        if (parsedPort > 0 && parsedPort < 65536) {
            host = hostPort.substring(0, colonIdx);
            port = parsedPort;
        }
    }

    return { host: host, port: port, path: path, secure: secure };
}

// ── WebSocket class ─────────────────────────────────────────────────────────

class WebSocket extends EventEmitter {
    constructor(url, protocols) {
        super();

        if (typeof url !== "string") {
            throw new TypeError("WebSocket: url must be a string");
        }

        this.url = url;
        this.readyState = CONNECTING;
        this.bufferedAmount = 0;
        this.extensions = "";
        this.protocol = "";
        this.binaryType = "blob";
        this._buffer = "";
        this._handle = 0;
        this._secure = false;
        this._socket = null;
        this._key = "";

        this.onopen = null;
        this.onmessage = null;
        this.onclose = null;
        this.onerror = null;

        this._protocols = [];
        if (typeof protocols === "string") {
            this._protocols = [protocols];
        } else if (protocols && typeof protocols.length === "number") {
            for (var i = 0; i < protocols.length; i++) {
                this._protocols.push(protocols[i]);
            }
        }

        var parsed = _parseWsUrl(url);
        this._secure = parsed.secure;
        this._host = parsed.host;
        this._port = parsed.port;
        this._path = parsed.path;
        this._key = _wb.randomKey();

        var self = this;
        this._connect(function() {
            self._doHandshake();
        });
    }

    // ── Connection ───────────────────────────────────────────────────────────

    _connect(callback) {
        var self = this;

        if (this._secure) {
            _nb.tlsConnectNb(this._host, this._port, function(handle, errCode) {
                if (errCode !== 0 || handle === 0) {
                    self._emitError("connect ECONNREFUSED " + self._host + ":" + self._port);
                    self._close(1006, "");
                    return;
                }
                self._handle = handle;
                self._secure = true;
                callback();
            });
        } else {
            _nb.tcpConnectNb(this._host, this._port, function(handle, errCode) {
                if (errCode !== 0 || handle === 0) {
                    self._emitError("connect ECONNREFUSED " + self._host + ":" + self._port);
                    self._close(1006, "");
                    return;
                }
                self._handle = handle;
                callback();
            });
        }
    }

    // ── HTTP Upgrade Handshake ───────────────────────────────────────────────

    _doHandshake() {
        var req = "GET " + this._path + " HTTP/1.1" + CRLF;
        req += "Host: " + this._host;
        if ((this._secure && this._port !== 443) || (!this._secure && this._port !== 80)) {
            req += ":" + this._port;
        }
        req += CRLF;
        req += "Upgrade: websocket" + CRLF;
        req += "Connection: Upgrade" + CRLF;
        req += "Sec-WebSocket-Key: " + this._key + CRLF;
        req += "Sec-WebSocket-Version: 13" + CRLF;
        if (this._protocols.length > 0) {
            req += "Sec-WebSocket-Protocol: " + this._protocols.join(", ") + CRLF;
        }
        req += CRLF;

        this._writeRaw(req);
        this._readHandshakeResponse();
    }

    _readHandshakeResponse() {
        var self = this;
        var doubleCRLF = CRLF + CRLF;

        this._readNb(function(data) {
            if (!data || data.length === 0) {
                self._emitError("WebSocket handshake: connection closed");
                self._close(1006, "");
                return;
            }

            self._buffer += data;

            var headerEnd = self._buffer.indexOf(doubleCRLF);
            if (headerEnd < 0) {
                self._readHandshakeResponse();
                return;
            }

            var headerSection = self._buffer.substring(0, headerEnd);
            var remaining = self._buffer.substring(headerEnd + doubleCRLF.length);
            self._buffer = remaining;

            var firstLine = "";
            var cr = String.fromCharCode(13);
            var lineEnd = headerSection.indexOf(cr);
            if (lineEnd >= 0) {
                firstLine = headerSection.substring(0, lineEnd);
            } else {
                firstLine = headerSection;
            }

            if (firstLine.indexOf("101") < 0) {
                var hasUR = self.listeners("unexpected-response").length > 0;
                if (hasUR) {
                    self.emit("unexpected-response", firstLine, headerSection);
                } else {
                    self._emitError("WebSocket handshake: unexpected status: " + firstLine);
                }
                self._close(1006, "");
                return;
            }

            var headers = {};
            var pos = firstLine.length + CRLF.length;
            while (pos < headerSection.length) {
                var nl = headerSection.indexOf(cr, pos);
                if (nl < 0) { nl = headerSection.length; }
                var line = headerSection.substring(pos, nl);
                pos = nl + CRLF.length;
                var colonIdx = line.indexOf(":");
                if (colonIdx > 0) {
                    var key = line.substring(0, colonIdx).toLowerCase();
                    var val = line.substring(colonIdx + 1);
                    while (val.length > 0 && val.charAt(0) === " ") {
                        val = val.substring(1);
                    }
                    headers[key] = val;
                }
            }

            var expectedAccept = _wb.acceptKey(self._key);
            var actualAccept = headers["sec-websocket-accept"] || "";
            if (actualAccept !== expectedAccept) {
                self._emitError("WebSocket handshake: Sec-WebSocket-Accept mismatch");
                self._close(1006, "");
                return;
            }

            if (headers["sec-websocket-protocol"]) {
                self.protocol = headers["sec-websocket-protocol"];
            }
            if (headers["sec-websocket-extensions"]) {
                self.extensions = headers["sec-websocket-extensions"];
            }

            self.readyState = OPEN;
            self.emit("open");
            if (self.onopen) { self.onopen({ type: "open", target: self }); }

            self._readLoop();
        });
    }

    // ── Frame I/O ────────────────────────────────────────────────────────────

    _readLoop() {
        var self = this;
        if (self.readyState === CLOSED) { return; }

        // Process any data already buffered (e.g. frames coalesced with
        // the HTTP 101 response in the same TCP read).
        if (self._buffer.length > 0) {
            self._processFrames();
            if (self.readyState !== OPEN && self.readyState !== CLOSING) {
                return;
            }
        }

        self._readNb(function(data) {
            if (!data || data.length === 0) {
                if (self.readyState !== CLOSED && self.readyState !== CLOSING) {
                    self._close(1006, "");
                }
                return;
            }

            self._buffer += data;
            self._processFrames();

            if (self.readyState === OPEN || self.readyState === CLOSING) {
                self._readLoop();
            }
        });
    }

    _processFrames() {
        while (this._buffer.length > 0) {
            var result = _decodeFrameJS(this._buffer, 0);
            var opcode = result[0];
            var payloadStart = result[1];
            var payloadLen = result[2];
            var frameLen = result[3];
            var fin = result[4];

            if (opcode === -1) { break; }

            var payload = this._buffer.substring(payloadStart, payloadStart + payloadLen);
            this._buffer = this._buffer.substring(frameLen);
            this._handleFrame(opcode, payload, fin);
        }
    }

    _handleFrame(opcode, payload, fin) {
        if (opcode === OP_TEXT || opcode === OP_BINARY) {
            var ev = { type: "message", data: payload, isBinary: opcode === OP_BINARY, target: this };
            this.emit("message", ev);
            if (this.onmessage) { this.onmessage(ev); }
        } else if (opcode === OP_CLOSE) {
            var closeResult = _parseCloseJS(payload, 0, payload.length);
            var code = closeResult[0];
            var reason = closeResult[1];

            if (this.readyState === OPEN) {
                this.readyState = CLOSING;
                var cp = _wb.makeClosePayload(code, reason);
                _wb.sendFrame(this._handle, OP_CLOSE, cp, true, this._secure);
            }
            this._close(code, reason);
        } else if (opcode === OP_PING) {
            if (this.readyState === OPEN) {
                _wb.sendFrame(this._handle, OP_PONG, payload, true, this._secure);
            }
            this.emit("ping", payload);
        } else if (opcode === OP_PONG) {
            this.emit("pong", payload);
        }
    }

    // ── Public API ───────────────────────────────────────────────────────────

    send(data) {
        if (this.readyState !== OPEN) {
            throw new Error("WebSocket is not open (readyState=" + this.readyState + ")");
        }

        var opcode = OP_TEXT;
        if (typeof data !== "string") {
            opcode = OP_BINARY;
            data = String(data);
        }

        _wb.sendFrame(this._handle, opcode, data, true, this._secure);
    }

    close(code, reason) {
        if (this.readyState === CLOSING || this.readyState === CLOSED) {
            return;
        }

        if (code === undefined) { code = 1000; }
        if (reason === undefined) { reason = ""; }

        this.readyState = CLOSING;

        var closePayload = _wb.makeClosePayload(code, reason);
        _wb.sendFrame(this._handle, OP_CLOSE, closePayload, true, this._secure);
    }

    ping(data) {
        if (this.readyState !== OPEN) { return; }
        if (data === undefined) { data = ""; }
        _wb.sendFrame(this._handle, OP_PING, data, true, this._secure);
    }

    pong(data) {
        if (this.readyState !== OPEN) { return; }
        if (data === undefined) { data = ""; }
        _wb.sendFrame(this._handle, OP_PONG, data, true, this._secure);
    }

    terminate() {
        if (this.readyState === CLOSED) { return; }
        this._close(1006, "");
    }

    // ── Low-level I/O helpers ────────────────────────────────────────────────

    _writeRaw(data) {
        if (this._handle === 0) { return; }
        if (this._secure) {
            _nb.tlsWrite(this._handle, data);
        } else {
            _nb.tcpWrite(this._handle, data);
        }
    }

    _readNb(callback) {
        if (this._handle === 0) {
            callback("");
            return;
        }
        if (this._secure) {
            _nb.tlsReadNb(this._handle, 65536, callback);
        } else {
            _nb.tcpReadNb(this._handle, 65536, callback);
        }
    }

    _close(code, reason) {
        if (this.readyState === CLOSED) { return; }
        this.readyState = CLOSED;

        if (this._handle !== 0) {
            if (this._secure) {
                _nb.tlsClose(this._handle);
            } else {
                _nb.tcpClose(this._handle);
            }
            this._handle = 0;
        }

        var ev = { type: "close", code: code, reason: reason, wasClean: code === 1000, target: this };
        this.emit("close", ev);
        if (this.onclose) { this.onclose(ev); }
    }

    _emitError(msg) {
        var ev = { type: "error", message: msg, target: this };
        this.emit("error", ev);
        if (this.onerror) { this.onerror(ev); }
    }
}

// Static constants
WebSocket.CONNECTING = CONNECTING;
WebSocket.OPEN       = OPEN;
WebSocket.CLOSING    = CLOSING;
WebSocket.CLOSED     = CLOSED;

// ── Module exports ───────────────────────────────────────────────────────────

globalThis.WebSocket = WebSocket;

module.exports = WebSocket;
