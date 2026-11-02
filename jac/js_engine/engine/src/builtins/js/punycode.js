/**
 * node:punycode — Punycode/IDNA encoding (deprecated but still importable)
 *
 * Node.js reference: https://nodejs.org/api/punycode.html
 * RFC 3492: https://tools.ietf.org/html/rfc3492  (Punycode)
 * RFC 5891: https://tools.ietf.org/html/rfc5891  (IDNA)
 *
 * This module is deprecated since Node.js v7 in favour of the `url.URL` API,
 * but many packages still import it.
 */

// ── Punycode constants (RFC 3492 §5) ────────────────────────────────────────

var BASE         = 36;
var TMIN         = 1;
var TMAX         = 26;
var SKEW         = 38;
var DAMP         = 700;
var INITIAL_BIAS = 72;
var INITIAL_N    = 128;
var DELIMITER    = "-";

// ── Error helper ─────────────────────────────────────────────────────────────

function _error(msg) {
    throw new RangeError("punycode: " + msg);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Bias adaptation function (RFC 3492 §3.4).
 */
function _adapt(delta, numPoints, firstTime) {
    if (firstTime) {
        delta = Math.floor(delta / DAMP);
    } else {
        delta = Math.floor(delta / 2);
    }
    delta = delta + Math.floor(delta / numPoints);
    var k = 0;
    while (delta > Math.floor(((BASE - TMIN) * TMAX) / 2)) {
        delta = Math.floor(delta / (BASE - TMIN));
        k = k + BASE;
    }
    return k + Math.floor(((BASE - TMIN + 1) * delta) / (delta + SKEW));
}

/**
 * Convert a basic code point (digit) to its numeric value.
 * a-z → 0-25, 0-9 → 26-35
 */
function _basicToDigit(cp) {
    if (cp >= 48 && cp <= 57)  { return cp - 22; }  // '0'-'9' → 26-35
    if (cp >= 65 && cp <= 90)  { return cp - 65; }  // 'A'-'Z' → 0-25
    if (cp >= 97 && cp <= 122) { return cp - 97; }  // 'a'-'z' → 0-25
    return BASE;  // invalid
}

/**
 * Convert a digit (0-35) to a basic code point ('a'-'z' or '0'-'9').
 * Uses lowercase output by default.
 */
function _digitToBasic(digit) {
    if (digit < 26) { return digit + 97; }   // 0-25 → 'a'-'z'
    return digit - 26 + 48;                   // 26-35 → '0'-'9'
}

/**
 * Convert a JS string to an array of Unicode code points.
 * Handles surrogate pairs.
 */
function _ucs2decode(str) {
    var output = [];
    var len = str.length;
    var i = 0;
    while (i < len) {
        var c = str.charCodeAt(i);
        if (c >= 0xd800 && c <= 0xdbff && i + 1 < len) {
            var lo = str.charCodeAt(i + 1);
            if (lo >= 0xdc00 && lo <= 0xdfff) {
                output.push(0x10000 + ((c - 0xd800) << 10) + (lo - 0xdc00));
                i += 2;
            } else {
                output.push(c);
                i++;
            }
        } else {
            output.push(c);
            i++;
        }
    }
    return output;
}

/**
 * Convert an array of Unicode code points to a JS string.
 * Handles code points > 0xFFFF via surrogate pairs.
 */
function _ucs2encode(codePoints) {
    var result = "";
    for (var i = 0; i < codePoints.length; i++) {
        var cp = codePoints[i];
        if (cp > 0xffff) {
            cp = cp - 0x10000;
            result += String.fromCharCode(0xd800 + (cp >> 10));
            result += String.fromCharCode(0xdc00 + (cp & 0x3ff));
        } else {
            result += String.fromCharCode(cp);
        }
    }
    return result;
}

// ── Core Punycode decode (RFC 3492 §6.2) ─────────────────────────────────────

/**
 * punycode.decode(input) → string
 *
 * Decodes a Punycode-encoded string of ASCII-only symbols to a string of
 * Unicode symbols.
 */
function decode(input) {
    var output = [];
    var inputLen = input.length;

    // Find the last delimiter; everything before it is basic (ASCII) code points
    var basic = 0;
    for (var j = 0; j < inputLen; j++) {
        if (input[j] === DELIMITER) { basic = j; }
    }

    // Copy basic code points to output
    for (var j = 0; j < basic; j++) {
        var cp = input.charCodeAt(j);
        if (cp >= 0x80) { _error("not-basic"); }
        output.push(cp);
    }

    // Decode the extended (non-basic) portion
    var i = 0;
    var n = INITIAL_N;
    var bias = INITIAL_BIAS;
    var index = basic > 0 ? basic + 1 : 0;

    while (index < inputLen) {
        var oldi = i;
        var w = 1;
        var k = BASE;
        var done = false;
        while (!done) {
            if (index >= inputLen) { _error("invalid-input"); }
            var digit = _basicToDigit(input.charCodeAt(index));
            index++;
            if (digit >= BASE) { _error("invalid-input"); }
            if (digit > Math.floor((0x7fffffff - i) / w)) { _error("overflow"); }
            i = i + digit * w;
            var t = k <= bias ? TMIN : (k >= bias + TMAX ? TMAX : k - bias);
            if (digit < t) {
                done = true;
            } else {
                if (w > Math.floor(0x7fffffff / (BASE - t))) { _error("overflow"); }
                w = w * (BASE - t);
                k = k + BASE;
            }
        }
        var out = output.length + 1;
        bias = _adapt(i - oldi, out, oldi === 0);
        if (Math.floor(i / out) > 0x7fffffff - n) { _error("overflow"); }
        n = n + Math.floor(i / out);
        i = i % out;

        // Insert code point at position i
        output.splice(i, 0, n);
        i++;
    }

    return _ucs2encode(output);
}

// ── Core Punycode encode (RFC 3492 §6.3) ─────────────────────────────────────

/**
 * punycode.encode(input) → string
 *
 * Encodes a string of Unicode symbols to a Punycode string of ASCII-only symbols.
 */
function encode(input) {
    var codePoints = _ucs2decode(input);
    var inputLen = codePoints.length;

    // Separate basic and non-basic code points
    var output = "";
    var basicCount = 0;
    for (var j = 0; j < inputLen; j++) {
        var cp = codePoints[j];
        if (cp < 0x80) {
            output += String.fromCharCode(cp);
            basicCount++;
        }
    }

    if (basicCount > 0) {
        output += DELIMITER;
    }

    var n = INITIAL_N;
    var delta = 0;
    var bias = INITIAL_BIAS;
    var h = basicCount;

    while (h < inputLen) {
        // Find the minimum non-basic code point >= n
        var m = 0x7fffffff;
        for (var j = 0; j < inputLen; j++) {
            var cp = codePoints[j];
            if (cp >= n && cp < m) { m = cp; }
        }

        if (m - n > Math.floor((0x7fffffff - delta) / (h + 1))) { _error("overflow"); }
        delta = delta + (m - n) * (h + 1);
        n = m;

        for (var j = 0; j < inputLen; j++) {
            var cp = codePoints[j];
            if (cp < n) {
                delta++;
                if (delta > 0x7fffffff) { _error("overflow"); }
            }
            if (cp === n) {
                var q = delta;
                var k = BASE;
                var done2 = false;
                while (!done2) {
                    var t = k <= bias ? TMIN : (k >= bias + TMAX ? TMAX : k - bias);
                    if (q < t) {
                        done2 = true;
                    } else {
                        output += String.fromCharCode(_digitToBasic(t + ((q - t) % (BASE - t))));
                        q = Math.floor((q - t) / (BASE - t));
                        k = k + BASE;
                    }
                }
                output += String.fromCharCode(_digitToBasic(q));
                bias = _adapt(delta, h + 1, h === basicCount);
                delta = 0;
                h++;
            }
        }
        delta++;
        n++;
    }

    return output;
}

// ── Domain-level IDNA functions ──────────────────────────────────────────────

/**
 * Split a domain into labels, apply a mapping function, rejoin.
 */
function _mapDomain(domain, fn) {
    var parts = domain.split(".");
    var mapped = [];
    for (var i = 0; i < parts.length; i++) {
        mapped.push(fn(parts[i]));
    }
    return mapped.join(".");
}

/**
 * punycode.toASCII(domain) → string
 *
 * Converts a Unicode domain name to an ASCII-compatible (Punycode) representation.
 * Non-ASCII labels are prefixed with "xn--".
 */
function toASCII(domain) {
    return _mapDomain(domain, function(label) {
        // Check if label has any non-ASCII characters
        var hasNonASCII = false;
        for (var i = 0; i < label.length; i++) {
            if (label.charCodeAt(i) >= 0x80) {
                hasNonASCII = true;
                break;
            }
        }
        if (hasNonASCII) {
            return "xn--" + encode(label);
        }
        return label;
    });
}

/**
 * punycode.toUnicode(domain) → string
 *
 * Converts an ASCII-compatible (Punycode) domain to Unicode.
 * "xn--" prefixed labels are decoded.
 */
function toUnicode(domain) {
    return _mapDomain(domain, function(label) {
        if (label.length > 4 && label[0] === "x" && label[1] === "n" &&
            label[2] === "-" && label[3] === "-") {
            return decode(label.substring(4));
        }
        return label;
    });
}

// ── UCS-2 helpers (exposed as properties) ────────────────────────────────────

var ucs2 = {
    decode: _ucs2decode,
    encode: _ucs2encode
};

// ── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
    decode: decode,
    encode: encode,
    toASCII: toASCII,
    toUnicode: toUnicode,
    ucs2: ucs2,
    version: "2.3.1"
};
