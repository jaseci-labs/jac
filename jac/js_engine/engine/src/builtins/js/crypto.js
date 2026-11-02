/**
 * crypto.js — Node.js v22 `crypto` / `node:crypto` + Web Crypto API
 *
 * Native primitives via globalThis.__crypto (OpenSSL/libcrypto).
 * Binary data via Buffer (builtins/js/buffer.js) and __buf.
 */

function _nc() {
    if (!globalThis.__crypto) {
        throw new Error("crypto: __crypto native bridge is not available");
    }
    return globalThis.__crypto;
}

// Retrieve the most recent OpenSSL error code and throw with a formatted
// message.  Falls back to a generic message when the queue is empty.
// getLastError() returns the raw integer error code as a JS double (or 0).
function _openSSLError(context) {
    var code = 0;
    try { code = _nc().getLastError(); } catch (e) {}
    if (typeof code === "number" && code > 0) {
        throw new Error("OpenSSL error 0x" + Math.floor(code).toString(16) + " [" + context + "]");
    }
    throw new Error(context + " failed");
}
var _bufApi = globalThis.__buf;

function _getBuffer() {
    if (typeof globalThis !== "undefined" && globalThis.Buffer) {
        return globalThis.Buffer;
    }
    try {
        return require("buffer").Buffer;
    } catch (e) {
        return null;
    }
}

var Buffer = _getBuffer();

function _isBufferLike(v) {
    return v && (v.__isBuf === true || (typeof Uint8Array !== "undefined" && v instanceof Uint8Array));
}

function _toBuffer(input, encoding) {
    if (!Buffer) throw new Error("Buffer is not available");
    if (_isBufferLike(input)) {
        if (input.__isBuf) {
            var out = Buffer.alloc(input.length);
            for (var i = 0; i < input.length; i++) {
                out[i] = (input._readAt ? input._readAt(i) : input[i]);
            }
            return out;
        }
        return Buffer.from(input);
    }
    if (typeof input === "string") {
        return Buffer.from(input, encoding || "utf8");
    }
    if (input && typeof input === "object" && typeof input.length === "number") {
        return Buffer.from(input);
    }
    throw new TypeError("Invalid input");
}

function _ptrFromBuffer(b, off, len) {
    off = off || 0;
    len = len === undefined ? b.length - off : len;
    var ptr = _bufApi.alloc(len);
    for (var i = 0; i < len; i++) {
        var bv = (b._readAt ? b._readAt(off + i) : b[off + i]);
        _bufApi.setByte(ptr, i, bv & 0xff);
    }
    return { ptr: ptr, len: len };
}

function _freePtr(p) {
    if (p && p.ptr) _bufApi.free(p.ptr);
}

function _bufferFromHex(hex) {
    if (!Buffer) throw new Error("Buffer is not available");
    return Buffer.from(hex, "hex");
}

function _normalizeHashAlgo(algo) {
    var a = String(algo).toLowerCase();
    if (a === "sha-256") return "sha256";
    if (a === "sha-384") return "sha384";
    if (a === "sha-512") return "sha512";
    if (a === "sha-1") return "sha1";
    return a;
}

// ── createHash / hash ───────────────────────────────────────────────────────

function createHash(algorithm, options) {
    var algo = _normalizeHashAlgo(algorithm);
    var hid = _nc().hashNew(algo);
    if (!hid) throw new Error("Digest method not supported");
    var state = { _hid: hid, _algo: algo };
    state.update = function (data, inputEncoding) {
        // Hand the native side the Buffer / typed array itself: it hashes the
        // view's bytes in place. Copying them into a scratch allocation one byte
        // at a time from JS (_ptrFromBuffer) cost ~35 us/byte — the SHA-1 ETag
        // Vite's dev server computes per response took ~35 s for a 1 MB module.
        var view = (typeof data === "string") ? Buffer.from(data, inputEncoding || "utf8")
            : (_isBufferLike(data) && !data.__isBuf) ? data : _toBuffer(data, inputEncoding);
        if (_nc().hashUpdate(hid, view) !== 1) {
            var p = _ptrFromBuffer(view);
            _nc().hashUpdate(hid, p.ptr, p.len);
            _freePtr(p);
        }
        return state;
    };
    state.digest = function (outputEncoding) {
        var hex = _nc().hashFinal(hid);
        state._hid = 0;
        if (hex === "") _openSSLError("digest");
        if (outputEncoding === "hex") return hex;
        if (outputEncoding === "latin1" || outputEncoding === "binary") {
            return _bufferFromHex(hex).toString("latin1");
        }
        // Any other named encoding (base64, base64url, …) is a string as well;
        // only a missing encoding yields a Buffer (Node). The `etag` package
        // calls digest('base64').substring(…) on every dev-server response.
        if (typeof outputEncoding === "string" && outputEncoding !== "buffer") {
            return _bufferFromHex(hex).toString(outputEncoding);
        }
        return _bufferFromHex(hex);
    };
    return state;
}

function hash(algorithm, data, outputEncoding, options) {
    var h = createHash(algorithm, options);
    h.update(data);
    return h.digest(outputEncoding);
}

// ── createHmac ────────────────────────────────────────────────────────────────

function _hmacKeyToBuffer(key) {
    if (isKeyObject(key)) {
        var s = _requireSlots(key);
        if (s.type !== "secret") {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "key" argument must be a secret KeyObject');
        }
        return s.secret;
    }
    if (typeof key === "string" || _isBufferLike(key) ||
        (typeof ArrayBuffer !== "undefined" && key instanceof ArrayBuffer)) {
        return _toBuffer(key);
    }
    throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
        'The "key" argument must be of type string or an instance of ' +
        "ArrayBuffer, Buffer, TypedArray, DataView, or KeyObject");
}

function createHmac(algorithm, key) {
    var algo = _normalizeHashAlgo(algorithm);
    var keyBuf = _hmacKeyToBuffer(key);
    var state = { _algo: algo, _key: keyBuf, _chunks: [] };
    state.update = function (data, inputEncoding) {
        state._chunks.push(_toBuffer(data, inputEncoding));
        return state;
    };
    state.digest = function (outputEncoding) {
        var total = 0;
        var i;
        for (i = 0; i < state._chunks.length; i++) total += state._chunks[i].length;
        var data = Buffer.alloc(total);
        var off = 0;
        for (i = 0; i < state._chunks.length; i++) {
            state._chunks[i].copy(data, off);
            off += state._chunks[i].length;
        }
        var kp = _ptrFromBuffer(state._key);
        var dp = _ptrFromBuffer(data);
        var hex = _nc().hmac(algo, kp.ptr, kp.len, dp.ptr, dp.len);
        _freePtr(kp);
        _freePtr(dp);
        if (hex === "") _openSSLError("hmac");
        if (outputEncoding === "hex") return hex;
        // Same rule as Hash#digest: any named encoding returns a string.
        if (typeof outputEncoding === "string" && outputEncoding !== "buffer") {
            return _bufferFromHex(hex).toString(outputEncoding);
        }
        return _bufferFromHex(hex);
    };
    return state;
}

// ── random ────────────────────────────────────────────────────────────────────

function randomBytes(size, callback) {
    if (typeof size === "function") {
        callback = size;
        size = undefined;
    }
    var n = size >>> 0;
    if (n > 1048576) throw new RangeError("size out of range");
    var hex = _nc().randomHex(n);
    var buf = _bufferFromHex(hex);
    if (typeof callback === "function") {
        process.nextTick(function () { callback(null, buf); });
        return;
    }
    return buf;
}

function randomFill(buf, offset, size, callback) {
    if (typeof offset === "function") {
        callback = offset;
        offset = 0;
        size = buf.length;
    } else if (typeof size === "function") {
        callback = size;
        size = buf.length - offset;
    }
    var rb = randomBytes(size);
    rb.copy(buf, offset);
    if (callback) process.nextTick(function () { callback(null, buf); });
    return buf;
}

function randomFillSync(buf, offset, size) {
    if (offset === undefined) offset = 0;
    if (size === undefined) size = buf.length - offset;
    var rb = randomBytes(size);
    rb.copy(buf, offset);
    return buf;
}

function randomInt(min, max, callback) {
    if (typeof min === "function") {
        callback = min;
        min = 0;
        max = 4294967295;
    } else if (typeof max === "function") {
        callback = max;
        max = min;
        min = 0;
    }
    if (max === undefined) {
        max = min;
        min = 0;
    }
    var range = max - min;
    if (range <= 0) throw new RangeError("Invalid interval");
    var rb = randomBytes(6);
    var v = 0;
    for (var i = 0; i < 6; i++) v = (v * 256 + rb[i]) >>> 0;
    var result = min + (v % range);
    if (callback) process.nextTick(function () { callback(null, result); });
    return result;
}

function randomUUID(options) {
    var rb = randomBytes(16);
    rb[6] = (rb[6] & 0x0f) | 0x40;
    rb[8] = (rb[8] & 0x3f) | 0x80;
    var h = rb.toString("hex");
    return h.slice(0, 8) + "-" + h.slice(8, 12) + "-" + h.slice(12, 16) + "-" + h.slice(16, 20) + "-" + h.slice(20, 32);
}

// ── timingSafeEqual ─────────────────────────────────────────────────────────────

function timingSafeEqual(a, b) {
    var ba = _toBuffer(a);
    var bb = _toBuffer(b);
    if (ba.length !== bb.length) {
        throw new RangeError("Input buffers must have the same length");
    }
    var pa = _ptrFromBuffer(ba);
    var pb = _ptrFromBuffer(bb);
    var eq = _nc().timingSafeEqual(pa.ptr, pa.len, pb.ptr, pb.len);
    _freePtr(pa);
    _freePtr(pb);
    return eq === true;
}

// ── getHashes / getCiphers / constants ──────────────────────────────────────

function getHashes() {
    return _nc().getHashes().split(",");
}

function getCiphers() {
    return _nc().getCiphers().split(",");
}

var constants = {
    RSA_PKCS1_PADDING: 1,
    RSA_SSLV23_PADDING: 2,
    RSA_NO_PADDING: 3,
    RSA_PKCS1_OAEP_PADDING: 4,
    RSA_X931_PADDING: 5,
    RSA_PKCS1_PSS_PADDING: 6,
    POINT_CONVERSION_COMPRESSED: 2,
    POINT_CONVERSION_UNCOMPRESSED: 4,
    POINT_CONVERSION_HYBRID: 6
};

// ── pbkdf2 ────────────────────────────────────────────────────────────────────

function pbkdf2Sync(password, salt, iterations, keylen, digest) {
    var pass = _toBuffer(password);
    var saltBuf = _toBuffer(salt);
    var pp = _ptrFromBuffer(pass);
    var sp = _ptrFromBuffer(saltBuf);
    var dig = digest ? _normalizeHashAlgo(digest) : "sha1";
    var hex = _nc().pbkdf2(pp.ptr, pp.len, sp.ptr, sp.len, iterations, keylen, dig);
    _freePtr(pp);
    _freePtr(sp);
    if (hex === "") _openSSLError("pbkdf2");
    return _bufferFromHex(hex);
}

function pbkdf2(password, salt, iterations, keylen, digest, callback) {
    if (typeof digest === "function") {
        callback = digest;
        digest = "sha1";
    }
    try {
        var key = pbkdf2Sync(password, salt, iterations, keylen, digest);
        if (callback) process.nextTick(function () { callback(null, key); });
    } catch (e) {
        if (callback) process.nextTick(function () { callback(e); });
    }
}

// ── createCipheriv / createDecipheriv ─────────────────────────────────────────

function createCipheriv(algorithm, key, iv, options) {
    var algo = String(algorithm).toLowerCase();
    var keyBuf = _toBuffer(key);
    var ivBuf = iv ? _toBuffer(iv) : Buffer.alloc(0);
    var chunks = [];
    var aadChunks = [];
    var state = {
        update: function (data, inputEncoding, outputEncoding) {
            chunks.push(_toBuffer(data, inputEncoding));
            // One-shot backend: ciphertext is produced in final(); Node's
            // update() must still return a Buffer (or string w/ encoding).
            var out = Buffer.alloc(0);
            return outputEncoding ? out.toString(outputEncoding) : out;
        },
        setAAD: function (buf) {
            aadChunks.push(_toBuffer(buf));
            return state;
        },
        final: function () {
            var total = 0;
            var i;
            for (i = 0; i < chunks.length; i++) total += chunks[i].length;
            var plain = Buffer.alloc(total);
            var off = 0;
            for (i = 0; i < chunks.length; i++) {
                chunks[i].copy(plain, off);
                off += chunks[i].length;
            }
            var kp = _ptrFromBuffer(keyBuf);
            var ip = _ptrFromBuffer(ivBuf);
            var pp = _ptrFromBuffer(plain);
            var aadPtr = 0;
            var aadLen = 0;
            if (aadChunks.length > 0) {
                var at = 0;
                for (i = 0; i < aadChunks.length; i++) at += aadChunks[i].length;
                var ab = Buffer.alloc(at);
                off = 0;
                for (i = 0; i < aadChunks.length; i++) {
                    aadChunks[i].copy(ab, off);
                    off += aadChunks[i].length;
                }
                var ap = _ptrFromBuffer(ab);
                aadPtr = ap.ptr;
                aadLen = ap.len;
            }
            var hexOut;
            if (aadLen > 0) {
                hexOut = _nc().cipherEncrypt(algo, kp.ptr, kp.len, ip.ptr, ip.len, pp.ptr, pp.len, aadPtr, aadLen);
            } else {
                hexOut = _nc().cipherEncrypt(algo, kp.ptr, kp.len, ip.ptr, ip.len, pp.ptr, pp.len);
            }
            _freePtr(kp);
            _freePtr(ip);
            _freePtr(pp);
            if (hexOut === "") _openSSLError("cipherEncrypt");
            if (algo.indexOf("gcm") >= 0) {
                var ctLen = hexOut.length - 32;
                var ctHex = hexOut.slice(0, ctLen);
                var tagHex = hexOut.slice(ctLen);
                state._authTag = _bufferFromHex(tagHex);
                return _bufferFromHex(ctHex);
            }
            return _bufferFromHex(hexOut);
        },
        getAuthTag: function () {
            return state._authTag || Buffer.alloc(0);
        }
    };
    return state;
}

function createDecipheriv(algorithm, key, iv, options) {
    var algo = String(algorithm).toLowerCase();
    var keyBuf = _toBuffer(key);
    var ivBuf = _toBuffer(iv);
    var chunks = [];
    var authTag = null;
    var state = {
        update: function (data, inputEncoding, outputEncoding) {
            chunks.push(_toBuffer(data, inputEncoding));
            // One-shot backend: plaintext is produced in final(); Node's
            // update() must still return a Buffer (or string w/ encoding).
            var out = Buffer.alloc(0);
            return outputEncoding ? out.toString(outputEncoding) : out;
        },
        setAuthTag: function (tag) {
            authTag = _toBuffer(tag);
            return state;
        },
        final: function () {
            var total = 0;
            var i;
            for (i = 0; i < chunks.length; i++) total += chunks[i].length;
            var ct = Buffer.alloc(total);
            var off = 0;
            for (i = 0; i < chunks.length; i++) {
                chunks[i].copy(ct, off);
                off += chunks[i].length;
            }
            var kp = _ptrFromBuffer(keyBuf);
            var ip = _ptrFromBuffer(ivBuf);
            var cp = _ptrFromBuffer(ct);
            var tagHex = authTag ? authTag.toString("hex") : "";
            var hexOut = _nc().cipherDecrypt(algo, kp.ptr, ip.ptr, cp.ptr, cp.len, tagHex);
            _freePtr(kp);
            _freePtr(ip);
            _freePtr(cp);
            if (hexOut === "") {
                // Distinguish genuine failure (OpenSSL error) from 0-byte plaintext.
                var errCode = 0;
                try { errCode = _nc().getLastError(); } catch (e) {}
                // For GCM, empty output from non-empty ciphertext is always an
                // auth-tag failure even if ERR_get_error() returns 0.
                var isGcm = algo.indexOf("gcm") >= 0;
                if (errCode || isGcm) {
                    var hexCode = errCode ? " 0x" + Math.floor(errCode).toString(16) : "";
                    throw new Error("OpenSSL error" + hexCode + " [cipherDecrypt]");
                }
            }
            return _bufferFromHex(hexOut);
        }
    };
    return state;
}

// ── KeyObject ───────────────────────────────────────────────────────────────
//
// Native EVP_PKEY handles live in _keySlots, which is reachable only from this
// module.  Membership in it *is* the brand check: an object that merely has a
// KeyObject prototype (or a forged Symbol.hasInstance) has no slots and every
// accessor rejects it with ERR_INVALID_THIS, matching Node's NativeKeyObject.

var _keySlots = new WeakMap();

function _cryptoError(code, Ctor, msg) {
    var e = new (Ctor || Error)(msg);
    e.code = code;
    return e;
}

function _invalidThis() {
    return _cryptoError("ERR_INVALID_THIS", TypeError,
        'Value of "this" must be of type KeyObject');
}

function _slotsOf(value) {
    if (value === null || (typeof value !== "object" && typeof value !== "function")) {
        return undefined;
    }
    return _keySlots.get(value);
}

function _requireSlots(self, kinds) {
    var s = _slotsOf(self);
    if (s === undefined) throw _invalidThis();
    if (kinds && kinds.indexOf(s.type) < 0) throw _invalidThis();
    return s;
}

function isKeyObject(value) {
    return _slotsOf(value) !== undefined;
}

var _CURVE_ALIASES = {
    "P-256": "prime256v1",
    "p-256": "prime256v1",
    "secp256r1": "prime256v1",
    "P-384": "secp384r1",
    "p-384": "secp384r1",
    "P-521": "secp521r1",
    "p-521": "secp521r1"
};

function _normalizeCurve(name) {
    var n = String(name);
    if (Object.prototype.hasOwnProperty.call(_CURVE_ALIASES, n)) return _CURVE_ALIASES[n];
    return n;
}

var _RAW_KEY_TYPES = ["ed25519", "ed448", "x25519", "x448"];

function _parseKeyInfo(handle) {
    var raw = _nc().keyInfo(handle);
    if (!raw) return null;
    var parts = raw.split("|");
    if (!parts[0]) return null;
    return {
        type: parts[0],
        bits: parseInt(parts[1], 10) || 0,
        exponent: parseInt(parts[2], 10) || 0,
        curve: parts[3] || ""
    };
}

function _detailsFor(info) {
    if (info.type === "rsa" || info.type === "rsa-pss") {
        return { modulusLength: info.bits, publicExponent: BigInt(info.exponent) };
    }
    if (info.type === "ec") return { namedCurve: info.curve };
    if (info.type === "dsa" || info.type === "dh") return { modulusLength: info.bits };
    return {};
}

class KeyObject {
    constructor() {
        throw _cryptoError("ERR_ILLEGAL_CONSTRUCTOR", TypeError, "Illegal constructor");
    }

    get type() {
        return _requireSlots(this).type;
    }

    equals(otherKeyObject) {
        var a = _requireSlots(this);
        var b = _slotsOf(otherKeyObject);
        if (b === undefined) {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "otherKeyObject" argument must be an instance of KeyObject');
        }
        if (a.type !== b.type) return false;
        if (a.type === "secret") {
            if (a.secret.length !== b.secret.length) return false;
            return timingSafeEqual(a.secret, b.secret);
        }
        return _nc().keyEquals(a.handle, b.handle) === true;
    }
}

class SecretKeyObject extends KeyObject {
    get symmetricKeySize() {
        return _requireSlots(this, ["secret"]).secret.length;
    }

    export(options) {
        var s = _requireSlots(this, ["secret"]);
        var format = options && options.format;
        if (format === "jwk") {
            throw _cryptoError("ERR_CRYPTO_UNSUPPORTED_OPERATION", Error,
                "JWK export is not supported");
        }
        if (format !== undefined && format !== "buffer") {
            throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
                'The value "' + format + '" is invalid for option "format"');
        }
        return Buffer.from(s.secret);
    }
}

class AsymmetricKeyObject extends KeyObject {
    get asymmetricKeyType() {
        return _requireSlots(this, ["public", "private"]).info.type;
    }

    get asymmetricKeyDetails() {
        return _detailsFor(_requireSlots(this, ["public", "private"]).info);
    }

    export(options) {
        return _exportAsymmetric(_requireSlots(this, ["public", "private"]), options);
    }
}

class PublicKeyObject extends AsymmetricKeyObject {}
class PrivateKeyObject extends AsymmetricKeyObject {}

function _incompatible(msg) {
    return _cryptoError("ERR_CRYPTO_INCOMPATIBLE_KEY_OPTIONS", Error, msg);
}

function _exportKind(keyType, type, isPrivate) {
    if (isPrivate) {
        if (type === "pkcs8") return "pkcs8";
        if (type === "pkcs1") {
            if (keyType !== "rsa") throw _incompatible("pkcs1 is only valid for RSA keys");
            return "pkcs1";
        }
        if (type === "sec1") {
            if (keyType !== "ec") throw _incompatible("sec1 is only valid for EC keys");
            return "sec1";
        }
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
            'The value "' + type + '" is invalid for option "type"');
    }
    if (type === "spki") return "spki";
    if (type === "pkcs1") {
        if (keyType !== "rsa") throw _incompatible("pkcs1 is only valid for RSA keys");
        return "pkcs1-public";
    }
    throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
        'The value "' + type + '" is invalid for option "type"');
}

function _exportRaw(slots, format, options) {
    if (options.passphrase !== undefined || options.cipher !== undefined) {
        throw _incompatible("passphrase is not supported for raw key formats");
    }
    var keyType = slots.info.type;
    if (format === "raw-seed") {
        throw _incompatible(keyType + " keys do not support the raw-seed format");
    }
    var isEc = keyType === "ec";
    if (!isEc && _RAW_KEY_TYPES.indexOf(keyType) < 0) {
        throw _incompatible(keyType + " keys do not support the " + format + " format");
    }
    if (format === "raw-public" && options.type !== undefined) {
        if (options.type !== "compressed" && options.type !== "uncompressed") {
            throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
                'The value "' + options.type + '" is invalid for option "type"');
        }
        if (options.type === "compressed") {
            throw _cryptoError("ERR_CRYPTO_UNSUPPORTED_OPERATION", Error,
                "Compressed raw EC point export is not supported");
        }
    }
    if (format === "raw-private" && slots.type !== "private") {
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
            "raw-private is only valid for private keys");
    }
    var hex = _nc().keyExport(slots.handle, format, "der");
    if (hex === "") {
        throw _incompatible(keyType + " keys do not support the " + format + " format");
    }
    return _bufferFromHex(hex);
}

function _exportAsymmetric(slots, options) {
    options = options || {};
    var format = options.format === undefined ? "pem" : String(options.format);
    if (format === "jwk") {
        throw _cryptoError("ERR_CRYPTO_UNSUPPORTED_OPERATION", Error,
            "JWK export is not supported");
    }
    if (format === "raw-public" || format === "raw-private" || format === "raw-seed") {
        return _exportRaw(slots, format, options);
    }
    if (format !== "pem" && format !== "der") {
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
            'The value "' + format + '" is invalid for option "format"');
    }
    var isPrivate = slots.type === "private";
    var type = options.type;
    if (type === undefined) type = isPrivate ? "pkcs8" : "spki";
    var kind = _exportKind(slots.info.type, String(type), isPrivate);
    var cipher = "";
    var passphrase = "";
    if (isPrivate && (options.passphrase !== undefined || options.cipher !== undefined)) {
        cipher = options.cipher !== undefined ? String(options.cipher) : "aes-256-cbc";
        if (options.passphrase !== undefined && options.passphrase !== null) {
            if (typeof options.passphrase === "string") {
                passphrase = options.passphrase;
            } else if (Buffer.isBuffer(options.passphrase)) {
                passphrase = options.passphrase.toString("latin1");
            } else {
                passphrase = String(options.passphrase);
            }
        }
    }
    var out = _nc().keyExport(slots.handle, kind, format, cipher, passphrase);
    if (out === "") _openSSLError("keyExport");
    if (format === "pem") return out;
    return _bufferFromHex(out);
}

function _newKeyObject(Ctor, slots) {
    var obj = Object.create(Ctor.prototype);
    _keySlots.set(obj, slots);
    return obj;
}

function _wrapHandle(handle, type) {
    var info = _parseKeyInfo(handle);
    if (!info) {
        _nc().keyFree(handle);
        throw _cryptoError("ERR_CRYPTO_UNSUPPORTED_OPERATION", Error, "Unsupported key type");
    }
    var slots = { type: type, handle: handle, info: info };
    return _newKeyObject(type === "private" ? PrivateKeyObject : PublicKeyObject, slots);
}

function _invalidKeyArg(name) {
    return _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
        'The "' + name + '" argument must be of type string or an instance of ' +
        "Buffer, TypedArray, DataView, or KeyObject");
}

// Normalize the many accepted shapes of a key argument into
// { data, format, type, asymmetricKeyType, namedCurve }.
function _parseKeySpec(key, argName) {
    if (typeof key === "string") {
        return { data: Buffer.from(key, "utf8"), format: "pem" };
    }
    if (_isBufferLike(key)) {
        return { data: _toBuffer(key), format: "pem" };
    }
    if (key === null || typeof key !== "object") throw _invalidKeyArg(argName);

    var inner = key.key;
    var format = key.format === undefined ? "pem" : String(key.format);
    if (format === "raw-public" || format === "raw-private" || format === "raw-seed") {
        if (!_isBufferLike(inner)) throw _invalidKeyArg("key.key");
        if (typeof key.asymmetricKeyType !== "string") {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "key.asymmetricKeyType" argument must be of type string');
        }
        return {
            data: _toBuffer(inner),
            format: format,
            asymmetricKeyType: key.asymmetricKeyType,
            namedCurve: key.namedCurve
        };
    }
    if (isKeyObject(inner)) throw _invalidKeyArg(argName);
    if (typeof inner === "string") {
        return { data: Buffer.from(inner, key.encoding || "utf8"), format: format, type: key.type };
    }
    if (_isBufferLike(inner)) {
        return { data: _toBuffer(inner), format: format, type: key.type };
    }
    throw _invalidKeyArg("key.key");
}

function _importRaw(spec, want) {
    var t = String(spec.asymmetricKeyType);
    if (t === "ec") {
        var curve = spec.namedCurve;
        if (typeof curve !== "string") {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "key.namedCurve" argument must be of type string');
        }
        if (_RAW_KEY_TYPES.indexOf(curve) >= 0 ||
            !Object.prototype.hasOwnProperty.call(_CURVE_ALIASES, curve)) {
            throw _cryptoError("ERR_CRYPTO_INVALID_CURVE", Error, "Invalid EC curve name");
        }
        throw _cryptoError("ERR_CRYPTO_UNSUPPORTED_OPERATION", Error,
            "Raw EC key import is not supported");
    }
    if (_RAW_KEY_TYPES.indexOf(t) < 0) {
        if (t === "rsa" || t === "dsa" || t === "dh") {
            throw _incompatible(t + " keys do not support raw key formats");
        }
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
            "Invalid asymmetricKeyType: " + t);
    }
    if (spec.format === "raw-seed") {
        throw _incompatible(t + " keys do not support the raw-seed format");
    }
    if (want === "private" && spec.format === "raw-public") {
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
            "raw-public cannot be imported as a private key");
    }
    var p = _ptrFromBuffer(spec.data);
    var handle = _nc().keyImport(p.ptr, p.len, spec.format, want, t, "");
    _freePtr(p);
    if (!handle) {
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError, "Invalid raw key material");
    }
    return _wrapHandle(handle, want);
}

function _importKey(spec, want) {
    if (spec.format === "raw-public" || spec.format === "raw-private" ||
        spec.format === "raw-seed") {
        return _importRaw(spec, want);
    }
    if (spec.format !== "pem" && spec.format !== "der") {
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
            'The value "' + spec.format + '" is invalid for option "format"');
    }
    var kind = want;
    if (want === "public" && spec.format === "der" && spec.type === "pkcs1") {
        kind = "pkcs1";
    }
    var p = _ptrFromBuffer(spec.data);
    var handle = _nc().keyImport(p.ptr, p.len, spec.format, kind, "", "");
    _freePtr(p);
    if (!handle) {
        throw _cryptoError("ERR_CRYPTO_INVALID_KEYPAIR", Error,
            "Failed to read " + want + " key");
    }
    return _wrapHandle(handle, want);
}

function createSecretKey(key, encoding) {
    var buf;
    if (typeof key === "string") {
        buf = Buffer.from(key, encoding || "utf8");
    } else if (_isBufferLike(key)) {
        buf = _toBuffer(key);
    } else {
        throw _invalidKeyArg("key");
    }
    return _newKeyObject(SecretKeyObject, { type: "secret", secret: buf });
}

function createPrivateKey(key) {
    if (isKeyObject(key)) {
        var s = _requireSlots(key);
        if (s.type !== "private") {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "key" argument must be a private KeyObject');
        }
        return key;
    }
    return _importKey(_parseKeySpec(key, "key"), "private");
}

function createPublicKey(key) {
    if (isKeyObject(key)) {
        var s = _requireSlots(key);
        if (s.type === "public") return key;
        if (s.type !== "private") {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "key" argument must be an asymmetric KeyObject');
        }
        var derived = _nc().keyPublicOf(s.handle);
        if (!derived) _openSSLError("createPublicKey");
        return _wrapHandle(derived, "public");
    }
    return _importKey(_parseKeySpec(key, "key"), "public");
}

// ── generateKeyPair ─────────────────────────────────────────────────────────

var _GENERATABLE = ["rsa", "ec", "ed25519", "ed448", "x25519", "x448", "dh"];
var _KNOWN_KEY_TYPES = ["rsa", "rsa-pss", "dsa", "ec", "ed25519", "ed448",
                        "x25519", "x448", "dh"];

function _encodeWith(keyObject, encoding) {
    if (!encoding) return keyObject;
    return _exportAsymmetric(_requireSlots(keyObject), encoding);
}

function generateKeyPairSync(type, options) {
    if (typeof type !== "string") {
        throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
            'The "type" argument must be of type string');
    }
    var t = type.toLowerCase();
    if (_GENERATABLE.indexOf(t) < 0) {
        if (_KNOWN_KEY_TYPES.indexOf(t) >= 0) {
            throw _cryptoError("ERR_CRYPTO_UNSUPPORTED_OPERATION", Error,
                "'" + type + "' key generation is not supported");
        }
        throw _cryptoError("ERR_INVALID_ARG_VALUE", TypeError,
            "The argument 'type' must be a supported key type. Received '" + type + "'");
    }
    options = options || {};
    var bits = 0;
    var expo = 0;
    var curve = "";
    if (t === "rsa") {
        if (typeof options.modulusLength !== "number") {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "options.modulusLength" property must be of type number');
        }
        bits = options.modulusLength >>> 0;
        expo = options.publicExponent === undefined ? 65537 : Number(options.publicExponent);
    } else if (t === "ec") {
        if (typeof options.namedCurve !== "string") {
            throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
                'The "options.namedCurve" property must be of type string');
        }
        curve = _normalizeCurve(options.namedCurve);
    } else if (t === "dh") {
        bits = options.primeLength === undefined ? 2048 : (options.primeLength >>> 0);
        expo = options.generator === undefined ? 2 : Number(options.generator);
    }
    var privHandle = _nc().keygen(t, bits, expo, curve);
    if (!privHandle) {
        if (t === "ec") {
            throw _cryptoError("ERR_CRYPTO_INVALID_CURVE", Error,
                "Invalid EC curve name");
        }
        _openSSLError("generateKeyPair");
    }
    var pubHandle = _nc().keyPublicOf(privHandle);
    if (!pubHandle) {
        _nc().keyFree(privHandle);
        _openSSLError("generateKeyPair");
    }
    var privateKey = _wrapHandle(privHandle, "private");
    var publicKey = _wrapHandle(pubHandle, "public");
    return {
        publicKey: _encodeWith(publicKey, options.publicKeyEncoding),
        privateKey: _encodeWith(privateKey, options.privateKeyEncoding)
    };
}

function generateKeyPair(type, options, callback) {
    if (typeof options === "function") {
        callback = options;
        options = undefined;
    }
    if (typeof callback !== "function") {
        throw _cryptoError("ERR_INVALID_ARG_TYPE", TypeError,
            'The "callback" argument must be of type function');
    }
    var pair = null;
    var failure = null;
    try {
        pair = generateKeyPairSync(type, options);
    } catch (e) {
        failure = e;
    }
    process.nextTick(function () {
        if (failure) {
            callback(failure);
            return;
        }
        callback(null, pair.publicKey, pair.privateKey);
    });
}

if (typeof Symbol !== "undefined" && typeof Symbol.for === "function") {
    Object.defineProperty(generateKeyPair, Symbol.for("nodejs.util.promisify.custom"), {
        configurable: true,
        value: function (type, options) {
            return new Promise(function (resolve, reject) {
                generateKeyPair(type, options, function (err, publicKey, privateKey) {
                    if (err) reject(err);
                    else resolve({ publicKey: publicKey, privateKey: privateKey });
                });
            });
        }
    });
}

// util.types.isKeyObject has no way to reach this module's WeakMap directly.
if (typeof globalThis !== "undefined") {
    globalThis.__isKeyObject = isKeyObject;
}

// ── Web Crypto (Node v22 subset) ────────────────────────────────────────────

function SubtleCrypto() {}

SubtleCrypto.prototype.digest = function (algorithm, data) {
    var name = typeof algorithm === "string" ? algorithm : algorithm.name;
    name = _normalizeHashAlgo(name);
    var buf = _toBuffer(data);
    var p = _ptrFromBuffer(buf);
    var hex = _nc().hashOneshot(name, p.ptr, p.len);
    _freePtr(p);
    var out = _bufferFromHex(hex);
  if (typeof Uint8Array !== "undefined") {
        var u8 = new Uint8Array(out.length);
        for (var i = 0; i < out.length; i++) u8[i] = out[i];
        return Promise.resolve(u8.buffer);
    }
    return Promise.resolve(out);
};

SubtleCrypto.prototype.importKey = function (format, keyData, algorithm, extractable, keyUsages) {
    return Promise.resolve({
        type: "secret",
        algorithm: typeof algorithm === "string" ? { name: algorithm } : algorithm,
        extractable: !!extractable,
        usages: keyUsages || [],
        _raw: _toBuffer(keyData)
    });
};

SubtleCrypto.prototype.exportKey = function (format, key) {
    if (format === "raw") {
        var raw = key._raw || Buffer.alloc(0);
        if (typeof ArrayBuffer !== "undefined") {
            return Promise.resolve(raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength));
        }
        return Promise.resolve(raw);
    }
    return Promise.reject(new Error("Unsupported export format"));
};

SubtleCrypto.prototype.encrypt = function (algorithm, key, data) {
    var name = algorithm.name.toLowerCase();
    var iv = _toBuffer(algorithm.iv);
    var plain = _toBuffer(data);
    var c = createCipheriv(name, key._raw, iv);
    var ct = c.update(plain);
    var fin = c.final();
    var out = Buffer.concat([ct, fin]);
    if (typeof ArrayBuffer !== "undefined") {
        return Promise.resolve(out.buffer.slice(out.byteOffset, out.byteOffset + out.byteLength));
    }
    return Promise.resolve(out);
};

SubtleCrypto.prototype.decrypt = function (algorithm, key, data) {
    var name = algorithm.name.toLowerCase();
    var iv = _toBuffer(algorithm.iv);
    var ct = _toBuffer(data);
    var d = createDecipheriv(name, key._raw, iv);
    if (name.indexOf("gcm") >= 0 && algorithm.tagLength) {
        var tagLen = (algorithm.tagLength || 128) / 8;
        var tag = ct.slice(ct.length - tagLen);
        var body = ct.slice(0, ct.length - tagLen);
        d.setAuthTag(tag);
        var p1 = d.update(body);
        return Promise.resolve(Buffer.concat([p1, d.final()]));
    }
    var p1 = d.update(ct);
    return Promise.resolve(Buffer.concat([p1, d.final()]));
};

SubtleCrypto.prototype.sign = function () {
    return Promise.reject(new Error("sign not yet implemented"));
};
SubtleCrypto.prototype.verify = function () {
    return Promise.reject(new Error("verify not yet implemented"));
};
SubtleCrypto.prototype.generateKey = function () {
    return Promise.reject(new Error("generateKey not yet implemented"));
};
SubtleCrypto.prototype.deriveBits = function () {
    return Promise.reject(new Error("deriveBits not yet implemented"));
};
SubtleCrypto.prototype.deriveKey = function () {
    return Promise.reject(new Error("deriveKey not yet implemented"));
};
SubtleCrypto.prototype.wrapKey = function () {
    return Promise.reject(new Error("wrapKey not yet implemented"));
};
SubtleCrypto.prototype.unwrapKey = function () {
    return Promise.reject(new Error("unwrapKey not yet implemented"));
};

function _getRandomValues(typedArray) {
    if (!typedArray || typeof typedArray.length !== "number") {
        throw new TypeError("Expected TypedArray");
    }
    if (typedArray.length > 65536) {
        throw new QuotaExceededError("getRandomValues length limit exceeded");
    }
    var rb = randomBytes(typedArray.length);
    for (var i = 0; i < typedArray.length; i++) {
        typedArray[i] = rb[i];
    }
    return typedArray;
}

function Crypto() {
    this.subtle = new SubtleCrypto();
    this.getRandomValues = _getRandomValues;
    this.randomUUID = randomUUID;
}

function QuotaExceededError(msg) {
    this.name = "QuotaExceededError";
    this.message = msg;
}

var webcrypto = new Crypto();

// ── Module exports ──────────────────────────────────────────────────────────────

/** crypto.getFips() — FIPS mode probe. Always 0 (disabled) in js_engine. */
function getFips() {
    return 0;
}

/** crypto.setFips() — no-op when disabling; reject enabling (unsupported). */
function setFips(val) {
    if (val) {
        var err = new Error("Cannot set FIPS mode: not supported in js_engine");
        err.code = "ERR_CRYPTO_FIPS_UNAVAILABLE";
        throw err;
    }
}

module.exports = {
    createHash: createHash,
    hash: hash,
    createHmac: createHmac,
    randomBytes: randomBytes,
    randomFill: randomFill,
    randomFillSync: randomFillSync,
    randomInt: randomInt,
    randomUUID: randomUUID,
    timingSafeEqual: timingSafeEqual,
    getHashes: getHashes,
    getCiphers: getCiphers,
    getFips: getFips,
    setFips: setFips,
    constants: constants,
    pbkdf2: pbkdf2,
    pbkdf2Sync: pbkdf2Sync,
    createCipheriv: createCipheriv,
    createDecipheriv: createDecipheriv,
    KeyObject: KeyObject,
    createSecretKey: createSecretKey,
    createPrivateKey: createPrivateKey,
    createPublicKey: createPublicKey,
    generateKeyPair: generateKeyPair,
    generateKeyPairSync: generateKeyPairSync,
    webcrypto: webcrypto,
    subtle: webcrypto.subtle,
    getRandomValues: _getRandomValues,
};

if (typeof globalThis !== "undefined") {
    globalThis.crypto = webcrypto;
}
