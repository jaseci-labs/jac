// ────────────────────────────────────────────────────────────────────────────
// builtins/js/url.js — Node.js `url` module
//
// Pure JavaScript implementation of the URL and URLSearchParams APIs.
// Loaded by `require("url")` / `require("node:url")`.
//
// Implements:
// - WHATWG URL class (§ URL Standard)
// - URLSearchParams class
// - Legacy url.parse(), url.format(), url.resolve()
//
// Node.js reference: https://nodejs.org/api/url.html
// Bun reference:     bun/src/js/node/url.ts
// ────────────────────────────────────────────────────────────────────────────

var qs = require("querystring");

// ═══════════════════════════════════════════════════════════════════════════
//  URLSearchParams
// ═══════════════════════════════════════════════════════════════════════════

class URLSearchParams {
    constructor(init) {
        this._list = [];  // array of [key, value] pairs

        if (init === undefined || init === null) {
            // empty
        } else if (typeof init === "string") {
            this._parseString(init);
        } else if (Array.isArray(init)) {
            // Array of [key, value] pairs
            var i = 0;
            while (i < init.length) {
                var pair = init[i];
                if (!Array.isArray(pair) || pair.length < 2) {
                    throw new TypeError("Each query pair must be an iterable [name, value]");
                }
                this._list.push([String(pair[0]), String(pair[1])]);
                i = i + 1;
            }
        } else if (typeof init === "object") {
            var keys = Object.keys(init);
            var ki = 0;
            while (ki < keys.length) {
                this._list.push([String(keys[ki]), String(init[keys[ki]])]);
                ki = ki + 1;
            }
        }
    }

    _parseString(str) {
        // Strip leading ?
        if (str.length > 0 && str[0] === "?") {
            str = str.substring(1);
        }
        if (str.length === 0) { return; }
        var pairs = str.split("&");
        var i = 0;
        while (i < pairs.length) {
            var pair = pairs[i];
            if (pair.length > 0) {
                var eqIdx = pair.indexOf("=");
                var key;
                var val;
                if (eqIdx < 0) {
                    key = _sp_decode(pair);
                    val = "";
                } else {
                    key = _sp_decode(pair.substring(0, eqIdx));
                    val = _sp_decode(pair.substring(eqIdx + 1));
                }
                this._list.push([key, val]);
            }
            i = i + 1;
        }
    }

    append(name, value) {
        this._list.push([String(name), String(value)]);
        this._updateUrl();
    }

    delete(name, value) {
        var newList = [];
        var i = 0;
        while (i < this._list.length) {
            var entry = this._list[i];
            if (entry[0] === String(name)) {
                if (value !== undefined && entry[1] !== String(value)) {
                    newList.push(entry);
                }
                // else: skip (delete it)
            } else {
                newList.push(entry);
            }
            i = i + 1;
        }
        this._list = newList;
        this._updateUrl();
    }

    get(name) {
        var sname = String(name);
        var i = 0;
        while (i < this._list.length) {
            if (this._list[i][0] === sname) {
                return this._list[i][1];
            }
            i = i + 1;
        }
        return null;
    }

    getAll(name) {
        var sname = String(name);
        var result = [];
        var i = 0;
        while (i < this._list.length) {
            if (this._list[i][0] === sname) {
                result.push(this._list[i][1]);
            }
            i = i + 1;
        }
        return result;
    }

    has(name, value) {
        var sname = String(name);
        var i = 0;
        while (i < this._list.length) {
            if (this._list[i][0] === sname) {
                if (value === undefined) { return true; }
                if (this._list[i][1] === String(value)) { return true; }
            }
            i = i + 1;
        }
        return false;
    }

    set(name, value) {
        var sname = String(name);
        var svalue = String(value);
        var found = false;
        var newList = [];
        var i = 0;
        while (i < this._list.length) {
            if (this._list[i][0] === sname) {
                if (!found) {
                    newList.push([sname, svalue]);
                    found = true;
                }
                // else skip duplicates
            } else {
                newList.push(this._list[i]);
            }
            i = i + 1;
        }
        if (!found) {
            newList.push([sname, svalue]);
        }
        this._list = newList;
        this._updateUrl();
    }

    sort() {
        // Stable sort by name
        var len = this._list.length;
        var i = 0;
        while (i < len) {
            var j = i + 1;
            while (j < len) {
                if (this._list[j][0] < this._list[i][0]) {
                    var tmp = this._list[i];
                    this._list[i] = this._list[j];
                    this._list[j] = tmp;
                }
                j = j + 1;
            }
            i = i + 1;
        }
        this._updateUrl();
    }

    entries() {
        var idx = 0;
        var list = this._list;
        return {
            next: function() {
                if (idx >= list.length) { return { value: undefined, done: true }; }
                var val = [list[idx][0], list[idx][1]];
                idx = idx + 1;
                return { value: val, done: false };
            }
        };
    }

    keys() {
        var idx = 0;
        var list = this._list;
        return {
            next: function() {
                if (idx >= list.length) { return { value: undefined, done: true }; }
                var val = list[idx][0];
                idx = idx + 1;
                return { value: val, done: false };
            }
        };
    }

    values() {
        var idx = 0;
        var list = this._list;
        return {
            next: function() {
                if (idx >= list.length) { return { value: undefined, done: true }; }
                var val = list[idx][1];
                idx = idx + 1;
                return { value: val, done: false };
            }
        };
    }

    forEach(callback, thisArg) {
        var i = 0;
        while (i < this._list.length) {
            callback.call(thisArg, this._list[i][1], this._list[i][0], this);
            i = i + 1;
        }
    }

    toString() {
        var parts = [];
        var i = 0;
        while (i < this._list.length) {
            parts.push(_sp_encode(this._list[i][0]) + "=" + _sp_encode(this._list[i][1]));
            i = i + 1;
        }
        return parts.join("&");
    }

    get size() {
        return this._list.length;
    }

    // Symbol.iterator — alias for entries(), enables for...of
    [Symbol.iterator]() {
        return this.entries();
    }

    // Internal: notify the owning URL that searchParams changed
    _updateUrl() {
        if (this._url) {
            var s = this.toString();
            this._url._search = s.length > 0 ? "?" + s : "";
        }
    }
}

// ── URLSearchParams encoding/decoding helpers ───────────────────────────────
// WHATWG spec: application/x-www-form-urlencoded serializer
// Encodes everything except: * - . _ 0-9 A-Z a-z
// Spaces become +

function _sp_encode(str) {
    str = String(str);
    var out = "";
    var i = 0;
    while (i < str.length) {
        var c = str.charCodeAt(i);
        if (
            (c >= 48 && c <= 57)  ||   // 0-9
            (c >= 65 && c <= 90)  ||   // A-Z
            (c >= 97 && c <= 122) ||   // a-z
            c === 42  ||  // *
            c === 45  ||  // -
            c === 46  ||  // .
            c === 95      // _
        ) {
            out = out + str[i];
        } else if (c === 32) {
            out = out + "+";
        } else {
            out = out + encodeURIComponent(str[i]);
        }
        i = i + 1;
    }
    return out;
}

function _sp_decode(str) {
    // + → space, then percent-decode
    try {
        return decodeURIComponent(str.split("+").join(" "));
    } catch (e) {
        return str;
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  URL class (WHATWG URL Standard)
// ═══════════════════════════════════════════════════════════════════════════

// Default ports per protocol (used for origin and to suppress port display)
var _defaultPorts = {
    "http:":  "80",
    "https:": "443",
    "ftp:":   "21",
    "ws:":    "80",
    "wss:":   "443"
};

// Protocols that use // slashes
var _slashProtocols = {
    "http:":  true,
    "https:": true,
    "ftp:":   true,
    "ws:":    true,
    "wss:":   true,
    "file:":  true
};

class URL {
    constructor(input, base) {
        if (input === undefined || input === null) {
            throw new TypeError("Invalid URL");
        }
        input = String(input).trim();

        // If base is provided, resolve input against it
        if (base !== undefined && base !== null) {
            var baseUrl;
            if (typeof base === "object" && base instanceof URL) {
                baseUrl = base;
            } else {
                baseUrl = new URL(String(base));
            }
            // Resolve relative URL against base
            input = _resolveUrl(String(baseUrl), input);
        }

        this._protocol = "";
        this._username = "";
        this._password = "";
        this._hostname = "";
        this._port     = "";
        this._pathname = "/";
        this._search   = "";
        this._hash     = "";
        this._searchParams = null;

        this._parse(input);

        // Create searchParams linked to this URL
        this._searchParams = new URLSearchParams(this._search);
        this._searchParams._url = this;
    }

    _parse(input) {
        var rest = input;
        var idx;

        // 1) Extract fragment
        idx = rest.indexOf("#");
        if (idx >= 0) {
            this._hash = rest.substring(idx);
            rest = rest.substring(0, idx);
        }

        // 2) Extract query
        idx = rest.indexOf("?");
        if (idx >= 0) {
            this._search = rest.substring(idx);
            rest = rest.substring(0, idx);
        }

        // 3) Extract protocol
        var colonIdx = rest.indexOf(":");
        if (colonIdx > 0) {
            var proto = rest.substring(0, colonIdx + 1).toLowerCase();
            // Simple check: protocol must be [a-z][a-z0-9+-.]*:
            if (_isValidProtocol(proto)) {
                this._protocol = proto;
                rest = rest.substring(colonIdx + 1);
            }
        }

        if (this._protocol === "") {
            throw new TypeError("Invalid URL: " + input);
        }

        // 4) Extract authority (// user:pass@host:port)
        if (rest.length >= 2 && rest[0] === "/" && rest[1] === "/") {
            rest = rest.substring(2);

            // Find path start
            var pathStart = rest.indexOf("/");
            var authority;
            if (pathStart < 0) {
                authority = rest;
                rest = "";
            } else {
                authority = rest.substring(0, pathStart);
                rest = rest.substring(pathStart);
            }

            // Extract userinfo
            var atIdx = authority.lastIndexOf("@");
            if (atIdx >= 0) {
                var userinfo = authority.substring(0, atIdx);
                authority = authority.substring(atIdx + 1);
                var uColonIdx = userinfo.indexOf(":");
                if (uColonIdx >= 0) {
                    this._username = userinfo.substring(0, uColonIdx);
                    this._password = userinfo.substring(uColonIdx + 1);
                } else {
                    this._username = userinfo;
                }
            }

            // Extract host:port
            // Handle IPv6: [::1]:port
            if (authority.length > 0 && authority[0] === "[") {
                var bracketEnd = authority.indexOf("]");
                if (bracketEnd >= 0) {
                    this._hostname = authority.substring(0, bracketEnd + 1);
                    var afterBracket = authority.substring(bracketEnd + 1);
                    if (afterBracket.length > 0 && afterBracket[0] === ":") {
                        this._port = afterBracket.substring(1);
                    }
                } else {
                    this._hostname = authority;
                }
            } else {
                var hColonIdx = authority.lastIndexOf(":");
                if (hColonIdx >= 0) {
                    this._hostname = authority.substring(0, hColonIdx).toLowerCase();
                    this._port = authority.substring(hColonIdx + 1);
                } else {
                    this._hostname = authority.toLowerCase();
                }
            }

            // Suppress default port
            if (this._port !== "" && _defaultPorts[this._protocol] === this._port) {
                this._port = "";
            }
        }

        // 5) Pathname
        if (rest.length > 0) {
            this._pathname = rest;
        } else if (_slashProtocols[this._protocol]) {
            this._pathname = "/";
        } else {
            this._pathname = rest;
        }
    }

    // ── Getters / Setters ────────────────────────────────────────────────────

    get href() {
        return this._serialize();
    }

    set href(val) {
        this._parse(String(val));
        this._searchParams = new URLSearchParams(this._search);
        this._searchParams._url = this;
    }

    get origin() {
        if (_slashProtocols[this._protocol]) {
            return this._protocol + "//" + this.host;
        }
        return "null";
    }

    get protocol() { return this._protocol; }
    set protocol(val) {
        var s = String(val);
        if (s.length > 0 && s[s.length - 1] !== ":") { s = s + ":"; }
        this._protocol = s.toLowerCase();
    }

    get username() { return this._username; }
    set username(val) { this._username = String(val); }

    get password() { return this._password; }
    set password(val) { this._password = String(val); }

    get host() {
        if (this._port !== "") {
            return this._hostname + ":" + this._port;
        }
        return this._hostname;
    }
    set host(val) {
        var s = String(val);
        var cIdx = s.lastIndexOf(":");
        if (cIdx >= 0) {
            this._hostname = s.substring(0, cIdx).toLowerCase();
            this._port = s.substring(cIdx + 1);
        } else {
            this._hostname = s.toLowerCase();
            this._port = "";
        }
    }

    get hostname() { return this._hostname; }
    set hostname(val) { this._hostname = String(val).toLowerCase(); }

    get port() { return this._port; }
    set port(val) {
        var s = String(val);
        if (s === "") { this._port = ""; return; }
        var n = parseInt(s, 10);
        if (isNaN(n) || n < 0 || n > 65535) { return; }
        // Suppress default port
        var ns = String(n);
        if (_defaultPorts[this._protocol] === ns) {
            this._port = "";
        } else {
            this._port = ns;
        }
    }

    get pathname() { return this._pathname; }
    set pathname(val) { this._pathname = String(val); }

    get search() { return this._search; }
    set search(val) {
        var s = String(val);
        if (s.length > 0 && s[0] !== "?") { s = "?" + s; }
        if (s === "?") { s = ""; }
        this._search = s;
        // Re-create searchParams
        this._searchParams = new URLSearchParams(s);
        this._searchParams._url = this;
    }

    get searchParams() { return this._searchParams; }

    get hash() { return this._hash; }
    set hash(val) {
        var s = String(val);
        if (s.length > 0 && s[0] !== "#") { s = "#" + s; }
        if (s === "#") { s = ""; }
        this._hash = s;
    }

    // ── Methods ──────────────────────────────────────────────────────────────

    toString() {
        return this._serialize();
    }

    toJSON() {
        return this._serialize();
    }

    _serialize() {
        var out = this._protocol;
        if (_slashProtocols[this._protocol]) {
            out = out + "//";
            if (this._username !== "" || this._password !== "") {
                out = out + this._username;
                if (this._password !== "") {
                    out = out + ":" + this._password;
                }
                out = out + "@";
            }
            out = out + this._hostname;
            if (this._port !== "") {
                out = out + ":" + this._port;
            }
        }
        out = out + this._pathname + this._search + this._hash;
        return out;
    }
}

// Static method
URL.canParse = function(input, base) {
    try {
        new URL(input, base);
        return true;
    } catch (e) {
        return false;
    }
};

// ── Helper: validate protocol ───────────────────────────────────────────────
function _isValidProtocol(proto) {
    if (proto.length < 2) { return false; }  // at least "x:"
    var first = proto.charCodeAt(0);
    // First char must be a letter
    if (!((first >= 65 && first <= 90) || (first >= 97 && first <= 122))) {
        return false;
    }
    return true;
}

// ── Helper: resolve a relative URL against a base ───────────────────────────
function _resolveUrl(base, relative) {
    // If relative is already absolute, return it
    var colonIdx = relative.indexOf(":");
    if (colonIdx > 0) {
        var maybeProto = relative.substring(0, colonIdx + 1).toLowerCase();
        if (_isValidProtocol(maybeProto)) {
            // Check if it looks like a protocol (followed by //)
            if (relative.length > colonIdx + 2 && relative[colonIdx + 1] === "/" && relative[colonIdx + 2] === "/") {
                return relative;
            }
            // Single-letter "protocols" like C: are drive letters, not protocols
            if (colonIdx !== 1) {
                return relative;
            }
        }
    }

    // Parse base
    var baseObj;
    try {
        baseObj = _legacyParse(base, false, false);
    } catch (e) {
        throw new TypeError("Invalid base URL: " + base);
    }

    if (relative === "") {
        return base;
    }

    // Protocol-relative
    if (relative.length >= 2 && relative[0] === "/" && relative[1] === "/") {
        return (baseObj.protocol || "http:") + relative;
    }

    // Absolute path
    if (relative[0] === "/") {
        var origin = (baseObj.protocol || "") + "//" + (baseObj.host || "");
        return origin + relative;
    }

    // Query/hash only
    if (relative[0] === "?" || relative[0] === "#") {
        // Strip existing query/hash from base
        var bHref = baseObj.href || base;
        var qIdx = bHref.indexOf("?");
        var hIdx = bHref.indexOf("#");
        var cutIdx = -1;
        if (relative[0] === "?") {
            cutIdx = (qIdx >= 0) ? qIdx : (hIdx >= 0 ? hIdx : -1);
        } else {
            cutIdx = (hIdx >= 0) ? hIdx : -1;
        }
        if (cutIdx >= 0) {
            return bHref.substring(0, cutIdx) + relative;
        }
        return bHref + relative;
    }

    // Relative path — resolve against base path
    var basePath = baseObj.pathname || "/";
    // Remove last segment of base path
    var lastSlash = basePath.lastIndexOf("/");
    var dir = (lastSlash >= 0) ? basePath.substring(0, lastSlash + 1) : "/";
    var merged = dir + relative;

    // Normalize . and ..
    merged = _normalizePath(merged);

    var origin2 = (baseObj.protocol || "") + "//" + (baseObj.host || "");
    return origin2 + merged;
}

// ── Normalize . and .. in a path ────────────────────────────────────────────
function _normalizePath(path) {
    var parts = path.split("/");
    var out = [];
    var i = 0;
    while (i < parts.length) {
        var seg = parts[i];
        if (seg === ".") {
            // skip
        } else if (seg === "..") {
            if (out.length > 1) { out.pop(); }
        } else {
            out.push(seg);
        }
        i = i + 1;
    }
    var result = out.join("/");
    if (result.length === 0 || result[0] !== "/") {
        result = "/" + result;
    }
    return result;
}


// ═══════════════════════════════════════════════════════════════════════════
//  Legacy url.parse()
// ═══════════════════════════════════════════════════════════════════════════

function _legacyParse(urlString, parseQueryString, slashesDenoteHost) {
    if (typeof urlString !== "string") {
        throw new TypeError("Parameter 'url' must be a string");
    }

    var result = {
        protocol: null,
        slashes:  null,
        auth:     null,
        host:     null,
        port:     null,
        hostname: null,
        hash:     null,
        search:   null,
        query:    null,
        pathname: null,
        path:     null,
        href:     urlString
    };

    var rest = urlString.trim();

    // 1) Extract hash
    var hashIdx = rest.indexOf("#");
    if (hashIdx >= 0) {
        result.hash = rest.substring(hashIdx);
        rest = rest.substring(0, hashIdx);
    }

    // 2) Extract query
    var qIdx = rest.indexOf("?");
    if (qIdx >= 0) {
        result.search = rest.substring(qIdx);
        var queryStr = rest.substring(qIdx + 1);
        if (parseQueryString) {
            result.query = qs.parse(queryStr);
        } else {
            result.query = queryStr;
        }
        rest = rest.substring(0, qIdx);
    } else {
        if (parseQueryString) {
            result.query = {};
            result.search = "";
        }
    }

    // 3) Extract protocol
    var colonIdx = rest.indexOf(":");
    if (colonIdx > 0) {
        var proto = rest.substring(0, colonIdx + 1).toLowerCase();
        if (_isValidProtocol(proto)) {
            result.protocol = proto;
            rest = rest.substring(colonIdx + 1);
        }
    }

    // 4) Detect slashes
    if (rest.length >= 2 && rest[0] === "/" && rest[1] === "/") {
        result.slashes = true;
        rest = rest.substring(2);

        // Extract authority
        var pathStart = rest.indexOf("/");
        var authority;
        if (pathStart < 0) {
            authority = rest;
            rest = "";
        } else {
            authority = rest.substring(0, pathStart);
            rest = rest.substring(pathStart);
        }

        // Extract auth
        var atIdx = authority.lastIndexOf("@");
        if (atIdx >= 0) {
            result.auth = authority.substring(0, atIdx);
            authority = authority.substring(atIdx + 1);
        }

        // Host and port
        if (authority.length > 0 && authority[0] === "[") {
            // IPv6
            var bracketEnd = authority.indexOf("]");
            if (bracketEnd >= 0) {
                result.hostname = authority.substring(0, bracketEnd + 1);
                var afterBracket = authority.substring(bracketEnd + 1);
                if (afterBracket.length > 0 && afterBracket[0] === ":") {
                    result.port = afterBracket.substring(1);
                }
            } else {
                result.hostname = authority;
            }
        } else {
            var hColonIdx = authority.lastIndexOf(":");
            if (hColonIdx >= 0) {
                result.hostname = authority.substring(0, hColonIdx).toLowerCase();
                result.port = authority.substring(hColonIdx + 1);
                if (result.port === "") { result.port = null; }
            } else {
                result.hostname = authority.toLowerCase();
            }
        }

        // Build host = hostname[:port]
        if (result.hostname !== null) {
            if (result.port !== null) {
                result.host = result.hostname + ":" + result.port;
            } else {
                result.host = result.hostname;
            }
        }
    } else if (slashesDenoteHost && rest.length > 0 && rest[0] !== "/") {
        // slashesDenoteHost mode: treat rest as authority
        var sd_pathStart = rest.indexOf("/");
        var sd_authority;
        if (sd_pathStart < 0) {
            sd_authority = rest;
            rest = "";
        } else {
            sd_authority = rest.substring(0, sd_pathStart);
            rest = rest.substring(sd_pathStart);
        }
        result.hostname = sd_authority.toLowerCase();
        result.host = result.hostname;
    }

    // 5) Pathname
    if (rest.length > 0) {
        result.pathname = rest;
    } else {
        if (result.slashes) { result.pathname = "/"; }
    }

    // 6) Build path = pathname + search
    if (result.pathname !== null) {
        result.path = result.pathname + (result.search || "");
    }

    // 7) Reconstruct href
    result.href = _legacyFormat(result);

    return result;
}

// ── Legacy url.format() ─────────────────────────────────────────────────────

function _legacyFormat(urlObj) {
    if (typeof urlObj === "string") { return urlObj; }
    if (typeof urlObj !== "object" || urlObj === null) { return ""; }

    var out = "";
    var protocol = urlObj.protocol || "";
    out = out + protocol;

    if (urlObj.slashes || (protocol !== "" && _slashProtocols[protocol])) {
        out = out + "//";
    }

    if (urlObj.auth) {
        out = out + urlObj.auth + "@";
    }

    if (urlObj.host) {
        out = out + urlObj.host;
    } else {
        if (urlObj.hostname) {
            out = out + urlObj.hostname;
        }
        if (urlObj.port) {
            out = out + ":" + urlObj.port;
        }
    }

    if (urlObj.pathname) {
        out = out + urlObj.pathname;
    }

    if (urlObj.search) {
        out = out + urlObj.search;
    } else if (urlObj.query) {
        if (typeof urlObj.query === "string") {
            out = out + "?" + urlObj.query;
        } else if (typeof urlObj.query === "object") {
            var qStr = qs.stringify(urlObj.query);
            if (qStr.length > 0) {
                out = out + "?" + qStr;
            }
        }
    }

    if (urlObj.hash) {
        out = out + urlObj.hash;
    }

    return out;
}

// ── Legacy url.resolve(from, to) ────────────────────────────────────────────

function _legacyResolve(from, to) {
    return _resolveUrl(String(from), String(to));
}


// ═══════════════════════════════════════════════════════════════════════════
//  Register URL / URLSearchParams as globals (Node.js ≥10 / WHATWG spec)
// ═══════════════════════════════════════════════════════════════════════════
globalThis.URL = URL;
globalThis.URLSearchParams = URLSearchParams;

// ── pathToFileURL (Node.js url.pathToFileURL) ───────────────────────────────

function pathToFileURL(filepath) {
    filepath = String(filepath);
    var p = filepath.split("\\").join("/");
    if (p.length > 0 && p[0] === "/") {
        return new URL("file://" + p);
    }
    return new URL("file:///" + p);
}

// ── fileURLToPath (Node.js url.fileURLToPath) ───────────────────────────────
// Converts a file: URL (string or URL object) to an absolute path string.
// Mirrors Node.js behaviour: decodes percent-encoded characters, strips the
// file:// authority prefix, and returns the raw path portion.

function _percentDecodePath(rawPath) {
    // Node-compatible percent-decoding: only decode valid %HH sequences;
    // leave malformed % sequences intact instead of throwing URIError.
    var out = "";
    var i = 0;
    while (i < rawPath.length) {
        var ch = rawPath.charAt(i);
        if (ch === "%" && i + 2 < rawPath.length) {
            var h1 = rawPath.charAt(i + 1);
            var h2 = rawPath.charAt(i + 2);
            if (/[0-9a-fA-F]/.test(h1) && /[0-9a-fA-F]/.test(h2)) {
                out += String.fromCharCode(parseInt(h1 + h2, 16));
                i += 3;
                continue;
            }
        }
        out += ch;
        i += 1;
    }
    return out;
}

function fileURLToPath(urlInput) {
    var href;
    if (urlInput !== null && typeof urlInput === "object" && typeof urlInput.href === "string") {
        // URL object
        href = urlInput.href;
    } else {
        href = String(urlInput);
    }
    if (href.length < 7 || href.slice(0, 7).toLowerCase() !== "file://") {
        var schemeErr = new TypeError("The URL must be of scheme file");
        schemeErr.code = "ERR_INVALID_URL_SCHEME";
        throw schemeErr;
    }
    // Strip the scheme+authority: "file://" (7 chars), then keep the path.
    // "file:///abs/path" → strip 7 → "/abs/path" (starts with /)
    // "file://host/path" → strip 7 → "host/path"
    var rest = href.slice(7);
    var pathStart = rest.indexOf("/");
    if (pathStart < 0) {
        throw new TypeError("Invalid file URL");
    }
    // Non-empty hostname is invalid on POSIX unless it is "localhost".
    if (pathStart > 0) {
        var host = rest.slice(0, pathStart).toLowerCase();
        if (host !== "localhost") {
            var hostErr = new TypeError('File URL host must be "localhost" or empty on this platform');
            hostErr.code = "ERR_INVALID_FILE_URL_HOST";
            throw hostErr;
        }
    }
    var rawPath = rest.slice(pathStart);
    // Encoded / (and \ on Windows) are rejected before decode.
    if (/%2f/i.test(rawPath) || /%5c/i.test(rawPath)) {
        var pathErr = new TypeError("File URL path must not include encoded / or \\ characters");
        pathErr.code = "ERR_INVALID_FILE_URL_PATH";
        throw pathErr;
    }
    return _percentDecodePath(rawPath);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Module exports
// ═══════════════════════════════════════════════════════════════════════════

module.exports = {
    URL: URL,
    URLSearchParams: URLSearchParams,
    pathToFileURL: pathToFileURL,
    fileURLToPath: fileURLToPath,
    parse: function(urlString, parseQueryString, slashesDenoteHost) {
        return _legacyParse(urlString, parseQueryString, slashesDenoteHost);
    },
    format: function(urlObj) {
        return _legacyFormat(urlObj);
    },
    resolve: function(from, to) {
        return _legacyResolve(from, to);
    }
};
