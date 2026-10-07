// ────────────────────────────────────────────────────────────────────────────
// builtins/js/zlib.js — Node.js `zlib` module (real libz compression)
//
// Uses the native __zlib / __buf bridges exposed by the engine:
//   __zlib.open(wbits)                    → inflate-stream handle (decompress)
//   __zlib.feed(h, ptr, len)              → decompressed str (text output)
//   __zlib.close(h)                       → void
//   __zlib.inflate(ptr, len, wbits)       → decompressed str (one-shot)
//   __zlib.dopen(wbits, level)            → deflate-stream handle (compress)
//   __zlib.dfeed(h, ptr, len, flush)      → int (bytes produced; binary-safe)
//   __zlib.dclose(h)                      → void
//   __zlib.compress(ptr, len, wbits)      → int (Z_OK=0; one-shot compress)
//   __zlib.cptr()                         → int (output buffer ptr after compress/dfeed)
//   __zlib.clen()                         → int (output byte count after compress/dfeed)
//   __buf.alloc(n)                        → native ptr
//   __buf.free(ptr)                       → void
//   __buf.getByte(ptr, off)               → 0-255
//   __buf.setByte(ptr, off, val)          → void
//
// Node.js reference: https://nodejs.org/api/zlib.html
// ────────────────────────────────────────────────────────────────────────────

var EventEmitter = require("events");
var Buffer = require("buffer").Buffer;

// ── Constants ────────────────────────────────────────────────────────────────
var constants = {
    BROTLI_PARAM_MODE: 0,
    BROTLI_PARAM_QUALITY: 1,
    BROTLI_PARAM_SIZE_HINT: 2,
    BROTLI_PARAM_LGWIN: 3,
    BROTLI_PARAM_LGBLOCK: 4,
    BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING: 5,
    BROTLI_PARAM_LARGE_WINDOW: 6,
    BROTLI_PARAM_NPOSTFIX: 7,
    BROTLI_PARAM_NDIRECT: 8,
    BROTLI_MODE_GENERIC: 0,
    BROTLI_MODE_TEXT: 1,
    BROTLI_MODE_FONT: 2,
    BROTLI_DEFAULT_QUALITY: 11,
    BROTLI_MIN_QUALITY: 0,
    BROTLI_MAX_QUALITY: 11,
    BROTLI_DEFAULT_WINDOW: 22,
    BROTLI_MIN_WINDOW_BITS: 10,
    BROTLI_MAX_WINDOW_BITS: 24,
    BROTLI_OPERATION_PROCESS: 0,
    BROTLI_OPERATION_FLUSH: 1,
    BROTLI_OPERATION_FINISH: 2,
    BROTLI_OPERATION_EMIT_METADATA: 3,
    ZSTD_CLEVEL_DEFAULT: 3,
    ZSTD_e_continue: 0,
    ZSTD_e_flush: 1,
    ZSTD_e_end: 2,
    Z_NO_FLUSH: 0,
    Z_PARTIAL_FLUSH: 1,
    Z_SYNC_FLUSH: 2,
    Z_FULL_FLUSH: 3,
    Z_FINISH: 4,
    Z_BLOCK: 5,
    Z_TREES: 6,
    Z_FILTERED: 1,
    Z_HUFFMAN_ONLY: 2,
    Z_RLE: 3,
    Z_FIXED: 4,
    Z_DEFAULT_STRATEGY: 0,
    Z_DEFAULT_WINDOWBITS: 15,
    Z_NO_COMPRESSION: 0,
    Z_BEST_SPEED: 1,
    Z_BEST_COMPRESSION: 9,
    Z_DEFAULT_COMPRESSION: -1,
    Z_OK: 0,
    Z_STREAM_END: 1,
    Z_NEED_DICT: 2,
    Z_ERRNO: -1,
    Z_STREAM_ERROR: -2,
    Z_DATA_ERROR: -3,
    Z_MEM_ERROR: -4,
    Z_BUF_ERROR: -5,
    Z_VERSION_ERROR: -6,
    Z_BINARY: 0,
    Z_TEXT: 1,
    Z_ASCII: 1,
    Z_UNKNOWN: 2,
    Z_DEFLATED: 8,
};

// windowBits for each format
var _WBITS_GZIP     =  31;   // gzip header
var _WBITS_ZLIB     =  15;   // zlib/deflate header
var _WBITS_RAW      = -15;   // raw deflate (no header)
var _WBITS_AUTO     =  47;   // auto-detect
var _Z_SYNC_FLUSH   =   2;
var _Z_FINISH       =   4;
var _Z_DEFAULT_COMP =  -1;

// ── Internal byte helpers ─────────────────────────────────────────────────────

/**
 * Copy a JS Buffer/Uint8Array/Array into a native C buffer.
 * Returns {ptr, len}. Caller must __buf.free(ptr) when done.
 */
function _bufCopyIn(src) {
    // `| 0` coerces to a plain int32. A TypedArray/Buffer `.length` accessor can
    // return a number that fails the native i32/double type checks in the __zlib
    // dispatch (so avail_in read as 0 → empty 20-byte gzip). |0 forces a value
    // the bridge marshals correctly.
    var n = src.length | 0;
    if (!n) return { ptr: 0, len: 0 };
    var ptr = __buf.alloc(n + 1);
    for (var i = 0; i < n; i++) __buf.setByte(ptr, i, src[i] & 0xff);
    return { ptr: ptr, len: n };
}

/**
 * Read `len` bytes from native ptr into a Buffer using getByte.
 * Binary-safe: no null-byte truncation.
 */
function _ptrLenToBuffer(ptr, len) {
    var arr = new Uint8Array(len);
    for (var i = 0; i < len; i++) arr[i] = __buf.getByte(ptr, i);
    return Buffer.from(arr);
}

/**
 * Convert the raw-byte string returned by __zlib.inflate into a Buffer.
 * Only used for inflate (decompress) output which is text — no null bytes.
 */
function _strToBuffer(s) {
    var len = s.length;
    var arr = new Uint8Array(len);
    for (var i = 0; i < len; i++) arr[i] = s.charCodeAt(i) & 0xff;
    return Buffer.from(arr);
}

// ── Sync one-shot helpers ─────────────────────────────────────────────────────

// Native address of a byte view's backing store (its ArrayBuffer's `_ptr`),
// or 0 when it has none.
function _abPtr(view) {
    var ab = view.buffer;
    return (ab && typeof ab._ptr === "number" && ab._ptr > 0) ? ab._ptr : 0;
}

function _compressSync(input, wbits, level) {
    // A string compresses as its UTF-8 bytes, as in node (it used to be cut to
    // the low byte of each UTF-16 unit). The input bytes go to libz in place
    // and the output comes back with one copy — the old per-byte
    // __buf.setByte / getByte bridge calls cost a native call per byte (vite
    // gzips every chunk to report compressed sizes).
    var src;
    if (typeof input === "string") src = Buffer.from(input, "utf8");
    else if (ArrayBuffer.isView(input)) src = input;
    else if (input instanceof ArrayBuffer) src = new Uint8Array(input);
    else src = Buffer.from(input);
    var n = src.byteLength | 0;
    var base = n ? _abPtr(src) : 0;
    var rc;
    if (n && !base) {
        // No backing-store pointer: stage through a __buf block.
        var nb = _bufCopyIn(src instanceof Uint8Array ? src : new Uint8Array(src.buffer, src.byteOffset, n));
        if (!nb.ptr) throw new Error("zlib: alloc failed");
        rc = __zlib.compress(nb.ptr, nb.len, wbits);
        __buf.free(nb.ptr);
    } else {
        // One-shot compress — stores output in __zlib.cptr()/clen() (binary-safe)
        rc = __zlib.compress(n ? base + src.byteOffset : 0, n, wbits);
    }
    if (rc !== 0) throw new Error("zlib compress error: " + rc);
    var olen = __zlib.clen();
    var out = Buffer.allocUnsafe(olen);
    var obase = olen ? _abPtr(out) : 0;
    if (olen && obase) __buf.copy(obase, out.byteOffset, __zlib.cptr(), 0, olen);
    else if (olen) return _ptrLenToBuffer(__zlib.cptr(), olen);
    return out;
}

function _decompressSync(input, wbits) {
    var nb = _bufCopyIn(input);
    if (!nb.ptr && nb.len > 0) throw new Error("zlib: alloc failed");
    var out = __zlib.inflate(nb.ptr, nb.len, wbits);
    if (nb.ptr) __buf.free(nb.ptr);
    return _strToBuffer(out);
}

// ── Sync public API ───────────────────────────────────────────────────────────

function gzipSync(buf, opts) {
    return _compressSync(buf, _WBITS_GZIP, opts && opts.level);
}
function gunzipSync(buf, opts) {
    return _decompressSync(buf, _WBITS_GZIP);
}
function deflateSync(buf, opts) {
    return _compressSync(buf, _WBITS_ZLIB, opts && opts.level);
}
function inflateSync(buf, opts) {
    return _decompressSync(buf, _WBITS_ZLIB);
}
function deflateRawSync(buf, opts) {
    return _compressSync(buf, _WBITS_RAW, opts && opts.level);
}
function inflateRawSync(buf, opts) {
    return _decompressSync(buf, _WBITS_RAW);
}
function unzipSync(buf, opts) {
    return _decompressSync(buf, _WBITS_AUTO);
}

// ── Async one-shot (callback) ─────────────────────────────────────────────────
// Runs synchronously then schedules the callback on the next tick so that
// calling code doesn't need to handle synchronous throws.

function _asyncWrap(syncFn, buf, opts, cb) {
    if (typeof opts === "function") { cb = opts; opts = {}; }
    try {
        var result = syncFn(buf, opts || {});
        setImmediate(function() { cb(null, result); });
    } catch (e) {
        setImmediate(function() { cb(e); });
    }
}

function gzip(buf, opts, cb) {
    _asyncWrap(gzipSync, buf, opts, cb);
}
function gunzip(buf, opts, cb) {
    _asyncWrap(gunzipSync, buf, opts, cb);
}
function deflate(buf, opts, cb) {
    _asyncWrap(deflateSync, buf, opts, cb);
}
function inflate(buf, opts, cb) {
    _asyncWrap(inflateSync, buf, opts, cb);
}
function deflateRaw(buf, opts, cb) {
    _asyncWrap(deflateRawSync, buf, opts, cb);
}
function inflateRaw(buf, opts, cb) {
    _asyncWrap(inflateRawSync, buf, opts, cb);
}
function unzip(buf, opts, cb) {
    _asyncWrap(unzipSync, buf, opts, cb);
}

// ── Streaming Transform (createGzip / createDeflateRaw / …) ──────────────────
// Implements the Node.js Transform stream interface used by ws permessage-deflate
// and Vite's HTTP compression middleware.
//
// Approach: open a stateful deflate/inflate handle, feed chunks on write(),
// emit 'data' events with the (de)compressed output. flush() forces a
// Z_SYNC_FLUSH so WebSocket framing boundaries are honoured.

function ZlibStream(wbits, level, isDeflate, opts) {
    EventEmitter.init.call(this);
    this._wbits     = wbits;
    this._level     = (level !== undefined) ? level : _Z_DEFAULT_COMP;
    this._isDeflate = isDeflate; // true = compress, false = decompress
    this._opts      = opts || {};
    this._handle    = 0;         // native stream handle (0 = not yet opened)
    this._closed    = false;
    this.readable   = true;
    this.writable   = true;
    // honour opts.level / opts.chunkSize (ignored for now)
    if (opts && opts.level !== undefined) this._level = opts.level;
}
ZlibStream.prototype = Object.create(EventEmitter.prototype);
ZlibStream.prototype.constructor = ZlibStream;

ZlibStream.prototype._ensureHandle = function() {
    if (this._handle) return true;
    if (this._isDeflate) {
        this._handle = __zlib.dopen(this._wbits, this._level);
    } else {
        this._handle = __zlib.open(this._wbits);
    }
    return this._handle !== 0;
};

ZlibStream.prototype._feedNative = function(ptr, len, flush) {
    if (this._isDeflate) {
        // dfeed now returns int (bytes produced); output bytes in __zlib.cptr()/clen()
        var produced = __zlib.dfeed(this._handle, ptr, len, flush);
        if (produced > 0) {
            return _ptrLenToBuffer(__zlib.cptr(), produced);
        }
        return null;
    } else {
        // inflate streaming: feed returns decompressed str (text output, no null bytes)
        var s = __zlib.feed(this._handle, ptr, len);
        return (s && s.length) ? _strToBuffer(s) : null;
    }
};

ZlibStream.prototype.write = function(chunk, encoding, cb) {
    if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
    if (this._closed) {
        if (typeof cb === "function") cb(new Error("zlib stream already closed"));
        return this;
    }
    if (!this._ensureHandle()) {
        var err = new Error("zlib: failed to open stream");
        this.emit("error", err);
        if (typeof cb === "function") cb(err);
        return this;
    }
    // copy chunk to native buffer
    var nb = _bufCopyIn(chunk);
    if (nb.len > 0 || chunk.length === 0) {
        var out = this._feedNative(nb.ptr, nb.len, 0 /* Z_NO_FLUSH */);
        if (nb.ptr) __buf.free(nb.ptr);
        if (out && out.length) {
            this.emit("data", out);
        }
    }
    if (typeof cb === "function") cb();
    return this;
};

ZlibStream.prototype.flush = function(kind, cb) {
    if (typeof kind === "function") { cb = kind; kind = _Z_SYNC_FLUSH; }
    if (kind === undefined || kind === null) kind = _Z_SYNC_FLUSH;
    if (this._closed || !this._handle) {
        if (typeof cb === "function") cb();
        return;
    }
    if (this._isDeflate) {
        var produced = __zlib.dfeed(this._handle, 0, 0, kind);
        if (produced > 0) {
            this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced));
        }
    }
    if (typeof cb === "function") cb();
};

ZlibStream.prototype.end = function(chunk, encoding, cb) {
    if (typeof chunk === "function") { cb = chunk; chunk = undefined; }
    if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
    if (chunk !== undefined && chunk !== null) {
        this.write(chunk, encoding);
    }
    // flush remaining data
    if (this._handle) {
        var finalFlush = this._isDeflate ? _Z_FINISH : _Z_SYNC_FLUSH;
        if (this._isDeflate) {
            var produced2 = __zlib.dfeed(this._handle, 0, 0, finalFlush);
            if (produced2 > 0) {
                this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced2));
            }
        }
    }
    this.emit("end");
    if (typeof cb === "function") cb();
    this._cleanup();
};

ZlibStream.prototype.close = function(cb) {
    this._cleanup();
    if (typeof cb === "function") cb();
    this.emit("close");
};

ZlibStream.prototype._cleanup = function() {
    if (this._closed) return;
    this._closed = true;
    if (this._handle) {
        if (this._isDeflate) { __zlib.dclose(this._handle); }
        else { __zlib.close(this._handle); }
        this._handle = 0;
    }
};

ZlibStream.prototype.pipe = function(dest, opts) {
    this.on("data", function(chunk) { dest.write(chunk); });
    this.on("end",  function() { if (!opts || opts.end !== false) dest.end(); });
    return dest;
};

ZlibStream.prototype.params = function(level, strategy, cb) {
    // In a full impl this would call deflateParams(); for now just ack.
    if (typeof cb === "function") cb();
};

ZlibStream.prototype.reset = function() {
    this._cleanup();
    this._closed = false;
};

// ── Factory functions ─────────────────────────────────────────────────────────
function createGzip(opts)        { return new ZlibStream(_WBITS_GZIP,  undefined, true,  opts); }
function createGunzip(opts)      { return new ZlibStream(_WBITS_GZIP,  undefined, false, opts); }
function createDeflate(opts)     { return new ZlibStream(_WBITS_ZLIB,  undefined, true,  opts); }
function createInflate(opts)     { return new ZlibStream(_WBITS_ZLIB,  undefined, false, opts); }
function createDeflateRaw(opts)  { return new ZlibStream(_WBITS_RAW,   undefined, true,  opts); }
function createInflateRaw(opts)  { return new ZlibStream(_WBITS_RAW,   undefined, false, opts); }
function createUnzip(opts)       { return new ZlibStream(_WBITS_AUTO,  undefined, false, opts); }

// ── crc32 ─────────────────────────────────────────────────────────────────────

function crc32(data, value) {
    var init = (value === undefined || value === null) ? 0 : (value >>> 0);
    if (data === undefined || data === null) {
        return __zlib.crc32(0, 0, init) >>> 0;
    }
    var nb;
    if (typeof data === "string") {
        nb = { ptr: __buf.alloc(data.length + 1), len: data.length };
        for (var i = 0; i < data.length; i++) __buf.setByte(nb.ptr, i, data.charCodeAt(i) & 0xff);
    } else {
        nb = _bufCopyIn(data);
    }
    var out = __zlib.crc32(nb.ptr, nb.len, init) >>> 0;
    if (nb.ptr) __buf.free(nb.ptr);
    return out;
}

// ── Brotli / Zstd one-shot ────────────────────────────────────────────────────

function _optsQuality(opts, fallback) {
    if (!opts) return fallback;
    if (opts.params && opts.params[constants.BROTLI_PARAM_QUALITY] !== undefined) {
        return opts.params[constants.BROTLI_PARAM_QUALITY] | 0;
    }
    if (opts.level !== undefined) return opts.level | 0;
    return fallback;
}

function _maxOutputLength(opts) {
    if (opts && opts.maxOutputLength !== undefined) return opts.maxOutputLength | 0;
    return 0;
}

function _toNativeBuf(input) {
    if (typeof input === "string") {
        var nb = { ptr: __buf.alloc(input.length + 1), len: input.length };
        for (var i = 0; i < input.length; i++) __buf.setByte(nb.ptr, i, input.charCodeAt(i) & 0xff);
        return nb;
    }
    return _bufCopyIn(input);
}

function brotliCompressSync(buf, opts) {
    var nb = _toNativeBuf(buf);
    var q = _optsQuality(opts, constants.BROTLI_DEFAULT_QUALITY);
    var rc = __zlib.bcompress(nb.ptr, nb.len, q);
    if (nb.ptr) __buf.free(nb.ptr);
    if (rc !== 0) throw new Error("brotli compress error: " + rc);
    return _ptrLenToBuffer(__zlib.cptr(), __zlib.clen());
}

function brotliDecompressSync(buf, opts) {
    var nb = _toNativeBuf(buf);
    var maxOut = _maxOutputLength(opts);
    var rc = __zlib.bdecompress(nb.ptr, nb.len, maxOut);
    if (nb.ptr) __buf.free(nb.ptr);
    if (rc !== 0) {
        var err = new Error("brotli decompress error: " + rc);
        if (maxOut > 0) { err.code = "ERR_BUFFER_TOO_LARGE"; }
        throw err;
    }
    var outLen = __zlib.clen();
    if (maxOut > 0 && outLen > maxOut) {
        var e2 = new RangeError("Cannot create a Buffer larger than " + maxOut + " bytes");
        e2.code = "ERR_BUFFER_TOO_LARGE";
        throw e2;
    }
    return _ptrLenToBuffer(__zlib.cptr(), outLen);
}

function zstdCompressSync(buf, opts) {
    var nb = _toNativeBuf(buf);
    var level = (opts && opts.level !== undefined) ? (opts.level | 0) : constants.ZSTD_CLEVEL_DEFAULT;
    var rc = __zlib.zcompress(nb.ptr, nb.len, level);
    if (nb.ptr) __buf.free(nb.ptr);
    if (rc !== 0) throw new Error("zstd compress error: " + rc);
    return _ptrLenToBuffer(__zlib.cptr(), __zlib.clen());
}

function zstdDecompressSync(buf, opts) {
    var nb = _toNativeBuf(buf);
    var maxOut = _maxOutputLength(opts);
    var rc = __zlib.zdecompress(nb.ptr, nb.len, maxOut);
    if (nb.ptr) __buf.free(nb.ptr);
    if (rc !== 0) {
        var err = new Error("zstd decompress error: " + rc);
        if (maxOut > 0) { err.code = "ERR_BUFFER_TOO_LARGE"; }
        throw err;
    }
    return _ptrLenToBuffer(__zlib.cptr(), __zlib.clen());
}

function brotliCompress(buf, opts, cb) { _asyncWrap(brotliCompressSync, buf, opts, cb); }
function brotliDecompress(buf, opts, cb) { _asyncWrap(brotliDecompressSync, buf, opts, cb); }
function zstdCompress(buf, opts, cb) { _asyncWrap(zstdCompressSync, buf, opts, cb); }
function zstdDecompress(buf, opts, cb) { _asyncWrap(zstdDecompressSync, buf, opts, cb); }

// ── Brotli / Zstd streaming ───────────────────────────────────────────────────

function BrotliStream(isCompress, opts) {
    EventEmitter.init.call(this);
    this._isCompress = isCompress;
    this._opts = opts || {};
    this._quality = _optsQuality(this._opts, constants.BROTLI_DEFAULT_QUALITY);
    this._handle = 0;
    this._closed = false;
    this.readable = true;
    this.writable = true;
}
BrotliStream.prototype = Object.create(EventEmitter.prototype);
BrotliStream.prototype.constructor = BrotliStream;

BrotliStream.prototype._ensureHandle = function() {
    if (this._handle) return true;
    this._handle = this._isCompress ? __zlib.bopen(this._quality) : __zlib.bdopen();
    return this._handle !== 0;
};

BrotliStream.prototype.write = function(chunk, encoding, cb) {
    if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
    if (this._closed) {
        if (typeof cb === "function") cb(new Error("brotli stream already closed"));
        return this;
    }
    if (!this._ensureHandle()) {
        var err = new Error("brotli: failed to open stream");
        this.emit("error", err);
        if (typeof cb === "function") cb(err);
        return this;
    }
    var nb = _bufCopyIn(chunk || Buffer.alloc(0));
    var produced = this._isCompress
        ? __zlib.bfeed(this._handle, nb.ptr, nb.len, constants.BROTLI_OPERATION_PROCESS)
        : __zlib.bdfeed(this._handle, nb.ptr, nb.len);
    if (nb.ptr) __buf.free(nb.ptr);
    if (produced > 0) this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced));
    if (typeof cb === "function") cb();
    return this;
};

BrotliStream.prototype.flush = function(kind, cb) {
    if (typeof kind === "function") { cb = kind; }
    if (this._closed || !this._handle || !this._isCompress) {
        if (typeof cb === "function") cb();
        return;
    }
    var produced = __zlib.bfeed(this._handle, 0, 0, constants.BROTLI_OPERATION_FLUSH);
    if (produced > 0) this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced));
    if (typeof cb === "function") cb();
};

BrotliStream.prototype.end = function(chunk, encoding, cb) {
    if (typeof chunk === "function") { cb = chunk; chunk = undefined; }
    if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
    if (chunk !== undefined && chunk !== null) this.write(chunk, encoding);
    if (this._handle && this._isCompress) {
        var produced = __zlib.bfeed(this._handle, 0, 0, constants.BROTLI_OPERATION_FINISH);
        if (produced > 0) this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced));
    }
    this.emit("end");
    if (typeof cb === "function") cb();
    this._cleanup();
};

BrotliStream.prototype.close = function(cb) {
    this._cleanup();
    if (typeof cb === "function") cb();
    this.emit("close");
};

BrotliStream.prototype._cleanup = function() {
    if (this._closed) return;
    this._closed = true;
    if (this._handle) {
        if (this._isCompress) __zlib.bclose(this._handle);
        else __zlib.bdclose(this._handle);
        this._handle = 0;
    }
};

BrotliStream.prototype.pipe = function(dest, opts) {
    this.on("data", function(chunk) { dest.write(chunk); });
    this.on("end", function() { if (!opts || opts.end !== false) dest.end(); });
    return dest;
};

function ZstdStream(isCompress, opts) {
    EventEmitter.init.call(this);
    this._isCompress = isCompress;
    this._opts = opts || {};
    this._level = (opts && opts.level !== undefined) ? (opts.level | 0) : constants.ZSTD_CLEVEL_DEFAULT;
    this._handle = 0;
    this._closed = false;
    this.readable = true;
    this.writable = true;
}
ZstdStream.prototype = Object.create(EventEmitter.prototype);
ZstdStream.prototype.constructor = ZstdStream;

ZstdStream.prototype._ensureHandle = function() {
    if (this._handle) return true;
    this._handle = this._isCompress ? __zlib.zopen(this._level) : __zlib.zdopen();
    return this._handle !== 0;
};

ZstdStream.prototype.write = function(chunk, encoding, cb) {
    if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
    if (this._closed) {
        if (typeof cb === "function") cb(new Error("zstd stream already closed"));
        return this;
    }
    if (!this._ensureHandle()) {
        var err = new Error("zstd: failed to open stream");
        this.emit("error", err);
        if (typeof cb === "function") cb(err);
        return this;
    }
    var nb = _bufCopyIn(chunk || Buffer.alloc(0));
    var produced = this._isCompress
        ? __zlib.zfeed(this._handle, nb.ptr, nb.len, constants.ZSTD_e_continue)
        : __zlib.zdfeed(this._handle, nb.ptr, nb.len);
    if (nb.ptr) __buf.free(nb.ptr);
    if (produced > 0) this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced));
    if (typeof cb === "function") cb();
    return this;
};

ZstdStream.prototype.flush = function(kind, cb) {
    if (typeof kind === "function") { cb = kind; }
    if (this._closed || !this._handle || !this._isCompress) {
        if (typeof cb === "function") cb();
        return;
    }
    var produced = __zlib.zfeed(this._handle, 0, 0, constants.ZSTD_e_flush);
    if (produced > 0) this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced));
    if (typeof cb === "function") cb();
};

ZstdStream.prototype.end = function(chunk, encoding, cb) {
    if (typeof chunk === "function") { cb = chunk; chunk = undefined; }
    if (typeof encoding === "function") { cb = encoding; encoding = undefined; }
    if (chunk !== undefined && chunk !== null) this.write(chunk, encoding);
    if (this._handle && this._isCompress) {
        var produced = __zlib.zfeed(this._handle, 0, 0, constants.ZSTD_e_end);
        if (produced > 0) this.emit("data", _ptrLenToBuffer(__zlib.cptr(), produced));
    }
    this.emit("end");
    if (typeof cb === "function") cb();
    this._cleanup();
};

ZstdStream.prototype.close = function(cb) {
    this._cleanup();
    if (typeof cb === "function") cb();
    this.emit("close");
};

ZstdStream.prototype._cleanup = function() {
    if (this._closed) return;
    this._closed = true;
    if (this._handle) {
        if (this._isCompress) __zlib.zclose(this._handle);
        else __zlib.zdclose(this._handle);
        this._handle = 0;
    }
};

ZstdStream.prototype.pipe = function(dest, opts) {
    this.on("data", function(chunk) { dest.write(chunk); });
    this.on("end", function() { if (!opts || opts.end !== false) dest.end(); });
    return dest;
};

function createBrotliCompress(opts) { return new BrotliStream(true, opts); }
function createBrotliDecompress(opts) { return new BrotliStream(false, opts); }
function createZstdCompress(opts) { return new ZstdStream(true, opts); }
function createZstdDecompress(opts) { return new ZstdStream(false, opts); }

// ── Exports ───────────────────────────────────────────────────────────────────
module.exports = {
    constants: constants,
    Z_NO_FLUSH:           constants.Z_NO_FLUSH,
    Z_PARTIAL_FLUSH:      constants.Z_PARTIAL_FLUSH,
    Z_SYNC_FLUSH:         constants.Z_SYNC_FLUSH,
    Z_FULL_FLUSH:         constants.Z_FULL_FLUSH,
    Z_FINISH:             constants.Z_FINISH,
    Z_DEFAULT_WINDOWBITS: constants.Z_DEFAULT_WINDOWBITS,
    Z_NO_COMPRESSION:     constants.Z_NO_COMPRESSION,
    Z_BEST_SPEED:         constants.Z_BEST_SPEED,
    Z_BEST_COMPRESSION:   constants.Z_BEST_COMPRESSION,
    Z_DEFAULT_COMPRESSION: constants.Z_DEFAULT_COMPRESSION,
    Z_DEFAULT_STRATEGY:   constants.Z_DEFAULT_STRATEGY,
    Z_OK:                 constants.Z_OK,
    // Constructors (Node.js exposes the class itself too)
    Gzip:        function Gzip(opts)        { return new ZlibStream(_WBITS_GZIP,  undefined, true,  opts); },
    Gunzip:      function Gunzip(opts)      { return new ZlibStream(_WBITS_GZIP,  undefined, false, opts); },
    Deflate:     function Deflate(opts)     { return new ZlibStream(_WBITS_ZLIB,  undefined, true,  opts); },
    Inflate:     function Inflate(opts)     { return new ZlibStream(_WBITS_ZLIB,  undefined, false, opts); },
    DeflateRaw:  function DeflateRaw(opts)  { return new ZlibStream(_WBITS_RAW,   undefined, true,  opts); },
    InflateRaw:  function InflateRaw(opts)  { return new ZlibStream(_WBITS_RAW,   undefined, false, opts); },
    Unzip:       function Unzip(opts)       { return new ZlibStream(_WBITS_AUTO,  undefined, false, opts); },
    BrotliCompress:   function BrotliCompress(opts) { return new BrotliStream(true, opts); },
    BrotliDecompress: function BrotliDecompress(opts) { return new BrotliStream(false, opts); },
    ZstdCompress:     function ZstdCompress(opts) { return new ZstdStream(true, opts); },
    ZstdDecompress:   function ZstdDecompress(opts) { return new ZstdStream(false, opts); },
    // Factory functions
    createGzip:        createGzip,
    createGunzip:      createGunzip,
    createDeflate:     createDeflate,
    createInflate:     createInflate,
    createDeflateRaw:  createDeflateRaw,
    createInflateRaw:  createInflateRaw,
    createUnzip:       createUnzip,
    createBrotliCompress:   createBrotliCompress,
    createBrotliDecompress: createBrotliDecompress,
    createZstdCompress:     createZstdCompress,
    createZstdDecompress:   createZstdDecompress,
    // One-shot async
    gzip:        gzip,
    gunzip:      gunzip,
    deflate:     deflate,
    inflate:     inflate,
    deflateRaw:  deflateRaw,
    inflateRaw:  inflateRaw,
    unzip:       unzip,
    brotliCompress:   brotliCompress,
    brotliDecompress: brotliDecompress,
    zstdCompress:     zstdCompress,
    zstdDecompress:   zstdDecompress,
    // One-shot sync
    gzipSync:        gzipSync,
    gunzipSync:      gunzipSync,
    deflateSync:     deflateSync,
    inflateSync:     inflateSync,
    deflateRawSync:  deflateRawSync,
    inflateRawSync:  inflateRawSync,
    unzipSync:       unzipSync,
    brotliCompressSync:   brotliCompressSync,
    brotliDecompressSync: brotliDecompressSync,
    zstdCompressSync:     zstdCompressSync,
    zstdDecompressSync:   zstdDecompressSync,
    crc32: crc32,
};

