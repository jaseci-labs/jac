/**
 * text_codec.js — global TextEncoder / TextDecoder (WHATWG Encoding minimal)
 *
 * Vite V-16: parse5, magic-string, and other deps expect these globals.
 * Loaded after binary_types.js (needs Uint8Array).
 */

function _normalizeLabel(label) {
    if (label === undefined || label === null || label === "") {
        return "utf-8";
    }
    var e = String(label).toLowerCase();
    if (e === "utf8" || e === "utf-8") {
        return "utf-8";
    }
    return e;
}

function _taByte(view, i) {
    if (view && typeof view._readAt === "function") {
        return view._readAt(i) & 0xff;
    }
    return view[i] & 0xff;
}

function _bytesFromBufferSource(input) {
    if (input === undefined || input === null) {
        return [];
    }
    if (typeof Uint8Array !== "undefined" && input instanceof Uint8Array) {
        var out = [];
        for (var i = 0; i < input.length; i++) {
            out.push(_taByte(input, i));
        }
        return out;
    }
    if (input && typeof input === "object" && input.buffer instanceof ArrayBuffer) {
        var off = input.byteOffset || 0;
        var len = input.byteLength !== undefined ? input.byteLength : input.length;
        var view = new Uint8Array(input.buffer, off, len);
        var arr = [];
        for (var j = 0; j < view.length; j++) {
            arr.push(_taByte(view, j));
        }
        return arr;
    }
    if (typeof ArrayBuffer !== "undefined" && input instanceof ArrayBuffer) {
        var view2 = new Uint8Array(input);
        var arr2 = [];
        for (var k = 0; k < view2.length; k++) {
            arr2.push(_taByte(view2, k));
        }
        return arr2;
    }
    throw new TypeError("The input is not a valid BufferSource");
}

function _utf8EncodeString(str) {
    var bytes = [];
    var s = String(str);
    var i = 0;
    while (i < s.length) {
        var c = s.charCodeAt(i);
        if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
            var c2 = s.charCodeAt(i + 1);
            if (c2 >= 0xdc00 && c2 <= 0xdfff) {
                c = 0x10000 + ((c - 0xd800) << 10) + (c2 - 0xdc00);
                i++;
            }
        }
        if (c < 0x80) {
            bytes.push(c);
        } else if (c < 0x800) {
            bytes.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
        } else if (c < 0x10000) {
            bytes.push(
                0xe0 | (c >> 12),
                0x80 | ((c >> 6) & 0x3f),
                0x80 | (c & 0x3f)
            );
        } else {
            bytes.push(
                0xf0 | (c >> 18),
                0x80 | ((c >> 12) & 0x3f),
                0x80 | ((c >> 6) & 0x3f),
                0x80 | (c & 0x3f)
            );
        }
        i++;
    }
    return new Uint8Array(bytes);
}

function _utf8DecodeBytes(buf, start, end, fatal) {
    var result = "";
    var i = start;
    while (i < end) {
        var b0 = buf[i] & 0xff;
        if (b0 < 0x80) {
            result += String.fromCharCode(b0);
            i++;
        } else if ((b0 & 0xe0) === 0xc0) {
            if (i + 1 >= end) {
                if (fatal) {
                    throw new TypeError("Invalid UTF-8");
                }
                result += "\uFFFD";
                break;
            }
            var b1 = buf[i + 1] & 0xff;
            if ((b1 & 0xc0) !== 0x80 || (b0 & 0xfe) === 0xc0) {
                if (fatal) {
                    throw new TypeError("Invalid UTF-8");
                }
                result += "\uFFFD";
                i++;
                continue;
            }
            result += String.fromCharCode(((b0 & 0x1f) << 6) | (b1 & 0x3f));
            i += 2;
        } else if ((b0 & 0xf0) === 0xe0) {
            if (i + 2 >= end) {
                if (fatal) {
                    throw new TypeError("Invalid UTF-8");
                }
                result += "\uFFFD";
                break;
            }
            var b1e = buf[i + 1] & 0xff;
            var b2e = buf[i + 2] & 0xff;
            if ((b1e & 0xc0) !== 0x80 || (b2e & 0xc0) !== 0x80 || b0 === 0xe0 && b1e < 0xa0) {
                if (fatal) {
                    throw new TypeError("Invalid UTF-8");
                }
                result += "\uFFFD";
                i++;
                continue;
            }
            result += String.fromCharCode(
                ((b0 & 0x0f) << 12) | ((b1e & 0x3f) << 6) | (b2e & 0x3f)
            );
            i += 3;
        } else if ((b0 & 0xf8) === 0xf0) {
            if (i + 3 >= end) {
                if (fatal) {
                    throw new TypeError("Invalid UTF-8");
                }
                result += "\uFFFD";
                break;
            }
            var b1f = buf[i + 1] & 0xff;
            var b2f = buf[i + 2] & 0xff;
            var b3f = buf[i + 3] & 0xff;
            if (
                (b1f & 0xc0) !== 0x80 ||
                (b2f & 0xc0) !== 0x80 ||
                (b3f & 0xc0) !== 0x80 ||
                b0 > 0xf4 ||
                (b0 === 0xf0 && b1f < 0x90) ||
                (b0 === 0xf4 && b1f > 0x8f)
            ) {
                if (fatal) {
                    throw new TypeError("Invalid UTF-8");
                }
                result += "\uFFFD";
                i++;
                continue;
            }
            var cp =
                ((b0 & 0x07) << 18) |
                ((b1f & 0x3f) << 12) |
                ((b2f & 0x3f) << 6) |
                (b3f & 0x3f);
            cp = cp - 0x10000;
            result += String.fromCharCode(0xd800 + (cp >> 10));
            result += String.fromCharCode(0xdc00 + (cp & 0x3ff));
            i += 4;
        } else {
            if (fatal) {
                throw new TypeError("Invalid UTF-8");
            }
            result += "\uFFFD";
            i++;
        }
    }
    return result;
}

// Native hooks (globalThis.__buf, installed by global.jac before this file
// loads), resolved once so the hot decode path pays no per-call lookups.
var _bufNative = typeof globalThis !== "undefined" ? globalThis.__buf : null;
var _tdDecodeNative = (_bufNative && typeof _bufNative.tdDecode === "function") ? _bufNative.tdDecode : null;
var _teUtf8Len = (_bufNative && typeof _bufNative.utf8ByteLength === "function") ? _bufNative.utf8ByteLength : null;
var _teWriteString = (_bufNative && typeof _bufNative.writeString === "function") ? _bufNative.writeString : null;

class TextEncoder {
    constructor() {
        this.encoding = "utf-8";
    }

    encode(input) {
        if (input === undefined) {
            return new Uint8Array(0);
        }
        if (typeof input !== "string") {
            input = String(input);
        }
        // Native: wire-UTF-8 length + encode straight into a fresh Uint8Array
        // (the JS path built a byte Array and fed it through the iterable
        // constructor — ~530µs for an 11-char string).
        if (_teUtf8Len !== null && _teWriteString !== null) {
            var n = _teUtf8Len(input);
            if (n !== undefined) {
                var out = new Uint8Array(n);
                if (n > 0) { _teWriteString(out, input, 0, n, "utf8"); }
                return out;
            }
        }
        return _utf8EncodeString(input);
    }

    encodeInto(source, destination) {
        var encoded = this.encode(source);
        var written = Math.min(encoded.length, destination.length);
        for (var i = 0; i < written; i++) {
            destination[i] = encoded[i];
        }
        return { read: source.length, written: written };
    }
}

class TextDecoder {
    constructor(label, options) {
        this._encoding = _normalizeLabel(label);
        this._fatal = !!(options && options.fatal);
    }

    get encoding() {
        return this._encoding;
    }

    get fatal() {
        return this._fatal;
    }

    decode(input) {
        if (this._encoding !== "utf-8") {
            throw new RangeError("Unsupported encoding: " + this._encoding);
        }
        // Native full UTF-8 decode straight off the backing store (typed
        // array or ArrayBuffer), honouring `fatal`; undefined → JS fallback
        // (DataView input, non-BufferSource → its TypeError). The native is
        // resolved once at load (_tdDecodeNative): each `typeof`/global read
        // here costs ~0.4µs in this interpreter and decode is a hot call.
        if (_tdDecodeNative !== null) {
            var fastFull = _tdDecodeNative(input, this._fatal);
            if (fastFull !== undefined) { return fastFull; }
        }
        var g = _bufNative;
        if (g && typeof g.decodeUtf8 === "function" && input && typeof input === "object") {
            var vptr = 0;
            var vlen = -1;
            if (input._buffer && input._buffer._ptr) {
                vptr = input._buffer._ptr + (input._byteOffset | 0);
                vlen = input.byteLength !== undefined ? input.byteLength : input.length;
            } else if (input._ptr && input.byteLength !== undefined) {
                vptr = input._ptr;
                vlen = input.byteLength;
            }
            if (vptr !== 0 && vlen >= 0) {
                var fast = g.decodeUtf8(vptr, 0, vlen);
                if (fast !== undefined) { return fast; }
            }
        }
        var bytes = _bytesFromBufferSource(input);
        return _utf8DecodeBytes(bytes, 0, bytes.length, this._fatal);
    }
}

// Native `decode` (buffer_native.jac td_decode_method): the JS method above
// becomes its registered slow path (non-utf-8 labels, duck-typed sources).
if (_bufNative && typeof _bufNative.tdDecodeMethod === "function" && typeof _bufNative.setTdDecodeSlow === "function") {
    _bufNative.setTdDecodeSlow(TextDecoder.prototype.decode);
    Object.defineProperty(TextDecoder.prototype, "decode", {
        value: _bufNative.tdDecodeMethod, writable: true, enumerable: false, configurable: true
    });
}

globalThis.TextEncoder = TextEncoder;
globalThis.TextDecoder = TextDecoder;
