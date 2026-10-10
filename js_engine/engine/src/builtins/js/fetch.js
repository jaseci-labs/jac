// ────────────────────────────────────────────────────────────────────────────
// builtins/js/fetch.js — Fetch API (Headers, Request, Response, fetch)
//
// Implements the WHATWG Fetch Standard as a JS builtin.
// Uses the native __net bridge (globalThis.__net) for TCP/TLS socket I/O.
// Uses require("url") for URL parsing.
//
// Phase 6.3: Headers class
// Phase 6.4: Request, Response, fetch()
//
// WHATWG Fetch spec: https://fetch.spec.whatwg.org/
// Bun reference:    bun/src/bun.js/webcore/fetch.zig
// ────────────────────────────────────────────────────────────────────────────
var urlMod = require("url");
var URL = urlMod.URL;
var net = globalThis.__net;
// CRLF for HTTP/1.1 wire format
var CRLF = String.fromCharCode(13) + "\n";
// ═══════════════════════════════════════════════════════════════════════════
//  Headers (WHATWG Fetch Standard §2.1)
// ═══════════════════════════════════════════════════════════════════════════
function _normalizeHeaderName(name) {
    if (typeof name !== "string") {
        name = String(name);
    }
    return name.toLowerCase();
}

function _normalizeHeaderValue(value) {
    if (typeof value !== "string") {
        value = String(value);
    }
    // Strip leading/trailing whitespace
    return value.trim();
}
class Headers {
    constructor(init) {
        this._entries = []; // Array of [name, value] pairs (names stored lowercase)
        this._guard = "none"; // "none" | "immutable" | "request" | "response"
        if (init !== undefined && init !== null) {
            if (init instanceof Headers) {
                // Copy from another Headers object
                var src = init._entries;
                var i = 0;
                while (i < src.length) {
                    this._entries.push([src[i][0], src[i][1]]);
                    i = i + 1;
                }
            } else if (Array.isArray(init)) {
                // Array of [name, value] pairs
                var j = 0;
                while (j < init.length) {
                    var pair = init[j];
                    this.append(pair[0], pair[1]);
                    j = j + 1;
                }
            } else if (typeof init === "object") {
                // Plain object
                var keys = Object.keys(init);
                var k = 0;
                while (k < keys.length) {
                    this.append(keys[k], init[keys[k]]);
                    k = k + 1;
                }
            }
        }
    }
    append(name, value) {
        if (this._guard === "immutable") {
            throw new TypeError("Headers are immutable");
        }
        name = _normalizeHeaderName(name);
        value = _normalizeHeaderValue(value);
        this._entries.push([name, value]);
    }
    set(name, value) {
        if (this._guard === "immutable") {
            throw new TypeError("Headers are immutable");
        }
        name = _normalizeHeaderName(name);
        value = _normalizeHeaderValue(value);
        // Remove all existing entries with this name, then add one
        var newEntries = [];
        var replaced = false;
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i][0] === name) {
                if (!replaced) {
                    newEntries.push([name, value]);
                    replaced = true;
                }
                // Skip duplicate
            } else {
                newEntries.push(this._entries[i]);
            }
            i = i + 1;
        }
        if (!replaced) {
            newEntries.push([name, value]);
        }
        this._entries = newEntries;
    }
    get(name) {
        name = _normalizeHeaderName(name);
        // Combine all values for this header name with ", "
        var values = [];
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i][0] === name) {
                values.push(this._entries[i][1]);
            }
            i = i + 1;
        }
        if (values.length === 0) {
            return null;
        }
        return values.join(", ");
    }
    has(name) {
        name = _normalizeHeaderName(name);
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i][0] === name) {
                return true;
            }
            i = i + 1;
        }
        return false;
    }
    delete(name) {
        if (this._guard === "immutable") {
            throw new TypeError("Headers are immutable");
        }
        name = _normalizeHeaderName(name);
        var newEntries = [];
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i][0] !== name) {
                newEntries.push(this._entries[i]);
            }
            i = i + 1;
        }
        this._entries = newEntries;
    }
    forEach(callback) {
        var i = 0;
        while (i < this._entries.length) {
            callback(this._entries[i][1], this._entries[i][0], this);
            i = i + 1;
        }
    }
    keys() {
        var result = [];
        var i = 0;
        while (i < this._entries.length) {
            result.push(this._entries[i][0]);
            i = i + 1;
        }
        return result;
    }
    values() {
        var result = [];
        var i = 0;
        while (i < this._entries.length) {
            result.push(this._entries[i][1]);
            i = i + 1;
        }
        return result;
    }
    entries() {
        var result = [];
        var i = 0;
        while (i < this._entries.length) {
            result.push([this._entries[i][0], this._entries[i][1]]);
            i = i + 1;
        }
        return result;
    }
    // getSetCookie() — returns array of individual Set-Cookie values (Node 20+)
    getSetCookie() {
        var result = [];
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i][0] === "set-cookie") {
                result.push(this._entries[i][1]);
            }
            i = i + 1;
        }
        return result;
    }
    // Symbol.iterator — enables `for (const [k, v] of headers)` iteration
    [Symbol.iterator]() {
        var entries = this._entries;
        var idx = 0;
        return {
            next: function() {
                if (idx >= entries.length) {
                    return {
                        value: undefined,
                        done: true
                    };
                }
                var e = entries[idx];
                idx = idx + 1;
                return {
                    value: [e[0], e[1]],
                    done: false
                };
            }
        };
    }
    // Serialize to HTTP/1.1 wire format
    _toRaw() {
        var result = "";
        var i = 0;
        while (i < this._entries.length) {
            result = result + this._entries[i][0] + ": " + this._entries[i][1] + CRLF;
            i = i + 1;
        }
        return result;
    }
}
// ═══════════════════════════════════════════════════════════════════════════
//  HTTP Methods (Phase 6.3)
// ═══════════════════════════════════════════════════════════════════════════
var _METHODS_WITH_BODY = {
    "POST": true,
    "PUT": true,
    "PATCH": true,
    "DELETE": true
};
var _VALID_METHODS = {
    "GET": true,
    "POST": true,
    "PUT": true,
    "DELETE": true,
    "HEAD": true,
    "OPTIONS": true,
    "PATCH": true,
    "CONNECT": true,
    "TRACE": true
};

function _normalizeMethod(method) {
    if (typeof method !== "string") {
        return "GET";
    }
    var upper = method.toUpperCase();
    if (_VALID_METHODS[upper]) {
        return upper;
    }
    return method; // Non-standard methods passed through
}
// ═══════════════════════════════════════════════════════════════════════════
//  MIME type helpers (Phase 6.3)
// ═══════════════════════════════════════════════════════════════════════════
var _MIME_TYPES = {
    ".html": "text/html",
    ".htm": "text/html",
    ".css": "text/css",
    ".js": "application/javascript",
    ".mjs": "application/javascript",
    ".json": "application/json",
    ".xml": "application/xml",
    ".txt": "text/plain",
    ".md": "text/markdown",
    ".csv": "text/csv",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".ico": "image/x-icon",
    ".webp": "image/webp",
    ".avif": "image/avif",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
    ".eot": "application/vnd.ms-fontobject",
    ".pdf": "application/pdf",
    ".zip": "application/zip",
    ".gz": "application/gzip",
    ".tar": "application/x-tar",
    ".mp3": "audio/mpeg",
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".ogg": "audio/ogg",
    ".wav": "audio/wav",
    ".wasm": "application/wasm",
    ".map": "application/json",
    ".ts": "application/typescript",
    ".tsx": "application/typescript",
    ".jsx": "application/javascript",
    ".yaml": "application/yaml",
    ".yml": "application/yaml",
    ".toml": "application/toml",
    ".sh": "application/x-sh"
};

function mimeFromExtension(ext) {
    if (typeof ext !== "string") {
        return "application/octet-stream";
    }
    ext = ext.toLowerCase();
    if (ext.length > 0 && ext[0] !== ".") {
        ext = "." + ext;
    }
    if (_MIME_TYPES[ext]) {
        return _MIME_TYPES[ext];
    }
    return "application/octet-stream";
}

function mimeFromPath(path) {
    if (typeof path !== "string") {
        return "application/octet-stream";
    }
    var dotIdx = path.lastIndexOf(".");
    if (dotIdx < 0) {
        return "application/octet-stream";
    }
    return mimeFromExtension(path.substring(dotIdx));
}

function mimeIsText(mime) {
    if (typeof mime !== "string") {
        return false;
    }
    if (mime.startsWith("text/")) {
        return true;
    }
    if (mime === "application/json" || mime === "application/javascript" || mime === "application/xml" || mime === "application/typescript" || mime === "application/yaml" || mime === "image/svg+xml") {
        return true;
    }
    return false;
}
// Extract charset parameter from a MIME type string.
// e.g. "text/html; charset=utf-8" → "utf-8", "application/json" → ""
function mimeCharset(mime) {
    if (typeof mime !== "string") {
        return "";
    }
    var lower = mime.toLowerCase();
    var idx = lower.indexOf("charset=");
    if (idx < 0) {
        return "";
    }
    var rest = lower.substring(idx + 8);
    // Strip optional quotes
    if (rest.length > 0 && rest[0] === '"') {
        var endQ = rest.indexOf('"', 1);
        if (endQ > 0) {
            return rest.substring(1, endQ);
        }
        return rest.substring(1);
    }
    // Until semicolon or end
    var semi = rest.indexOf(";");
    if (semi >= 0) {
        return rest.substring(0, semi).trim();
    }
    return rest.trim();
}
// ═══════════════════════════════════════════════════════════════════════════
//  Request (WHATWG Fetch Standard §5.3)
// ═══════════════════════════════════════════════════════════════════════════
class Request {
    constructor(input, init) {
        if (typeof input === "string") {
            this.url = input;
        } else if (input instanceof Request) {
            this.url = input.url;
        } else if (typeof input === "object" && input !== null && input.url) {
            this.url = String(input.url);
        } else {
            this.url = String(input);
        }
        if (init === undefined || init === null) {
            init = {};
        }
        this.method = _normalizeMethod(init.method || (input instanceof Request ? input.method : "GET"));
        this.headers = new Headers(init.headers || (input instanceof Request ? input.headers : undefined));
        this.body = init.body !== undefined ? init.body : (input instanceof Request ? input.body : null);
        this.redirect = init.redirect || "follow"; // "follow" | "error" | "manual"
        this.credentials = init.credentials || "same-origin";
        this.cache = init.cache || "default";
        this.signal = init.signal || null;
        this.mode = init.mode || "cors";
        this.referrer = init.referrer !== undefined ? init.referrer : "about:client";
        this.referrerPolicy = init.referrerPolicy || "";
        this.integrity = init.integrity || "";
        this.keepalive = init.keepalive || false;
        // Phase 6.12: decompress option (non-standard, matches undici autoDecompress)
        // Default undefined = use async streaming path (no decompression).
        // Set to true to enable sync binary-safe gzip/deflate decompression
        // (only safe for external servers — blocks the event loop).
        this._decompress = (init.decompress !== undefined) ? init.decompress : undefined;
    }
    clone() {
        return new Request(this.url, {
            method: this.method,
            headers: new Headers(this.headers),
            body: this.body,
            redirect: this.redirect,
            credentials: this.credentials,
            cache: this.cache,
            signal: this.signal
        });
    }
}
// ═══════════════════════════════════════════════════════════════════════════
//  WHATWG ReadableStream + ReadableStreamDefaultReader (Phase 6.11)
//
//  Push-model implementation:
//    • underlyingSource.start(controller) is called synchronously
//    • consumer calls reader.read() → returns a Promise<{value,done}>
//    • producer calls controller.enqueue(chunk) / controller.close()
//  Backpressure via controller.desiredSize (unread > 0 → stop producing).
// ═══════════════════════════════════════════════════════════════════════════
class ReadableStreamDefaultController {
    constructor() {
        this._queue = [];
        this._pendingReads = []; // { resolve, reject } pairs waiting for data
        this._closed = false;
        this._errored = false;
        this._errorVal = undefined;
    }
    enqueue(chunk) {
        if (this._closed || this._errored) {
            return;
        }
        if (this._pendingReads.length > 0) {
            var pr = this._pendingReads.shift();
            pr.resolve({
                value: chunk,
                done: false
            });
        } else {
            this._queue.push(chunk);
        }
    }
    close() {
        if (this._closed || this._errored) {
            return;
        }
        this._closed = true;
        while (this._pendingReads.length > 0) {
            this._pendingReads.shift().resolve({
                value: undefined,
                done: true
            });
        }
    }
    error(e) {
        if (this._closed || this._errored) {
            return;
        }
        this._errored = true;
        this._errorVal = e;
        while (this._pendingReads.length > 0) {
            this._pendingReads.shift().reject(e);
        }
    }
    // Internal: called by reader.read()
    _pull() {
        var self = this;
        if (self._errored) {
            return Promise.reject(self._errorVal);
        }
        if (self._queue.length > 0) {
            return Promise.resolve({
                value: self._queue.shift(),
                done: false
            });
        }
        if (self._closed) {
            return Promise.resolve({
                value: undefined,
                done: true
            });
        }
        return new Promise(function(resolve, reject) {
            self._pendingReads.push({
                resolve: resolve,
                reject: reject
            });
        });
    }
    get desiredSize() {
        return 1 - this._queue.length;
    }
}
class ReadableStreamDefaultReader {
    constructor(stream) {
        if (stream._locked) {
            throw new TypeError("ReadableStream is already locked to a reader");
        }
        stream._locked = true;
        this._stream = stream;
        this._ctrl = stream._controller;
        var self = this;
        this.closed = new Promise(function(res, rej) {
            self._closedRes = res;
            self._closedRej = rej;
        });
    }
    read() {
        var self = this;
        return self._ctrl._pull().then(function(result) {
            if (result.done && self._closedRes) {
                var res = self._closedRes;
                self._closedRes = null;
                res(undefined);
            }
            return result;
        }, function(err) {
            if (self._closedRej) {
                var rej = self._closedRej;
                self._closedRej = null;
                rej(err);
            }
            return Promise.reject(err);
        });
    }
    cancel(reason) {
        this._stream._locked = false;
        if (this._stream._cancelCb) {
            return Promise.resolve(this._stream._cancelCb(reason));
        }
        return Promise.resolve();
    }
    releaseLock() {
        this._stream._locked = false;
    }
}
class ReadableStream {
    constructor(underlyingSource) {
        if (underlyingSource === undefined || underlyingSource === null) {
            underlyingSource = {};
        }
        this._locked = false;
        this._controller = new ReadableStreamDefaultController();
        this._cancelCb = underlyingSource.cancel || null;
        if (underlyingSource.start) {
            underlyingSource.start(this._controller);
        }
        // for await...of support — set on instance so the VM finds it as own property.
        // All functions must be plain closures; class-method calls inside ITER_NEXT
        // cause a VM "list index out of range" crash. We inline pull logic using
        // direct closure-captured references to _queue, _closed, _errored.
        var self = this;
        this[Symbol.asyncIterator] = function() {
            var _ctrl = self._controller;
            self._locked = true;
            return {
                next: function() {
                    if (_ctrl._errored) {
                        return Promise.reject(_ctrl._errorVal);
                    }
                    if (_ctrl._queue.length > 0) {
                        return Promise.resolve({
                            value: _ctrl._queue.shift(),
                            done: false
                        });
                    }
                    if (_ctrl._closed) {
                        return Promise.resolve({
                            value: undefined,
                            done: true
                        });
                    }
                    return new Promise(function(resolve, reject) {
                        _ctrl._pendingReads.push({
                            resolve: resolve,
                            reject: reject
                        });
                    });
                },
                return: function(val) {
                    self._locked = false;
                    return Promise.resolve({
                        value: val,
                        done: true
                    });
                }
            };
        };
    }
    get locked() {
        return this._locked;
    }
    getReader() {
        return new ReadableStreamDefaultReader(this);
    }
    cancel(reason) {
        if (this._cancelCb) {
            return Promise.resolve(this._cancelCb(reason));
        }
        return Promise.resolve();
    }
}
// Drain a ReadableStream to a concatenated string (used by Response.text()).
function _drainStream(stream) {
    return new Promise(function(resolve, reject) {
        var reader = stream.getReader();
        var parts = [];

        function pump() {
            reader.read().then(function(r) {
                if (r.done) {
                    reader.releaseLock();
                    resolve(parts.join(""));
                } else {
                    parts.push(String(r.value));
                    pump();
                }
            }, function(e) {
                reader.releaseLock();
                reject(e);
            });
        }
        pump();
    });
}
// ═══════════════════════════════════════════════════════════════════════════
//  Response (WHATWG Fetch Standard §5.4)
// ═══════════════════════════════════════════════════════════════════════════
class Response {
    constructor(body, init) {
        if (init === undefined || init === null) {
            init = {};
        }
        this.status = init.status !== undefined ? init.status : 200;
        this.statusText = init.statusText || _statusText(this.status);
        this.headers = new Headers(init.headers);
        this.url = init.url || "";
        this.ok = (this.status >= 200 && this.status < 300);
        this.redirected = init.redirected || false;
        this.type = "basic";
        this._bodyUsed = false;
        // Phase 6.11: body may be a ReadableStream or a plain string
        if (body instanceof ReadableStream) {
            this._bodyStream = body;
            this._body = null;
        } else {
            this._body = (body !== undefined && body !== null) ? String(body) : "";
            this._bodyStream = null;
        }
    }
    get bodyUsed() {
        return this._bodyUsed;
    }
    // Phase 6.11: expose WHATWG ReadableStream body.
    // For string bodies, wraps the string in a one-chunk pre-closed stream.
    get body() {
        if (this._bodyStream !== null) {
            return this._bodyStream;
        }
        var str = this._body || "";
        return new ReadableStream({
            start: function(ctrl) {
                if (str.length > 0) {
                    ctrl.enqueue(str);
                }
                ctrl.close();
            }
        });
    }
    text() {
        var self = this;
        if (self._bodyStream) {
            self._bodyUsed = true;
            return _drainStream(self._bodyStream);
        }
        return new Promise(function(resolve) {
            self._bodyUsed = true;
            resolve(self._body || "");
        });
    }
    json() {
        return this.text().then(function(txt) {
            return JSON.parse(txt);
        });
    }
    arrayBuffer() {
        var self = this;
        return this.text().then(function(txt) {
            // Convert string to ArrayBuffer via Uint8Array (Latin-1 encoding)
            var AB = globalThis.ArrayBuffer;
            var U8 = globalThis.Uint8Array;
            if (!AB || !U8) {
                return txt;
            } // fallback if binary_types not loaded
            var len = txt.length;
            var ab = new AB(len);
            var u8 = new U8(ab);
            var i = 0;
            while (i < len) {
                u8[i] = txt.charCodeAt(i) & 0xFF;
                i = i + 1;
            }
            self._bodyUsed = true;
            return ab;
        });
    }
    blob() {
        // Response.blob() — returns a real Blob instance (Phase 6.14A)
        var self = this;
        return this.text().then(function(txt) {
            self._bodyUsed = true;
            var ct = self.headers.get("content-type") || "";
            return new Blob([txt], {
                type: ct
            });
        });
    }
    bytes() {
        // Response.bytes() — returns Uint8Array (Node 20+)
        var self = this;
        return this.text().then(function(txt) {
            var U8 = globalThis.Uint8Array;
            if (!U8) {
                return txt;
            }
            var len = txt.length;
            var u8 = new U8(len);
            var i = 0;
            while (i < len) {
                u8[i] = txt.charCodeAt(i) & 0xFF;
                i = i + 1;
            }
            self._bodyUsed = true;
            return u8;
        });
    }
    formData() {
        // Response.formData() — parses body as multipart/form-data or
        // application/x-www-form-urlencoded and returns a FormData instance.
        var self = this;
        return this.text().then(function(txt) {
            self._bodyUsed = true;
            var ct = self.headers.get("content-type") || "";
            return _parseFormData(txt, ct);
        });
    }
    clone() {
        if (this._bodyUsed) {
            throw new TypeError("Cannot clone a Response whose body is already used");
        }
        // Clone always uses string body (stream bodies cannot be tee'd yet)
        return new Response(this._body !== null ? this._body : "", {
            status: this.status,
            statusText: this.statusText,
            headers: new Headers(this.headers),
            url: this.url,
            redirected: this.redirected
        });
    }
}
// Static factory methods
Response.json = function(data, init) {
    if (init === undefined || init === null) {
        init = {};
    }
    var body = JSON.stringify(data);
    var h = new Headers(init.headers);
    h.set("Content-Type", "application/json");
    return new Response(body, {
        status: init.status || 200,
        statusText: init.statusText || "OK",
        headers: h
    });
};
Response.redirect = function(url, status) {
    if (status === undefined) {
        status = 302;
    }
    var h = new Headers();
    h.set("Location", String(url));
    return new Response(null, {
        status: status,
        headers: h
    });
};
Response.error = function() {
    var r = new Response(null, {
        status: 0
    });
    r.type = "error";
    return r;
};
// ═══════════════════════════════════════════════════════════════════════════
//  AbortController / AbortSignal (DOM Standard — minimal)
// ═══════════════════════════════════════════════════════════════════════════
class AbortSignal {
    constructor() {
        this.aborted = false;
        this.reason = undefined;
        this._listeners = [];
        this._onabort = null;
    }
    get onabort() {
        return this._onabort;
    }
    set onabort(fn) {
        // Remove previous onabort listener if any
        if (this._onabort !== null) {
            this.removeEventListener("abort", this._onabort);
        }
        this._onabort = typeof fn === "function" ? fn : null;
        if (this._onabort !== null) {
            this.addEventListener("abort", this._onabort);
        }
    }
    addEventListener(type, listener) {
        if (type === "abort") {
            this._listeners.push(listener);
        }
    }
    removeEventListener(type, listener) {
        if (type === "abort") {
            var newL = [];
            var i = 0;
            while (i < this._listeners.length) {
                if (this._listeners[i] !== listener) {
                    newL.push(this._listeners[i]);
                }
                i = i + 1;
            }
            this._listeners = newL;
        }
    }
    _fire() {
        var i = 0;
        while (i < this._listeners.length) {
            this._listeners[i]();
            i = i + 1;
        }
    }
    // WHATWG DOM §3.2 — throwIfAborted()
    // If the signal is aborted, throw this.reason (or a generic AbortError).
    throwIfAborted() {
        if (this.aborted) {
            var r = this.reason;
            if (r === undefined) {
                r = new DOMException("The operation was aborted.", "AbortError");
            }
            throw r;
        }
    }
}
// AbortSignal.abort(reason) — returns a pre-aborted signal (WHATWG DOM §3.2)
AbortSignal.abort = function(reason) {
    var signal = new AbortSignal();
    signal.aborted = true;
    signal.reason = reason !== undefined ? reason : new DOMException("The operation was aborted.", "AbortError");
    return signal;
};
// AbortSignal.timeout(ms) — returns a signal that auto-aborts after `ms` milliseconds
// Node.js ≥18: https://nodejs.org/api/globals.html#static-method-abortsignaltimeoutdelay
AbortSignal.timeout = function(ms) {
    var signal = new AbortSignal();
    setTimeout(function() {
        if (!signal.aborted) {
            signal.aborted = true;
            signal.reason = new DOMException("The operation was aborted due to timeout.", "TimeoutError");
            signal._fire();
        }
    }, ms);
    return signal;
};
// AbortSignal.any(signals) — composite signal that aborts when any input aborts (Node v20+)
AbortSignal.any = function(signals) {
    var composite = new AbortSignal();
    if (!Array.isArray(signals)) {
        return composite;
    }
    var i = 0;
    while (i < signals.length) {
        var s = signals[i];
        if (s && s.aborted) {
            composite.aborted = true;
            composite.reason = s.reason;
            return composite;
        }
        i = i + 1;
    }

    function _onSourceAbort(src) {
        return function() {
            if (!composite.aborted) {
                composite.aborted = true;
                composite.reason = src.reason;
                composite._fire();
            }
        };
    }
    var j = 0;
    while (j < signals.length) {
        if (signals[j] && signals[j].addEventListener) {
            signals[j].addEventListener("abort", _onSourceAbort(signals[j]));
        }
        j = j + 1;
    }
    return composite;
};
class AbortController {
    constructor() {
        this.signal = new AbortSignal();
    }
    abort(reason) {
        if (this.signal.aborted) {
            return;
        }
        this.signal.aborted = true;
        this.signal.reason = reason !== undefined ? reason : new DOMException("The operation was aborted.", "AbortError");
        this.signal._fire();
    }
}
// DOMException — proper class extending Error with .code property (WHATWG DOM §4.3)
var _DOM_EXCEPTION_CODES = {
    "IndexSizeError": 1,
    "HierarchyRequestError": 3,
    "WrongDocumentError": 4,
    "InvalidCharacterError": 5,
    "NoModificationAllowedError": 7,
    "NotFoundError": 8,
    "NotSupportedError": 9,
    "InvalidStateError": 11,
    "SyntaxError": 12,
    "InvalidModificationError": 13,
    "NamespaceError": 14,
    "InvalidAccessError": 15,
    "TypeMismatchError": 17,
    "SecurityError": 18,
    "NetworkError": 19,
    "AbortError": 20,
    "URLMismatchError": 21,
    "QuotaExceededError": 22,
    "TimeoutError": 23,
    "DataCloneError": 25
};
class DOMException extends Error {
    constructor(message, name) {
        super(message || "");
        this.name = name || "Error";
        this.code = _DOM_EXCEPTION_CODES[this.name] || 0;
    }
}
// ═══════════════════════════════════════════════════════════════════════════
//  HTTP status text lookup
// ═══════════════════════════════════════════════════════════════════════════
var _STATUS_TEXTS = {
    "100": "Continue",
    "101": "Switching Protocols",
    "200": "OK",
    "201": "Created",
    "202": "Accepted",
    "204": "No Content",
    "206": "Partial Content",
    "301": "Moved Permanently",
    "302": "Found",
    "303": "See Other",
    "304": "Not Modified",
    "307": "Temporary Redirect",
    "308": "Permanent Redirect",
    "400": "Bad Request",
    "401": "Unauthorized",
    "403": "Forbidden",
    "404": "Not Found",
    "405": "Method Not Allowed",
    "408": "Request Timeout",
    "409": "Conflict",
    "413": "Payload Too Large",
    "414": "URI Too Long",
    "415": "Unsupported Media Type",
    "422": "Unprocessable Entity",
    "429": "Too Many Requests",
    "500": "Internal Server Error",
    "502": "Bad Gateway",
    "503": "Service Unavailable",
    "504": "Gateway Timeout"
};

function _statusText(code) {
    var key = String(code);
    if (_STATUS_TEXTS[key]) {
        return _STATUS_TEXTS[key];
    }
    return "";
}
// ═══════════════════════════════════════════════════════════════════════════
//  HTTP/1.1 response parser
// ═══════════════════════════════════════════════════════════════════════════
// Find "\r\n" (CRLF) in a string starting from offset
function _findCRLF(data, from) {
    var cr = String.fromCharCode(13);
    var i = from;
    while (i < data.length - 1) {
        if (data[i] === cr && data[i + 1] === "\n") {
            return i;
        }
        i = i + 1;
    }
    return -1;
}
// Parse "HTTP/1.1 200 OK\r\n..." into {status, statusText, headers, headerEndIndex}
function _parseHTTPResponse(raw) {
    var result = {
        status: 0,
        statusText: "",
        headers: new Headers(),
        headerEnd: -1
    };
    // Find end of status line
    var statusLineEnd = _findCRLF(raw, 0);
    if (statusLineEnd < 0) {
        return result;
    }
    var statusLine = raw.substring(0, statusLineEnd);
    // Parse "HTTP/1.x <status> <text>"
    var spaceIdx = statusLine.indexOf(" ");
    if (spaceIdx < 0) {
        return result;
    }
    var rest = statusLine.substring(spaceIdx + 1);
    var spaceIdx2 = rest.indexOf(" ");
    if (spaceIdx2 < 0) {
        result.status = parseInt(rest, 10);
    } else {
        result.status = parseInt(rest.substring(0, spaceIdx2), 10);
        result.statusText = rest.substring(spaceIdx2 + 1);
    }
    // Parse headers
    var pos = statusLineEnd + 2; // skip CRLF
    while (pos < raw.length) {
        var lineEnd = _findCRLF(raw, pos);
        if (lineEnd < 0) {
            break;
        }
        if (lineEnd === pos) {
            // Empty line → end of headers
            result.headerEnd = pos + 2;
            break;
        }
        var headerLine = raw.substring(pos, lineEnd);
        var colonIdx = headerLine.indexOf(":");
        if (colonIdx > 0) {
            var hName = headerLine.substring(0, colonIdx);
            var hValue = headerLine.substring(colonIdx + 1).trim();
            result.headers.append(hName, hValue);
        }
        pos = lineEnd + 2;
    }
    return result;
}
// ═══════════════════════════════════════════════════════════════════════════
//  Chunked Transfer-Encoding decoder
// ═══════════════════════════════════════════════════════════════════════════
function _decodeChunked(raw) {
    var result = "";
    var pos = 0;
    while (pos < raw.length) {
        // Find chunk size line
        var lineEnd = _findCRLF(raw, pos);
        if (lineEnd < 0) {
            break;
        }
        var sizeStr = raw.substring(pos, lineEnd).trim();
        // Strip chunk extensions (;...)
        var semiIdx = sizeStr.indexOf(";");
        if (semiIdx >= 0) {
            sizeStr = sizeStr.substring(0, semiIdx);
        }
        var chunkSize = parseInt(sizeStr, 16);
        if (chunkSize === 0 || isNaN(chunkSize)) {
            break;
        }
        var chunkStart = lineEnd + 2;
        var chunkEnd = chunkStart + chunkSize;
        if (chunkEnd > raw.length) {
            // Incomplete chunk — take what we have
            result = result + raw.substring(chunkStart);
            break;
        }
        result = result + raw.substring(chunkStart, chunkEnd);
        pos = chunkEnd + 2; // skip trailing CRLF after chunk data
    }
    return result;
}
// ═══════════════════════════════════════════════════════════════════════════
//  Core fetch() implementation
// ═══════════════════════════════════════════════════════════════════════════
// Read all response data from a socket handle
function _readAll(handle, maxBytes) {
    var isTLS = (handle < 0);
    var result = "";
    var remaining = maxBytes;
    while (remaining > 0) {
        var chunkSize = remaining;
        if (chunkSize > 8192) {
            chunkSize = 8192;
        }
        var chunk;
        if (isTLS) {
            chunk = net.tlsRead(handle, chunkSize);
        } else {
            chunk = net.tcpRead(handle, chunkSize);
        }
        if (chunk === undefined || chunk === null || chunk.length === 0) {
            break;
        }
        result = result + chunk;
        remaining = remaining - chunk.length;
    }
    return result;
}
// Read response with Content-Length or chunked transfer encoding
function _readHTTPBody(handle, headers, maxBodySize) {
    var isTLS = (handle < 0);
    // Check for Content-Length
    var clHeader = headers.get("content-length");
    if (clHeader !== null) {
        var contentLength = parseInt(clHeader, 10);
        if (isNaN(contentLength) || contentLength < 0) {
            contentLength = 0;
        }
        if (contentLength === 0) {
            return "";
        }
        return _readAll(handle, contentLength);
    }
    // Check for chunked transfer encoding
    var teHeader = headers.get("transfer-encoding");
    if (teHeader !== null && teHeader.toLowerCase().indexOf("chunked") >= 0) {
        // Read chunks until "0\r\n\r\n"
        var raw = "";
        var maxRead = maxBodySize;
        while (maxRead > 0) {
            var chunkSize = 8192;
            if (chunkSize > maxRead) {
                chunkSize = maxRead;
            }
            var chunk;
            if (isTLS) {
                chunk = net.tlsRead(handle, chunkSize);
            } else {
                chunk = net.tcpRead(handle, chunkSize);
            }
            if (chunk === undefined || chunk === null || chunk.length === 0) {
                break;
            }
            raw = raw + chunk;
            maxRead = maxRead - chunk.length;
            // Check for terminator: 0\r\n\r\n
            if (raw.indexOf("0" + CRLF + CRLF) >= 0) {
                break;
            }
        }
        return _decodeChunked(raw);
    }
    // No Content-Length and not chunked — read until connection close
    return _readAll(handle, maxBodySize);
}
// Perform a single HTTP/1.1 request on a socket handle.
// Returns a Response object.
function _doHTTPRequest(handle, parsedUrl, method, headers, body) {
    var isTLS = (handle < 0);
    // Build request line
    var path = parsedUrl.pathname || "/";
    if (parsedUrl.search) {
        path = path + parsedUrl.search;
    }
    var requestLine = method + " " + path + " HTTP/1.1" + CRLF;
    // Ensure Host header
    if (!headers.has("host")) {
        var hostVal = parsedUrl.hostname;
        var port = parsedUrl.port;
        if (port && port !== "443" && port !== "80") {
            hostVal = hostVal + ":" + port;
        }
        headers.set("Host", hostVal);
    }
    // Set Content-Length for body
    if (body !== null && body !== undefined && body.length > 0) {
        headers.set("Content-Length", String(body.length));
    }
    // Set Connection header (keep-alive for pooling, close otherwise)
    if (!headers.has("connection")) {
        headers.set("Connection", "keep-alive");
    }
    // Assemble the full request
    var rawRequest = requestLine + headers._toRaw() + CRLF;
    if (body !== null && body !== undefined && body.length > 0) {
        rawRequest = rawRequest + body;
    }
    // Send
    if (isTLS) {
        net.tlsWrite(handle, rawRequest);
    } else {
        net.tcpWrite(handle, rawRequest);
    }
    // Read response headers (read in chunks until we find \r\n\r\n)
    var headerBuf = "";
    var headerParsed = null;
    var maxHeaderRead = 65536; // 64KB max header size
    var doubleCRLF = CRLF + CRLF;
    while (headerBuf.length < maxHeaderRead) {
        var chunk;
        if (isTLS) {
            chunk = net.tlsRead(handle, 4096);
        } else {
            chunk = net.tcpRead(handle, 4096);
        }
        if (chunk === undefined || chunk === null || chunk.length === 0) {
            break;
        }
        headerBuf = headerBuf + chunk;
        // Check for end of headers
        var endIdx = headerBuf.indexOf(doubleCRLF);
        if (endIdx >= 0) {
            headerParsed = _parseHTTPResponse(headerBuf);
            break;
        }
    }
    if (headerParsed === null) {
        headerParsed = _parseHTTPResponse(headerBuf);
    }
    // Read body — anything after headerEnd in the buffer plus remaining from socket
    var bodyPrefetch = "";
    if (headerParsed.headerEnd > 0 && headerParsed.headerEnd < headerBuf.length) {
        bodyPrefetch = headerBuf.substring(headerParsed.headerEnd);
    }
    // Calculate remaining body to read
    var maxBodySize = 10485760; // 10MB default max
    var body = bodyPrefetch;
    var clHeader = headerParsed.headers.get("content-length");
    if (clHeader !== null) {
        var contentLength = parseInt(clHeader, 10);
        if (!isNaN(contentLength) && contentLength > 0) {
            var remaining = contentLength - bodyPrefetch.length;
            if (remaining > 0) {
                body = body + _readAll(handle, remaining);
            }
        }
    } else {
        var teHeader = headerParsed.headers.get("transfer-encoding");
        if (teHeader !== null && teHeader.toLowerCase().indexOf("chunked") >= 0) {
            // Read the rest of the chunked body
            var maxRead = maxBodySize - bodyPrefetch.length;
            while (maxRead > 0) {
                var chunkSize = 8192;
                if (chunkSize > maxRead) {
                    chunkSize = maxRead;
                }
                var rdChunk;
                if (isTLS) {
                    rdChunk = net.tlsRead(handle, chunkSize);
                } else {
                    rdChunk = net.tcpRead(handle, chunkSize);
                }
                if (rdChunk === undefined || rdChunk === null || rdChunk.length === 0) {
                    break;
                }
                body = body + rdChunk;
                maxRead = maxRead - rdChunk.length;
                if (body.indexOf("0" + CRLF + CRLF) >= 0) {
                    break;
                }
            }
            body = _decodeChunked(body);
        } else {
            // Read until connection close
            var moreData = _readAll(handle, maxBodySize - bodyPrefetch.length);
            body = body + moreData;
        }
    }
    return new Response(body, {
        status: headerParsed.status,
        statusText: headerParsed.statusText,
        headers: headerParsed.headers,
        url: parsedUrl.href
    });
}
// ═══════════════════════════════════════════════════════════════════════════
//  Phase 6.10 — Connection Pooling
//
//  Per-origin socket reuse with HTTP keep-alive. Idle sockets are stored
//  in a pool keyed by "host:port:proto" and reused by subsequent fetch()
//  calls. Matches Node.js http.Agent / undici connection pool semantics.
// ═══════════════════════════════════════════════════════════════════════════
class ConnectionPool {
    constructor(options) {
        options = options || {};
        this.maxSocketsPerOrigin = options.maxSocketsPerOrigin || 6;
        this.maxTotalSockets = options.maxTotalSockets || 256;
        this.idleTimeout = options.idleTimeout || 5000; // ms
        this.keepAlive = options.keepAlive !== undefined ? options.keepAlive : true;
        this._free = {}; // key → [{ handle, timer }]
        this._active = {}; // key → count of in-flight sockets
        this._totalActive = 0;
        this._totalFree = 0;
    }
    // Build a pool key from host, port, and protocol flag
    _key(host, port, isTLS) {
        return host + ":" + port + ":" + (isTLS ? "tls" : "tcp");
    }
    // Try to acquire an idle socket for a given origin.
    // Returns the handle (int) or 0 if none available.
    acquire(host, port, isTLS) {
        if (!this.keepAlive) {
            return 0;
        }
        var key = this._key(host, port, isTLS);
        var free = this._free[key];
        if (!free || free.length === 0) {
            return 0;
        }
        var entry = free.pop();
        if (free.length === 0) {
            delete this._free[key];
        }
        if (entry.timer) {
            clearTimeout(entry.timer);
            entry.timer = null;
        }
        this._totalFree = this._totalFree - 1;
        // Track as active
        if (!this._active[key]) {
            this._active[key] = 0;
        }
        this._active[key] = this._active[key] + 1;
        this._totalActive = this._totalActive + 1;
        return entry.handle;
    }
    // Release an active socket back to the pool for reuse.
    // If the server sent Connection: close, or pool is full, close instead.
    release(host, port, isTLS, handle, serverClose) {
        var key = this._key(host, port, isTLS);
        // Decrement active count
        if (this._active[key]) {
            this._active[key] = this._active[key] - 1;
            if (this._active[key] <= 0) {
                delete this._active[key];
            }
        }
        if (this._totalActive > 0) {
            this._totalActive = this._totalActive - 1;
        }
        // If server said close, or pool disabled, or handle is invalid, close it
        if (serverClose || !this.keepAlive || handle === 0) {
            this._closeHandle(handle, isTLS);
            return;
        }
        // Check per-origin free limit
        if (!this._free[key]) {
            this._free[key] = [];
        }
        if (this._free[key].length >= this.maxSocketsPerOrigin) {
            this._closeHandle(handle, isTLS);
            return;
        }
        // Check total free limit
        if (this._totalFree >= this.maxTotalSockets) {
            this._closeHandle(handle, isTLS);
            return;
        }
        // Add to free pool with an idle timeout
        var self = this;
        var entry = {
            handle: handle,
            timer: null
        };
        entry.timer = setTimeout(function() {
            self._evict(key, entry);
        }, this.idleTimeout);
        this._free[key].push(entry);
        this._totalFree = this._totalFree + 1;
    }
    // Mark a handle as active (used when a new connection is created)
    trackActive(host, port, isTLS) {
        var key = this._key(host, port, isTLS);
        if (!this._active[key]) {
            this._active[key] = 0;
        }
        this._active[key] = this._active[key] + 1;
        this._totalActive = this._totalActive + 1;
    }
    // Get number of active sockets for an origin
    activeCount(host, port, isTLS) {
        var key = this._key(host, port, isTLS);
        return (this._active[key] || 0);
    }
    // Get number of free sockets for an origin
    freeCount(host, port, isTLS) {
        var key = this._key(host, port, isTLS);
        return (this._free[key] ? this._free[key].length : 0);
    }
    // Close a socket handle
    _closeHandle(handle, isTLS) {
        if (handle === 0) {
            return;
        }
        if (isTLS) {
            net.tlsClose(handle);
        } else {
            net.tcpClose(handle);
        }
    }
    // Evict a specific entry from the free pool and close its handle
    _evict(key, entry) {
        var free = this._free[key];
        if (!free) {
            return;
        }
        var idx = free.indexOf(entry);
        if (idx !== -1) {
            free.splice(idx, 1);
            if (free.length === 0) {
                delete this._free[key];
            }
            this._totalFree = this._totalFree - 1;
        }
        if (entry.timer) {
            clearTimeout(entry.timer);
            entry.timer = null;
        }
        var isTLS = key.indexOf(":tls") !== -1;
        this._closeHandle(entry.handle, isTLS);
    }
    // Close all pooled sockets
    destroy() {
        var keys = Object.keys(this._free);
        for (var i = 0; i < keys.length; i++) {
            var free = this._free[keys[i]];
            var isTLS = keys[i].indexOf(":tls") !== -1;
            for (var j = 0; j < free.length; j++) {
                if (free[j].timer) {
                    clearTimeout(free[j].timer);
                    free[j].timer = null;
                }
                this._closeHandle(free[j].handle, isTLS);
            }
        }
        this._free = {};
        this._totalFree = 0;
    }
    // Stats for testing
    stats() {
        return {
            totalActive: this._totalActive,
            totalFree: this._totalFree
        };
    }
} // class ConnectionPool
// Global connection pool shared by all fetch() calls
var _globalPool = new ConnectionPool();
// ═══════════════════════════════════════════════════════════════════════════
//  Phase 6.9 — Node.js-compatible async fetch() (true non-blocking I/O)
//
//  HTTP  (plain)  : async tcpConnectNb  + sync tcpWrite + async tcpReadNb
//  HTTPS (TLS)    : sync  tlsConnect    + sync tlsWrite + sync tlsRead
//                   (async TLS handshake planned for Phase 6.9b)
//
//  Promise.all([fetch(a), fetch(b)]) now issues both requests concurrently:
//  both TCP connects are in-flight simultaneously via the libuv event loop.
// ═══════════════════════════════════════════════════════════════════════════
// Build a raw HTTP/1.1 request string without touching the socket.
function _buildRawRequest(parsedUrl, method, reqHdrs, body, keepAlive) {
    var path = parsedUrl.pathname || "/";
    if (parsedUrl.search) {
        path = path + parsedUrl.search;
    }
    var line = method + " " + path + " HTTP/1.1" + CRLF;
    if (!reqHdrs.has("host")) {
        var hostVal = parsedUrl.hostname;
        var p = parsedUrl.port;
        if (p && p !== "443" && p !== "80") {
            hostVal = hostVal + ":" + p;
        }
        reqHdrs.set("Host", hostVal);
    }
    if (body !== null && body !== undefined && body.length > 0) {
        reqHdrs.set("Content-Length", String(body.length));
    }
    if (!reqHdrs.has("connection")) {
        reqHdrs.set("Connection", keepAlive ? "keep-alive" : "close");
    }
    // Phase 6.12: send Accept-Encoding by default so servers can compress
    if (!reqHdrs.has("accept-encoding")) {
        reqHdrs.set("Accept-Encoding", "gzip, deflate");
    }
    var raw = line + reqHdrs._toRaw() + CRLF;
    if (body !== null && body !== undefined && body.length > 0) {
        raw = raw + body;
    }
    return raw;
}
// Return true once a raw HTTP response buffer contains the complete response.
// Called from the async read loop to know when to stop reading.
function _isHTTPResponseComplete(buf) {
    var hdrEnd = buf.indexOf(CRLF + CRLF);
    if (hdrEnd < 0) {
        return false;
    }
    var hdrs = buf.substring(0, hdrEnd);
    var body = buf.substring(hdrEnd + 4);
    var lc = hdrs.toLowerCase();
    // No-body status classes (1xx / 204 / 304)
    var statusLine = hdrs.split(CRLF)[0];
    var stParts = statusLine.split(" ");
    if (stParts.length >= 2) {
        var code = parseInt(stParts[1], 10);
        if (code >= 100 && code < 200) {
            return true;
        }
        if (code === 204 || code === 304) {
            return true;
        }
    }
    // chunked: look for terminal 0-chunk
    if (lc.indexOf("transfer-encoding: chunked") >= 0) {
        return body.indexOf("\r\n0\r\n\r\n") >= 0 || body.indexOf("\r\n0\r\n") >= 0;
    }
    // content-length: wait until body has that many bytes
    var clIdx = lc.indexOf("content-length:");
    if (clIdx >= 0) {
        var nlIdx = lc.indexOf("\n", clIdx);
        var clStr = hdrs.substring(clIdx + 15, nlIdx >= 0 ? nlIdx : hdrEnd).trim();
        var cl = parseInt(clStr, 10);
        if (!isNaN(cl) && cl >= 0) {
            return body.length >= cl;
        }
    }
    // no content-length, not chunked → wait for EOF (isEOF flag from caller)
    return false;
}
// Convert a raw HTTP response buffer to a Response object.
function _rawBufToResponse(rawBuf, url) {
    var hp = _parseHTTPResponse(rawBuf);
    if (!hp) {
        return new Response("", {
            status: 500,
            statusText: "Parse Error",
            headers: new Headers(),
            url: url
        });
    }
    var bodyStr = (hp.headerEnd > 0 && hp.headerEnd < rawBuf.length) ? rawBuf.substring(hp.headerEnd) : "";
    var te = hp.headers.get("transfer-encoding");
    if (te && te.toLowerCase().indexOf("chunked") >= 0) {
        bodyStr = _decodeChunked(bodyStr);
    }
    return new Response(bodyStr, {
        status: hp.status,
        statusText: hp.statusText,
        headers: hp.headers,
        url: url
    });
}
// Async read loop: register one tcpReadNb/tlsReadNb, accumulate, repeat until done.
// signal checked at each iteration for fast abort path (polling fallback).
// Socket is NOT closed here — caller (_fetchOneHTTPAsync/_fetchOneHTTPSAsync) owns the handle.
function _asyncReadLoop(handle, accum, signal, onDone, isTLS) {
    if (signal && signal.aborted) {
        onDone(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }
    var readFn = isTLS ? net.tlsReadNb : net.tcpReadNb;
    readFn(handle, 65536, function(chunk, isEOF) {
        accum = accum + chunk;
        if (signal && signal.aborted) {
            onDone(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        if (isEOF || _isHTTPResponseComplete(accum)) {
            onDone(accum, null);
        } else {
            _asyncReadLoop(handle, accum, signal, onDone, isTLS);
        }
    });
}
// ─── Phase 6.11 — Streaming body helpers ────────────────────────────────────
// Read headers only (up to CRLF+CRLF).  onDone(accum, sepIdx, isEOF).
// Legacy string-based header reader (kept for reference; not used in the main path).
function _asyncReadHeaders(handle, isTLS, signal, accum, onDone) {
    if (signal && signal.aborted) {
        onDone(accum, -1, true);
        return;
    }
    var readFn = isTLS ? net.tlsReadNb : net.tcpReadNb;
    readFn(handle, 8192, function(chunk, isEOF) {
        if (chunk && chunk.length > 0) {
            accum = accum + chunk;
        }
        var sep = accum.indexOf(CRLF + CRLF);
        if (sep >= 0 || isEOF) {
            onDone(accum, sep, isEOF);
        } else {
            _asyncReadHeaders(handle, isTLS, signal, accum, onDone);
        }
    });
}
// Scan a Uint8Array for the first occurrence of CRLFCRLF (13,10,13,10).
// Returns the index of the leading CR, or -1 if not found.
function _findCRLFCRLF(buf) {
    for (var i = 0; i <= buf.length - 4; i++) {
        if (buf[i] === 13 && buf[i + 1] === 10 && buf[i + 2] === 13 && buf[i + 3] === 10) {
            return i;
        }
    }
    return -1;
}
// Binary-safe header reader.  Accumulates raw bytes in a Uint8Array so that
// null bytes in an early body prefix (e.g. the first bytes of a gzip stream)
// are never lost.  Once CRLFCRLF is found the callback receives:
//   onDone(headerStr, bodyPrefixArr, isEOF)
// where headerStr is the ASCII header block (including trailing CRLFCRLF) and
// bodyPrefixArr is a Uint8Array of any body bytes already pulled from the socket.
function _asyncReadHeadersBinary(handle, isTLS, signal, accArr, onDone) {
    var sep = _findCRLFCRLF(accArr);
    if (sep >= 0) {
        // Decode header bytes as Latin-1 (HTTP headers are always ASCII)
        var headerStr = "";
        for (var hi = 0; hi < sep + 4; hi++) {
            headerStr += String.fromCharCode(accArr[hi]);
        }
        onDone(headerStr, accArr.subarray(sep + 4), false);
        return;
    }
    if (signal && signal.aborted) {
        onDone("", new Uint8Array(0), true);
        return;
    }
    var readFn = isTLS ? net.tlsReadBinaryNb : net.tcpReadBinaryNb;
    readFn(handle, 8192, function(ptr, len, isEOF) {
        var newAcc;
        if (len > 0) {
            newAcc = new Uint8Array(accArr.length + len);
            newAcc.set(accArr, 0);
            for (var j = 0; j < len; j++) {
                newAcc[accArr.length + j] = __buf.getByte(ptr, j);
            }
            __buf.free(ptr);
        } else {
            if (ptr > 0) {
                __buf.free(ptr);
            }
            newAcc = accArr;
        }
        if (isEOF) {
            // Deliver whatever we have — let caller handle truncated response
            onDone("", new Uint8Array(0), true);
            return;
        }
        _asyncReadHeadersBinary(handle, isTLS, signal, newAcc, onDone);
    });
}
// Stream exactly `remaining` bytes from the socket into `controller`.
function _streamBodyByLength(handle, isTLS, signal, remaining, controller, onDone) {
    if (remaining <= 0) {
        onDone(null);
        return;
    }
    if (signal && signal.aborted) {
        onDone(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }
    var readSize = (remaining > 65536) ? 65536 : remaining;
    var readFn = isTLS ? net.tlsReadNb : net.tcpReadNb;
    readFn(handle, readSize, function(chunk, isEOF) {
        if (chunk && chunk.length > 0) {
            controller.enqueue(chunk);
            remaining = remaining - chunk.length;
        }
        if (isEOF || remaining <= 0) {
            onDone(null);
        } else {
            _streamBodyByLength(handle, isTLS, signal, remaining, controller, onDone);
        }
    });
}
// Stream until connection EOF.
function _streamBodyUntilEOF(handle, isTLS, signal, controller, onDone) {
    if (signal && signal.aborted) {
        onDone(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }
    var readFn = isTLS ? net.tlsReadNb : net.tcpReadNb;
    readFn(handle, 65536, function(chunk, isEOF) {
        if (chunk && chunk.length > 0) {
            controller.enqueue(chunk);
        }
        if (isEOF) {
            onDone(null);
        } else {
            _streamBodyUntilEOF(handle, isTLS, signal, controller, onDone);
        }
    });
}
// Stream a chunked-encoded body; parse chunk sizes and enqueue decoded data.
function _streamChunkedLoop(handle, isTLS, signal, accum, controller, onDone) {
    // Emit all complete chunks from accum first
    while (true) {
        var nlIdx = accum.indexOf(CRLF);
        if (nlIdx < 0) {
            break;
        }
        var sizeStr = accum.substring(0, nlIdx).trim();
        var semiIdx = sizeStr.indexOf(";");
        if (semiIdx >= 0) {
            sizeStr = sizeStr.substring(0, semiIdx).trim();
        }
        var chunkSize = parseInt(sizeStr, 16);
        if (isNaN(chunkSize)) {
            onDone(new TypeError("Invalid chunked encoding"));
            return;
        }
        if (chunkSize === 0) {
            onDone(null);
            return;
        } // terminal chunk
        var dataStart = nlIdx + 2;
        var dataEnd = dataStart + chunkSize;
        if (accum.length < dataEnd + 2) {
            break;
        } // need more data
        controller.enqueue(accum.substring(dataStart, dataEnd));
        accum = accum.substring(dataEnd + 2); // skip data + trailing CRLF
    }
    // Need more bytes
    if (signal && signal.aborted) {
        onDone(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }
    var readFn = isTLS ? net.tlsReadNb : net.tcpReadNb;
    readFn(handle, 65536, function(chunk, isEOF) {
        if (chunk && chunk.length > 0) {
            accum = accum + chunk;
        }
        if (isEOF) {
            onDone(null);
            return;
        }
        _streamChunkedLoop(handle, isTLS, signal, accum, controller, onDone);
    });
}
// ─── Phase 6.12 — Streaming decompression ────────────────────────────────────
// wbits values (mirrors ffi/zlib.na.jac constants):
var _WBITS_GZIP = 31; // gzip header
var _WBITS_AUTO = 47; // auto-detect gzip or zlib
var _WBITS_RAW = -15; // raw deflate, no header
// Determine wbits from a Content-Encoding header value.
// Returns null if the encoding is not compressed (identity/null).
function _wbitsForEncoding(enc) {
    if (enc === null || enc === undefined) {
        return null;
    }
    var lc = enc.toLowerCase().trim();
    if (lc === "gzip" || lc === "x-gzip") {
        return _WBITS_GZIP;
    }
    if (lc === "deflate") {
        return _WBITS_AUTO;
    } // servers often send zlib-wrapped
    if (lc === "identity" || lc === "") {
        return null;
    }
    return null;
}
// Dispatch body streaming based on Content-Length / Transfer-Encoding header.
// `bodyPrefixArr` is a Uint8Array of body bytes already pulled during header read.
// These bytes are binary-exact (no null-byte truncation).
// Phase 6.12: if Content-Encoding is gzip/deflate, route through stateful inflate.
function _asyncStreamBody(handle, isTLS, signal, hp, bodyPrefixArr, controller, onDone) {
    var ce = hp.headers.get("content-encoding");
    var wbits = _wbitsForEncoding(ce);
    var te = hp.headers.get("transfer-encoding");
    var clStr = hp.headers.get("content-length");
    var prefixLen = bodyPrefixArr ? bodyPrefixArr.length : 0;
    // ── Compressed body path ─────────────────────────────────────────────────
    if (wbits !== null) {
        hp.headers.delete("content-encoding");
        // Helper: copy prefix Uint8Array into a C buffer and feed through zlib.
        // Calls cb() when done (or immediately if prefix is empty).
        function feedPrefix(zh, cb) {
            if (prefixLen === 0) {
                cb();
                return;
            }
            var pfxPtr = __buf.alloc(prefixLen);
            for (var pi = 0; pi < prefixLen; pi++) {
                __buf.setByte(pfxPtr, pi, bodyPrefixArr[pi]);
            }
            var chunk = __zlib.feed(zh, pfxPtr, prefixLen);
            __buf.free(pfxPtr);
            if (chunk && chunk.length > 0) {
                controller.enqueue(chunk);
            }
            cb();
        }
        if (te !== null && te.toLowerCase().indexOf("chunked") >= 0) {
            // Collect all chunk bodies as a Uint8Array (binary-safe), then decompress.
            _streamChunkedAccumBinary(handle, isTLS, signal, bodyPrefixArr, function(bodyArr, err) {
                if (err) {
                    onDone(err);
                    return;
                }
                _decompressUint8ArrayAndEnqueue(bodyArr, wbits, controller, onDone);
            });
            return;
        }
        if (clStr !== null && !isNaN(parseInt(clStr, 10))) {
            var cl = parseInt(clStr, 10);
            var zlibH = __zlib.open(wbits);
            if (zlibH === 0) {
                onDone(new TypeError("__zlib.open failed"));
                return;
            }
            feedPrefix(zlibH, function() {
                var remaining3 = cl - prefixLen;
                if (remaining3 <= 0) {
                    __zlib.close(zlibH);
                    onDone(null);
                    return;
                }
                _streamBodyGzipWithHandle(handle, isTLS, signal, remaining3, controller, onDone, zlibH);
            });
            return;
        }
        // EOF-terminated compressed stream
        var zlibH2 = __zlib.open(wbits);
        if (zlibH2 === 0) {
            onDone(new TypeError("__zlib.open failed"));
            return;
        }
        feedPrefix(zlibH2, function() {
            _streamBodyGzipWithHandle(handle, isTLS, signal, null, controller, onDone, zlibH2);
        });
        return;
    }
    // ── Uncompressed path ────────────────────────────────────────────────────
    // Decode prefix bytes as Latin-1 for text content (safe for ASCII bodies).
    var prefixStr = "";
    if (prefixLen > 0) {
        for (var ui = 0; ui < prefixLen; ui++) {
            prefixStr += String.fromCharCode(bodyPrefixArr[ui]);
        }
    }
    if (te !== null && te.toLowerCase().indexOf("chunked") >= 0) {
        _streamChunkedLoop(handle, isTLS, signal, prefixStr, controller, onDone);
    } else if (clStr !== null && !isNaN(parseInt(clStr, 10))) {
        var cl2 = parseInt(clStr, 10);
        if (prefixLen > 0) {
            controller.enqueue(prefixStr);
        }
        _streamBodyByLength(handle, isTLS, signal, cl2 - prefixLen, controller, onDone);
    } else {
        if (prefixLen > 0) {
            controller.enqueue(prefixStr);
        }
        _streamBodyUntilEOF(handle, isTLS, signal, controller, onDone);
    }
}
// Stream a compressed body using an already-opened zlib handle.
// Closes the handle when done (EOF or error).
function _streamBodyGzipWithHandle(handle, isTLS, signal, remaining, controller, onDone, zlibH) {
    var readFn = isTLS ? net.tlsReadBinaryNb : net.tcpReadBinaryNb;

    function readOne() {
        if (signal && signal.aborted) {
            __zlib.close(zlibH);
            onDone(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        var readSize = 65536;
        if (remaining !== null && remaining < readSize) {
            readSize = remaining;
        }
        if (readSize <= 0) {
            __zlib.close(zlibH);
            onDone(null);
            return;
        }
        readFn(handle, readSize, function(ptr, len, isEOF) {
            if (len > 0) {
                var chunk = __zlib.feed(zlibH, ptr, len);
                __buf.free(ptr);
                if (chunk && chunk.length > 0) {
                    controller.enqueue(chunk);
                }
                if (remaining !== null) {
                    remaining = remaining - len;
                }
            } else if (ptr > 0) {
                __buf.free(ptr);
            }
            if (isEOF || (remaining !== null && remaining <= 0)) {
                __zlib.close(zlibH);
                onDone(null);
                return;
            }
            readOne();
        });
    }
    readOne();
}
// Binary-safe chunked accumulator: collects all chunk bodies into a Uint8Array,
// delivering onDone(bodyArr: Uint8Array, err) at the terminal chunk.
// Chunk size lines are ASCII; chunk bodies are read via binary reads — no NUL truncation.
function _streamChunkedAccumBinary(handle, isTLS, signal, seedArr, onDone) {
    // accArr holds everything received so far (header prefix + more chunks)
    var accArr = seedArr || new Uint8Array(0);
    var bodyParts = []; // array of Uint8Array pieces — concatenated at terminal chunk
    // Append raw bytes from a binary read into accArr
    function appendBinary(ptr, len) {
        var next = new Uint8Array(accArr.length + len);
        next.set(accArr, 0);
        for (var j = 0; j < len; j++) {
            next[accArr.length + j] = __buf.getByte(ptr, j);
        }
        __buf.free(ptr);
        accArr = next;
    }
    // Find CRLF (13, 10) in accArr starting at `from`
    function findCRLF(from) {
        for (var k = from; k < accArr.length - 1; k++) {
            if (accArr[k] === 13 && accArr[k + 1] === 10) {
                return k;
            }
        }
        return -1;
    }
    // Merge all bodyParts into a single Uint8Array
    function merge() {
        var total = 0;
        for (var m = 0; m < bodyParts.length; m++) {
            total += bodyParts[m].length;
        }
        var out = new Uint8Array(total);
        var off = 0;
        for (var n = 0; n < bodyParts.length; n++) {
            out.set(bodyParts[n], off);
            off += bodyParts[n].length;
        }
        return out;
    }

    function processAccum() {
        // Parse as many complete chunks as possible from accArr
        var pos = 0;
        while (true) {
            var nlIdx = findCRLF(pos);
            if (nlIdx < 0) {
                break;
            }
            // Decode size line as ASCII
            var sizeStr = "";
            for (var si = pos; si < nlIdx; si++) {
                sizeStr += String.fromCharCode(accArr[si]);
            }
            sizeStr = sizeStr.trim();
            var semiIdx = sizeStr.indexOf(";");
            if (semiIdx >= 0) {
                sizeStr = sizeStr.substring(0, semiIdx).trim();
            }
            var chunkSize = parseInt(sizeStr, 16);
            if (isNaN(chunkSize)) {
                onDone(new Uint8Array(0), new TypeError("Invalid chunked encoding"));
                return;
            }
            if (chunkSize === 0) {
                onDone(merge(), null);
                return;
            } // terminal chunk
            var dataStart = nlIdx + 2;
            var dataEnd = dataStart + chunkSize;
            if (accArr.length < dataEnd + 2) {
                break;
            } // need more bytes
            bodyParts.push(accArr.subarray(dataStart, dataEnd));
            pos = dataEnd + 2; // skip trailing CRLF
        }
        // Compact: keep only unprocessed bytes
        if (pos > 0) {
            accArr = accArr.slice(pos);
        }
        if (signal && signal.aborted) {
            onDone(merge(), signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        var readFn = isTLS ? net.tlsReadBinaryNb : net.tcpReadBinaryNb;
        readFn(handle, 65536, function(ptr, len, isEOF) {
            if (len > 0) {
                appendBinary(ptr, len);
            } else if (ptr > 0) {
                __buf.free(ptr);
            }
            if (isEOF) {
                onDone(merge(), null);
                return;
            }
            processAccum();
        });
    }
    processAccum();
}
// _streamChunkedAccum — text-mode version kept for non-compressed chunked bodies
// (called from the uncompressed path which remains text-based)
function _streamChunkedAccum(handle, isTLS, signal, accum, onDone) {
    var body = "";

    function processAccum() {
        while (true) {
            var nlIdx = accum.indexOf(CRLF);
            if (nlIdx < 0) {
                break;
            }
            var sizeStr = accum.substring(0, nlIdx).trim();
            var semiIdx = sizeStr.indexOf(";");
            if (semiIdx >= 0) {
                sizeStr = sizeStr.substring(0, semiIdx).trim();
            }
            var chunkSize = parseInt(sizeStr, 16);
            if (isNaN(chunkSize)) {
                onDone("", new TypeError("Invalid chunked encoding"));
                return;
            }
            if (chunkSize === 0) {
                onDone(body, null);
                return;
            }
            var dataStart = nlIdx + 2;
            var dataEnd = dataStart + chunkSize;
            if (accum.length < dataEnd + 2) {
                break;
            }
            body = body + accum.substring(dataStart, dataEnd);
            accum = accum.substring(dataEnd + 2);
        }
        if (signal && signal.aborted) {
            onDone("", signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        var readFn = isTLS ? net.tlsReadNb : net.tcpReadNb;
        readFn(handle, 65536, function(chunk, isEOF) {
            if (chunk && chunk.length > 0) {
                accum = accum + chunk;
            }
            if (isEOF) {
                onDone(body, null);
                return;
            }
            processAccum();
        });
    }
    processAccum();
}
// One-shot Uint8Array decompress: copy bytes into C buffer, inflate, enqueue result.
function _decompressUint8ArrayAndEnqueue(arr, wbits, controller, onDone) {
    if (!arr || arr.length === 0) {
        onDone(null);
        return;
    }
    var n = arr.length;
    var ptr = __buf.alloc(n + 1);
    for (var i = 0; i < n; i++) {
        __buf.setByte(ptr, i, arr[i]);
    }
    var zh = __zlib.open(wbits);
    if (zh === 0) {
        __buf.free(ptr);
        onDone(null);
        return;
    }
    var out = __zlib.feed(zh, ptr, n);
    __zlib.close(zh);
    __buf.free(ptr);
    if (out && out.length > 0) {
        controller.enqueue(out);
    }
    onDone(null);
}
// _decompressStringAndEnqueue — thin wrapper kept for call-site compatibility;
// converts Latin-1 string to Uint8Array first (only safe if string has no NUL truncation).
function _decompressStringAndEnqueue(data, wbits, controller, onDone) {
    if (!data || data.length === 0) {
        onDone(null);
        return;
    }
    var arr2 = new Uint8Array(data.length);
    for (var i = 0; i < data.length; i++) {
        arr2[i] = data.charCodeAt(i) & 0xFF;
    }
    _decompressUint8ArrayAndEnqueue(arr2, wbits, controller, onDone);
}
// Build a streaming Response: parse headers from `accum`, return it immediately,
// then continue streaming body chunks into the ReadableStream controller.
// Build a streaming Response from a binary header read result.
// headerStr  — ASCII header block including trailing CRLFCRLF
// bodyPrefixArr — Uint8Array of body bytes already pulled from socket during
//                 header read (may contain binary data, never truncated by NUL)
function _buildStreamingResponse(handle, isTLS, headerStr, bodyPrefixArr, signal, hostname, port, onResponse) {
    if (!headerStr) {
        onResponse(null, _networkError("Connection closed before response headers were received", "ECONNRESET"));
        return;
    }
    var hp;
    try {
        hp = _parseHTTPResponse(headerStr);
    } catch (e) {
        onResponse(null, e);
        return;
    }
    // Create the ReadableStream and capture the controller reference
    var ctrl;
    var bodyStream = new ReadableStream({
        start: function(c) {
            ctrl = c;
        }
    });
    var response = new Response(bodyStream, {
        status: hp.status,
        statusText: hp.statusText,
        headers: hp.headers,
        url: ""
    });
    // Resolve the fetch Promise now — body arrives later
    onResponse(response, null);
    // Determine keep-alive so we can hand the socket back to the pool correctly
    var connHdr = hp.headers.get("connection");
    var serverClose = connHdr !== null && connHdr.toLowerCase().indexOf("close") >= 0;
    // Stream body asynchronously; release socket when body is done
    _asyncStreamBody(handle, isTLS, signal, hp, bodyPrefixArr, ctrl, function(err) {
        if (err) {
            ctrl.error(err);
        } else {
            ctrl.close();
        }
        if (hostname !== null) {
            _globalPool.release(hostname, port, isTLS, handle, serverClose);
        }
    });
}
// Abort is handled event-based: registers an "abort" listener so that even
// long-delay responses (where no tcpReadNb callback fires for seconds) abort
// immediately when AbortSignal.timeout(ms) fires.
// Phase 6.10: tries pool first, returns socket to pool on keep-alive.
function _fetchOneHTTPAsync(hostname, port, rawReq, signal, done) {
    // once-guard so abort listener and read completion never both call done()
    var _fired = false;
    var _sockHandle = 0;
    var _abortListener = null;
    var _reused = false;

    function _finish(buf, err) {
        if (_fired) {
            return;
        }
        _fired = true;
        if (_abortListener && signal) {
            signal.removeEventListener("abort", _abortListener);
        }
        if (err) {
            // On error, close the socket — don't return to pool
            if (_sockHandle !== 0) {
                net.tcpClose(_sockHandle);
                _sockHandle = 0;
            }
            if (_reused) {
                _globalPool.release(hostname, port, false, 0, true);
            } else if (_sockHandle === 0) {
                /* already closed */ }
            done(null, err);
            return;
        }
        // Determine if server wants keep-alive
        var serverClose = false;
        if (buf) {
            var lcBuf = buf.toLowerCase();
            if (lcBuf.indexOf("connection: close") >= 0) {
                serverClose = true;
            }
        }
        var h = _sockHandle;
        _sockHandle = 0;
        _globalPool.release(hostname, port, false, h, serverClose);
        done(buf, null);
    }
    // Wire abort event listener BEFORE issuing the connect
    if (signal) {
        _abortListener = function() {
            _finish(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        };
        signal.addEventListener("abort", _abortListener);
    }
    // Pre-abort fast path
    if (signal && signal.aborted) {
        if (_abortListener) {
            signal.removeEventListener("abort", _abortListener);
        }
        done(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }
    // Try pool first
    var pooled = _globalPool.acquire(hostname, port, false);
    if (pooled !== 0) {
        _sockHandle = pooled;
        _reused = true;
        net.tcpWrite(pooled, rawReq);
        _asyncReadLoop(pooled, "", signal, function(rawBuf, abortErr) {
            if (abortErr) {
                _finish(null, abortErr);
                return;
            }
            _finish(rawBuf, null);
        }, false);
        return;
    }
    // No pooled socket — create new connection
    _globalPool.trackActive(hostname, port, false);
    net.tcpConnectNb(hostname, port, function(handle, errCode) {
        if (_fired) {
            // Abort already fired between connect start and callback
            if (errCode === 0 && handle !== 0) {
                net.tcpClose(handle);
            }
            return;
        }
        _sockHandle = handle;
        if (errCode !== 0 || handle === 0) {
            _finish(null, _networkError("Failed to connect to " + hostname + ":" + String(port), "ECONNREFUSED"));
            return;
        }
        if (signal && signal.aborted) {
            _finish(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        // Synchronous write — kernel buffers the request immediately
        net.tcpWrite(handle, rawReq);
        _asyncReadLoop(handle, "", signal, function(rawBuf, abortErr) {
            if (abortErr) {
                _finish(null, abortErr);
                return;
            }
            _finish(rawBuf, null);
        }, false); // isTLS = false
    });
}
// Async single HTTPS hop: non-blocking TCP connect → blocking TLS handshake
// → sync TLS write → async TLS read.  Same abort/once-guard pattern as HTTP.
// Phase 6.10: tries pool first, returns socket to pool on keep-alive.
function _fetchOneHTTPSAsync(hostname, port, rawReq, signal, done) {
    var _fired = false;
    var _sockHandle = 0;
    var _abortListener = null;
    var _reused = false;

    function _finish(buf, err) {
        if (_fired) {
            return;
        }
        _fired = true;
        if (_abortListener && signal) {
            signal.removeEventListener("abort", _abortListener);
        }
        if (err) {
            if (_sockHandle !== 0) {
                net.tlsClose(_sockHandle);
                _sockHandle = 0;
            }
            if (_reused) {
                _globalPool.release(hostname, port, true, 0, true);
            }
            done(null, err);
            return;
        }
        var serverClose = false;
        if (buf) {
            var lcBuf = buf.toLowerCase();
            if (lcBuf.indexOf("connection: close") >= 0) {
                serverClose = true;
            }
        }
        var h = _sockHandle;
        _sockHandle = 0;
        _globalPool.release(hostname, port, true, h, serverClose);
        done(buf, null);
    }
    if (signal) {
        _abortListener = function() {
            _finish(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        };
        signal.addEventListener("abort", _abortListener);
    }
    if (signal && signal.aborted) {
        if (_abortListener) {
            signal.removeEventListener("abort", _abortListener);
        }
        done(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }
    // Try pool first
    var pooled = _globalPool.acquire(hostname, port, true);
    if (pooled !== 0) {
        _sockHandle = pooled;
        _reused = true;
        net.tlsWrite(pooled, rawReq);
        _asyncReadLoop(pooled, "", signal, function(rawBuf, abortErr) {
            if (abortErr) {
                _finish(null, abortErr);
                return;
            }
            _finish(rawBuf, null);
        }, true);
        return;
    }
    // No pooled socket — create new connection
    _globalPool.trackActive(hostname, port, true);
    net.tlsConnectNb(hostname, port, function(handle, errCode) {
        if (_fired) {
            if (errCode === 0 && handle !== 0) {
                net.tlsClose(handle);
            }
            return;
        }
        _sockHandle = handle;
        if (errCode !== 0 || handle === 0) {
            _finish(null, _networkError("Failed to connect (TLS) to " + hostname + ":" + String(port), "ERR_TLS_CERT_ALTNAME_INVALID"));
            return;
        }
        if (signal && signal.aborted) {
            _finish(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        // Synchronous TLS write — OpenSSL + kernel buffer the request
        net.tlsWrite(handle, rawReq);
        _asyncReadLoop(handle, "", signal, function(rawBuf, abortErr) {
            if (abortErr) {
                _finish(null, abortErr);
                return;
            }
            _finish(rawBuf, null);
        }, true); // isTLS = true
    });
}
// Handle a received Response: redirect or resolve/reject.
function _handleFetchResponse(response, currentUrl, method, headers, body, request, resolve, reject, redirectCount, redirected) {
    var isRedirect = (response.status === 301 || response.status === 302 || response.status === 303 || response.status === 307 || response.status === 308);
    if (isRedirect && request.redirect === "follow") {
        var location = response.headers.get("location");
        if (location === null) {
            resolve(response);
            return;
        }
        var parsed2;
        try {
            parsed2 = new URL(currentUrl);
        } catch (e) {
            resolve(response);
            return;
        }
        if (location.indexOf("://") < 0) {
            var base = parsed2.protocol + "//" + parsed2.hostname + (parsed2.port ? ":" + parsed2.port : "");
            location = (location[0] === "/") ? base + location : base + "/" + location;
        }
        var nextMethod = method;
        var nextBody = body;
        if (response.status === 303 || ((response.status === 301 || response.status === 302) && method !== "GET" && method !== "HEAD")) {
            nextMethod = "GET";
            nextBody = null;
        }
        _fetchFollow(location, nextMethod, new Headers(headers), nextBody, request, resolve, reject, redirectCount + 1, true);
        return;
    }
    if (request.redirect === "error" && response.status >= 300 && response.status < 400) {
        reject(new TypeError("Redirect not allowed (redirect: 'error')"));
        return;
    }
    response.redirected = redirected;
    response.url = currentUrl;
    resolve(response);
}
// ─── Phase G — HTTP/2 fetch transport (ALPN-negotiated) ──────────────────
// Called after a new TLS connection negotiates "h2" via ALPN.
// Creates an nghttp2 client session, submits the request, accumulates the
// response body, and calls done(response, null) on stream close.
// Uses the same net.* bridge functions as http2.js (h2SessionCreateClient,
// h2Request, h2SessionSend, h2GetSendPtr, h2SessionRecv, h2PopEvent, etc.).
function _doH2FetchAsync(hostname, port, h2Method, h2Path, h2ReqHdrs, tlsHandle, signal, done) {
    // 1. Create nghttp2 client session
    var h2Handle = net.h2SessionCreateClient();
    if (h2Handle < 0) {
        done(null, _networkError("Failed to create HTTP/2 session", "ERR_HTTP2_ERROR"));
        return;
    }

    // Helper: flush all pending nghttp2 output to the TLS socket
    function _h2FlushLocal() {
        while (true) {
            var n = net.h2SessionSend(h2Handle);
            if (n <= 0) { break; }
            var sptr = net.h2GetSendPtr(h2Handle);
            if (!sptr || sptr === 0) { break; }
            var raw = "";
            for (var si = 0; si < n; si++) {
                raw += String.fromCharCode(__buf.getByte(sptr, si));
            }
            net.tlsWrite(tlsHandle, raw);
        }
    }

    // 2. Build flat header array (pseudo-headers first, then regular headers)
    var authority = hostname;
    if (port !== 443) { authority = hostname + ":" + String(port); }
    var hdrsArr = [
        ":method",    h2Method || "GET",
        ":path",      h2Path   || "/",
        ":scheme",    "https",
        ":authority", authority
    ];
    if (h2ReqHdrs && h2ReqHdrs._entries) {
        var ent = h2ReqHdrs._entries;
        for (var ei = 0; ei < ent.length; ei++) {
            var hk = ent[ei][0];
            // Skip headers that must not appear in h2 (hop-by-hop and :authority-replacing)
            if (hk === "host" || hk === "connection" || hk === "transfer-encoding" ||
                hk === "keep-alive" || hk === "upgrade") {
                continue;
            }
            hdrsArr.push(hk);
            hdrsArr.push(ent[ei][1]);
        }
    }

    // 3. Submit request (endStream=true — body not yet supported in this path)
    var streamId = net.h2Request(h2Handle, hdrsArr);

    // 4. Flush client connection preface + HEADERS frame
    _h2FlushLocal();

    // 5. Accumulate response headers and body chunks
    var respStatus  = 200;
    var respHeaders = {};
    var bodyChunks  = [];
    var streamDone  = false;

    // H2_EV_* constants must match http2_bridge.na.jac
    var _H2_EV_HEADER       = 2;
    var _H2_EV_DATA_CHUNK   = 3;
    var _H2_EV_STREAM_CLOSE = 4;
    var _H2_EV_FRAME_RECV   = 5;
    var _FLAG_END_STREAM    = 0x01;

    function _h2DrainLocal() {
        while (true) {
            var ev = net.h2PopEvent(h2Handle);
            if (!ev) { break; }
            var etype = ev.type;
            var sid   = ev.d0;

            if (etype === _H2_EV_HEADER && sid === streamId) {
                // name/value are heap-allocated copies — must free after reading
                var namePtr = ev.d1; var nameLen = ev.d2;
                var valPtr  = ev.d3; var valLen  = ev.d4;
                var hname = "";
                for (var ni = 0; ni < nameLen; ni++) {
                    hname += String.fromCharCode(__buf.getByte(namePtr, ni));
                }
                var hval = "";
                for (var vi = 0; vi < valLen; vi++) {
                    hval += String.fromCharCode(__buf.getByte(valPtr, vi));
                }
                __buf.free(namePtr);
                __buf.free(valPtr);
                if (hname === ":status") {
                    respStatus = parseInt(hval) || 200;
                } else {
                    respHeaders[hname] = hval;
                }

            } else if (etype === _H2_EV_DATA_CHUNK && sid === streamId) {
                var dataPtr = ev.d2; var dataLen = ev.d3;
                var chunk = "";
                for (var di = 0; di < dataLen; di++) {
                    chunk += String.fromCharCode(__buf.getByte(dataPtr, di));
                }
                __buf.free(dataPtr);
                bodyChunks.push(chunk);
                net.h2Consume(h2Handle, streamId, dataLen);

            } else if (etype === _H2_EV_STREAM_CLOSE && sid === streamId) {
                streamDone = true;

            } else if (etype === _H2_EV_FRAME_RECV) {
                if (sid === streamId && (ev.d2 & _FLAG_END_STREAM)) {
                    streamDone = true;
                }
            }
        }
    }

    function _h2ReadLoop() {
        if (streamDone) {
            // Stream closed — build and return the fetch Response
            net.h2SessionDel(h2Handle);
            _globalPool.release(hostname, port, true, tlsHandle, false);
            var hdrsObj = new Headers(respHeaders);
            var respText = bodyChunks.join("");
            var resp = new Response(respText, { status: respStatus, headers: hdrsObj });
            done(resp, null);
            return;
        }

        net.tlsReadBinaryNb(tlsHandle, 65536, function(ptr, len, isEOF) {
            if (len > 0) {
                net.h2SessionRecv(h2Handle, ptr, len);
                __buf.free(ptr);
                _h2FlushLocal();   // flush SETTINGS ACK, WINDOW_UPDATE, etc.
                _h2DrainLocal();
            } else if (ptr && ptr !== 0) {
                __buf.free(ptr);
            }

            if (isEOF || streamDone) {
                net.h2SessionDel(h2Handle);
                _globalPool.release(hostname, port, true, tlsHandle, false);
                var hdrsObj2 = new Headers(respHeaders);
                var respText2 = bodyChunks.join("");
                var resp2 = new Response(respText2, { status: respStatus, headers: hdrsObj2 });
                done(resp2, null);
                return;
            }
            _h2ReadLoop();
        });
    }

    _h2ReadLoop();
}

// ─── Phase 6.11 — Streaming async HTTP hop ────────────────────────────────
// done(response, err) — called as soon as headers are parsed.
// Body is streamed asynchronously into response.body (ReadableStream).
function _fetchOneHTTPStreamAsync(hostname, port, rawReq, signal, done) {
    var _fired = false;
    var _sockHandle = 0;
    var _abortListener = null;
    var _reused = false;

    function _abortNow(err) {
        if (_fired) {
            return;
        }
        _fired = true;
        if (_abortListener && signal) {
            signal.removeEventListener("abort", _abortListener);
        }
        if (_sockHandle !== 0) {
            net.tcpClose(_sockHandle);
            _sockHandle = 0;
        }
        if (_reused) {
            _globalPool.release(hostname, port, false, 0, true);
        }
        done(null, err);
    }
    if (signal) {
        _abortListener = function() {
            _abortNow(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        };
        signal.addEventListener("abort", _abortListener);
    }
    if (signal && signal.aborted) {
        if (_abortListener) {
            signal.removeEventListener("abort", _abortListener);
        }
        done(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }

    function _startStream(handle) {
        _asyncReadHeadersBinary(handle, false, signal, new Uint8Array(0), function(headerStr, bodyPrefixArr, isEOF) {
            if (_fired) {
                net.tcpClose(handle);
                return;
            }
            _fired = true;
            if (_abortListener && signal) {
                signal.removeEventListener("abort", _abortListener);
            }
            if (isEOF) {
                done(null, _networkError("Connection closed before headers completed", "ECONNRESET"));
                return;
            }
            _buildStreamingResponse(handle, false, headerStr, bodyPrefixArr, signal, hostname, port, done);
        });
    }
    var pooled = _globalPool.acquire(hostname, port, false);
    if (pooled !== 0) {
        _sockHandle = pooled;
        _reused = true;
        net.tcpWrite(pooled, rawReq);
        _startStream(pooled);
        return;
    }
    _globalPool.trackActive(hostname, port, false);
    net.tcpConnectNb(hostname, port, function(handle, errCode) {
        if (_fired) {
            if (errCode === 0 && handle !== 0) {
                net.tcpClose(handle);
            }
            return;
        }
        _sockHandle = handle;
        if (errCode !== 0 || handle === 0) {
            _abortNow(_networkError("Failed to connect to " + hostname + ":" + String(port), "ECONNREFUSED"));
            return;
        }
        if (signal && signal.aborted) {
            _abortNow(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        net.tcpWrite(handle, rawReq);
        _startStream(handle);
    });
}

// h2Method / h2Path / h2ReqHdrs are optional — supplied by _fetchFollow when
// isTLS=true so that a Phase G ALPN "h2" response can be handled natively.
function _fetchOneHTTPSStreamAsync(hostname, port, rawReq, signal, done, h2Method, h2Path, h2ReqHdrs) {
    var _fired = false;
    var _sockHandle = 0;
    var _abortListener = null;
    var _reused = false;

    function _abortNow(err) {
        if (_fired) {
            return;
        }
        _fired = true;
        if (_abortListener && signal) {
            signal.removeEventListener("abort", _abortListener);
        }
        if (_sockHandle !== 0) {
            net.tlsClose(_sockHandle);
            _sockHandle = 0;
        }
        if (_reused) {
            _globalPool.release(hostname, port, true, 0, true);
        }
        done(null, err);
    }
    if (signal) {
        _abortListener = function() {
            _abortNow(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        };
        signal.addEventListener("abort", _abortListener);
    }
    if (signal && signal.aborted) {
        if (_abortListener) {
            signal.removeEventListener("abort", _abortListener);
        }
        done(null, signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }

    function _startStream(handle) {
        _asyncReadHeadersBinary(handle, true, signal, new Uint8Array(0), function(headerStr, bodyPrefixArr, isEOF) {
            if (_fired) {
                net.tlsClose(handle);
                return;
            }
            _fired = true;
            if (_abortListener && signal) {
                signal.removeEventListener("abort", _abortListener);
            }
            if (isEOF) {
                done(null, _networkError("Connection closed before headers completed (TLS)", "ECONNRESET"));
                return;
            }
            _buildStreamingResponse(handle, true, headerStr, bodyPrefixArr, signal, hostname, port, done);
        });
    }
    var pooled = _globalPool.acquire(hostname, port, true);
    if (pooled !== 0) {
        _sockHandle = pooled;
        _reused = true;
        net.tlsWrite(pooled, rawReq);
        _startStream(pooled);
        return;
    }
    _globalPool.trackActive(hostname, port, true);
    // Pass ALPN "h2,http/1.1" so servers that support HTTP/2 can negotiate it.
    // args: (host, port, callback, rejectUnauthorized=true, alpn)
    net.tlsConnectNb(hostname, port, function(handle, errCode) {
        if (_fired) {
            if (errCode === 0 && handle !== 0) {
                net.tlsClose(handle);
            }
            return;
        }
        _sockHandle = handle;
        if (errCode !== 0 || handle === 0) {
            _abortNow(_networkError("Failed to connect (TLS) to " + hostname + ":" + String(port), "ERR_TLS_CERT_ALTNAME_INVALID"));
            return;
        }
        if (signal && signal.aborted) {
            _abortNow(signal.reason || new DOMException("The operation was aborted.", "AbortError"));
            return;
        }
        // Phase G: check ALPN and route to HTTP/2 if negotiated
        if (h2Method && h2Path && h2ReqHdrs) {
            var alpnProto = net.tlsGetAlpn ? net.tlsGetAlpn(handle) : "";
            if (alpnProto === "h2") {
                _fired = true;  // prevent duplicate callbacks
                if (_abortListener && signal) { signal.removeEventListener("abort", _abortListener); }
                _doH2FetchAsync(hostname, port, h2Method, h2Path, h2ReqHdrs, handle, signal, done);
                return;
            }
        }
        // HTTP/1.1 path (server did not negotiate h2, or h2 params not provided)
        net.tlsWrite(handle, rawReq);
        _startStream(handle);
    }, true, "h2,http/1.1");
}
// ─── Phase 6.12 — Sync decompression fetch helper ──────────────────────────
// Uses a blocking connection + native binary-safe response reader for
// compressed (gzip/deflate) response bodies.  This avoids the null-byte
// truncation that Jac native str causes on raw compressed bytes.
function _fetchSyncDecompress(parsed, port, isTLS, request, currentUrl, method, headers, body, resolve, reject, redirectCount, redirected) {
    try {
        // Sync connect
        var handle;
        if (isTLS) {
            handle = net.tlsConnect(parsed.hostname, port);
        } else {
            handle = net.tcpConnect(parsed.hostname, port);
        }
        if (handle === 0) {
            reject(_networkError("Failed to connect to " + parsed.hostname + ":" + String(port), "ECONNREFUSED"));
            return;
        }
        // Build request with Accept-Encoding
        var reqHdrs = new Headers(headers);
        if (!reqHdrs.has("accept-encoding")) {
            reqHdrs.set("Accept-Encoding", "gzip, deflate");
        }
        var rawReq = _buildRawRequest(parsed, method, reqHdrs, body, false);
        // Sync write
        if (isTLS) {
            net.tlsWrite(handle, rawReq);
        } else {
            net.tcpWrite(handle, rawReq);
        }
        // Native binary-safe response reader (reads headers + body, decompresses)
        var result = net.readHTTPResponse(handle, 10485760, 1);
        // Close connection (no keep-alive for sync decompression path)
        if (isTLS) {
            net.tlsClose(handle);
        } else {
            net.tcpClose(handle);
        }
        if (result === undefined || result === null) {
            reject(_networkError("Failed to read response from " + currentUrl, "ECONNRESET"));
            return;
        }
        // Parse headers from the raw header block
        var hp = _parseHTTPResponse(result.headers);
        if (!hp) {
            reject(new TypeError("Failed to parse response headers"));
            return;
        }
        // Remove compression headers (body is already decompressed)
        hp.headers.delete("content-encoding");
        hp.headers.delete("content-length");
        var response = new Response(result.body, {
            status: hp.status,
            statusText: hp.statusText,
            headers: hp.headers,
            url: currentUrl
        });
        _handleFetchResponse(response, currentUrl, method, headers, body, request, resolve, reject, redirectCount, redirected);
    } catch (e) {
        reject(e);
    }
}
// Internal: fetch one URL, following redirects asynchronously.
// Phase 6.11: uses streaming fetch functions — response.body is a ReadableStream.
// Phase 6.12: when decompress option is explicitly true, uses sync binary-safe
//             path for gzip/deflate decompression.  Default is async streaming.
//             Note: decompress:true uses blocking I/O — only safe for external servers,
//             not for same-process servers (would deadlock the event loop).
// ─── Phase 6.14: HTTP_PROXY / HTTPS_PROXY / NO_PROXY support ───────────
function _getProxyForUrl(parsed) {
    // Check NO_PROXY first
    var noProxy = "";
    if (typeof process !== "undefined" && process.env) {
        noProxy = process.env.NO_PROXY || process.env.no_proxy || "";
    }
    if (noProxy === "*") {
        return null;
    }
    if (noProxy) {
        var entries = noProxy.split(",");
        var host = parsed.hostname.toLowerCase();
        var i = 0;
        while (i < entries.length) {
            var pat = entries[i].trim().toLowerCase();
            if (pat.length > 0) {
                // Strip leading dot for suffix match
                if (pat.charAt(0) === ".") {
                    pat = pat.substring(1);
                }
                if (host === pat || host.endsWith("." + pat)) {
                    return null;
                }
            }
            i = i + 1;
        }
    }
    var isTLS = (parsed.protocol === "https:");
    var proxyUrl = "";
    if (typeof process !== "undefined" && process.env) {
        if (isTLS) {
            proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy || "";
        } else {
            proxyUrl = process.env.HTTP_PROXY || process.env.http_proxy || "";
        }
    }
    if (!proxyUrl) {
        return null;
    }
    try {
        return new URL(proxyUrl);
    } catch (e) {
        return null;
    }
}
// HTTP CONNECT tunnel for HTTPS through an HTTP proxy
function _fetchViaProxy(proxyParsed, targetParsed, targetPort, isTLS, rawReq, signal, done) {
    var proxyPort = proxyParsed.port ? parseInt(proxyParsed.port, 10) : 80;
    if (!isTLS) {
        // Plain HTTP proxy: send absolute-form request to proxy
        _fetchOneHTTPStreamAsync(proxyParsed.hostname, proxyPort, rawReq, signal, done);
        return;
    }
    // HTTPS: establish CONNECT tunnel, then TLS-upgrade
    net.tcpConnectNb(proxyParsed.hostname, proxyPort, function(handle, errCode) {
        if (errCode !== 0 || handle === 0) {
            done(null, _networkError("Failed to connect to proxy " + proxyParsed.hostname + ":" + String(proxyPort), "ECONNREFUSED"));
            return;
        }
        var connectReq = "CONNECT " + targetParsed.hostname + ":" + String(targetPort) + " HTTP/1.1" + CRLF + "Host: " + targetParsed.hostname + ":" + String(targetPort) + CRLF + CRLF;
        net.tcpWrite(handle, connectReq);
        // Read CONNECT response
        _asyncReadLoop(handle, "", signal, function(rawResp, abortErr) {
            if (abortErr) {
                net.tcpClose(handle);
                done(null, abortErr);
                return;
            }
            if (!rawResp || rawResp.indexOf("200") < 0) {
                net.tcpClose(handle);
                done(null, new TypeError("Proxy CONNECT failed"));
                return;
            }
            // Upgrade to TLS on the tunneled socket
            // NOTE: net.tlsUpgrade may not exist yet — returns 0 if unavailable
            var tlsHandle = 0;
            if (net.tlsUpgrade) {
                tlsHandle = net.tlsUpgrade(handle, targetParsed.hostname);
            }
            if (tlsHandle === 0) {
                net.tcpClose(handle);
                done(null, new TypeError("TLS handshake via proxy failed"));
                return;
            }
            // Send the original request through the TLS tunnel
            net.tlsWrite(tlsHandle, rawReq);
            _asyncReadHeadersBinary(tlsHandle, true, signal, new Uint8Array(0), function(headerStr, bodyPrefixArr, isEOF) {
                if (isEOF) {
                    net.tlsClose(tlsHandle);
                    done(null, _networkError("Connection closed before headers", "ECONNRESET"));
                    return;
                }
                _buildStreamingResponse(tlsHandle, true, headerStr, bodyPrefixArr, signal, targetParsed.hostname, targetPort, done);
            });
        }, false);
    });
}

function _fetchFollow(currentUrl, method, headers, body, request, resolve, reject, redirectCount, redirected) {
    if (redirectCount > 20) {
        reject(new TypeError("Too many redirects"));
        return;
    }
    var parsed;
    try {
        parsed = new URL(currentUrl);
    } catch (e) {
        reject(new TypeError("Invalid URL: " + currentUrl));
        return;
    }
    var isTLS = (parsed.protocol === "https:");
    var port = parsed.port ? parseInt(parsed.port, 10) : (isTLS ? 443 : 80);
    if (request.signal && request.signal.aborted) {
        reject(request.signal.reason || new DOMException("The operation was aborted.", "AbortError"));
        return;
    }
    // Phase 6.12: explicit decompress:true uses sync binary-safe path
    if (request._decompress === true) {
        _fetchSyncDecompress(parsed, port, isTLS, request, currentUrl, method, headers, body, resolve, reject, redirectCount, redirected);
        return;
    }
    // Default async streaming path — send Accept-Encoding unless caller set it
    var aHdrs = new Headers(headers);
    if (!aHdrs.has("accept-encoding")) {
        aHdrs.set("Accept-Encoding", "gzip, deflate");
    }
    // Phase 6.14: proxy support
    var proxyParsed = _getProxyForUrl(parsed);
    if (proxyParsed) {
        var rawReqProxy;
        if (isTLS) {
            // For HTTPS through proxy, request is to the origin server (CONNECT handles tunneling)
            rawReqProxy = _buildRawRequest(parsed, method, aHdrs, body, _globalPool.keepAlive);
        } else {
            // For HTTP proxy, use absolute-form URL in request line
            rawReqProxy = method + " " + currentUrl + " HTTP/1.1" + CRLF + "Host: " + parsed.hostname + (port !== 80 ? ":" + String(port) : "") + CRLF + aHdrs._toRaw() + CRLF;
            if (body) {
                rawReqProxy = rawReqProxy + body;
            }
        }
        _fetchViaProxy(proxyParsed, parsed, port, isTLS, rawReqProxy, request.signal, function(resp, err) {
            if (err) {
                reject(err);
                return;
            }
            resp.url = currentUrl;
            _handleFetchResponse(resp, currentUrl, method, headers, body, request, resolve, reject, redirectCount, redirected);
        });
        return;
    }
    if (isTLS) {
        var rawReqTLS = _buildRawRequest(parsed, method, aHdrs, body, _globalPool.keepAlive);
        // Phase G: pass h2 params so the function can auto-upgrade to HTTP/2 if ALPN negotiates "h2"
        var h2UrlPath = (parsed.pathname || "/") + (parsed.search || "");
        _fetchOneHTTPSStreamAsync(parsed.hostname, port, rawReqTLS, request.signal, function(resp, err) {
            if (err) {
                reject(err);
                return;
            }
            resp.url = currentUrl;
            _handleFetchResponse(resp, currentUrl, method, headers, body, request, resolve, reject, redirectCount, redirected);
        }, method, h2UrlPath, aHdrs);
    } else {
        var rawReq2 = _buildRawRequest(parsed, method, aHdrs, body, _globalPool.keepAlive);
        _fetchOneHTTPStreamAsync(parsed.hostname, port, rawReq2, request.signal, function(resp, err) {
            if (err) {
                reject(err);
                return;
            }
            resp.url = currentUrl;
            _handleFetchResponse(resp, currentUrl, method, headers, body, request, resolve, reject, redirectCount, redirected);
        });
    }
}
// The fetch() global — Node.js ≥18 / WHATWG Fetch API
// ── Default fetch timeout ─────────────────────────────────────────────────
// Prevents infinite hangs when a server accepts the connection but never
// responds. Default: 30 s. Override: globalThis.fetchTimeout = <ms>
// Set to 0 to disable.
var _FETCH_DEFAULT_TIMEOUT_MS = 30000;

function _getFetchTimeout() {
    if (typeof globalThis.fetchTimeout === "number") {
        return globalThis.fetchTimeout;
    }
    return _FETCH_DEFAULT_TIMEOUT_MS;
}
// ── Structured network errors ─────────────────────────────────────────────
// WHATWG Fetch network errors are TypeErrors; we attach a `.code` for
// Node.js compatibility so `err.code === "ECONNREFUSED"` etc. work.
function _networkError(msg, code) {
    var e = new TypeError(msg);
    if (code) {
        e.code = code;
    }
    return e;
}

function fetch(input, init) {
    var request;
    if (input instanceof Request) {
        request = init ? new Request(input, init) : input;
    } else {
        request = new Request(input, init);
    }
    if (request.signal && request.signal.aborted) {
        return Promise.reject(request.signal.reason || new DOMException("The operation was aborted.", "AbortError"));
    }
    // Default timeout: if no signal provided, auto-apply one to prevent infinite hangs.
    var timeoutMs = _getFetchTimeout();
    if (timeoutMs > 0 && !request.signal) {
        request.signal = AbortSignal.timeout(timeoutMs);
    }
    // Phase 6.11: if request body is a ReadableStream, drain it first before sending
    var reqBody = request.body;
    if (reqBody instanceof ReadableStream) {
        return _drainStream(reqBody).then(function(bodyStr) {
            request.body = bodyStr;
            return new Promise(function(resolve, reject) {
                _fetchFollow(request.url, request.method, new Headers(request.headers), bodyStr, request, resolve, reject, 0, false);
            });
        });
    }
    return new Promise(function(resolve, reject) {
        _fetchFollow(request.url, request.method, new Headers(request.headers), request.body, request, resolve, reject, 0, false);
    });
}
// ═══════════════════════════════════════════════════════════════════════════
//  Blob  (Node.js ≥15.7 / Web API)
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Blob — immutable raw-data object.
 *
 * new Blob(blobParts?, options?)
 *   blobParts — array of string | ArrayBuffer | TypedArray | Blob
 *   options.type — MIME-type string (default "")
 *   options.endings — "transparent" | "native" (ignored; we always use "transparent")
 */
class Blob {
    constructor(blobParts, options) {
        options = options || {};
        this.type = (options.type !== undefined ? String(options.type) : "").toLowerCase();
        // Normalise: if type contains bytes outside U+0020–U+007E, clear it (spec §4.1).
        // Use charCode loop instead of regex to avoid null-termination issues with \x00.
        var _valid_type = true;
        var _ti = 0;
        while (_ti < this.type.length) {
            var _tc = this.type.charCodeAt(_ti);
            if (_tc < 0x20 || _tc > 0x7E) {
                _valid_type = false;
                break;
            }
            _ti = _ti + 1;
        }
        if (!_valid_type) {
            this.type = "";
        }
        // Flatten all parts into a single string (byte-by-byte)
        var data = "";
        if (blobParts && typeof blobParts === "object" && typeof blobParts.length === "number") {
            var i = 0;
            while (i < blobParts.length) {
                var part = blobParts[i];
                if (part instanceof Blob) {
                    data = data + part._data;
                } else if (typeof part === "string") {
                    data = data + part;
                } else if (part && typeof part === "object") {
                    // ArrayBuffer or TypedArray — convert via byte values
                    var buf = null;
                    if (typeof ArrayBuffer !== "undefined" && part instanceof ArrayBuffer) {
                        buf = new Uint8Array(part);
                    } else if (typeof part.buffer !== "undefined") {
                        buf = new Uint8Array(part.buffer, part.byteOffset || 0, part.byteLength);
                    }
                    if (buf) {
                        var j = 0;
                        while (j < buf.length) {
                            data = data + String.fromCharCode(buf[j]);
                            j = j + 1;
                        }
                    }
                }
                i = i + 1;
            }
        }
        this._data = data;
        this.size = data.length;
    }
    text() {
        var self = this;
        return Promise.resolve(self._data);
    }
    arrayBuffer() {
        var self = this;
        var len = self._data.length;
        var ab = new ArrayBuffer(len);
        var u8 = new Uint8Array(ab);
        var i = 0;
        while (i < len) {
            u8[i] = self._data.charCodeAt(i) & 0xFF;
            i = i + 1;
        }
        return Promise.resolve(ab);
    }
    bytes() {
        var self = this;
        var len = self._data.length;
        var u8 = new Uint8Array(len);
        var i = 0;
        while (i < len) {
            u8[i] = self._data.charCodeAt(i) & 0xFF;
            i = i + 1;
        }
        return Promise.resolve(u8);
    }
    slice(start, end, contentType) {
        var len = this._data.length;
        start = start === undefined ? 0 : (start < 0 ? Math.max(len + start, 0) : Math.min(start, len));
        end = end === undefined ? len : (end < 0 ? Math.max(len + end, 0) : Math.min(end, len));
        if (end < start) {
            end = start;
        }
        var slicedData = this._data.substring(start, end);
        var b = new Blob([slicedData], {
            type: contentType !== undefined ? contentType : this.type
        });
        return b;
    }
    stream() {
        var self = this;
        return new ReadableStream({
            start: function(ctrl) {
                ctrl.enqueue(self._data);
                ctrl.close();
            }
        });
    }
    get[Symbol.toStringTag]() {
        return "Blob";
    }
} // class Blob
// ═══════════════════════════════════════════════════════════════════════════
//  FormData  (WHATWG / Node.js ≥18)
// ═══════════════════════════════════════════════════════════════════════════
/**
 * FormData — multipart/form-data container.
 * Supports append, get, getAll, has, delete, set, entries, keys, values,
 * forEach and Symbol.iterator.  Blob/File values are accepted (stored as-is).
 */
class FormData {
    constructor() {
        // Ordered list of [name, value] pairs (spec §6.1)
        this._entries = [];
    }
    append(name, value, filename) {
        name = String(name);
        // If value is a Blob/File, attach filename
        if (value instanceof Blob) {
            var entry = {
                name: name,
                value: value,
                filename: filename !== undefined ? String(filename) : "blob"
            };
            this._entries.push(entry);
        } else {
            this._entries.push({
                name: name,
                value: String(value),
                filename: undefined
            });
        }
    }
    set(name, value, filename) {
        name = String(name);
        // Remove all existing entries with this name, then append
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i].name === name) {
                this._entries.splice(i, 1);
            } else {
                i = i + 1;
            }
        }
        this.append(name, value, filename);
    }
    get(name) {
        name = String(name);
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i].name === name) {
                return this._entries[i].value;
            }
            i = i + 1;
        }
        return null;
    }
    getAll(name) {
        name = String(name);
        var result = [];
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i].name === name) {
                result.push(this._entries[i].value);
            }
            i = i + 1;
        }
        return result;
    }
    has(name) {
        name = String(name);
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i].name === name) {
                return true;
            }
            i = i + 1;
        }
        return false;
    }
    delete(name) {
        name = String(name);
        var i = 0;
        while (i < this._entries.length) {
            if (this._entries[i].name === name) {
                this._entries.splice(i, 1);
            } else {
                i = i + 1;
            }
        }
    }
    forEach(cb, thisArg) {
        var i = 0;
        while (i < this._entries.length) {
            var e = this._entries[i];
            cb.call(thisArg, e.value, e.name, this);
            i = i + 1;
        }
    }
    entries() {
        var arr = [];
        var i = 0;
        while (i < this._entries.length) {
            arr.push([this._entries[i].name, this._entries[i].value]);
            i = i + 1;
        }
        return arr;
    }
    keys() {
        var arr = [];
        var i = 0;
        while (i < this._entries.length) {
            arr.push(this._entries[i].name);
            i = i + 1;
        }
        return arr;
    }
    values() {
            var arr = [];
            var i = 0;
            while (i < this._entries.length) {
                arr.push(this._entries[i].value);
                i = i + 1;
            }
            return arr;
        }
        [Symbol.iterator]() {
            // Return a proper iterator (object with .next()) so for...of works on
            // FormData instances directly.  entries() returns an array; we wrap it.
            var arr = this.entries();
            var _idx = 0;
            return {
                next: function() {
                    if (_idx >= arr.length) {
                        return {
                            value: undefined,
                            done: true
                        };
                    }
                    var v = arr[_idx];
                    _idx = _idx + 1;
                    return {
                        value: v,
                        done: false
                    };
                }
            };
        }
    get[Symbol.toStringTag]() {
        return "FormData";
    }
} // class FormData
// ── FormData body encoding ────────────────────────────────────────────────
var _FORM_BOUNDARY_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

function _randomBoundary() {
    var s = "----FormBoundary";
    var i = 0;
    while (i < 16) {
        s = s + _FORM_BOUNDARY_CHARS[Math.floor(Math.random() * 62)];
        i = i + 1;
    }
    return s;
}
// Encode a FormData instance as multipart/form-data; returns { body, contentType }
function _encodeMultipart(fd) {
    var boundary = _randomBoundary();
    var body = "";
    var i = 0;
    while (i < fd._entries.length) {
        var e = fd._entries[i];
        body = body + "--" + boundary + "\r\n";
        if (e.value instanceof Blob) {
            var fn = e.filename !== undefined ? e.filename : "blob";
            body = body + "Content-Disposition: form-data; name=\"" + e.name + "\"; filename=\"" + fn + "\"\r\n";
            body = body + "Content-Type: " + (e.value.type || "application/octet-stream") + "\r\n\r\n";
            body = body + e.value._data + "\r\n";
        } else {
            body = body + "Content-Disposition: form-data; name=\"" + e.name + "\"\r\n\r\n";
            body = body + e.value + "\r\n";
        }
        i = i + 1;
    }
    body = body + "--" + boundary + "--\r\n";
    return {
        body: body,
        contentType: "multipart/form-data; boundary=" + boundary
    };
}
// ── Response.formData() ───────────────────────────────────────────────────
// Parses both application/x-www-form-urlencoded and multipart/form-data bodies.
// Added inside the Response class below via prototype patch.
function _parseFormData(bodyText, contentType) {
    var fd = new FormData();
    contentType = contentType || "";
    if (contentType.indexOf("application/x-www-form-urlencoded") !== -1) {
        // Simple percent-decoded key=value pairs
        bodyText.split("&").forEach(function(pair) {
            if (!pair) {
                return;
            }
            var eq = pair.indexOf("=");
            var k, v;
            if (eq === -1) {
                k = decodeURIComponent(pair.replace(/\+/g, " "));
                v = "";
            } else {
                k = decodeURIComponent(pair.substring(0, eq).replace(/\+/g, " "));
                v = decodeURIComponent(pair.substring(eq + 1).replace(/\+/g, " "));
            }
            fd.append(k, v);
        });
        return fd;
    }
    // multipart/form-data — extract boundary
    var bm = contentType.match(/boundary=([^\s;]+)/);
    if (!bm) {
        return fd;
    } // unrecognised content-type → empty FormData
    var boundary = bm[1];
    // Strip optional quotes
    if (boundary.charAt(0) === '"') {
        boundary = boundary.slice(1, -1);
    }
    var delimiter = "--" + boundary;
    var parts = bodyText.split(delimiter);
    // parts[0] is preamble, parts[last] is "--\r\n"
    var p = 1;
    while (p < parts.length - 1) {
        var part = parts[p];
        // Remove leading \r\n
        if (part.indexOf("\r\n") === 0) {
            part = part.substring(2);
        }
        var headerEnd = part.indexOf("\r\n\r\n");
        if (headerEnd === -1) {
            p = p + 1;
            continue;
        }
        var headerStr = part.substring(0, headerEnd);
        var valueRaw = part.substring(headerEnd + 4);
        // Remove trailing \r\n
        if (valueRaw.slice(-2) === "\r\n") {
            valueRaw = valueRaw.slice(0, -2);
        }
        // Parse Content-Disposition header
        var cdLine = "";
        headerStr.split("\r\n").forEach(function(hl) {
            if (hl.toLowerCase().indexOf("content-disposition:") === 0) {
                cdLine = hl;
            }
        });
        var nm = cdLine.match(/name="([^"]*)"/);
        if (!nm) {
            p = p + 1;
            continue;
        }
        var fieldName = nm[1];
        // Is it a file upload?
        var fnm = cdLine.match(/filename="([^"]*)"/);
        if (fnm) {
            var ctLine = "";
            headerStr.split("\r\n").forEach(function(hl) {
                if (hl.toLowerCase().indexOf("content-type:") === 0) {
                    ctLine = hl;
                }
            });
            var partCT = ctLine ? ctLine.split(":")[1].trim() : "application/octet-stream";
            fd.append(fieldName, new Blob([valueRaw], {
                type: partCT
            }), fnm[1]);
        } else {
            fd.append(fieldName, valueRaw);
        }
        p = p + 1;
    }
    return fd;
}
// ═══════════════════════════════════════════════════════════════════════════
//  Global registration  (Node.js ≥18 — these are globals, not modules)
// ═══════════════════════════════════════════════════════════════════════════
globalThis.fetch = fetch;
globalThis.Headers = Headers;
globalThis.Request = Request;
globalThis.Response = Response;
globalThis.ReadableStream = ReadableStream;
globalThis.ReadableStreamDefaultReader = ReadableStreamDefaultReader;
globalThis.AbortController = AbortController;
globalThis.AbortSignal = AbortSignal;
globalThis.DOMException = DOMException;
globalThis.Blob = Blob;
globalThis.FormData = FormData;
// Internal helpers — not globals, exported for engine-internal use only
module.exports = {
    mimeFromExtension: mimeFromExtension,
    mimeFromPath: mimeFromPath,
    mimeIsText: mimeIsText,
    mimeCharset: mimeCharset,
    ConnectionPool: ConnectionPool,
    _globalPool: _globalPool,
    _encodeMultipart: _encodeMultipart,
    FormData: FormData
};