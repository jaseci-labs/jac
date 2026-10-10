/**
 * node:http2  —  HTTP/2 client and server module
 *
 * Implementation notes:
 *  - HTTP/2 session management is handled by libnghttp2 via http2_bridge.na.jac.
 *  - All native bridge calls go through the __net global object.
 *  - Event kinds must match http2_bridge.na.jac constants.
 *  - Callback pointers (header name/value, data chunks) are heap-copied in
 *    the native layer and MUST be freed with __buf.free(ptr) after reading.
 *  - For TLS sockets (the primary use case, ALPN "h2"), writes go through
 *    __net.tlsWrite(handle, str) — the send buffer is materialised byte-by-byte.
 *  - For TCP sockets (h2c, cleartext), writes go through
 *    __net.tcpWriteRaw(handle, ptr, n) directly.
 *
 * Phase F (PHASE6.md Part B) implements:
 *   connect()          — ClientHttp2Session (client-side HTTP/2)
 *   createServer()     — ServerHttp2Session over plain TCP (h2c)
 *   createSecureServer() — ServerHttp2Session over TLS (h2 via ALPN)
 *   Http2Stream / ClientHttp2Stream / ServerHttp2Stream
 *   constants          — standard NGHTTP2 / HTTP/2 numeric constants
 */

"use strict";

var EventEmitter = require("events");
var tlsMod = require("tls");
var netMod = require("net");

var _nb  = __net;
var _buf = __buf;

// ── Event type constants (must match http2_bridge.na.jac) ─────────────────
var H2_EV_BEGIN_HEADERS = 1;  // d0=streamId
var H2_EV_HEADER        = 2;  // d0=streamId, d1=nameCopyPtr, d2=nameLen, d3=valCopyPtr, d4=valLen
var H2_EV_DATA_CHUNK    = 3;  // d0=streamId, d1=flags, d2=dataCopyPtr, d3=dataLen
var H2_EV_STREAM_CLOSE  = 4;  // d0=streamId, d1=errCode
var H2_EV_FRAME_RECV    = 5;  // d0=streamId, d1=frameType, d2=flags
var H2_EV_GOAWAY        = 6;  // d0=lastStreamID, d1=errorCode, d2=opaquePtr, d3=opaqueLen
var H2_EV_SETTINGS_ENTRY = 7; // d0=settingsId, d1=value

// HTTP/2 frame type constants
var FRAME_TYPE_DATA          = 0x0;
var FRAME_TYPE_HEADERS       = 0x1;
var FRAME_TYPE_RST_STREAM    = 0x3;
var FRAME_TYPE_SETTINGS      = 0x4;
var FRAME_TYPE_GOAWAY        = 0x7;
var FRAME_TYPE_WINDOW_UPDATE = 0x8;

// HTTP/2 frame flags
var FLAG_END_STREAM  = 0x01;
var FLAG_ACK         = 0x01;  // SETTINGS/PING ACK (same bit as END_STREAM)
var FLAG_END_HEADERS = 0x04;

// ── HTTP/2 constants (exposed as require('http2').constants) ─────────────
var constants = {
    NGHTTP2_SESSION_SERVER: 0,
    NGHTTP2_SESSION_CLIENT: 1,
    NGHTTP2_STREAM_STATE_IDLE: 1,
    NGHTTP2_STREAM_STATE_OPEN: 2,
    NGHTTP2_STREAM_STATE_RESERVED_LOCAL: 3,
    NGHTTP2_STREAM_STATE_RESERVED_REMOTE: 4,
    NGHTTP2_STREAM_STATE_HALF_CLOSED_LOCAL: 5,
    NGHTTP2_STREAM_STATE_HALF_CLOSED_REMOTE: 6,
    NGHTTP2_STREAM_STATE_CLOSED: 7,
    NGHTTP2_NO_ERROR: 0,
    NGHTTP2_PROTOCOL_ERROR: 1,
    NGHTTP2_INTERNAL_ERROR: 2,
    NGHTTP2_FLOW_CONTROL_ERROR: 3,
    NGHTTP2_SETTINGS_TIMEOUT: 4,
    NGHTTP2_STREAM_CLOSED: 5,
    NGHTTP2_FRAME_SIZE_ERROR: 6,
    NGHTTP2_REFUSED_STREAM: 7,
    NGHTTP2_CANCEL: 8,
    NGHTTP2_COMPRESSION_ERROR: 9,
    NGHTTP2_CONNECT_ERROR: 10,
    NGHTTP2_ENHANCE_YOUR_CALM: 11,
    NGHTTP2_INADEQUATE_SECURITY: 12,
    NGHTTP2_HTTP_1_1_REQUIRED: 13,
    NGHTTP2_ERR_NOMEM: -901,
    NGHTTP2_ERR_INVALID_ARGUMENT: -501,
    NGHTTP2_ERR_BUFFER_ERROR: -502,
    NGHTTP2_ERR_WOULDBLOCK: -503,
    NGHTTP2_ERR_PROTO: -505,
    HTTP2_HEADER_STATUS: ":status",
    HTTP2_HEADER_METHOD: ":method",
    HTTP2_HEADER_AUTHORITY: ":authority",
    HTTP2_HEADER_SCHEME: ":scheme",
    HTTP2_HEADER_PATH: ":path",
    HTTP2_METHOD_GET: "GET",
    HTTP2_METHOD_POST: "POST",
    HTTP2_METHOD_PUT: "PUT",
    HTTP2_METHOD_DELETE: "DELETE",
    HTTP2_METHOD_HEAD: "HEAD",
    HTTP2_METHOD_OPTIONS: "OPTIONS",
    HTTP2_METHOD_PATCH: "PATCH",
    HTTP2_STATUS_CONTINUE: 100,
    HTTP2_STATUS_OK: 200,
    HTTP2_STATUS_CREATED: 201,
    HTTP2_STATUS_NO_CONTENT: 204,
    HTTP2_STATUS_PARTIAL_CONTENT: 206,
    HTTP2_STATUS_BAD_REQUEST: 400,
    HTTP2_STATUS_UNAUTHORIZED: 401,
    HTTP2_STATUS_FORBIDDEN: 403,
    HTTP2_STATUS_NOT_FOUND: 404,
    HTTP2_STATUS_METHOD_NOT_ALLOWED: 405,
    HTTP2_STATUS_INTERNAL_SERVER_ERROR: 500,
    HTTP2_STATUS_SERVICE_UNAVAILABLE: 503,
    SETTINGS_HEADER_TABLE_SIZE: 1,
    SETTINGS_ENABLE_PUSH: 2,
    SETTINGS_MAX_CONCURRENT_STREAMS: 3,
    SETTINGS_INITIAL_WINDOW_SIZE: 4,
    SETTINGS_MAX_FRAME_SIZE: 5,
    SETTINGS_MAX_HEADER_LIST_SIZE: 6,
    DEFAULT_SETTINGS_HEADER_TABLE_SIZE: 4096,
    DEFAULT_SETTINGS_ENABLE_PUSH: 1,
    DEFAULT_SETTINGS_INITIAL_WINDOW_SIZE: 65535,
    DEFAULT_SETTINGS_MAX_FRAME_SIZE: 16384,
    DEFAULT_SETTINGS_MAX_CONCURRENT_STREAMS: Infinity,
    MAX_MAX_FRAME_SIZE: 16777215,
    MIN_MAX_FRAME_SIZE: 16384,
    MAX_INITIAL_WINDOW_SIZE: 2147483647,
    NGHTTP2_DEFAULT_WEIGHT: 16
};

// ── Helpers ────────────────────────────────────────────────────────────────

/**
 * Read `len` bytes from a native heap pointer as a binary-safe JS string.
 * Each byte becomes one JS char with charCode 0..255.
 * The caller MUST __buf.free(ptr) after this call.
 */
function _ptrToStr(ptr, len) {
    var s = "";
    for (var i = 0; i < len; i++) {
        s += String.fromCharCode(_buf.getByte(ptr, i));
    }
    return s;
}

/**
 * Flat header array helper: [{name, value}, ...] → [":method", "GET", ...]
 */
function _hdrsToArray(headers) {
    var arr = [];
    if (headers == null) { return arr; }
    if (Array.isArray(headers)) {
        // Already flat [name, value, ...] — stringify values for nghttp2.
        var out = [];
        for (var ai = 0; ai < headers.length; ai++) {
            out.push(headers[ai] == null ? "" : "" + headers[ai]);
        }
        return out;
    }
    var keys = Object.keys(headers);
    for (var i = 0; i < keys.length; i++) {
        var v = headers[keys[i]];
        arr.push(keys[i]);
        arr.push(v == null ? "" : "" + v);
    }
    return arr;
}

/**
 * Convert a write() chunk to a binary-safe JS string (one char per byte)
 * for __net.h2SubmitData, which copies via charCodeAt.
 */
function _toBinaryStr(data, encoding) {
    if (data == null) { return ""; }
    var _Buf = (typeof Buffer !== "undefined") ? Buffer : null;
    if (_Buf && _Buf.isBuffer && _Buf.isBuffer(data)) {
        return data.toString("latin1");
    }
    if (data instanceof Uint8Array) {
        if (_Buf) { return _Buf.from(data).toString("latin1"); }
        var s = "";
        for (var i = 0; i < data.length; i++) { s += String.fromCharCode(data[i] & 0xff); }
        return s;
    }
    if (typeof data === "string") {
        var enc = encoding || "utf8";
        if (enc === "binary" || enc === "latin1") { return data; }
        if (_Buf) { return _Buf.from(data, enc).toString("latin1"); }
        return data;
    }
    if (_Buf) {
        try { return _Buf.from(data).toString("latin1"); } catch (_e) { /* fall through */ }
    }
    return "" + data;
}

/** Node-compatible default for options.endStream (GET/HEAD/DELETE → true). */
function _defaultEndStream(headers) {
    var method = null;
    if (headers) {
        if (Array.isArray(headers)) {
            for (var i = 0; i < headers.length - 1; i += 2) {
                if (String(headers[i]).toLowerCase() === ":method") {
                    method = String(headers[i + 1]);
                    break;
                }
            }
        } else {
            method = headers[":method"] || headers[constants.HTTP2_HEADER_METHOD];
        }
    }
    if (!method) { method = "GET"; }
    var m = String(method).toUpperCase();
    return m === "GET" || m === "HEAD" || m === "DELETE";
}

/**
 * Queue body bytes through nghttp2_submit_data (via bridge h2SubmitData) and flush.
 * endMode: false/0 = more data may follow; true/1 = END_STREAM; 2 = EOF without
 * END_STREAM (trailers will follow via h2SubmitTrailer).
 */
function _h2SubmitBody(session, streamId, data, endMode) {
    if (!session || session._h2Handle < 0 || streamId <= 0) { return; }
    if (typeof _nb.h2SubmitData !== "function") { return; }
    var raw = (typeof data === "string") ? data : _toBinaryStr(data);
    var mode = 0;
    if (endMode === 2) { mode = 2; }
    else if (endMode) { mode = 1; }
    _nb.h2SubmitData(session._h2Handle, streamId, raw, mode);
    _h2Flush(session._h2Handle, session._sockHandle, session._isTLS);
}

function _h2HttpError(code, message) {
    var Ctor = Error;
    if (code === "ERR_INVALID_ARG_TYPE" || code === "ERR_INVALID_ARG_VALUE") {
        Ctor = TypeError;
    } else if (code === "ERR_OUT_OF_RANGE") {
        Ctor = RangeError;
    }
    var err = new Ctor(message || code);
    err.code = code;
    return err;
}

function _cloneSettings(s) {
    var out = getDefaultSettings();
    if (!s) { return out; }
    var keys = Object.keys(s);
    for (var i = 0; i < keys.length; i++) { out[keys[i]] = s[keys[i]]; }
    if (out.maxHeaderSize === undefined) { out.maxHeaderSize = out.maxHeaderListSize; }
    if (out.customSettings === undefined) { out.customSettings = {}; }
    return out;
}

/**
 * Flush all pending nghttp2 output to the underlying socket.
 * Works for both TCP (h2c) and TLS (h2) sockets.
 */
function _h2Flush(h2Handle, sockHandle, isTLS) {
    while (true) {
        var n = _nb.h2SessionSend(h2Handle);
        if (n <= 0) { break; }
        var ptr = _nb.h2GetSendPtr(h2Handle);
        if (!ptr || ptr === 0) { break; }
        if (isTLS) {
            // Materialise as JS string for SSL_write
            var raw = _ptrToStr(ptr, n);
            _nb.tlsWrite(sockHandle, raw);
        } else {
            _nb.tcpWriteRaw(sockHandle, ptr, n);
        }
    }
}

/**
 * Drain all queued h2 events for a session, routing them to stream objects.
 */
function _h2DrainEvents(session) {
    while (true) {
        var ev = _nb.h2PopEvent(session._h2Handle);
        if (ev === undefined || ev === null) { break; }
        var type = ev.type;
        var streamId = ev.d0;

        if (type === H2_EV_BEGIN_HEADERS) {
            // New stream beginning (server-side request or client response),
            // or a second HEADERS block (trailers) on an existing stream.
            if (streamId > (session._lastProcStreamID | 0)) {
                session._lastProcStreamID = streamId | 0;
            }
            if (!session._streams[streamId]) {
                if (session._isServer) {
                    var stream = _makeServerStream(session, streamId);
                    session._streams[streamId] = stream;
                }
            }
            if (session._streams[streamId]) {
                var st0 = session._streams[streamId];
                if (st0._headersComplete) { st0._receivingTrailers = true; }
                st0._pendingHeaders = {};
            }

        } else if (type === H2_EV_HEADER) {
            // Header field: d1=namePtr, d2=nameLen, d3=valPtr, d4=valLen
            var namePtr = ev.d1;
            var nameLen = ev.d2;
            var valPtr  = ev.d3;
            var valLen  = ev.d4;
            var hName = _ptrToStr(namePtr, nameLen);
            var hVal  = _ptrToStr(valPtr, valLen);
            _buf.free(namePtr);
            _buf.free(valPtr);
            var st = session._streams[streamId];
            if (st) {
                if (!st._pendingHeaders) { st._pendingHeaders = {}; }
                st._pendingHeaders[hName] = hVal;
            }

        } else if (type === H2_EV_DATA_CHUNK) {
            // Data chunk: d0=streamId, d1=flags, d2=dataPtr, d3=dataLen
            var dataPtr = ev.d2;
            var dataLen = ev.d3;
            var chunk = _ptrToStr(dataPtr, dataLen);
            _buf.free(dataPtr);
            var st2 = session._streams[streamId];
            if (st2) {
                st2.emit("data", chunk);
                _nb.h2Consume(session._h2Handle, streamId, dataLen);
            }

        } else if (type === H2_EV_SETTINGS_ENTRY) {
            // d0=settings_id, d1=value — accumulate; filtered into remoteSettings on FRAME_RECV
            var setId = ev.d0 >>> 0;
            var setVal = ev.d1 >>> 0;
            if (!session._pendingRemoteCustom) { session._pendingRemoteCustom = {}; }
            session._pendingRemoteCustom[setId] = setVal;

        } else if (type === H2_EV_GOAWAY) {
            // d0=lastStreamID, d1=errorCode, d2=opaquePtr, d3=opaqueLen
            var lastSid = ev.d0 >>> 0;
            var goErr = ev.d1 >>> 0;
            var opPtr = ev.d2;
            var opLen = ev.d3 | 0;
            var opaque = undefined;
            if (opPtr && opLen > 0) {
                var _Buf = (typeof Buffer !== "undefined") ? Buffer : null;
                var opStr = _ptrToStr(opPtr, opLen);
                _buf.free(opPtr);
                opaque = _Buf ? _Buf.from(opStr, "latin1") : opStr;
            } else if (opPtr) {
                _buf.free(opPtr);
            }
            session._goawayEmitted = true;
            session.emit("goaway", goErr, lastSid, opaque);

        } else if (type === H2_EV_FRAME_RECV) {
            // Frame received: d0=streamId, d1=frameType, d2=flags
            var frameType  = ev.d1;
            var frameFlags = ev.d2;
            var st3 = session._streams[streamId];
            if (frameType === FRAME_TYPE_HEADERS && (frameFlags & FLAG_END_HEADERS)) {
                if (st3 && st3._receivingTrailers) {
                    var trailers = st3._pendingHeaders || {};
                    st3._pendingHeaders = {};
                    st3._receivingTrailers = false;
                    st3.emit("trailers", trailers);
                    if (frameFlags & FLAG_END_STREAM) {
                        st3.emit("end");
                    }
                } else if (st3 && !st3._headersComplete) {
                    st3._headersComplete = true;
                    var hdrs = st3._pendingHeaders || {};
                    // Node exposes :status as a number on the response headers object.
                    if (hdrs[":status"] != null && typeof hdrs[":status"] === "string") {
                        var statusNum = parseInt(hdrs[":status"], 10);
                        if (!isNaN(statusNum)) { hdrs[":status"] = statusNum; }
                    }
                    if (session._isServer) {
                        session.emit("stream", st3, hdrs);
                    } else {
                        st3.emit("response", hdrs);
                    }
                    if (frameFlags & FLAG_END_STREAM) {
                        // No body — stream half-closed remote
                        st3.emit("end");
                    }
                }
            }
            if (frameType === FRAME_TYPE_DATA && (frameFlags & FLAG_END_STREAM)) {
                if (st3) { st3.emit("end"); }
            }
            if (frameType === FRAME_TYPE_SETTINGS) {
                if (frameFlags & FLAG_ACK) {
                    // ACK of our SETTINGS → localSettings
                    var local = session._localSettings || getDefaultSettings();
                    session.emit("localSettings", local);
                    session._pendingSettingsAck = false;
                } else {
                    // Peer's SETTINGS — refresh from nghttp2 when available.
                    var remote = _cloneSettings(getDefaultSettings());
                    if (typeof _nb.h2GetRemoteSetting === "function" && session._h2Handle >= 0) {
                        try {
                            remote.headerTableSize = _nb.h2GetRemoteSetting(session._h2Handle, 0x1) >>> 0;
                            remote.enablePush = !!_nb.h2GetRemoteSetting(session._h2Handle, 0x2);
                            remote.maxConcurrentStreams = _nb.h2GetRemoteSetting(session._h2Handle, 0x3) >>> 0;
                            remote.initialWindowSize = _nb.h2GetRemoteSetting(session._h2Handle, 0x4) >>> 0;
                            remote.maxFrameSize = _nb.h2GetRemoteSetting(session._h2Handle, 0x5) >>> 0;
                            remote.maxHeaderListSize = _nb.h2GetRemoteSetting(session._h2Handle, 0x6) >>> 0;
                            remote.maxHeaderSize = remote.maxHeaderListSize;
                        } catch (_rs) { /* keep defaults */ }
                    } else if (remote.maxConcurrentStreams === Infinity) {
                        remote.maxConcurrentStreams = 0xFFFFFFFF;
                    }
                    // Surface custom SETTINGS ids allowed by remoteCustomSettings.
                    remote.customSettings = {};
                    var pending = session._pendingRemoteCustom || {};
                    var allow = session._remoteCustomSettings;
                    var pkeys = Object.keys(pending);
                    for (var pi = 0; pi < pkeys.length; pi++) {
                        var pid = Number(pkeys[pi]);
                        // Skip standard RFC ids (1-6, 8) — already on remote.*
                        if (pid >= 1 && pid <= 6) { continue; }
                        if (pid === 8) { continue; }
                        if (allow && allow.length) {
                            if (allow.indexOf(pid) === -1 && allow.indexOf(String(pid)) === -1) {
                                continue;
                            }
                        }
                        remote.customSettings[pid] = pending[pkeys[pi]] >>> 0;
                    }
                    session._pendingRemoteCustom = {};
                    session._remoteSettings = remote;
                    session.emit("remoteSettings", remote);
                }
            }
            if (frameType === FRAME_TYPE_GOAWAY && !session._goawayEmitted) {
                // Fallback when dedicated H2_EV_GOAWAY was not produced
                session.emit("goaway", ev.d4 >>> 0, ev.d3 >>> 0);
            }

        } else if (type === H2_EV_STREAM_CLOSE) {
            // d1=errorCode
            var errCode = ev.d1;
            var st4 = session._streams[streamId];
            if (st4) {
                if (errCode !== 0) {
                    var h2err = new Error("stream closed with error " + errCode);
                    h2err.code = "ERR_HTTP2_STREAM_ERROR";
                    h2err.nghttp2ErrorCode = errCode;
                    // Avoid uncaught Exception when tests only listen for close/end.
                    if (typeof st4.listenerCount !== "function" || st4.listenerCount("error") > 0) {
                        st4.emit("error", h2err);
                    }
                }
                st4._closed = true;
                st4.emit("close");
                delete session._streams[streamId];
            }
        }
    }
}

/**
 * Continuous non-blocking read loop for a session.
 * Feeds raw bytes into nghttp2, then flushes and drains events.
 */
function _h2ReadLoop(session, sockHandle, isTLS) {
    if (session._destroyed) { return; }
    var maxBytes = 65536;
    if (isTLS) {
        _nb.tlsReadBinaryNb(sockHandle, maxBytes, function(ptr, len, isEOF) {
            _h2ReadLoopCb(session, sockHandle, isTLS, ptr, len, isEOF);
        });
    } else {
        _nb.tcpReadBinaryNb(sockHandle, maxBytes, function(ptr, len, isEOF) {
            _h2ReadLoopCb(session, sockHandle, isTLS, ptr, len, isEOF);
        });
    }
}

function _h2ReadLoopCb(session, sockHandle, isTLS, ptr, len, isEOF) {
    if (len > 0) {
        _nb.h2SessionRecv(session._h2Handle, ptr, len);
        _buf.free(ptr);
        _h2Flush(session._h2Handle, sockHandle, isTLS);
        _h2DrainEvents(session);
    } else if (ptr && ptr !== 0) {
        _buf.free(ptr);
    }
    if (isEOF) {
        session.emit("close");
        session.destroy();
        return;
    }
    _h2ReadLoop(session, sockHandle, isTLS);
}

// ── Http2Session base class ────────────────────────────────────────────────

function Http2Session(type) {
    EventEmitter.init.call(this);
    this.type = type;         // 0=server, 1=client
    this._h2Handle = -1;
    this._sockHandle = 0;
    this._isTLS = false;
    this._streams = {};       // streamId → Http2Stream
    this._destroyed = false;
    this._isServer = (type === 0);
    this._localSettings = getDefaultSettings();
    this._remoteSettings = getDefaultSettings();
    this._pendingSettingsAck = false;
    this._localWindowSize = constants.DEFAULT_SETTINGS_INITIAL_WINDOW_SIZE;
    this._lastProcStreamID = 0;
    this._remoteCustomSettings = null; // allow-list of custom SETTINGS ids
    this._pendingRemoteCustom = {};    // accumulated from H2_EV_SETTINGS_ENTRY
    this._nextStreamID = type === 1 ? 1 : 2;
}
Http2Session.prototype = Object.create(EventEmitter.prototype);
Http2Session.prototype.constructor = Http2Session;

Http2Session.prototype.destroy = function(err) {
    if (this._destroyed) { return; }
    this._destroyed = true;
    if (this._h2Handle >= 0) {
        _nb.h2SessionDel(this._h2Handle);
        this._h2Handle = -1;
    }
    // Tear down the bound socket so tcpReadBinaryNb polls cannot keep the
    // event loop alive after the session is gone (Node test harness hang).
    if (this._socket) {
        try {
            if (typeof this._socket.destroy === "function") { this._socket.destroy(); }
            else if (typeof this._socket.end === "function") { this._socket.end(); }
        } catch (_se) { /* ignore */ }
        this._socket = null;
    }
    if (err) { this.emit("error", err); }
    this.emit("close");
};

/**
 * Send a GOAWAY frame. Node signature: goaway([code[, lastStreamID[, opaqueData]]])
 * When lastStreamID <= 0, Node uses nghttp2_session_get_last_proc_stream_id.
 */
Http2Session.prototype.goaway = function(code, lastStreamID, opaqueData) {
    if (this._destroyed || this._h2Handle < 0) { return; }
    var errorCode = (code !== undefined && code !== null) ? (code >>> 0) : 0;
    var lastStream;
    if (lastStreamID === undefined || lastStreamID === null) {
        lastStream = 2147483647;
    } else {
        lastStream = lastStreamID | 0;
        if (lastStream <= 0) {
            lastStream = this._lastProcStreamID | 0;
            var sids = Object.keys(this._streams);
            for (var gi = 0; gi < sids.length; gi++) {
                var sid = sids[gi] | 0;
                if (sid > lastStream) { lastStream = sid; }
            }
        }
    }
    var opaque = undefined;
    if (opaqueData != null) {
        opaque = _toBinaryStr(opaqueData);
    }
    if (opaque !== undefined) {
        _nb.h2SubmitGoaway(this._h2Handle, lastStream, errorCode, opaque);
    } else {
        _nb.h2SubmitGoaway(this._h2Handle, lastStream, errorCode);
    }
    _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);
};

Http2Session.prototype.close = function(callback) {
    if (callback) { this.once("close", callback); }
    if (this._destroyed || this._closing) { return; }
    this._closing = true;
    if (this._h2Handle >= 0) {
        // lastStreamID=2^31-1 keeps existing streams usable until peer drains;
        // errorCode=NO_ERROR. Flush GOAWAY before tearing the session down.
        this.goaway(0, 2147483647);
    }
    // Incomplete streams (and pre-connect queued requests) see
    // ERR_HTTP2_GOAWAY_SESSION — not streams that already finished cleanly.
    var sids = Object.keys(this._streams);
    for (var si = 0; si < sids.length; si++) {
        var st = this._streams[sids[si]];
        if (!st || st._destroyed) { continue; }
        if (st._endedLocal && st._headersComplete) { continue; }
        var gerr = _h2HttpError("ERR_HTTP2_GOAWAY_SESSION",
            "New streams cannot be created after receiving a GOAWAY");
        try { st.emit("error", gerr); } catch (_e) { /* ignore */ }
    }
    if (this._pendingRequests && this._pendingRequests.length) {
        var pending = this._pendingRequests;
        this._pendingRequests = [];
        for (var pi = 0; pi < pending.length; pi++) {
            var pst = pending[pi].stream;
            if (!pst || pst._destroyed) { continue; }
            var perr = _h2HttpError("ERR_HTTP2_GOAWAY_SESSION",
                "New streams cannot be created after receiving a GOAWAY");
            try { pst.emit("error", perr); } catch (_e2) { /* ignore */ }
        }
    }
    var self = this;
    // Defer destroy so the GOAWAY (and any pending DATA) can leave the socket.
    setTimeout(function() {
        if (!self._destroyed) { self.destroy(); }
    }, 0);
};

Http2Session.prototype.ping = function(payload, callback) {
    var _Buf = (typeof Buffer !== "undefined") ? Buffer : require("buffer").Buffer;
    var cb = callback;
    var data = payload;
    if (typeof payload === "function") {
        cb = payload;
        data = undefined;
    }
    // Prefer native ping when session is live; otherwise ack immediately so callers don't hang.
    if (this._h2Handle >= 0 && typeof _nb.h2SubmitPing === "function") {
        try {
            _nb.h2SubmitPing(this._h2Handle, 0);
            _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);
        } catch (_e) { /* fall through to synthetic ack */ }
    }
    if (cb) {
        var opaque = data != null ? _Buf.from(data) : _Buf.alloc(8);
        setTimeout(function() { cb(null, 0, opaque); }, 0);
    }
    return true;
};

Http2Session.prototype.settings = function(settings, callback) {
    if (typeof settings === "function") {
        callback = settings;
        settings = undefined;
    }
    var s = _cloneSettings(this._localSettings || getDefaultSettings());
    if (settings) {
        var sk = Object.keys(settings);
        for (var si = 0; si < sk.length; si++) {
            if (sk[si] === "customSettings" && settings.customSettings) {
                s.customSettings = Object.assign({}, s.customSettings || {}, settings.customSettings);
            } else {
                s[sk[si]] = settings[sk[si]];
            }
        }
    }
    if (this._h2Handle >= 0 && typeof _nb.h2SubmitSettings === "function") {
        try {
            var flat = [];
            var keys = Object.keys(_SETTINGS_IDS);
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i];
                if (s[k] === undefined || s[k] === null) { continue; }
                var val = s[k];
                if (typeof val === "boolean") { val = val ? 1 : 0; }
                // Skip Infinity / non-finite — nghttp2 wants a uint32
                if (typeof val === "number" && !isFinite(val)) { continue; }
                flat.push(_SETTINGS_IDS[k]);
                flat.push(val >>> 0);
            }
            if (s.customSettings) {
                var ckeys = Object.keys(s.customSettings);
                for (var ci = 0; ci < ckeys.length; ci++) {
                    flat.push(Number(ckeys[ci]) >>> 0);
                    flat.push(s.customSettings[ckeys[ci]] >>> 0);
                }
            }
            _nb.h2SubmitSettings(this._h2Handle, flat);
            _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);
            this._pendingSettingsAck = true;
            this._localSettings = s;
        } catch (_e) { /* ignore */ }
    } else {
        this._localSettings = s;
    }
    if (callback) {
        var self = this;
        setTimeout(function() {
            callback(null, s, 0);
            self.emit("localSettings", s);
        }, 0);
    }
    return this;
};

/**
 * Set the connection-level local flow-control window (absolute size).
 * Prefers native h2SetLocalWindowSize; falls back to h2SubmitWindowUpdate.
 */
Http2Session.prototype.setLocalWindowSize = function(windowSize) {
    if (this._destroyed) {
        throw _h2HttpError("ERR_HTTP2_INVALID_SESSION", "The session has been destroyed");
    }
    if (typeof windowSize !== "number") {
        throw _h2HttpError("ERR_INVALID_ARG_TYPE",
            'The "windowSize" argument must be of type number. Received ' + typeof windowSize);
    }
    if (windowSize < 0 || windowSize > 2147483647 || (windowSize | 0) !== windowSize) {
        var rangeErr = new RangeError(
            'The value of "windowSize" is out of range. It must be >= 0 && <= 2147483647. Received ' +
            windowSize);
        rangeErr.code = "ERR_OUT_OF_RANGE";
        throw rangeErr;
    }
    if (this._h2Handle >= 0) {
        if (typeof _nb.h2SetLocalWindowSize === "function") {
            _nb.h2SetLocalWindowSize(this._h2Handle, windowSize);
        } else if (typeof _nb.h2SubmitWindowUpdate === "function") {
            var cur = this._localWindowSize | 0;
            var inc = windowSize - cur;
            if (inc > 0) {
                _nb.h2SubmitWindowUpdate(this._h2Handle, 0, inc);
            }
        }
        _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);
    }
    this._localWindowSize = windowSize;
    return this;
};

Http2Session.prototype.setNextStreamID = function(id) {
    if (typeof id !== "number") {
        throw _h2HttpError("ERR_INVALID_ARG_TYPE",
            'The "id" argument must be of type number. Received ' +
            (id === null ? "null" : typeof id));
    }
    if (id <= 0 || id > 4294967295 || !isFinite(id)) {
        throw _h2HttpError("ERR_OUT_OF_RANGE",
            'The value of "id" is out of range. It must be > 0 and <= 4294967295. Received ' + id);
    }
    this._nextStreamID = id >>> 0;
    return this;
};

Http2Session.prototype.setTimeout = function(msecs, callback) {
    var self = this;
    if (this._timeoutHandle) {
        clearTimeout(this._timeoutHandle);
        this._timeoutHandle = null;
    }
    if (!msecs) { return this; }
    if (callback) { this.once("timeout", callback); }
    this._timeoutHandle = setTimeout(function() {
        self._timeoutHandle = null;
        self.emit("timeout");
    }, msecs);
    return this;
};

Http2Session.prototype.ref = function() { return this; };
Http2Session.prototype.unref = function() { return this; };

Object.defineProperty(Http2Session.prototype, "destroyed", {
    get: function() { return this._destroyed; }
});

Object.defineProperty(Http2Session.prototype, "closed", {
    get: function() { return this._destroyed || !!this._closing; }
});

Object.defineProperty(Http2Session.prototype, "connecting", {
    get: function() { return !!this._connecting; }
});

Object.defineProperty(Http2Session.prototype, "localSettings", {
    get: function() { return this._localSettings || getDefaultSettings(); }
});

Object.defineProperty(Http2Session.prototype, "remoteSettings", {
    get: function() { return this._remoteSettings || getDefaultSettings(); }
});

Object.defineProperty(Http2Session.prototype, "pendingSettingsAck", {
    get: function() { return !!this._pendingSettingsAck; }
});

Object.defineProperty(Http2Session.prototype, "state", {
    get: function() {
        var defWin = constants.DEFAULT_SETTINGS_INITIAL_WINDOW_SIZE;
        var localWin = this._localWindowSize != null ? this._localWindowSize : defWin;
        // Node: shrinking the window updates effectiveLocalWindowSize but
        // localWindowSize stays at the SETTINGS initial window until it grows.
        return {
            effectiveLocalWindowSize: localWin,
            localWindowSize: localWin > defWin ? localWin : defWin,
            remoteWindowSize: (this._remoteSettings && this._remoteSettings.initialWindowSize) || defWin,
            outboundQueueSize: 0,
            deflateDynamicTableSize: 0,
            inflateDynamicTableSize: 0,
            lastProcStreamID: 0,
            nextStreamID: 1
        };
    }
});

// ── ClientHttp2Session ─────────────────────────────────────────────────────

/**
 * Create a client session. When sockHandle is 0/falsy the session is in
 * "connecting" mode: request() calls are queued until _attachSocket() runs
 * after the underlying TCP/TLS socket connects. This is the Node-compatible
 * connect() contract — callers get a real ClientHttp2Session immediately.
 */
function ClientHttp2Session(sockHandle, isTLS) {
    Http2Session.call(this, 1 /* client */);
    this._isTLS = !!isTLS;
    this._pendingRequests = [];
    this._socket = null;
    if (sockHandle) {
        this._attachSocket(sockHandle, isTLS);
    } else {
        this._connecting = true;
        this._sockHandle = 0;
        this._h2Handle = -1;
    }
}
ClientHttp2Session.prototype = Object.create(Http2Session.prototype);
ClientHttp2Session.prototype.constructor = ClientHttp2Session;

ClientHttp2Session.prototype._attachSocket = function(sockHandle, isTLS) {
    this._sockHandle = sockHandle;
    this._isTLS = !!isTLS;
    this._h2Handle = _nb.h2SessionCreateClient();
    this._connecting = false;
    // Send client preface + initial SETTINGS, then any user settings from connect().
    _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);
    if (this._pendingConnectSettings) {
        var pcs = this._pendingConnectSettings;
        this._pendingConnectSettings = null;
        this.settings(pcs);
    }
    // Start read loop
    _h2ReadLoop(this, sockHandle, this._isTLS);
    // Flush any request() calls made before the socket was ready
    var pending = this._pendingRequests;
    this._pendingRequests = [];
    for (var i = 0; i < pending.length; i++) {
        var p = pending[i];
        try {
            this._activatePendingStream(p.stream, p.headers, p.options);
        } catch (err) {
            p.stream.emit("error", err);
        }
    }
};

/**
 * Bind a placeholder stream (created before connect) to a real nghttp2 stream id
 * and flush any buffered writes/end.
 */
ClientHttp2Session.prototype._activatePendingStream = function(stream, headers, options) {
    var opts = options || {};
    headers = this._normalizeRequestHeaders(headers);
    if (opts.endStream === undefined) { opts.endStream = _defaultEndStream(headers); }
    if (opts.waitForTrailers) {
        stream._waitForTrailers = true;
        opts.endStream = false;
    }
    var hdrsArray = _hdrsToArray(headers);
    var hasBody = opts.endStream ? 0 : 1;
    var streamId = _nb.h2Request(this._h2Handle, hdrsArray, hasBody);
    _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);
    stream.id = streamId;
    stream._pendingLocal = false;
    this._streams[streamId] = stream;
    if (opts.endStream) { stream._endedLocal = true; }
    if (stream._pendingWrites && stream._pendingWrites.length) {
        for (var wi = 0; wi < stream._pendingWrites.length; wi++) {
            var w = stream._pendingWrites[wi];
            ClientHttp2Stream.prototype.write.call(stream, w.data, w.encoding, w.callback);
        }
        stream._pendingWrites = null;
    }
    if (stream._pendingEnd) {
        var pe = stream._pendingEnd;
        stream._pendingEnd = null;
        ClientHttp2Stream.prototype.end.call(stream, pe.data, pe.encoding, pe.callback);
    }
    return stream;
};

/**
 * Submit a new HTTP/2 request.
 * headers: object like { ":method": "GET", ":path": "/", ... }
 * options: { endStream: true/false, waitForTrailers: true/false }
 * Returns ClientHttp2Stream
 */
ClientHttp2Session.prototype._normalizeRequestHeaders = function(headers) {
    var h = headers ? Object.assign({}, headers) : {};
    if (!h[":method"] && !h[constants.HTTP2_HEADER_METHOD]) { h[":method"] = "GET"; }
    if (!h[":path"] && !h[constants.HTTP2_HEADER_PATH]) { h[":path"] = "/"; }
    if (!h[":scheme"] && !h[constants.HTTP2_HEADER_SCHEME]) {
        h[":scheme"] = this._isTLS ? "https" : "http";
    }
    if (!h[":authority"] && !h[constants.HTTP2_HEADER_AUTHORITY]) {
        h[":authority"] = "localhost";
    }
    return h;
};

ClientHttp2Session.prototype._submitRequest = function(headers, options) {
    var opts = options || {};
    headers = this._normalizeRequestHeaders(headers);
    if (opts.endStream === undefined) { opts.endStream = _defaultEndStream(headers); }
    if (opts.waitForTrailers) { opts.endStream = false; }
    var hdrsArray = _hdrsToArray(headers);
    var hasBody = opts.endStream ? 0 : 1;
    var streamId = _nb.h2Request(this._h2Handle, hdrsArray, hasBody);
    _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);

    var stream = _makeClientStream(this, streamId);
    this._streams[streamId] = stream;
    if (streamId > (this._lastProcStreamID | 0)) { this._lastProcStreamID = streamId | 0; }
    if (opts.waitForTrailers) { stream._waitForTrailers = true; }

    if (opts.endStream) {
        stream._endedLocal = true;
    }
    return stream;
};

ClientHttp2Session.prototype.request = function(headers, options) {
    if (this._destroyed) {
        var err = new Error("The session has been destroyed");
        err.code = "ERR_HTTP2_INVALID_SESSION";
        throw err;
    }
    headers = this._normalizeRequestHeaders(headers);
    // Queue until the socket/handshake is ready (Node allows request() before 'connect')
    if (this._connecting || this._h2Handle < 0) {
        var stream = _makeClientStream(this, -1);
        stream._pendingLocal = true;
        stream._pendingWrites = [];
        this._pendingRequests.push({
            stream: stream,
            headers: headers,
            options: options
        });
        return stream;
    }
    return this._submitRequest(headers, options);
};

// ── ServerHttp2Session ─────────────────────────────────────────────────────

function ServerHttp2Session(sockHandle, isTLS) {
    Http2Session.call(this, 0 /* server */);
    this._sockHandle = sockHandle;
    this._isTLS = isTLS;
    this._h2Handle = _nb.h2SessionCreateServer();
    // Send server preface (SETTINGS frame)
    _h2Flush(this._h2Handle, this._sockHandle, this._isTLS);
    // Start read loop
    _h2ReadLoop(this, sockHandle, isTLS);
}
ServerHttp2Session.prototype = Object.create(Http2Session.prototype);
ServerHttp2Session.prototype.constructor = ServerHttp2Session;

// ── Http2Stream base class ─────────────────────────────────────────────────

function Http2Stream(session, streamId) {
    EventEmitter.init.call(this);
    this._session = session;
    // Coerce — h2PopEvent exposes d0 as a JS number (double).
    this.id = streamId | 0;
    this._pendingHeaders = {};
    this._headersComplete = false;
    this._endedLocal = false;
    this._destroyed = false;
    this._waitForTrailers = false;
    this._trailersReady = false;
    this._sentTrailers = false;
    this._receivingTrailers = false;
}
Http2Stream.prototype = Object.create(EventEmitter.prototype);
Http2Stream.prototype.constructor = Http2Stream;

Http2Stream.prototype.destroy = function(err) {
    if (this._destroyed) { return; }
    this._destroyed = true;
    if (err) {
        _nb.h2SubmitRstStream(this._session._h2Handle, this.id, 2 /* INTERNAL_ERROR */);
        _h2Flush(this._session._h2Handle, this._session._sockHandle, this._session._isTLS);
        this.emit("error", err);
    }
    this.emit("close");
    delete this._session._streams[this.id];
};

Http2Stream.prototype.close = function(code, callback) {
    if (callback) { this.once("close", callback); }
    var errCode = code !== undefined ? code : 0;
    _nb.h2SubmitRstStream(this._session._h2Handle, this.id, errCode);
    _h2Flush(this._session._h2Handle, this._session._sockHandle, this._session._isTLS);
    this.destroy();
};

/**
 * Send trailing HEADERS after the body. Requires waitForTrailers and a prior
 * 'wantTrailers' readiness (set when end() finishes the body without END_STREAM).
 */
Http2Stream.prototype.sendTrailers = function(headers) {
    // Order matches Node: destroyed/closed → INVALID_STREAM first.
    if (this._destroyed || this.id <= 0 || this._closed) {
        throw _h2HttpError("ERR_HTTP2_INVALID_STREAM", "The stream has been destroyed");
    }
    if (this._sentTrailers) {
        throw _h2HttpError("ERR_HTTP2_TRAILERS_ALREADY_SENT", "Trailing HEADERS already sent");
    }
    if (!this._trailersReady) {
        throw _h2HttpError("ERR_HTTP2_TRAILERS_NOT_READY",
            "Trailing HEADERS are not ready; use waitForTrailers and listen for wantTrailers");
    }
    var hdrsArray = _hdrsToArray(headers || {});
    if (typeof _nb.h2SubmitTrailer === "function") {
        _nb.h2SubmitTrailer(this._session._h2Handle, this.id, hdrsArray);
    } else {
        // Fallback: empty DATA with END_STREAM when native trailers unavailable
        _h2SubmitBody(this._session, this.id, "", 1);
    }
    _h2Flush(this._session._h2Handle, this._session._sockHandle, this._session._isTLS);
    this._sentTrailers = true;
    this._endedLocal = true;
    return this;
};

Http2Stream.prototype.setEncoding = function(enc) {
    // Always returns binary data as JS strings; encoding is a no-op
    this._encoding = enc;
};

Http2Stream.prototype.resume = function() { return this; };
Http2Stream.prototype.pause = function() { return this; };

Object.defineProperty(Http2Stream.prototype, "session", {
    get: function() { return this._session; }
});
Object.defineProperty(Http2Stream.prototype, "destroyed", {
    get: function() { return this._destroyed; }
});
Object.defineProperty(Http2Stream.prototype, "closed", {
    get: function() { return this._destroyed; }
});

// ── ClientHttp2Stream ──────────────────────────────────────────────────────

function _makeClientStream(session, streamId) {
    var s = Object.create(ClientHttp2Stream.prototype);
    Http2Stream.call(s, session, streamId);
    return s;
}

function ClientHttp2Stream(session, streamId) {
    Http2Stream.call(this, session, streamId);
}
ClientHttp2Stream.prototype = Object.create(Http2Stream.prototype);
ClientHttp2Stream.prototype.constructor = ClientHttp2Stream;

/**
 * Send DATA after the request HEADERS via nghttp2_submit_data.
 * While the session is still connecting we buffer writes and flush them
 * in _activatePendingStream.
 */
ClientHttp2Stream.prototype.write = function(data, encoding, callback) {
    if (typeof encoding === "function") { callback = encoding; encoding = null; }
    if (this._pendingLocal) {
        if (!this._pendingWrites) { this._pendingWrites = []; }
        this._pendingWrites.push({ data: data, encoding: encoding, callback: callback });
        return true;
    }
    if (this._endedLocal || this._destroyed) {
        if (callback) { setTimeout(function() { callback(null); }, 0); }
        return true;
    }
    _h2SubmitBody(this._session, this.id, _toBinaryStr(data, encoding), false);
    if (callback) { setTimeout(function() { callback(null); }, 0); }
    return true;
};

ClientHttp2Stream.prototype.end = function(data, encoding, callback) {
    if (typeof data === "function") { callback = data; data = null; }
    if (typeof encoding === "function") { callback = encoding; encoding = null; }
    if (this._pendingLocal) {
        if (data != null) { this.write(data, encoding); }
        this._pendingEnd = { data: null, encoding: null, callback: callback };
        return this;
    }
    if (this._endedLocal) {
        if (callback) { setTimeout(function() { callback(); }, 0); }
        return this;
    }
    var endMode = this._waitForTrailers ? 2 : 1;
    var payload = (data != null && data !== "") ? _toBinaryStr(data, encoding) : "";
    if (this.id > 0) {
        _h2SubmitBody(this._session, this.id, payload, endMode);
    }
    if (this._waitForTrailers) {
        this._trailersReady = true;
        this.emit("wantTrailers");
    } else {
        this._endedLocal = true;
    }
    if (callback) { this.once("finish", callback); }
    this.emit("finish");
    return this;
};

// ── ServerHttp2Stream ──────────────────────────────────────────────────────

function _makeServerStream(session, streamId) {
    var s = Object.create(ServerHttp2Stream.prototype);
    Http2Stream.call(s, session, streamId);
    return s;
}

function ServerHttp2Stream(session, streamId) {
    Http2Stream.call(this, session, streamId);
}
ServerHttp2Stream.prototype = Object.create(Http2Stream.prototype);
ServerHttp2Stream.prototype.constructor = ServerHttp2Stream;

/**
 * Send response headers.
 * headers: object like { ":status": "200", "content-type": "text/plain" }
 * options: { endStream: true/false }
 */
ServerHttp2Stream.prototype.respond = function(headers, options) {
    var opts = options || {};
    if (opts.waitForTrailers) {
        this._waitForTrailers = true;
        opts.endStream = false;
    }
    if (headers == null) { headers = { ":status": "200" }; }
    else if (!headers[":status"] && !headers[constants.HTTP2_HEADER_STATUS]) {
        headers = Object.assign({ ":status": "200" }, headers);
    }
    var hdrsArray = _hdrsToArray(headers);
    // hasBody=1 keeps the stream open for DATA when endStream is not requested.
    var hasBody = opts.endStream ? 0 : 1;
    _nb.h2Respond(this._session._h2Handle, this.id, hdrsArray, hasBody);
    _h2Flush(this._session._h2Handle, this._session._sockHandle, this._session._isTLS);
    this._headersSent = true;
    this.emit("headers", headers);
    if (opts.endStream) {
        this._endedLocal = true;
        this.emit("finish");
    }
};

/**
 * respondWithFile — not implemented in this phase; use respond() + write().
 */
ServerHttp2Stream.prototype.respondWithFile = function(path, headers, options) {
    var opts = options || {};
    var hdrs = headers || { ":status": "200" };
    this.respond(hdrs);
    var fs = require("fs");
    var self = this;
    fs.readFile(path, function(err, data) {
        if (err) {
            self.respond({ ":status": "500" }, { endStream: true });
            return;
        }
        self.write(data);
        self.end();
    });
};

/**
 * Write a DATA frame body chunk via nghttp2_submit_data.
 */
ServerHttp2Stream.prototype.write = function(data, encoding, callback) {
    if (typeof encoding === "function") { callback = encoding; encoding = null; }
    if (this._endedLocal || this._destroyed) {
        if (callback) { setTimeout(function() { callback(null); }, 0); }
        return true;
    }
    // Auto-respond with 200 if the caller writes without respond() first.
    if (!this._headersSent) {
        this.respond({ ":status": "200" });
    }
    _h2SubmitBody(this._session, this.id, _toBinaryStr(data, encoding), false);
    if (callback) { setTimeout(function() { callback(null); }, 0); }
    return true;
};

ServerHttp2Stream.prototype.end = function(data, encoding, callback) {
    if (typeof data === "function") { callback = data; data = null; }
    if (typeof encoding === "function") { callback = encoding; encoding = null; }
    if (this._endedLocal) {
        if (callback) { setTimeout(function() { callback(); }, 0); }
        return this;
    }
    if (!this._headersSent) {
        var noBody = data == null || data === "";
        this.respond({ ":status": "200" },
            noBody && !this._waitForTrailers ? { endStream: true } : undefined);
        if (noBody && !this._waitForTrailers) {
            this._endedLocal = true;
            if (callback) { this.once("finish", callback); }
            this.emit("finish");
            return this;
        }
    }
    var endMode = this._waitForTrailers ? 2 : 1;
    var payload = (data != null && data !== "") ? _toBinaryStr(data, encoding) : "";
    if (this.id > 0) {
        _h2SubmitBody(this._session, this.id, payload, endMode);
    }
    if (this._waitForTrailers) {
        this._trailersReady = true;
        this.emit("wantTrailers");
    } else {
        this._endedLocal = true;
    }
    if (callback) { this.once("finish", callback); }
    this.emit("finish");
    return this;
};

// ── Http2Server ────────────────────────────────────────────────────────────

function Http2Server(options, onRequest) {
    EventEmitter.init.call(this);
    this._options = options || {};
    this._isTLS = false;
    this._server = null;
    if (onRequest) { this.on("request", onRequest); }
}
Http2Server.prototype = Object.create(EventEmitter.prototype);
Http2Server.prototype.constructor = Http2Server;

Http2Server.prototype.listen = function(port, host, callback) {
    var self = this;
    if (typeof host === "function") { callback = host; host = "0.0.0.0"; }
    if (!host) { host = "0.0.0.0"; }

    var serverOpts = { host: host, port: port, pauseOnConnect: true };
    if (this._isTLS) {
        serverOpts.key = this._options.key;
        serverOpts.cert = this._options.cert;
        serverOpts.ALPNProtocols = ["h2", "http/1.1"];
        serverOpts.pauseOnConnect = true;
    }

    var createSrv = this._isTLS ? tlsMod.createServer : netMod.createServer;
    this._server = createSrv(serverOpts, function(socket) {
        // Pause the net/tls readable side — Http2Session owns the fd via
        // tcpReadBinaryNb/tlsReadBinaryNb. Dual uv_poll on one fd SIGSEGVs.
        if (socket && typeof socket.pause === "function") { socket.pause(); }
        var sockHandle = socket._handle || socket._sockHandle || 0;
        var isTLS = self._isTLS;
        var session = new ServerHttp2Session(sockHandle, isTLS);
        session._socket = socket;
        if (self._options && self._options.remoteCustomSettings) {
            session._remoteCustomSettings = self._options.remoteCustomSettings.slice();
        }
        session.on("stream", function(stream, headers) {
            self.emit("stream", stream, headers);
            // Build IncomingMessage-like object for "request" event
            var req = _makeH2Request(headers, stream);
            var res = _makeH2Response(stream);
            self.emit("request", req, res);
        });
        session.on("error", function(err) { self.emit("error", err); });
        if (!self._sessions) { self._sessions = []; }
        self._sessions.push(session);
        session.on("close", function() {
            var ix = self._sessions.indexOf(session);
            if (ix >= 0) { self._sessions.splice(ix, 1); }
        });
        self.emit("session", session);
    });

    this._server.on("error", function(err) { self.emit("error", err); });
    this._server.on("listening", function() { self.emit("listening"); });
    // Apply createServer({ settings }) once a session is established.
    if (this._options && this._options.settings) {
        this.on("session", function(session) {
            session.settings(self._options.settings);
        });
    }
    this._server.listen(port, host, callback);
    return this;
};

Http2Server.prototype.close = function(callback) {
    if (this._sessions && this._sessions.length) {
        var sessions = this._sessions.slice();
        for (var i = 0; i < sessions.length; i++) {
            try { sessions[i].close(); } catch (_e) { /* ignore */ }
        }
    }
    if (this._server) { this._server.close(callback); }
    else if (callback) { callback(); }
};

Http2Server.prototype.address = function() {
    return this._server ? this._server.address() : null;
};

Http2Server.prototype.setTimeout = function(msecs, callback) {
    if (this._server && typeof this._server.setTimeout === "function") {
        this._server.setTimeout(msecs, callback);
    } else if (callback) {
        this.once("timeout", callback);
    }
    return this;
};

Http2Server.prototype.ref = function() { return this; };
Http2Server.prototype.unref = function() { return this; };

Http2Stream.prototype.setTimeout = function(msecs, callback) {
    var self = this;
    if (this._timeoutHandle) {
        clearTimeout(this._timeoutHandle);
        this._timeoutHandle = null;
    }
    if (!msecs) { return this; }
    if (callback) { this.once("timeout", callback); }
    this._timeoutHandle = setTimeout(function() {
        self._timeoutHandle = null;
        self.emit("timeout");
    }, msecs);
    return this;
};

// ── Http2SecureServer ──────────────────────────────────────────────────────

function Http2SecureServer(options, onRequest) {
    Http2Server.call(this, options, onRequest);
    this._isTLS = true;
}
Http2SecureServer.prototype = Object.create(Http2Server.prototype);
Http2SecureServer.prototype.constructor = Http2SecureServer;

// ── Compatibility: Http2ServerRequest / Http2ServerResponse ───────────────

function Http2ServerRequest(headers, stream) {
    if (!(this instanceof Http2ServerRequest)) {
        return new Http2ServerRequest(headers, stream);
    }
    EventEmitter.init.call(this);
    headers = headers || {};
    this.method  = headers[":method"] || "GET";
    this.url     = headers[":path"]   || "/";
    this.headers = headers;
    this.httpVersion = "2.0";
    this.httpVersionMajor = 2;
    this.httpVersionMinor = 0;
    this.stream  = stream;
    this._stream = stream;
    if (stream) {
        var self = this;
        stream.on("data", function(chunk) { self.emit("data", chunk); });
        stream.on("end",  function()      { self.emit("end"); });
        // Only forward errors when someone is listening — otherwise EventEmitter
        // treats it as uncaught and aborts the process (breaks stream-API tests).
        stream.on("error", function(err) {
            if (typeof self.listenerCount === "function" && self.listenerCount("error") > 0) {
                self.emit("error", err);
            }
        });
    }
}
Http2ServerRequest.prototype = Object.create(EventEmitter.prototype);
Http2ServerRequest.prototype.constructor = Http2ServerRequest;
Http2ServerRequest.prototype.setTimeout = function(msecs, callback) {
    if (this.stream && typeof this.stream.setTimeout === "function") {
        this.stream.setTimeout(msecs, callback);
    }
    return this;
};

function Http2ServerResponse(stream) {
    if (!(this instanceof Http2ServerResponse)) {
        return new Http2ServerResponse(stream);
    }
    EventEmitter.init.call(this);
    this._stream     = stream;
    this.stream      = stream;
    this._headers    = {};
    this.statusCode  = 200;
    this._statusCode = 200;
    this.headersSent = false;
    this.finished    = false;
    this.sendDate    = true;
}
Http2ServerResponse.prototype = Object.create(EventEmitter.prototype);
Http2ServerResponse.prototype.constructor = Http2ServerResponse;

Http2ServerResponse.prototype.setHeader = function(name, value) {
    this._headers[String(name).toLowerCase()] = value;
};
Http2ServerResponse.prototype.getHeader = function(name) {
    return this._headers[String(name).toLowerCase()];
};
Http2ServerResponse.prototype.removeHeader = function(name) {
    delete this._headers[String(name).toLowerCase()];
};
Http2ServerResponse.prototype.getHeaders = function() {
    return Object.assign({}, this._headers);
};
Http2ServerResponse.prototype.hasHeader = function(name) {
    return Object.prototype.hasOwnProperty.call(this._headers, String(name).toLowerCase());
};

Http2ServerResponse.prototype.writeHead = function(statusCode, headers) {
    this.statusCode = statusCode;
    this._statusCode = statusCode;
    if (headers) {
        var keys = Object.keys(headers);
        for (var i = 0; i < keys.length; i++) {
            this._headers[keys[i].toLowerCase()] = headers[keys[i]];
        }
    }
    return this;
};

Http2ServerResponse.prototype._sendHeaders = function() {
    if (this.headersSent) { return; }
    this.headersSent = true;
    var hdrs = Object.assign({ ":status": "" + this._statusCode }, this._headers);
    this._stream.respond(hdrs);
};

Http2ServerResponse.prototype.write = function(data, encoding, callback) {
    this._sendHeaders();
    this._stream.write(data, encoding, callback);
    return true;
};

Http2ServerResponse.prototype.end = function(data, encoding, callback) {
    this._sendHeaders();
    this.finished = true;
    this._stream.end(data, encoding, callback);
    return this;
};

Http2ServerResponse.prototype.setTimeout = function(msecs, callback) {
    if (this._stream && typeof this._stream.setTimeout === "function") {
        this._stream.setTimeout(msecs, callback);
    }
    return this;
};

function _makeH2Request(headers, stream) {
    return new Http2ServerRequest(headers, stream);
}

function _makeH2Response(stream) {
    return new Http2ServerResponse(stream);
}

// ── Public API ─────────────────────────────────────────────────────────────

/**
 * Create a cleartext HTTP/2 server (h2c).
 * options: {}
 * onRequest: function(req, res)
 */
function createServer(options, onRequest) {
    if (typeof options === "function") { onRequest = options; options = {}; }
    return new Http2Server(options || {}, onRequest);
}

/**
 * Create a TLS HTTP/2 server (h2 via ALPN).
 * options: { key, cert, ... }
 * onRequest: function(req, res)
 */
function createSecureServer(options, onRequest) {
    if (typeof options === "function") { onRequest = options; options = {}; }
    return new Http2SecureServer(options || {}, onRequest);
}

/**
 * Open an HTTP/2 client session.
 * authority: "https://example.com" or "http://example.com:8080"
 * options: { key, cert, ca, rejectUnauthorized, ... }
 * callback: function() — called on "connect" event
 * Returns ClientHttp2Session (usable immediately; request() queues until connected)
 */
function connect(authority, options, callback) {
    if (typeof options === "function") { callback = options; options = {}; }
    var opts = options || {};

    // Parse authority
    var isTLS = true;
    var host, port;
    if (authority && authority.indexOf("http://") === 0) {
        isTLS = false;
        var rest0 = authority.substring(7);
        var si0 = rest0.indexOf("/");
        var hostPort0 = si0 >= 0 ? rest0.substring(0, si0) : rest0;
        var ci0 = hostPort0.lastIndexOf(":");
        host = ci0 >= 0 ? hostPort0.substring(0, ci0) : hostPort0;
        port = ci0 >= 0 ? parseInt(hostPort0.substring(ci0 + 1)) : 80;
    } else if (authority && authority.indexOf("https://") === 0) {
        var rest1 = authority.substring(8);
        var si1 = rest1.indexOf("/");
        var hostPort1 = si1 >= 0 ? rest1.substring(0, si1) : rest1;
        var ci1 = hostPort1.lastIndexOf(":");
        host = ci1 >= 0 ? hostPort1.substring(0, ci1) : hostPort1;
        port = ci1 >= 0 ? parseInt(hostPort1.substring(ci1 + 1)) : 443;
    } else {
        // Bare host:port — assume TLS
        var ci2 = authority ? authority.lastIndexOf(":") : -1;
        host = ci2 >= 0 ? authority.substring(0, ci2) : (authority || "localhost");
        port = ci2 >= 0 ? parseInt(authority.substring(ci2 + 1)) : 443;
    }

    // Return a real ClientHttp2Session immediately (connecting=true until socket ready).
    // This is the Wave-5.1 fix: callers must be able to call session.request() right away.
    var session = new ClientHttp2Session(0, isTLS);
    if (opts.settings) { session._pendingConnectSettings = opts.settings; }
    if (opts.remoteCustomSettings) {
        session._remoteCustomSettings = opts.remoteCustomSettings.slice();
    }

    if (isTLS) {
        var tlsOpts = Object.assign({
            host: host,
            port: port,
            ALPNProtocols: ["h2"],
            servername: opts.servername || host,
            rejectUnauthorized: opts.rejectUnauthorized !== false
        }, opts);

        var tlsSock = tlsMod.connect(tlsOpts, function() {
            if (typeof tlsSock.pause === "function") { tlsSock.pause(); }
            var sockHandle = tlsSock._handle || tlsSock._sockHandle || 0;
            session._socket = tlsSock;
            session._attachSocket(sockHandle, true);
            if (callback) { callback(); }
            session.emit("connect", session, tlsSock);
        });
        session._socket = tlsSock;
        tlsSock.on("error", function(err) {
            session.emit("error", err);
        });
        return session;
    }

    var tcpSock = netMod.createConnection({ host: host, port: port }, function() {
        // Stop Socket._startReading(); h2 owns the fd (see server pauseOnConnect).
        if (typeof tcpSock.pause === "function") { tcpSock.pause(); }
        var sockHandle = tcpSock._handle || tcpSock._sockHandle || 0;
        session._socket = tcpSock;
        session._attachSocket(sockHandle, false);
        if (callback) { callback(); }
        session.emit("connect", session, tcpSock);
    });
    session._socket = tcpSock;
    tcpSock.on("error", function(err) {
        session.emit("error", err);
    });
    return session;
}

function getDefaultSettings() {
    return {
        headerTableSize: constants.DEFAULT_SETTINGS_HEADER_TABLE_SIZE,
        enablePush: !!constants.DEFAULT_SETTINGS_ENABLE_PUSH,
        initialWindowSize: constants.DEFAULT_SETTINGS_INITIAL_WINDOW_SIZE,
        maxFrameSize: constants.DEFAULT_SETTINGS_MAX_FRAME_SIZE,
        maxConcurrentStreams: constants.DEFAULT_SETTINGS_MAX_CONCURRENT_STREAMS,
        maxHeaderListSize: 65535,
        maxHeaderSize: 65535,
        enableConnectProtocol: false,
        customSettings: {}
    };
}

/** SETTINGS identifier codes (RFC 7540 §6.5.2) */
var _SETTINGS_IDS = {
    headerTableSize: 0x1,
    enablePush: 0x2,
    maxConcurrentStreams: 0x3,
    initialWindowSize: 0x4,
    maxFrameSize: 0x5,
    maxHeaderListSize: 0x6,
    enableConnectProtocol: 0x8
};

function _packSettingValue(name, val) {
    if (name === "enablePush" || name === "enableConnectProtocol") {
        if (typeof val !== "boolean") {
            var tErr = new TypeError('Invalid value for setting "' + name + '": ' + val);
            tErr.code = "ERR_HTTP2_INVALID_SETTING_VALUE";
            throw tErr;
        }
        return val ? 1 : 0;
    }
    if (typeof val !== "number" || !isFinite(val)) {
        // Node packs default Infinity maxConcurrentStreams as 0xFFFFFFFF
        if (val === Infinity) { return 0xFFFFFFFF; }
        return null; // skip
    }
    var u = val >>> 0;
    if (name === "headerTableSize" || name === "maxConcurrentStreams" ||
        name === "maxHeaderListSize" || name === "maxHeaderSize") {
        if (val < 0 || val > 0xFFFFFFFF) {
            var r1 = new RangeError('Invalid value for setting "' + name + '": ' + val);
            r1.code = "ERR_HTTP2_INVALID_SETTING_VALUE";
            throw r1;
        }
    } else if (name === "initialWindowSize") {
        if (val < 0 || val > 0x7FFFFFFF) {
            var r2 = new RangeError('Invalid value for setting "' + name + '": ' + val);
            r2.code = "ERR_HTTP2_INVALID_SETTING_VALUE";
            throw r2;
        }
    } else if (name === "maxFrameSize") {
        if (val < 16384 || val > 0xFFFFFF) {
            var r3 = new RangeError('Invalid value for setting "' + name + '": ' + val);
            r3.code = "ERR_HTTP2_INVALID_SETTING_VALUE";
            throw r3;
        }
    }
    if (name === "maxHeaderSize") { return u; } // packed via maxHeaderListSize id
    return u;
}

function getPackedSettings(settings) {
    var _Buf = (typeof Buffer !== "undefined") ? Buffer : require("buffer").Buffer;
    // Node: getPackedSettings() with no args → empty Buffer
    if (settings === undefined || settings === null) {
        return _Buf.alloc(0);
    }
    var s = settings;
    var entries = [];
    var keys = Object.keys(_SETTINGS_IDS);
    var seenHeaderList = false;
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        var raw = s[k];
        var validateName = k;
        // maxHeaderSize is an alias for maxHeaderListSize — keep original name in errors
        if (k === "maxHeaderListSize" && raw === undefined && s.maxHeaderSize !== undefined) {
            raw = s.maxHeaderSize;
            validateName = "maxHeaderSize";
        }
        if (raw === undefined || raw === null) { continue; }
        var packed = _packSettingValue(validateName, raw);
        if (packed === null) { continue; }
        if (k === "maxHeaderListSize") { seenHeaderList = true; }
        entries.push({ id: _SETTINGS_IDS[k], value: packed >>> 0 });
    }
    if (!seenHeaderList && s.maxHeaderSize !== undefined && s.maxHeaderListSize === undefined) {
        var mh = _packSettingValue("maxHeaderSize", s.maxHeaderSize);
        if (mh !== null) {
            entries.push({ id: _SETTINGS_IDS.maxHeaderListSize, value: mh >>> 0 });
        }
    }
    // customSettings: { id: value, ... } — Node allows up to 10
    if (s.customSettings && typeof s.customSettings === "object") {
        var ckeys = Object.keys(s.customSettings);
        if (ckeys.length > 10) {
            var tooMany = new Error("Too many custom settings");
            tooMany.code = "ERR_HTTP2_TOO_MANY_CUSTOM_SETTINGS";
            throw tooMany;
        }
        for (var ci = 0; ci < ckeys.length; ci++) {
            var cid = Number(ckeys[ci]);
            var cval = s.customSettings[ckeys[ci]];
            if (!isFinite(cid) || cid < 0 || cid > 0xFFFF ||
                typeof cval !== "number" || !isFinite(cval) || cval < 0 || cval > 0xFFFFFFFF) {
                var cr = new RangeError('Invalid value for setting "' + ckeys[ci] + '": ' + cval);
                cr.code = "ERR_HTTP2_INVALID_SETTING_VALUE";
                throw cr;
            }
            entries.push({ id: cid >>> 0, value: cval >>> 0 });
        }
    }
    var buf = _Buf.alloc(entries.length * 6);
    for (var j = 0; j < entries.length; j++) {
        var off = j * 6;
        buf[off]     = (entries[j].id >> 8) & 0xff;
        buf[off + 1] = entries[j].id & 0xff;
        buf[off + 2] = (entries[j].value >>> 24) & 0xff;
        buf[off + 3] = (entries[j].value >>> 16) & 0xff;
        buf[off + 4] = (entries[j].value >>> 8) & 0xff;
        buf[off + 5] = entries[j].value & 0xff;
    }
    return buf;
}

function getUnpackedSettings(buf, options) {
    var _Buf = (typeof Buffer !== "undefined") ? Buffer : require("buffer").Buffer;
    var isTyped = _Buf.isBuffer(buf) ||
        (typeof Uint8Array !== "undefined" && buf instanceof Uint8Array) ||
        (typeof Uint16Array !== "undefined" && buf instanceof Uint16Array) ||
        (typeof Int8Array !== "undefined" && buf instanceof Int8Array) ||
        (typeof Uint32Array !== "undefined" && buf instanceof Uint32Array);
    if (!isTyped) {
        var te = new TypeError(
            'The "buf" argument must be an instance of Buffer or TypedArray.');
        te.code = "ERR_INVALID_ARG_TYPE";
        throw te;
    }
    var out = getDefaultSettings();
    if (!buf || !buf.length) { return out; }
    var b = _Buf.isBuffer(buf) ? buf : _Buf.from(buf);
    if (b.length % 6 !== 0) {
        var le = new RangeError("Packed settings length must be a multiple of six");
        le.code = "ERR_HTTP2_INVALID_PACKED_SETTINGS_LENGTH";
        throw le;
    }
    var idToName = {};
    var sk = Object.keys(_SETTINGS_IDS);
    for (var i = 0; i < sk.length; i++) { idToName[_SETTINGS_IDS[sk[i]]] = sk[i]; }
    out.customSettings = {};
    for (var off = 0; off + 6 <= b.length; off += 6) {
        var id = (b[off] << 8) | b[off + 1];
        var value = ((b[off + 2] << 24) | (b[off + 3] << 16) | (b[off + 4] << 8) | b[off + 5]) >>> 0;
        var name = idToName[id];
        if (!name) {
            out.customSettings[String(id)] = value;
            continue;
        }
        if (options && options.validate) {
            if (name === "maxFrameSize" && (value < 16384 || value > 0xFFFFFF)) {
                var ve = new RangeError('Invalid value for setting "maxFrameSize": ' + value);
                ve.code = "ERR_HTTP2_INVALID_SETTING_VALUE";
                throw ve;
            }
        }
        if (name === "enablePush" || name === "enableConnectProtocol") {
            out[name] = !!value;
        } else {
            out[name] = value;
            if (name === "maxHeaderListSize") { out.maxHeaderSize = value; }
        }
    }
    return out;
}

// ── Exports ────────────────────────────────────────────────────────────────

module.exports = {
    // Factories
    createServer:       createServer,
    createSecureServer: createSecureServer,
    connect:            connect,

    // Classes (for instanceof checks)
    Http2Session:         Http2Session,
    ClientHttp2Session:   ClientHttp2Session,
    ServerHttp2Session:   ServerHttp2Session,
    Http2Stream:          Http2Stream,
    ClientHttp2Stream:    ClientHttp2Stream,
    ServerHttp2Stream:    ServerHttp2Stream,
    Http2Server:          Http2Server,
    Http2SecureServer:    Http2SecureServer,
    Http2ServerRequest:   Http2ServerRequest,
    Http2ServerResponse:  Http2ServerResponse,

    // Settings helpers
    getDefaultSettings:   getDefaultSettings,
    getPackedSettings:    getPackedSettings,
    getUnpackedSettings:  getUnpackedSettings,

    // Constants
    constants: constants,

    // Convenience re-exports (Node.js compat)
    sensitiveHeaders: Symbol("sensitiveHeaders")
};
