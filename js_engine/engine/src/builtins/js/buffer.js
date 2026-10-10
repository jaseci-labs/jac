// ────────────────────────────────────────────────────────────────────────────
// builtins/js/buffer.js — Node.js Buffer module
//
// Buffer extends Uint8Array (Node-compatible) with encoding, bounds checks,
// and full module export surface for Vite / ecosystem parity.
//
// Node.js reference: https://nodejs.org/api/buffer.html
// ────────────────────────────────────────────────────────────────────────────

// Ensure typed-array globals exist (loaded at engine init via binary_types).
if (typeof Uint8Array === "undefined") {
    throw new Error("buffer.js requires Uint8Array (load binary_types first)");
}

var _ierrs = require("./internal/errors.js");

// ── Limits (Node 22 x64-ish defaults) ────────────────────────────────────────
var K_MAX_LENGTH = 0x7fffffff;
var K_STRING_MAX_LENGTH = 0x3fffffff;
var INSPECT_MAX_BYTES = 50;
var B32 = 4294967296n;

function _uint32PairToBigInt(hi, lo) {
    // All-BigInt arithmetic: mixing BigInt with Number is a TypeError (ES §13.15.3),
    // so coerce each 32-bit half to BigInt before combining. (`(x >>> 0)n` is not
    // valid syntax — the `n` suffix only applies to numeric literals.)
    return _toBigInt(hi >>> 0) * B32 + _toBigInt(lo >>> 0);
}

/** Split uint64 bigint into BE uint32 halves (engine may lack bigint >>/&). */
function _bigIntToHiLoBE(v) {
    if (typeof v !== "bigint") { v = _toBigInt(v); }
    if (v === 18446744073709551615n || v === -1n) {
        return { hi: 0xffffffff, lo: 0xffffffff };
    }
    var hi = 0;
    var lo = 0;
    if (typeof BigInt === "function") {
        try {
            hi = Number((v >> 32n) & 0xffffffffn);
            lo = Number(v & 0xffffffffn);
        } catch (e) { hi = 0; lo = 0; }
    }
    return { hi: hi >>> 0, lo: lo >>> 0 };
}

function _unsigned64ToSignedBigInt(u) {
    if (u === 18446744073709551615n) { return -1n; }
    if (u >= 9223372036854775808n) {
        var two64 = 18446744073709551616n;
        var diff = u - two64;
        if (diff === u) { return -1n; }
        return diff;
    }
    return u;
}

// ── Encoding helpers ─────────────────────────────────────────────────────────

function _normalizeEnc(enc) {
    if (enc === null || enc === undefined || enc === "") { return "utf8"; }
    var e = String(enc).toLowerCase();
    if (e === "utf-8" || e === "utf8") { return "utf8"; }
    if (e === "hex") { return "hex"; }
    if (e === "base64") { return "base64"; }
    if (e === "base64url") { return "base64url"; }
    if (e === "ascii" || e === "latin1" || e === "binary") { return "latin1"; }
    if (e === "ucs2" || e === "ucs-2" || e === "utf16le" || e === "utf-16le") { return "utf16le"; }
    return null;
}

function _encodingError(name) {
    var err = new TypeError("Unknown encoding: " + name);
    err.code = "ERR_UNKNOWN_ENCODING";
    return err;
}

function _stringTooLong() {
    var err = new Error("Attempt to write string longer than " + K_STRING_MAX_LENGTH + " characters");
    err.code = "ERR_STRING_TOO_LONG";
    return err;
}

/** Byte length of UTF-8 encoding without allocating (surrogate pairs counted). */
function _utf8ByteLength(s) {
    // Native wire-UTF-8 length straight off the engine string (buffer_native.jac).
    if (_rawUtf8Len !== null) {
        var nn = _rawUtf8Len(s);
        if (nn !== undefined) { return nn; }
    }
    var len = s.length;
    var n = 0;
    for (var i = 0; i < len; i++) {
        var c = s.charCodeAt(i);
        if (c < 0x80) { n += 1; }
        else if (c < 0x800) { n += 2; }
        else if (c >= 0xd800 && c <= 0xdbff && i + 1 < len) {
            var lo = s.charCodeAt(i + 1);
            if (lo >= 0xdc00 && lo <= 0xdfff) { n += 4; i++; }
            else { n += 3; }
        } else { n += 3; }
    }
    return n;
}

/** Native byte store (avoids TypedArray exotic [[Set]] which segfaults on large loops). */
var _rawBuf = typeof globalThis !== "undefined" ? globalThis.__buf : null;
// Hot natives resolved once (a `typeof x.y === "function"` probe costs ~0.4µs
// per call in this interpreter; toString is the hottest Buffer method).
var _rawToString = (_rawBuf && typeof _rawBuf.toString === "function") ? _rawBuf.toString : null;
var _rawMakeView = (_rawBuf && typeof _rawBuf.makeView === "function") ? _rawBuf.makeView : null;
var _rawUtf8Len = (_rawBuf && typeof _rawBuf.utf8ByteLength === "function") ? _rawBuf.utf8ByteLength : null;
var _rawWriteString = (_rawBuf && typeof _rawBuf.writeString === "function") ? _rawBuf.writeString : null;
var _rawCopyBytes = (_rawBuf && typeof _rawBuf.copyBytes === "function") ? _rawBuf.copyBytes : null;
var _rawEqualsBytes = (_rawBuf && typeof _rawBuf.equalsBytes === "function") ? _rawBuf.equalsBytes : null;
var _rawStrByteLen = (_rawBuf && typeof _rawBuf.stringByteLength === "function") ? _rawBuf.stringByteLength : null;

function _rawSetByte(ptr, off, value) {
    if (_rawBuf && typeof _rawBuf.setByte === "function") {
        _rawBuf.setByte(ptr, off, value & 0xff);
        return;
    }
    // Fallback only for tiny paths when __buf is unavailable.
    throw new Error("buffer encode requires globalThis.__buf.setByte");
}

function _viewPtr(view) {
    if (!view || !view._buffer) { return 0; }
    // NO bitwise on the pointer: `| 0` is ToInt32 and truncates real addresses
    // above the 2 GiB line to a negative int32 (wild write → SIGSEGV once the
    // heap grows past 0x80000000 — the rollup-suite "memory wall" crashes).
    var p = view._buffer._ptr || 0;
    var bo = view._byteOffset | 0;
    return p ? (p + bo) : 0;
}

/**
 * Write UTF-8 encoding of s[start:end] into dest at destOff.
 * Prefer native __buf.setByte when dest is a TypedArray/Buffer view.
 * Returns bytes written.
 */
function _writeUtf8IntoRange(dest, s, start, end, destOff) {
    // Whole-string encode into a view: one native call (buffer_native.jac).
    if (_rawWriteString !== null && start === 0 && end === s.length) {
        var wn = _rawWriteString(dest, s, destOff | 0, undefined, "utf8");
        if (wn !== undefined) { return wn; }
    }
    var o = destOff | 0;
    var ptr = _viewPtr(dest);
    var useRaw = ptr !== 0 && _rawBuf && typeof _rawBuf.setByte === "function";
    function put(b) {
        if (useRaw) { _rawSetByte(ptr, o, b); }
        else { dest[o] = b & 0xff; }
        o++;
    }
    for (var i = start; i < end; i++) {
        var c = s.charCodeAt(i);
        if (c < 0x80) {
            put(c);
        } else if (c < 0x800) {
            put(((c >> 6) & 0x1f) | 0xc0);
            put((c & 0x3f) | 0x80);
        } else if (c >= 0xd800 && c <= 0xdbff && i + 1 < end) {
            var lo = s.charCodeAt(i + 1);
            if (lo >= 0xdc00 && lo <= 0xdfff) {
                var cp = 0x10000 + ((c - 0xd800) << 10) + (lo - 0xdc00);
                put(((cp >> 18) & 0x07) | 0xf0);
                put(((cp >> 12) & 0x3f) | 0x80);
                put(((cp >> 6) & 0x3f) | 0x80);
                put((cp & 0x3f) | 0x80);
                i++;
            } else {
                put(((c >> 12) & 0x0f) | 0xe0);
                put(((c >> 6) & 0x3f) | 0x80);
                put((c & 0x3f) | 0x80);
            }
        } else {
            put(((c >> 12) & 0x0f) | 0xe0);
            put(((c >> 6) & 0x3f) | 0x80);
            put((c & 0x3f) | 0x80);
        }
    }
    return o - (destOff | 0);
}

function _writeUtf8Into(dest, s) {
    return _writeUtf8IntoRange(dest, s, 0, s.length, 0);
}

/**
 * Production UTF-8 encode: pre-sized Array for small strings; TypedArray +
 * raw setByte for larger (no push-growth, no exotic Store loops).
 */
function _encodeUtf8(s) {
    if (typeof s !== "string") { s = String(s); }
    if (s.length > K_STRING_MAX_LENGTH) { throw _stringTooLong(); }
    var n = _utf8ByteLength(s);
    if (n <= 65536) {
        var bytes = new Array(n);
        _writeUtf8Into(bytes, s);
        return bytes;
    }
    var u8 = new Uint8Array(n);
    _writeUtf8Into(u8, s);
    return u8;
}

function _encodeUtf16le(s) {
    if (typeof s !== "string") { s = String(s); }
    if (s.length > K_STRING_MAX_LENGTH) { throw _stringTooLong(); }
    var n = s.length * 2;
    if (n <= 65536) {
        var bytes = new Array(n);
        for (var i = 0; i < s.length; i++) {
            var c = s.charCodeAt(i);
            bytes[i * 2] = c & 0xff;
            bytes[i * 2 + 1] = (c >> 8) & 0xff;
        }
        return bytes;
    }
    var u8 = new Uint8Array(n);
    var ptr = _viewPtr(u8);
    for (var j = 0; j < s.length; j++) {
        var c2 = s.charCodeAt(j);
        _rawSetByte(ptr, j * 2, c2 & 0xff);
        _rawSetByte(ptr, j * 2 + 1, (c2 >> 8) & 0xff);
    }
    return u8;
}

function _encodeLatin1Raw(s) {
    if (typeof s !== "string") { s = String(s); }
    if (s.length > K_STRING_MAX_LENGTH) { throw _stringTooLong(); }
    var n = s.length;
    if (n <= 65536) {
        var bytes = new Array(n);
        for (var i = 0; i < n; i++) { bytes[i] = s.charCodeAt(i) & 0xff; }
        return bytes;
    }
    var u8 = new Uint8Array(n);
    var ptr = _viewPtr(u8);
    for (var j = 0; j < n; j++) { _rawSetByte(ptr, j, s.charCodeAt(j) & 0xff); }
    return u8;
}

/**
 * Engine crashes on large single-pass TypedArray/Buffer stores (~200 KiB+).
 * Encode into small destination buffers then native-memcpy concat.
 */
var _BUF_ENCODE_CHUNK = 32768;

function _utf8ByteLengthRange(s, start, end) {
    var n = 0;
    for (var i = start; i < end; i++) {
        var c = s.charCodeAt(i);
        if (c < 0x80) { n += 1; }
        else if (c < 0x800) { n += 2; }
        else if (c >= 0xd800 && c <= 0xdbff && i + 1 < end) {
            var lo = s.charCodeAt(i + 1);
            if (lo >= 0xdc00 && lo <= 0xdfff) { n += 4; i++; }
            else { n += 3; }
        } else { n += 3; }
    }
    return n;
}

function _bufferFromStringChunked(s, encNorm) {
    var len = s.length;
    var parts = [];
    var i = 0;
    while (i < len) {
        var end = i + _BUF_ENCODE_CHUNK;
        if (end < len) {
            var c = s.charCodeAt(end - 1);
            if (c >= 0xd800 && c <= 0xdbff) { end = end - 1; }
        }
        if (end <= i) { end = i + 1; }
        if (encNorm === "utf8") {
            var nb = _utf8ByteLengthRange(s, i, end);
            var chunk = Buffer.allocUnsafe(nb);
            _writeUtf8IntoRange(chunk, s, i, end, 0);
            parts.push(chunk);
        } else if (encNorm === "latin1") {
            var c1 = Buffer.allocUnsafe(end - i);
            var p1 = _viewPtr(c1);
            for (var li = i; li < end; li++) {
                _rawSetByte(p1, li - i, s.charCodeAt(li) & 0xff);
            }
            parts.push(c1);
        } else if (encNorm === "utf16le") {
            var c2 = Buffer.allocUnsafe((end - i) * 2);
            var p2 = _viewPtr(c2);
            for (var ui = i; ui < end; ui++) {
                var uc = s.charCodeAt(ui);
                var o2 = (ui - i) * 2;
                _rawSetByte(p2, o2, uc & 0xff);
                _rawSetByte(p2, o2 + 1, (uc >> 8) & 0xff);
            }
            parts.push(c2);
        } else {
            parts.push(new Buffer(_strToBytes(s.substring(i, end), encNorm)));
        }
        i = end;
    }
    if (parts.length === 1) { return parts[0]; }
    return Buffer.concat(parts);
}

function _bufByte(buf, i) {
    if (buf && typeof buf._readAt === "function") {
        return buf._readAt(i) & 0xff;
    }
    return buf[i] & 0xff;
}

function _decodeUtf8(buf, start, end) {
    // Native bulk decode (ASCII fast path). Returns undefined when the range
    // contains a byte >= 0x80 or the view has no raw pointer — fall through to
    // the per-byte decoder, which owns multibyte/invalid-sequence semantics.
    if (_rawBuf && typeof _rawBuf.decodeUtf8 === "function") {
        var nptr = _viewPtr(buf);
        if (nptr !== 0) {
            var fast = _rawBuf.decodeUtf8(nptr, start, end);
            if (fast !== undefined) { return fast; }
        }
    }
    var result = "";
    var i = start;
    while (i < end) {
        var b0 = _bufByte(buf, i);
        if (b0 < 0x80) {
            result += String.fromCharCode(b0);
            i++;
        } else if ((b0 & 0xe0) === 0xc0 && i + 1 < end) {
            var c = ((b0 & 0x1f) << 6) | (_bufByte(buf, i + 1) & 0x3f);
            result += String.fromCharCode(c);
            i += 2;
        } else if ((b0 & 0xf0) === 0xe0 && i + 2 < end) {
            var c2 = ((b0 & 0x0f) << 12) | ((_bufByte(buf, i + 1) & 0x3f) << 6) | (_bufByte(buf, i + 2) & 0x3f);
            result += String.fromCharCode(c2);
            i += 3;
        } else if ((b0 & 0xf8) === 0xf0 && i + 3 < end) {
            var cp = ((b0 & 0x07) << 18) | ((_bufByte(buf, i + 1) & 0x3f) << 12) |
                ((_bufByte(buf, i + 2) & 0x3f) << 6) | (_bufByte(buf, i + 3) & 0x3f);
            cp = cp - 0x10000;
            result += String.fromCharCode(0xd800 + (cp >> 10));
            result += String.fromCharCode(0xdc00 + (cp & 0x3ff));
            i += 4;
        } else {
            result += String.fromCharCode(0xfffd);
            i++;
        }
    }
    return result;
}

var _HEX_CHARS = "0123456789abcdef";

function _hexDigit(c) {
    if (c >= "0" && c <= "9") { return c.charCodeAt(0) - 48; }
    if (c >= "a" && c <= "f") { return c.charCodeAt(0) - 87; }
    if (c >= "A" && c <= "F") { return c.charCodeAt(0) - 55; }
    return -1;
}

function _encodeHex(s) {
    var bytes = [];
    var i = 0;
    while (i + 1 < s.length) {
        var hi = _hexDigit(s[i]);
        var lo = _hexDigit(s[i + 1]);
        if (hi < 0 || lo < 0) { break; }
        bytes.push((hi << 4) | lo);
        i += 2;
    }
    return bytes;
}

function _decodeHex(buf, start, end) {
    var out = "";
    for (var i = start; i < end; i++) {
        var b = _bufByte(buf, i);
        out += _HEX_CHARS[b >> 4];
        out += _HEX_CHARS[b & 0x0f];
    }
    return out;
}

var _B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

function _b64Val(c) {
    var idx = _B64_CHARS.indexOf(c);
    return idx;
}

function _encodeBase64(s, urlSafe) {
    var bytes = [];
    var clean = "";
    for (var i = 0; i < s.length; i++) {
        var ch = s[i];
        if (ch === "=" || ch === " " || ch === "\n" || ch === "\r" || ch === "\t") { continue; }
        if (urlSafe) {
            if (ch === "-") { ch = "+"; }
            else if (ch === "_") { ch = "/"; }
        }
        clean = clean + ch;
    }
    var ci = 0;
    while (ci < clean.length) {
        var a = _b64Val(clean[ci]);
        var b2 = ci + 1 < clean.length ? _b64Val(clean[ci + 1]) : 0;
        var c2 = ci + 2 < clean.length ? _b64Val(clean[ci + 2]) : 0;
        var d2 = ci + 3 < clean.length ? _b64Val(clean[ci + 3]) : 0;
        if (a < 0) { a = 0; }
        if (b2 < 0) { b2 = 0; }
        if (c2 < 0) { c2 = 0; }
        if (d2 < 0) { d2 = 0; }
        bytes.push((a << 2) | (b2 >> 4));
        if (ci + 2 < clean.length) { bytes.push(((b2 & 0x0f) << 4) | (c2 >> 2)); }
        if (ci + 3 < clean.length) { bytes.push(((c2 & 0x03) << 6) | d2); }
        ci += 4;
    }
    return bytes;
}

function _decodeBase64(buf, start, end, urlSafe) {
    var tbl = urlSafe ? "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_" : _B64_CHARS;
    var out = "";
    var i = start;
    while (i < end) {
        var b0 = _bufByte(buf, i);
        var b1 = i + 1 < end ? _bufByte(buf, i + 1) : 0;
        var b2 = i + 2 < end ? _bufByte(buf, i + 2) : 0;
        out += tbl[b0 >> 2];
        out += tbl[((b0 & 0x03) << 4) | (b1 >> 4)];
        if (i + 1 < end) {
            out += tbl[((b1 & 0x0f) << 2) | (b2 >> 6)];
        } else if (!urlSafe) {
            out += "=";
        }
        if (i + 2 < end) {
            out += tbl[b2 & 0x3f];
        } else if (!urlSafe) {
            out += "=";
        }
        i += 3;
    }
    return out;
}

function _encodeLatin1(s) {
    return _encodeLatin1Raw(s);
}

function _decodeLatin1(buf, start, end) {
    if (_rawBuf && typeof _rawBuf.decodeLatin1 === "function") {
        var nptr = _viewPtr(buf);
        if (nptr !== 0) {
            var fast = _rawBuf.decodeLatin1(nptr, start, end);
            if (fast !== undefined) { return fast; }
        }
    }
    var out = "";
    for (var i = start; i < end; i++) { out += String.fromCharCode(_bufByte(buf, i)); }
    return out;
}

function _strToBytes(s, enc) {
    var e = _normalizeEnc(enc);
    if (e === null) { throw _encodingError(enc); }
    if (e === "utf8") { return _encodeUtf8(s); }
    if (e === "utf16le") { return _encodeUtf16le(s); }
    if (e === "hex") { return _encodeHex(s); }
    if (e === "base64") { return _encodeBase64(s, false); }
    if (e === "base64url") { return _encodeBase64(s, true); }
    return _encodeLatin1(s);
}

function _bytesToStr(buf, start, end, enc) {
    var e = _normalizeEnc(enc);
    if (e === null) { throw _encodingError(enc); }
    if (e === "utf8") { return _decodeUtf8(buf, start, end); }
    if (e === "hex") { return _decodeHex(buf, start, end); }
    if (e === "base64") { return _decodeBase64(buf, start, end, false); }
    if (e === "base64url") { return _decodeBase64(buf, start, end, true); }
    return _decodeLatin1(buf, start, end);
}

function _toIndex(v, name) {
    var n = typeof v === "number" ? v : Number(v);
    if (n !== n) {
        var err = new RangeError("Invalid " + name);
        err.code = "ERR_INVALID_ARG_VALUE";
        throw err;
    }
    if (n < 0 || n > K_MAX_LENGTH) {
        var err2 = new RangeError("Invalid " + name);
        err2.code = "ERR_OUT_OF_RANGE";
        throw err2;
    }
    return n >>> 0;
}

/**
 * Node-compatible offset validation for Buffer read* / write* methods.
 * - undefined -> 0 (default)
 * - non-number -> ERR_INVALID_ARG_TYPE
 * - non-integer / outside [0, length-size] -> ERR_OUT_OF_RANGE
 * - buffer shorter than size (no valid offset) -> ERR_BUFFER_OUT_OF_BOUNDS
 * Returns the coerced integer offset.
 */
function _checkOffset(offset, byteLength, bufLength) {
    // Common case first: an in-range integer offset needs no error machinery.
    if (typeof offset === "number" && offset >= 0 && (offset | 0) === offset
        && offset <= bufLength - byteLength && bufLength >= byteLength) {
        return offset;
    }
    if (offset === undefined) {
        offset = 0;
    } else if (typeof offset !== "number") {
        var te = new TypeError(
            'The "offset" argument must be of type number. Received type ' +
            typeof offset
        );
        te.code = "ERR_INVALID_ARG_TYPE";
        throw te;
    }
    if (bufLength < byteLength) {
        var be = new RangeError("Attempt to access memory outside buffer bounds");
        be.code = "ERR_BUFFER_OUT_OF_BOUNDS";
        throw be;
    }
    var max = bufLength - byteLength;
    // Match Node boundsError order: non-integers (NaN, 1.01) first; Infinity
    // falls through because Math.floor(Infinity) === Infinity.
    if (Math.floor(offset) !== offset) {
        var reInt = new RangeError(
            'The value of "offset" is out of range. It must be an integer. Received ' +
            offset
        );
        reInt.code = "ERR_OUT_OF_RANGE";
        throw reInt;
    }
    if (offset > max || offset < 0) {
        var re = new RangeError(
            'The value of "offset" is out of range. It must be >= 0 and <= ' +
            max + ". Received " + offset
        );
        re.code = "ERR_OUT_OF_RANGE";
        throw re;
    }
    return offset;
}

function _checkRead(thisBuf, offset, size) {
    return _checkOffset(offset, size, thisBuf.length);
}

function _checkWrite(thisBuf, offset, size) {
    return _checkOffset(offset, size, thisBuf.length);
}

function _toBigInt(value) {
    if (typeof value === "bigint") { return value; }
    // Engine may expose bigint literals but not the BigInt() constructor.
    if (typeof BigInt === "function") { return BigInt(value); }
    var n = Number(value);
    if (n !== n) { throw new TypeError("Cannot convert to BigInt"); }
    return /** @type {bigint} */ (n);
}

function _isUint8Array(v) {
    if (v instanceof Uint8Array) { return true; }
    if (v && typeof v === "object" && typeof v.length === "number" &&
        typeof v.byteOffset === "number" && v.buffer instanceof ArrayBuffer) {
        return true;
    }
    return false;
}

// ── Buffer class (extends Uint8Array) ───────────────────────────────────────

class Buffer extends Uint8Array {
    constructor(arg, encodingOrOffset, length) {
        if (typeof arg === "number") {
            // new Buffer(number, encoding) is invalid — encoding implies string form
            if (encodingOrOffset !== undefined && encodingOrOffset !== null) {
                throw _ierrs.errInvalidArgType("string", "string", arg);
            }
            super(_toIndex(arg, "size"));
            this.__isBuf = true;
            return;
        }
        if (arg instanceof ArrayBuffer) {
            var off = encodingOrOffset !== undefined ? (encodingOrOffset >>> 0) : 0;
            var len = length !== undefined ? (length >>> 0) : arg.byteLength - off;
            super(arg, off, len);
            this.__isBuf = true;
            return;
        }
        if (Array.isArray(arg)) {
            var arr = [];
            for (var i = 0; i < arg.length; i++) { arr.push(arg[i] & 0xff); }
            super(arr);
            this.__isBuf = true;
            return;
        }
        if (_isUint8Array(arg)) {
            super(arg);
            this.__isBuf = true;
            return;
        }
        if (typeof arg === "string") {
            if (arg.length > K_STRING_MAX_LENGTH) { throw _stringTooLong(); }
            var encNorm = _normalizeEnc(encodingOrOffset);
            if (encNorm === null) { throw _encodingError(encodingOrOffset); }
            // Large single-pass JS encodes segfault (~200 KiB+): chunk + memcpy into
            // self — only when the native encoder is unavailable (it is O(n) and
            // allocation-free at any size).
            if (arg.length > _BUF_ENCODE_CHUNK && _rawWriteString === null &&
                (encNorm === "utf8" || encNorm === "latin1" || encNorm === "utf16le")) {
                var chunked = _bufferFromStringChunked(arg, encNorm);
                super(chunked.length);
                var dptr = _viewPtr(this);
                var sptr = _viewPtr(chunked);
                if (dptr && sptr && _rawBuf && typeof _rawBuf.copy === "function") {
                    _rawBuf.copy(dptr, 0, sptr, 0, chunked.length);
                } else {
                    _writeUtf8Into(this, arg);
                }
                this.__isBuf = true;
                return;
            }
            if (encNorm === "utf8") {
                super(_utf8ByteLength(arg));
                _writeUtf8Into(this, arg);
                this.__isBuf = true;
                return;
            }
            if (encNorm === "latin1") {
                super(arg.length);
                if (_rawWriteString === null || _rawWriteString(this, arg, 0, undefined, "latin1") === undefined) {
                    var lptr = _viewPtr(this);
                    for (var li = 0; li < arg.length; li++) {
                        _rawSetByte(lptr, li, arg.charCodeAt(li) & 0xff);
                    }
                }
                this.__isBuf = true;
                return;
            }
            if (encNorm === "utf16le") {
                super(arg.length * 2);
                var uptr = _viewPtr(this);
                for (var ui = 0; ui < arg.length; ui++) {
                    var uc = arg.charCodeAt(ui);
                    _rawSetByte(uptr, ui * 2, uc & 0xff);
                    _rawSetByte(uptr, ui * 2 + 1, (uc >> 8) & 0xff);
                }
                this.__isBuf = true;
                return;
            }
            // Native base64 / base64url / hex decode straight into the new buffer.
            if ((encNorm === "base64" || encNorm === "base64url" || encNorm === "hex")
                && _rawStrByteLen !== null && _rawWriteString !== null) {
                var nb = _rawStrByteLen(arg, encNorm);
                if (nb !== undefined) {
                    super(nb);
                    if (nb > 0) { _rawWriteString(this, arg, 0, nb, encNorm); }
                    this.__isBuf = true;
                    return;
                }
            }
            var encoded = _strToBytes(arg, encodingOrOffset);
            if (_isUint8Array(encoded)) {
                super(encoded.buffer, encoded.byteOffset, encoded.byteLength);
                this.__isBuf = true;
                return;
            }
            super(encoded.length);
            var eptr = _viewPtr(this);
            for (var si = 0; si < encoded.length; si++) {
                _rawSetByte(eptr, si, encoded[si] & 0xff);
            }
            this.__isBuf = true;
            return;
        }
        super(0);
        this.__isBuf = true;
    }

    // Node: slice shares backing store (unlike Uint8Array.slice which copies).
    slice(start, end) {
        return this.subarray(start, end);
    }

    // Override subarray so the result is a Buffer, not a plain Uint8Array.
    // The inherited Uint8Array.prototype.subarray uses this._ctor which is
    // set to Uint8Array (not Buffer) during construction, so we must override.
    subarray(start, end) {
        var len = this.length;
        var s = (start === undefined || start === null) ? 0
              : (start < 0 ? Math.max(0, len + start) : Math.min(start, len));
        var e = (end === undefined || end === null) ? len
              : (end < 0 ? Math.max(0, len + end) : Math.min(end, len));
        if (e < s) { e = s; }
        // Native view construction (buffer_native.jac): the result is always a
        // Buffer (node's FastBuffer), so pass Buffer.prototype + the __isBuf brand.
        if (_rawMakeView !== null) {
            var fastView = _rawMakeView(this, Buffer.prototype, s, e - s, true);
            if (fastView !== undefined) { return fastView; }
        }
        return new Buffer(this.buffer, this.byteOffset + s, e - s);
    }

    toString(encoding, start, end) {
        // Native fast path (utf8 / latin1 / binary / ascii): reads the backing
        // store via the binary side-table and decodes in one native call.
        // Returns undefined for encodings or receivers it does not handle.
        if (_rawToString !== null) {
            var fast = _rawToString(this, encoding, start, end);
            if (fast !== undefined) { return fast; }
        }
        if (!(this instanceof Uint8Array)) {
            throw new TypeError('The "this" argument must be an instance of Buffer or Uint8Array');
        }
        // Read .length ONCE: it is an exotic-object property (~10µs/read) and
        // this method is the hottest call in a bundler workload.
        var len = this.length;
        var s = start !== undefined && start !== null ? start : 0;
        var e = end !== undefined && end !== null ? end : len;
        if (s < 0) { s = len + s; }
        if (e < 0) { e = len + e; }
        if (s < 0) { s = 0; }
        if (e > len) { e = len; }
        return _bytesToStr(this, s, e, encoding);
    }

    write(string, offset, length, encoding) {
        var off = 0;
        var enc = encoding;
        var maxWrite;
        // node: write(string, offset, encoding) — a string in the length slot is the encoding.
        if (typeof length === "string") { enc = length; length = undefined; }
        if (typeof offset === "string") {
            enc = offset;
            off = 0;
            maxWrite = this.length;
        } else {
            off = offset !== undefined && offset !== null ? offset : 0;
            maxWrite = this.length - off;
            if (length !== undefined && length !== null && length < maxWrite) {
                maxWrite = length;
            }
        }
        // Native encode into the backing store for utf8 / latin1 / ascii
        // (undefined → other encodings or out-of-range offset: JS path below).
        if (typeof string === "string" && _rawWriteString !== null) {
            var wq = _rawWriteString(this, string, off, maxWrite, (enc === undefined || enc === null) ? "utf8" : enc);
            if (wq !== undefined) { return wq; }
        }
        var bytes = _strToBytes(string, enc);
        var n = bytes.length < maxWrite ? bytes.length : maxWrite;
        for (var i = 0; i < n; i++) { this[off + i] = bytes[i] & 0xff; }
        return n;
    }

    copy(target, targetStart, sourceStart, sourceEnd) {
        var ts = targetStart !== undefined && targetStart !== null ? targetStart : 0;
        var ss = sourceStart !== undefined && sourceStart !== null ? sourceStart : 0;
        var se = sourceEnd !== undefined && sourceEnd !== null ? sourceEnd : this.length;
        if (se > this.length) { se = this.length; }
        // Native memmove between live views (buffer_native.jac).
        if (_rawCopyBytes !== null) {
            var cn = _rawCopyBytes(this, target, ts, ss, se);
            if (cn !== undefined) { return cn; }
        }
        var n = se - ss;
        if (n <= 0) { return 0; }
        for (var i = 0; i < n; i++) {
            if (ts + i < target.length) { target[ts + i] = this[ss + i] & 0xff; }
        }
        return n;
    }

    fill(value, offset, end, encoding) {
        var s = offset !== undefined && offset !== null ? offset : 0;
        var e = end !== undefined && end !== null ? end : this.length;
        if (s < 0) { s = 0; }
        if (e > this.length) { e = this.length; }
        if (typeof value === "number") {
            var fb = value & 0xff;
            for (var i = s; i < e; i++) { this[i] = fb; }
            return this;
        }
        if (typeof value === "string") {
            var pat = _strToBytes(value, encoding);
            if (pat.length > 0) {
                for (var j = s; j < e; j++) { this[j] = pat[(j - s) % pat.length] & 0xff; }
            }
            return this;
        }
        return this;
    }

    _indexOf(value, byteOffset, encoding, fromEnd) {
        var start = byteOffset !== undefined && byteOffset !== null ? byteOffset : 0;
        if (start < 0) { start = this.length + start; }
        if (start < 0) { start = 0; }
        if (typeof value === "number") {
            var v = value & 0xff;
            if (fromEnd) {
                for (var i = this.length - 1; i >= start; i--) {
                    if ((this[i] & 0xff) === v) { return i; }
                }
            } else {
                for (var j = start; j < this.length; j++) {
                    if ((this[j] & 0xff) === v) { return j; }
                }
            }
            return -1;
        }
        var needle;
        if (typeof value === "string") {
            needle = _strToBytes(value, encoding);
        } else if (_isUint8Array(value)) {
            needle = value;
        } else {
            return -1;
        }
        if (needle.length === 0) { return start <= this.length ? start : this.length; }
        var last = this.length - needle.length;
        if (fromEnd) {
            // Search from end; byteOffset is the highest index to include in search.
            var endPos = start;
            if (endPos > last) { endPos = last; }
            for (var k = endPos; k >= 0; k--) {
                var ok = true;
                for (var n = 0; n < needle.length; n++) {
                    if ((this[k + n] & 0xff) !== (needle[n] & 0xff)) { ok = false; break; }
                }
                if (ok) { return k; }
            }
            return -1;
        }
        for (var p = start; p <= last; p++) {
            var ok2 = true;
            for (var m = 0; m < needle.length; m++) {
                if ((this[p + m] & 0xff) !== (needle[m] & 0xff)) { ok2 = false; break; }
            }
            if (ok2) { return p; }
        }
        return -1;
    }

    indexOf(value, byteOffset, encoding) {
        return this._indexOf(value, byteOffset, encoding, false);
    }

    lastIndexOf(value, byteOffset, encoding) {
        var start = byteOffset !== undefined && byteOffset !== null ? byteOffset : this.length - 1;
        if (start < 0) { start = this.length + start; }
        if (start >= this.length) { start = this.length - 1; }
        if (start < 0) { start = 0; }
        return this._indexOf(value, start, encoding, true);
    }

    includes(value, byteOffset, encoding) {
        return this.indexOf(value, byteOffset, encoding) !== -1;
    }

    equals(other) {
        if (!_isUint8Array(other)) {
            throw _ierrs.errInvalidArgType("otherBuffer", "Buffer or Uint8Array", other);
        }
        // Native memcmp between live views (buffer_native.jac).
        if (_rawEqualsBytes !== null) {
            var eq = _rawEqualsBytes(this, other);
            if (eq !== undefined) { return eq; }
        }
        if (this.length !== other.length) { return false; }
        for (var i = 0; i < this.length; i++) {
            if ((this[i] & 0xff) !== (other[i] & 0xff)) { return false; }
        }
        return true;
    }

    join(separator) {
        var sep = separator === undefined ? "," : String(separator);
        var parts = [];
        for (var i = 0; i < this.length; i++) { parts.push(String(this[i])); }
        return parts.join(sep);
    }

    toJSON() {
        var arr = [];
        for (var i = 0; i < this.length; i++) { arr.push(this[i] & 0xff); }
        return { type: "Buffer", data: arr };
    }

    // ── Numeric I/O (bounds-checked) ────────────────────────────────────────
    readUInt8(offset) {
        offset = _checkRead(this, offset, 1);
        return this[offset] & 0xff;
    }

    writeUInt8(value, offset) {
        offset = _checkWrite(this, offset, 1);
        this[offset] = value & 0xff;
        return offset + 1;
    }

    readUInt16BE(offset) {
        offset = _checkRead(this, offset, 2);
        return (((this[offset] & 0xff) << 8) | (this[offset + 1] & 0xff)) >>> 0;
    }

    readUInt16LE(offset) {
        offset = _checkRead(this, offset, 2);
        return ((this[offset] & 0xff) | ((this[offset + 1] & 0xff) << 8)) >>> 0;
    }

    writeUInt16BE(value, offset) {
        offset = _checkWrite(this, offset, 2);
        this[offset] = (value >>> 8) & 0xff;
        this[offset + 1] = value & 0xff;
        return offset + 2;
    }

    writeUInt16LE(value, offset) {
        offset = _checkWrite(this, offset, 2);
        this[offset] = value & 0xff;
        this[offset + 1] = (value >>> 8) & 0xff;
        return offset + 2;
    }

    readUInt32BE(offset) {
        offset = _checkRead(this, offset, 4);
        return (((this[offset] & 0xff) * 0x1000000) +
            ((this[offset + 1] & 0xff) << 16) +
            ((this[offset + 2] & 0xff) << 8) +
            (this[offset + 3] & 0xff)) >>> 0;
    }

    readUInt32LE(offset) {
        offset = _checkRead(this, offset, 4);
        return ((this[offset] & 0xff) +
            ((this[offset + 1] & 0xff) << 8) +
            ((this[offset + 2] & 0xff) << 16) +
            ((this[offset + 3] & 0xff) * 0x1000000)) >>> 0;
    }

    writeUInt32BE(value, offset) {
        offset = _checkWrite(this, offset, 4);
        this[offset] = (value >>> 24) & 0xff;
        this[offset + 1] = (value >>> 16) & 0xff;
        this[offset + 2] = (value >>> 8) & 0xff;
        this[offset + 3] = value & 0xff;
        return offset + 4;
    }

    writeUInt32LE(value, offset) {
        offset = _checkWrite(this, offset, 4);
        this[offset] = value & 0xff;
        this[offset + 1] = (value >>> 8) & 0xff;
        this[offset + 2] = (value >>> 16) & 0xff;
        this[offset + 3] = (value >>> 24) & 0xff;
        return offset + 4;
    }

    readInt8(offset) {
        var v = this.readUInt8(offset);
        return v >= 0x80 ? v - 0x100 : v;
    }

    readInt16BE(offset) {
        var v = this.readUInt16BE(offset);
        return v >= 0x8000 ? v - 0x10000 : v;
    }

    readInt16LE(offset) {
        var v = this.readUInt16LE(offset);
        return v >= 0x8000 ? v - 0x10000 : v;
    }

    readInt32BE(offset) {
        offset = _checkRead(this, offset, 4);
        return ((this[offset] & 0xff) << 24) |
            ((this[offset + 1] & 0xff) << 16) |
            ((this[offset + 2] & 0xff) << 8) |
            (this[offset + 3] & 0xff);
    }

    readInt32LE(offset) {
        offset = _checkRead(this, offset, 4);
        return (this[offset] & 0xff) |
            ((this[offset + 1] & 0xff) << 8) |
            ((this[offset + 2] & 0xff) << 16) |
            ((this[offset + 3] & 0xff) << 24);
    }

    writeInt8(value, offset) { return this.writeUInt8(value, offset); }
    writeInt16BE(value, offset) { return this.writeUInt16BE(value & 0xffff, offset); }
    writeInt16LE(value, offset) { return this.writeUInt16LE(value & 0xffff, offset); }
    writeInt32BE(value, offset) {
        offset = _checkWrite(this, offset, 4);
        this[offset] = (value >> 24) & 0xff;
        this[offset + 1] = (value >> 16) & 0xff;
        this[offset + 2] = (value >> 8) & 0xff;
        this[offset + 3] = value & 0xff;
        return offset + 4;
    }

    writeInt32LE(value, offset) {
        offset = _checkWrite(this, offset, 4);
        this[offset] = value & 0xff;
        this[offset + 1] = (value >> 8) & 0xff;
        this[offset + 2] = (value >> 16) & 0xff;
        this[offset + 3] = (value >> 24) & 0xff;
        return offset + 4;
    }

    _dataView(offset, size) {
        return new DataView(this.buffer, this.byteOffset + offset, size);
    }

    readFloatBE(offset) {
        offset = _checkRead(this, offset, 4);
        return this._dataView(offset, 4).getFloat32(0, false);
    }

    readFloatLE(offset) {
        offset = _checkRead(this, offset, 4);
        return this._dataView(offset, 4).getFloat32(0, true);
    }

    writeFloatBE(value, offset) {
        offset = _checkWrite(this, offset, 4);
        this._dataView(offset, 4).setFloat32(0, value, false);
        return offset + 4;
    }

    writeFloatLE(value, offset) {
        offset = _checkWrite(this, offset, 4);
        this._dataView(offset, 4).setFloat32(0, value, true);
        return offset + 4;
    }

    readDoubleBE(offset) {
        offset = _checkRead(this, offset, 8);
        return this._dataView(offset, 8).getFloat64(0, false);
    }

    readDoubleLE(offset) {
        offset = _checkRead(this, offset, 8);
        return this._dataView(offset, 8).getFloat64(0, true);
    }

    writeDoubleBE(value, offset) {
        offset = _checkWrite(this, offset, 8);
        this._dataView(offset, 8).setFloat64(0, value, false);
        return offset + 8;
    }

    writeDoubleLE(value, offset) {
        offset = _checkWrite(this, offset, 8);
        this._dataView(offset, 8).setFloat64(0, value, true);
        return offset + 8;
    }

    readBigUInt64BE(offset) {
        offset = _checkRead(this, offset, 8);
        return _uint32PairToBigInt(this.readUInt32BE(offset), this.readUInt32BE(offset + 4));
    }

    readBigUInt64LE(offset) {
        offset = _checkRead(this, offset, 8);
        return _uint32PairToBigInt(this.readUInt32LE(offset + 4), this.readUInt32LE(offset));
    }

    readBigInt64BE(offset) {
        offset = _checkRead(this, offset, 8);
        var hi = this.readUInt32BE(offset);
        var lo = this.readUInt32BE(offset + 4);
        if (hi === 0xffffffff && lo === 0xffffffff) { return -1n; }
        return _unsigned64ToSignedBigInt(_uint32PairToBigInt(hi, lo));
    }

    readBigInt64LE(offset) {
        offset = _checkRead(this, offset, 8);
        var lo = this.readUInt32LE(offset);
        var hi = this.readUInt32LE(offset + 4);
        if (hi === 0xffffffff && lo === 0xffffffff) { return -1n; }
        return _unsigned64ToSignedBigInt(_uint32PairToBigInt(hi, lo));
    }

    writeBigUInt64BE(value, offset) {
        offset = _checkWrite(this, offset, 8);
        var pair = _bigIntToHiLoBE(_toBigInt(value));
        this.writeUInt32BE(pair.hi, offset);
        this.writeUInt32BE(pair.lo, offset + 4);
        return offset + 8;
    }

    writeBigUInt64LE(value, offset) {
        offset = _checkWrite(this, offset, 8);
        var pair = _bigIntToHiLoBE(_toBigInt(value));
        this.writeUInt32LE(pair.lo, offset);
        this.writeUInt32LE(pair.hi, offset + 4);
        return offset + 8;
    }

    writeBigInt64BE(value, offset) {
        return this.writeBigUInt64BE(_toBigInt(value), offset);
    }

    writeBigInt64LE(value, offset) {
        return this.writeBigUInt64LE(_toBigInt(value), offset);
    }

    // ── Static methods ────────────────────────────────────────────────────────
    static alloc(size, fill, encoding) {
        var n = _toIndex(size, "size");
        var buf = new Buffer(n);
        if (fill !== undefined && fill !== null) {
            if (typeof fill === "number") {
                buf.fill(fill & 0xff);
            } else if (typeof fill === "string") {
                buf.fill(fill, 0, n, encoding);
            } else if (_isUint8Array(fill) && fill.length > 0) {
                for (var i = 0; i < n; i++) { buf[i] = fill[i % fill.length] & 0xff; }
            }
        }
        return buf;
    }

    static allocUnsafe(size) {
        return new Buffer(_toIndex(size, "size"));
    }

    static allocUnsafeSlow(size) {
        return Buffer.allocUnsafe(size);
    }

    static from(value, encodingOrOffset, length) {
        if (typeof value === "string") {
            if (value.length > K_STRING_MAX_LENGTH) { throw _stringTooLong(); }
            var encFrom = _normalizeEnc(encodingOrOffset);
            if (encFrom === null) { throw _encodingError(encodingOrOffset); }
            // Chunked JS path for large strings only without the native encoder.
            if (value.length > _BUF_ENCODE_CHUNK && _rawWriteString === null &&
                (encFrom === "utf8" || encFrom === "latin1" || encFrom === "utf16le")) {
                return _bufferFromStringChunked(value, encFrom);
            }
            return new Buffer(value, encodingOrOffset);
        }
        if (value instanceof ArrayBuffer) {
            var off = encodingOrOffset !== undefined ? (encodingOrOffset >>> 0) : 0;
            var len = length !== undefined ? (length >>> 0) : value.byteLength - off;
            return new Buffer(value, off, len);
        }
        if (Array.isArray(value)) {
            return new Buffer(value);
        }
        if (_isUint8Array(value)) {
            return new Buffer(value);
        }
        return new Buffer(0);
    }

    static isBuffer(obj) {
        return obj instanceof Buffer;
    }

    static byteLength(str, encoding) {
        if (typeof str === "string" && _rawUtf8Len !== null
            && (encoding === undefined || encoding === "utf8" || encoding === "utf-8")) {
            var nfast = _rawUtf8Len(str);
            if (nfast !== undefined) { return nfast; }
        }
        if (typeof str !== "string") {
            // Node accepts Buffer / ArrayBuffer / TypedArray and returns byteLength
            if (str && typeof str === "object") {
                if (typeof str.byteLength === "number") return str.byteLength;
                if (typeof str.length === "number" && _isUint8Array(str)) return str.length;
            }
            throw _ierrs.errInvalidArgType(
                "string",
                "string or an instance of Buffer or ArrayBuffer",
                str
            );
        }
        var e = _normalizeEnc(encoding);
        // Node: empty / unrecognized encodings are treated as utf8 for byteLength
        if (e === null) {
            return _utf8ByteLength(str);
        }
        if (e === "utf8") {
            return _utf8ByteLength(str);
        }
        if (e === "utf16le") { return str.length * 2; }
        if (e === "latin1") { return str.length; }
        if (e === "hex") {
            var n = 0;
            for (var i = 0; i + 1 < str.length; i += 2) {
                var hi = str.charCodeAt(i);
                var lo = str.charCodeAt(i + 1);
                var validHex = function(c) {
                    return (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102);
                };
                if (!validHex(hi) || !validHex(lo)) { break; }
                n++;
            }
            return n;
        }
        return _strToBytes(str, encoding).length;
    }

    static concat(list, totalLength) {
        if (!Array.isArray(list)) {
            throw _ierrs.errInvalidArgType("list", ["Array"], list);
        }
        for (var vi = 0; vi < list.length; vi++) {
            if (!_isUint8Array(list[vi])) {
                throw _ierrs.errInvalidArgType(
                    "list[" + vi + "]",
                    "Buffer or Uint8Array",
                    list[vi]
                );
            }
        }
        var total = 0;
        for (var i = 0; i < list.length; i++) {
            total += list[i].length;
        }
        if (totalLength !== undefined && totalLength !== null) {
            if (typeof totalLength !== "number") {
                throw _ierrs.errInvalidArgType("length", "number", totalLength);
            }
            if (!Number.isInteger(totalLength)) {
                throw _ierrs.errOutOfRange("length", "an integer", totalLength);
            }
            if (totalLength < 0 || totalLength > K_MAX_LENGTH) {
                throw _ierrs.errOutOfRange(
                    "length",
                    ">= 0 && <= " + K_MAX_LENGTH,
                    totalLength
                );
            }
            total = totalLength >>> 0;
        }
        var out = Buffer.allocUnsafe(total);
        var pos = 0;
        var dptr = _viewPtr(out);
        for (var j = 0; j < list.length; j++) {
            if (pos >= total) { break; }
            var cur = list[j];
            var n = cur.length;
            if (pos + n > total) { n = total - pos; }
            // Zero-length element: skip it — `break` here abandoned every
            // later buffer, returning allocUnsafe garbage/zeros for the rest.
            if (n <= 0) { continue; }
            var sptr = _viewPtr(cur);
            if (dptr && sptr && _rawBuf && typeof _rawBuf.copy === "function") {
                _rawBuf.copy(dptr, pos, sptr, 0, n);
            } else {
                for (var k = 0; k < n; k++) {
                    _rawSetByte(dptr, pos + k, cur[k] & 0xff);
                }
            }
            pos += n;
        }
        return out;
    }

}

// Native prototype methods (buffer_native.jac): toString / subarray / slice.
// The JS methods above are registered as the slow paths they fall back to
// (unknown encodings, non-number ranges, non-view receivers).
if (_rawBuf && typeof _rawBuf.bufToStringMethod === "function" && typeof _rawBuf.setBufSlow === "function") {
    _rawBuf.setBufSlow(Buffer.prototype.toString, Buffer.prototype.subarray, Buffer.prototype);
    Object.defineProperty(Buffer.prototype, "toString", { value: _rawBuf.bufToStringMethod, writable: true, enumerable: false, configurable: true });
    Object.defineProperty(Buffer.prototype, "subarray", { value: _rawBuf.bufSubarrayMethod, writable: true, enumerable: false, configurable: true });
    Object.defineProperty(Buffer.prototype, "slice", { value: _rawBuf.bufSubarrayMethod, writable: true, enumerable: false, configurable: true });
}

Buffer.poolSize = 8192;
Buffer.kMaxLength = K_MAX_LENGTH;
Buffer.kStringMaxLength = K_STRING_MAX_LENGTH;

// Instance compare with slice ranges (Node overload).
Buffer.prototype.compare = function(other, targetStart, targetEnd, sourceStart, sourceEnd) {
    if (!_isUint8Array(other)) {
        throw _ierrs.errInvalidArgType("target", "Buffer or Uint8Array", other);
    }
    var ts = targetStart !== undefined && targetStart !== null ? targetStart : 0;
    var te = targetEnd !== undefined && targetEnd !== null ? targetEnd : other.length;
    var ss = sourceStart !== undefined && sourceStart !== null ? sourceStart : 0;
    var se = sourceEnd !== undefined && sourceEnd !== null ? sourceEnd : this.length;
    return Buffer.compare(this, other, ts, te, ss, se);
};

// Fix static compare — replace broken recursive stub above with proper impl:
Buffer.compare = function(buf1, buf2, targetStart, targetEnd, sourceStart, sourceEnd) {
    if (!_isUint8Array(buf1)) {
        throw _ierrs.errInvalidArgType("buf1", "Buffer or Uint8Array", buf1);
    }
    if (!_isUint8Array(buf2)) {
        throw _ierrs.errInvalidArgType("buf2", "Buffer or Uint8Array", buf2);
    }
    var a = buf1;
    var b = buf2;
    var ts = 0;
    var te = b.length;
    var ss = 0;
    var se = a.length;
    if (arguments.length >= 3 && typeof targetStart === "number") {
        ts = targetStart;
        te = targetEnd !== undefined ? targetEnd : b.length;
        ss = sourceStart !== undefined ? sourceStart : 0;
        se = sourceEnd !== undefined ? sourceEnd : a.length;
    }
    var aLen = se - ss;
    var bLen = te - ts;
    var min = aLen < bLen ? aLen : bLen;
    for (var i = 0; i < min; i++) {
        var av = a[ss + i] & 0xff;
        var bv = b[ts + i] & 0xff;
        if (av < bv) { return -1; }
        if (av > bv) { return 1; }
    }
    if (aLen < bLen) { return -1; }
    if (aLen > bLen) { return 1; }
    return 0;
};

function SlowBuffer(size) {
    return Buffer.allocUnsafe(size);
}

// ── Web-ish helpers on buffer module ─────────────────────────────────────────

function btoa(str) {
    return Buffer.from(String(str), "binary").toString("base64");
}

function atob(str) {
    return Buffer.from(String(str), "base64").toString("binary");
}

function isUtf8(buf) {
    if (!_isUint8Array(buf)) { return false; }
    var i = 0;
    while (i < buf.length) {
        var b0 = _bufByte(buf, i);
        if (b0 < 0x80) { i++; continue; }
        if ((b0 & 0xe0) === 0xc0) {
            if (i + 1 >= buf.length || (_bufByte(buf, i + 1) & 0xc0) !== 0x80) { return false; }
            i += 2; continue;
        }
        if ((b0 & 0xf0) === 0xe0) {
            if (i + 2 >= buf.length || (_bufByte(buf, i + 1) & 0xc0) !== 0x80 || (_bufByte(buf, i + 2) & 0xc0) !== 0x80) {
                return false;
            }
            i += 3; continue;
        }
        if ((b0 & 0xf8) === 0xf0) {
            if (i + 3 >= buf.length || (_bufByte(buf, i + 1) & 0xc0) !== 0x80 ||
                (_bufByte(buf, i + 2) & 0xc0) !== 0x80 || (_bufByte(buf, i + 3) & 0xc0) !== 0x80) {
                return false;
            }
            i += 4; continue;
        }
        return false;
    }
    return true;
}

function isAscii(buf) {
    if (typeof ArrayBuffer !== "undefined" && buf instanceof ArrayBuffer) {
        var st = new Error("Cannot perform ArrayBuffer operation on a detached ArrayBuffer");
        st.code = "ERR_INVALID_STATE";
        throw st;
    }
    if (!_isUint8Array(buf)) {
        throw _ierrs.errInvalidArgType("buffer", "Buffer, TypedArray, or DataView", buf);
    }
    for (var i = 0; i < buf.length; i++) {
        if (_bufByte(buf, i) > 0x7f) { return false; }
    }
    return true;
}

function transcode(source, fromEnc, toEnc) {
    var fe = _normalizeEnc(fromEnc);
    var te = _normalizeEnc(toEnc);
    if (fe === null) { throw _encodingError(fromEnc); }
    if (te === null) { throw _encodingError(toEnc); }
    if (!_isUint8Array(source)) {
        throw new TypeError("source must be a Buffer or Uint8Array");
    }
    var s = _bytesToStr(source, 0, source.length, fe);
    return Buffer.from(s, te);
}

// Blob / File — prefer fetch globals, else minimal Blob for buffer module tests.
var BlobExport = typeof globalThis.Blob !== "undefined" ? globalThis.Blob : null;
if (!BlobExport) {
    BlobExport = class Blob {
        constructor(parts, options) {
            options = options || {};
            this.type = options.type || "";
            this.size = 0;
            this._parts = parts || [];
            for (var i = 0; i < this._parts.length; i++) {
                var p = this._parts[i];
                if (typeof p === "string") { this.size += p.length; }
                else if (p && typeof p.length === "number") { this.size += p.length; }
            }
        }
        arrayBuffer() {
            var u8 = new Uint8Array(this.size);
            return Promise.resolve(u8.buffer);
        }
    };
}

var FileExport = class File extends BlobExport {
    constructor(bits, name, options) {
        super(bits, options);
        this.name = name;
        this.lastModified = (options && options.lastModified) || Date.now();
    }
};

function resolveObjectURL(url) {
    if (typeof url !== "string") {
        throw new TypeError("url must be a string");
    }
    return url;
}

// Ensure JSON.stringify(Buffer) uses Node-shaped toJSON output.
Buffer.prototype.toJSON = function bufferToJSON() {
    var arr = [];
    for (var i = 0; i < this.length; i++) { arr.push(this[i] & 0xff); }
    return { type: "Buffer", data: arr };
};

// NOTE: no JSON.stringify wrapper is needed here. The serializer already calls
// `toJSON` on any value that has one (SerializeJSONProperty, ES §25.5.2.2), which
// is why the Buffer.prototype.toJSON above is sufficient — and it works at every
// depth, whereas a top-level wrapper only ever fixed `JSON.stringify(buf)` and
// missed `JSON.stringify({b: buf})`. Wrapping also replaced the native function
// with a JS one on the hot path and clobbered its `name`. (adel_fixes re-added
// that wrapper; dropped — it is a correctness regression and a hot-path cost.)

globalThis.Buffer = Buffer;

module.exports = {
    Buffer: Buffer,
    SlowBuffer: SlowBuffer,
    INSPECT_MAX_BYTES: INSPECT_MAX_BYTES,
    kMaxLength: K_MAX_LENGTH,
    kStringMaxLength: K_STRING_MAX_LENGTH,
    constants: {
        MAX_LENGTH: K_MAX_LENGTH,
        MAX_STRING_LENGTH: K_STRING_MAX_LENGTH
    },
    transcode: transcode,
    isUtf8: isUtf8,
    isAscii: isAscii,
    atob: atob,
    btoa: btoa,
    Blob: BlobExport,
    File: FileExport,
    resolveObjectURL: resolveObjectURL
};
