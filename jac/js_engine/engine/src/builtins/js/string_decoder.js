/**
 * node:string_decoder — handles multi-byte UTF-8 characters split across
 * Buffer chunks.
 *
 * Node.js reference: https://nodejs.org/api/string_decoder.html
 *
 * The key problem this solves: if you receive a multi-byte UTF-8 character
 * split across two network packets (Buffers), naively decoding each Buffer
 * independently would produce garbled output.  StringDecoder buffers
 * incomplete sequences and joins them across .write() calls.
 *
 * Supported encodings: utf8/utf-8, ascii, latin1/binary, hex, base64,
 *                      utf16le/ucs2/ucs-2.
 */

// ── Encoding normaliser ──────────────────────────────────────────────────────

function _normalizeEncoding(enc) {
    if (enc === null || enc === undefined || enc === "") { return "utf8"; }
    var e = enc.toLowerCase();
    if (e === "utf8" || e === "utf-8")           { return "utf8"; }
    if (e === "ascii")                            { return "ascii"; }
    if (e === "latin1" || e === "binary")         { return "latin1"; }
    if (e === "hex")                              { return "hex"; }
    if (e === "base64")                           { return "base64"; }
    if (e === "utf16le" || e === "ucs2" || e === "ucs-2") { return "utf16le"; }
    return "utf8";
}

// ── Byte-length helpers for multi-byte encodings ─────────────────────────────

/**
 * Given a leading UTF-8 byte, return how many total bytes this character is.
 */
function _utf8CharLength(leadByte) {
    if (leadByte < 0x80)       { return 1; }
    if ((leadByte & 0xe0) === 0xc0) { return 2; }
    if ((leadByte & 0xf0) === 0xe0) { return 3; }
    if ((leadByte & 0xf8) === 0xf0) { return 4; }
    return 1;  // invalid lead → treated as 1-byte replacement
}

/**
 * Given a leading UTF-16LE unit, return whether we need 2 or 4 bytes.
 * UTF-16LE is always 2 bytes per code unit; surrogates need 4.
 */
function _utf16leCharLength(b0, b1) {
    var unit = b0 | (b1 << 8);
    if (unit >= 0xd800 && unit <= 0xdbff) { return 4; }
    return 2;
}

// ── Internal: decode a complete buffer slice to string for a given encoding ──

function _decodeSlice(buf, start, end, enc) {
    if (start >= end) { return ""; }
    if (enc === "utf8") {
        return _decodeUtf8(buf, start, end);
    }
    if (enc === "ascii") {
        var s = "";
        for (var i = start; i < end; i++) {
            s += String.fromCharCode(buf[i] & 0x7f);
        }
        return s;
    }
    if (enc === "latin1") {
        var s = "";
        for (var i = start; i < end; i++) {
            s += String.fromCharCode(buf[i] & 0xff);
        }
        return s;
    }
    if (enc === "hex") {
        var s = "";
        var hexChars = "0123456789abcdef";
        for (var i = start; i < end; i++) {
            var b = buf[i] & 0xff;
            s += hexChars[(b >> 4) & 0xf];
            s += hexChars[b & 0xf];
        }
        return s;
    }
    if (enc === "base64") {
        return _encodeBase64(buf, start, end);
    }
    if (enc === "utf16le") {
        return _decodeUtf16le(buf, start, end);
    }
    // Fallback: utf8
    return _decodeUtf8(buf, start, end);
}

/** Decode a UTF-8 byte sequence, handling multi-byte chars. */
function _decodeUtf8(buf, start, end) {
    var result = "";
    var i = start;
    while (i < end) {
        var b0 = buf[i] & 0xff;
        if (b0 < 0x80) {
            result += String.fromCharCode(b0);
            i++;
        } else if ((b0 & 0xe0) === 0xc0 && i + 1 < end) {
            var c = ((b0 & 0x1f) << 6) | (buf[i + 1] & 0x3f);
            result += String.fromCharCode(c);
            i += 2;
        } else if ((b0 & 0xf0) === 0xe0 && i + 2 < end) {
            var c = ((b0 & 0x0f) << 12) | ((buf[i + 1] & 0x3f) << 6) | (buf[i + 2] & 0x3f);
            result += String.fromCharCode(c);
            i += 3;
        } else if ((b0 & 0xf8) === 0xf0 && i + 3 < end) {
            var cp = ((b0 & 0x07) << 18) | ((buf[i + 1] & 0x3f) << 12) |
                     ((buf[i + 2] & 0x3f) << 6) | (buf[i + 3] & 0x3f);
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

/** Decode UTF-16LE bytes to string. */
function _decodeUtf16le(buf, start, end) {
    var result = "";
    var i = start;
    while (i + 1 < end) {
        var unit = (buf[i] & 0xff) | ((buf[i + 1] & 0xff) << 8);
        result += String.fromCharCode(unit);
        i += 2;
    }
    return result;
}

/** Base64-encode a byte slice. */
function _encodeBase64(buf, start, end) {
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var result = "";
    var i = start;
    while (i < end) {
        var b0 = buf[i] & 0xff;
        if (i + 2 < end) {
            var b1 = buf[i + 1] & 0xff;
            var b2 = buf[i + 2] & 0xff;
            result += chars[b0 >> 2];
            result += chars[((b0 & 3) << 4) | (b1 >> 4)];
            result += chars[((b1 & 15) << 2) | (b2 >> 6)];
            result += chars[b2 & 63];
            i += 3;
        } else if (i + 1 < end) {
            var b1 = buf[i + 1] & 0xff;
            result += chars[b0 >> 2];
            result += chars[((b0 & 3) << 4) | (b1 >> 4)];
            result += chars[((b1 & 15) << 2)];
            result += "=";
            i += 2;
        } else {
            result += chars[b0 >> 2];
            result += chars[(b0 & 3) << 4];
            result += "==";
            i += 1;
        }
    }
    return result;
}

// ── StringDecoder class ──────────────────────────────────────────────────────

/**
 * new StringDecoder(encoding?)
 *
 * Creates a decoder that buffers incomplete multi-byte character sequences
 * and produces correct decoded strings.
 */
function StringDecoder(encoding) {
    this.encoding = _normalizeEncoding(encoding);
    // Internal buffer for incomplete multi-byte sequences
    // Stored as a plain array of byte values (0-255)
    this._buf = [];
    // Number of bytes needed to complete the current character
    this._needed = 0;
    // Total bytes expected for the current incomplete character
    this._charLen = 0;
}

/**
 * decoder.write(buffer) → string
 *
 * Decodes the buffer and returns a string, buffering any incomplete
 * multi-byte character at the end for the next write.
 */
StringDecoder.prototype.write = function(buffer) {
    if (buffer === undefined || buffer === null) { return ""; }

    // Accept string input directly
    if (typeof buffer === "string") { return buffer; }

    var len = buffer.length;
    if (len === 0) { return ""; }

    var enc = this.encoding;

    // For single-byte encodings, no buffering needed
    if (enc === "ascii" || enc === "latin1" || enc === "hex") {
        return _decodeSlice(buffer, 0, len, enc);
    }

    if (enc === "base64") {
        // Base64 needs groups of 3 bytes; buffer remainder
        var available = this._buf.length + len;
        var usable = available - (available % 3);

        // Merge internal buffer + new bytes
        var merged = [];
        for (var mi = 0; mi < this._buf.length; mi++) { merged.push(this._buf[mi]); }
        for (var mi = 0; mi < len; mi++) { merged.push(buffer[mi] & 0xff); }

        var toDecodeLen = usable;
        if (toDecodeLen > merged.length) { toDecodeLen = merged.length; }

        // Keep leftover
        this._buf = [];
        for (var mi = toDecodeLen; mi < merged.length; mi++) {
            this._buf.push(merged[mi]);
        }

        if (toDecodeLen === 0) { return ""; }
        return _decodeSlice(merged, 0, toDecodeLen, "base64");
    }

    if (enc === "utf16le") {
        return _doWriteUtf16le(this, buffer, len);
    }

    // ── UTF-8 path (the important one) ──────────────────────────────
    return _doWriteUtf8(this, buffer, len);
};

/**
 * Module-level UTF-8 write (avoids prototype dispatch which breaks with >20 functions).
 * Takes an explicit `decoder` parameter instead of `this`.
 */
function _doWriteUtf8(decoder, buffer, len) {
    var result = "";
    var offset = 0;

    // 1. If we have leftover bytes from a previous write, try to complete them
    if (decoder._buf.length > 0) {
        // Fill internal buffer until we have enough bytes for the character
        while (decoder._buf.length < decoder._charLen && offset < len) {
            decoder._buf.push(buffer[offset] & 0xff);
            offset++;
        }
        if (decoder._buf.length >= decoder._charLen) {
            // Complete character — decode it
            result += _decodeUtf8(decoder._buf, 0, decoder._charLen);
            decoder._buf = [];
            decoder._needed = 0;
            decoder._charLen = 0;
        } else {
            // Still incomplete — need more data
            decoder._needed = decoder._charLen - decoder._buf.length;
            return "";
        }
    }

    // 2. Find how many complete characters we can decode from the remaining input
    var completeEnd = len;

    // Check the last few bytes for an incomplete trailing sequence
    if (len > 0) {
        var trailCheck = _utf8IncompleteEnd(buffer, offset, len);
        if (trailCheck > 0) {
            completeEnd = len - trailCheck;
            // Buffer the trailing incomplete bytes
            decoder._buf = [];
            for (var ti = completeEnd; ti < len; ti++) {
                decoder._buf.push(buffer[ti] & 0xff);
            }
            decoder._charLen = _utf8CharLength(decoder._buf[0]);
            decoder._needed = decoder._charLen - decoder._buf.length;
        }
    }

    // 3. Decode the complete portion
    if (offset < completeEnd) {
        result += _decodeUtf8(buffer, offset, completeEnd);
    }

    return result;
}

/**
 * UTF-8 write with incomplete sequence buffering.
 * Prototype method kept for external callers; delegates to _doWriteUtf8.
 */
StringDecoder.prototype._writeUtf8 = function(buffer, len) {
    return _doWriteUtf8(this, buffer, len);
};

/**
 * Check how many bytes at the end of a buffer are part of an incomplete
 * UTF-8 character.  Returns 0 if the buffer ends on a character boundary.
 */
function _utf8IncompleteEnd(buf, start, end) {
    // Walk backwards from end, looking for a leading byte
    var i = end - 1;
    // Check up to 3 bytes back (max continuation bytes)
    var maxBack = 3;
    if (i - maxBack < start) { maxBack = i - start; }

    // Find the last leading byte (non-continuation byte)
    var checked = 0;
    while (checked <= maxBack && i >= start) {
        var b = buf[i] & 0xff;
        if ((b & 0xc0) !== 0x80) {
            // This is a leading byte
            var expectedLen = _utf8CharLength(b);
            var available = end - i;
            if (available < expectedLen) {
                return available;  // incomplete: these bytes are partial
            }
            return 0;  // complete: enough bytes for this character
        }
        i--;
        checked++;
    }
    return 0;
}

/**
 * Module-level UTF-16LE write (avoids prototype dispatch which breaks with >20 functions).
 */
function _doWriteUtf16le(decoder, buffer, len) {
    var result = "";
    var offset = 0;

    // Prepend any leftover byte from previous write
    if (decoder._buf.length > 0) {
        // We had one leftover byte, combine with first byte of new buffer
        if (offset < len) {
            decoder._buf.push(buffer[offset] & 0xff);
            offset++;
        }
        // If we now have a pair, decode it
        if (decoder._buf.length >= 2) {
            result += _decodeUtf16le(decoder._buf, 0, 2);
            decoder._buf = [];
        }
    }

    // Decode pairs from offset..len, buffer odd trailing byte
    var remaining = len - offset;
    var useLen = remaining - (remaining % 2);  // even number of bytes

    if (useLen > 0) {
        result += _decodeUtf16le(buffer, offset, offset + useLen);
    }

    // Buffer odd trailing byte
    if (remaining % 2 !== 0) {
        decoder._buf = [buffer[len - 1] & 0xff];
    }

    return result;
}

/**
 * UTF-16LE write with incomplete sequence buffering.
 * Prototype method kept for external callers; delegates to _doWriteUtf16le.
 */
StringDecoder.prototype._writeUtf16le = function(buffer, len) {
    return _doWriteUtf16le(this, buffer, len);
};

/**
 * decoder.end(buffer?) → string
 *
 * Flushes any remaining bytes in the internal buffer as a decoded string.
 * After this call, the decoder is reset and can be reused.
 */
StringDecoder.prototype.end = function(buffer) {
    var result = "";
    if (buffer !== undefined && buffer !== null) {
        result = this.write(buffer);
    }

    // Flush any remaining buffered bytes
    if (this._buf.length > 0) {
        var enc = this.encoding;
        if (enc === "utf8") {
            // Incomplete UTF-8: emit replacement character(s)
            for (var fi = 0; fi < this._buf.length; fi++) {
                result += String.fromCharCode(0xfffd);
            }
        } else if (enc === "utf16le") {
            // Odd trailing byte: emit as-is
            for (var fi = 0; fi < this._buf.length; fi++) {
                result += String.fromCharCode(this._buf[fi]);
            }
        } else if (enc === "base64") {
            // Flush remaining 1 or 2 bytes as base64 with padding
            if (this._buf.length > 0) {
                result += _encodeBase64(this._buf, 0, this._buf.length);
            }
        } else {
            // ascii, latin1, hex: decode remaining
            result += _decodeSlice(this._buf, 0, this._buf.length, enc);
        }
        this._buf = [];
        this._needed = 0;
        this._charLen = 0;
    }
    return result;
};

/**
 * decoder.text(buf, offset?) — alias for write used by some stream internals
 */
StringDecoder.prototype.text = StringDecoder.prototype.write;

// ── Exports ──────────────────────────────────────────────────────────────────

module.exports = { StringDecoder: StringDecoder };
