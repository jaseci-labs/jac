// ────────────────────────────────────────────────────────────────────────────
// builtins/js/querystring.js — Node.js `querystring` module
//
// Pure JavaScript implementation of the querystring API.
// Loaded by `require("querystring")` / `require("node:querystring")`.
//
// Node.js reference: https://nodejs.org/api/querystring.html
// Bun reference:     bun/src/js/node/querystring.ts
// ────────────────────────────────────────────────────────────────────────────

// ── Hex lookup table ────────────────────────────────────────────────────────
var hexTable = [];
var i = 0;
while (i < 256) {
    var hex = i.toString(16).toUpperCase();
    if (hex.length === 1) { hex = "0" + hex; }
    hexTable[i] = "%" + hex;
    i = i + 1;
}

// ── querystring.escape(str) ─────────────────────────────────────────────────
// Percent-encode a string for use in a query string.
// Encodes everything except: A-Z a-z 0-9 - _ . ~ ! * ' ( )
function escape(str) {
    if (typeof str !== "string") {
        str = String(str);
    }
    var out = "";
    var idx = 0;
    while (idx < str.length) {
        var c = str.charCodeAt(idx);
        // Unreserved characters (RFC 3986) plus extras matching Node.js behaviour
        if (
            (c >= 48 && c <= 57)   ||  // 0-9
            (c >= 65 && c <= 90)   ||  // A-Z
            (c >= 97 && c <= 122)  ||  // a-z
            c === 45  ||  // -
            c === 95  ||  // _
            c === 46  ||  // .
            c === 126 ||  // ~
            c === 33  ||  // !
            c === 42  ||  // *
            c === 39  ||  // '
            c === 40  ||  // (
            c === 41      // )
        ) {
            out = out + str[idx];
        } else if (c === 32) {
            // Space → +
            out = out + "+";
        } else if (c < 128) {
            out = out + hexTable[c];
        } else if (c < 2048) {
            // 2-byte UTF-8
            out = out + hexTable[192 | (c >> 6)] + hexTable[128 | (c & 63)];
        } else if (c < 55296 || c >= 57344) {
            // 3-byte UTF-8
            out = out + hexTable[224 | (c >> 12)] + hexTable[128 | ((c >> 6) & 63)] + hexTable[128 | (c & 63)];
        } else {
            // Surrogate pair → 4-byte UTF-8
            idx = idx + 1;
            if (idx < str.length) {
                var c2 = str.charCodeAt(idx);
                var cp = ((c & 1023) << 10 | (c2 & 1023)) + 65536;
                out = out + hexTable[240 | (cp >> 18)]
                    + hexTable[128 | ((cp >> 12) & 63)]
                    + hexTable[128 | ((cp >> 6) & 63)]
                    + hexTable[128 | (cp & 63)];
            }
        }
        idx = idx + 1;
    }
    return out;
}

// ── querystring.unescape(str) ───────────────────────────────────────────────
// Decode a percent-encoded query string. Also converts + to space.
function unescape(str) {
    if (typeof str !== "string") { return ""; }
    try {
        // Replace + with space first, then decode percent sequences
        return decodeURIComponent(str.split("+").join(" "));
    } catch (e) {
        // Fallback: return as-is if malformed
        return str;
    }
}

// ── Hex char to value ───────────────────────────────────────────────────────
function _hexVal(c) {
    if (c >= 48 && c <= 57)  { return c - 48; }       // 0-9
    if (c >= 65 && c <= 70)  { return c - 65 + 10; }  // A-F
    if (c >= 97 && c <= 102) { return c - 97 + 10; }  // a-f
    return -1;
}

// ── querystring.parse(str, sep, eq, options) ────────────────────────────────
// Parse a query string into a key-value object.
// Duplicate keys produce arrays.
function parse(str, sep, eq, options) {
    if (typeof str !== "string" || str.length === 0) { return {}; }

    var separator = (sep !== undefined && sep !== null) ? String(sep) : "&";
    var equals    = (eq  !== undefined && eq  !== null) ? String(eq)  : "=";
    var maxKeys   = 1000;
    if (options && typeof options.maxKeys === "number") {
        maxKeys = options.maxKeys;
    }
    // maxKeys 0 means unlimited
    if (maxKeys === 0) { maxKeys = -1; }

    var obj = {};
    var pairs = str.split(separator);
    var count = 0;
    var pIdx = 0;
    while (pIdx < pairs.length) {
        if (maxKeys > 0 && count >= maxKeys) { break; }
        var pair = pairs[pIdx];
        if (pair.length === 0) { pIdx = pIdx + 1; continue; }

        var eqIdx = pair.indexOf(equals);
        var key;
        var val;
        if (eqIdx < 0) {
            key = unescape(pair);
            val = "";
        } else {
            key = unescape(pair.substring(0, eqIdx));
            val = unescape(pair.substring(eqIdx + equals.length));
        }

        if (obj[key] !== undefined) {
            if (Array.isArray(obj[key])) {
                obj[key].push(val);
            } else {
                obj[key] = [obj[key], val];
            }
        } else {
            obj[key] = val;
        }
        count = count + 1;
        pIdx = pIdx + 1;
    }
    return obj;
}

// ── querystring.stringify(obj, sep, eq, options) ────────────────────────────
// Serialize an object into a query string.
function stringify(obj, sep, eq, options) {
    if (obj === null || obj === undefined || typeof obj !== "object") {
        return "";
    }

    var separator = (sep !== undefined && sep !== null) ? String(sep) : "&";
    var equals    = (eq  !== undefined && eq  !== null) ? String(eq)  : "=";

    var encodeFn = escape;
    if (options && typeof options.encodeURIComponent === "function") {
        encodeFn = options.encodeURIComponent;
    }

    var keys = Object.keys(obj);
    var parts = [];
    var kIdx = 0;
    while (kIdx < keys.length) {
        var key = keys[kIdx];
        var value = obj[key];

        var encodedKey = encodeFn(key);

        if (Array.isArray(value)) {
            var vIdx = 0;
            while (vIdx < value.length) {
                parts.push(encodedKey + equals + encodeFn(String(value[vIdx])));
                vIdx = vIdx + 1;
            }
        } else {
            var sv = (value === undefined || value === null) ? "" : String(value);
            parts.push(encodedKey + equals + encodeFn(sv));
        }
        kIdx = kIdx + 1;
    }
    return parts.join(separator);
}

// ── Module exports ──────────────────────────────────────────────────────────

module.exports = {
    parse: parse,
    stringify: stringify,
    escape: escape,
    unescape: unescape,
    decode: parse,
    encode: stringify
};
