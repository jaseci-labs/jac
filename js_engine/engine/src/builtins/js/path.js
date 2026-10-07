// ────────────────────────────────────────────────────────────────────────────
// builtins/js/path.js — Node.js `path` module (POSIX only)
//
// Pure JavaScript implementation of the POSIX path API.
// Loaded by `require("path")` / `require("node:path")`.
//
// Node.js reference: https://nodejs.org/api/path.html
// Bun reference:     bun/src/js/node/path.ts
// ────────────────────────────────────────────────────────────────────────────

var _perrs = require("./internal/errors.js");

function _validatePathString(value, name) {
    if (typeof value !== "string") {
        throw _perrs.errInvalidArgType(name || "path", "string", value);
    }
}

// ── helpers ─────────────────────────────────────────────────────────────────

function _splitPath(p) {
    var parts = [];
    var cur = "";
    var i = 0;
    while (i < p.length) {
        if (p[i] === "/") {
            parts.push(cur);
            cur = "";
        } else {
            cur = cur + p[i];
        }
        i = i + 1;
    }
    parts.push(cur);
    return parts;
}

function _normParts(parts, isAbs) {
    var result = [];
    var j = 0;
    while (j < parts.length) {
        var seg = parts[j];
        if (seg === "" || seg === ".") {
            // skip
        } else if (seg === "..") {
            if (result.length > 0 && result[result.length - 1] !== "..") {
                result.pop();
            } else if (!isAbs) {
                result.push("..");
            }
        } else {
            result.push(seg);
        }
        j = j + 1;
    }
    return result;
}

function _rejoin(parts) {
    var out = "";
    var k = 0;
    while (k < parts.length) {
        if (k > 0) out = out + "/";
        out = out + parts[k];
        k = k + 1;
    }
    return out;
}

// ── public API ──────────────────────────────────────────────────────────────

function normalize(p) {
    _validatePathString(p, "path");
    if (p.length === 0) return ".";
    var isAbs = p[0] === "/";
    // Node keeps a trailing separator: normalize("a/b/") === "a/b/", so
    // join("assets", "/") === "assets/" (Vite's build report slices file names
    // by that length).
    var trailingSep = p[p.length - 1] === "/";
    var normed = _normParts(_splitPath(p), isAbs);
    if (normed.length === 0) {
        if (isAbs) return "/";
        return trailingSep ? "./" : ".";
    }
    var result = _rejoin(normed);
    if (trailingSep) result = result + "/";
    if (isAbs) result = "/" + result;
    return result;
}

function join() {
    var joined = "";
    var i = 0;
    while (i < arguments.length) {
        var seg = arguments[i];
        _validatePathString(seg, "paths[" + i + "]");
        if (seg.length > 0) {
            if (joined.length > 0) joined = joined + "/";
            joined = joined + seg;
        }
        i = i + 1;
    }
    if (joined.length === 0) return ".";
    return normalize(joined);
}

function resolve() {
    var i0 = 0;
    while (i0 < arguments.length) {
        _validatePathString(arguments[i0], "paths[" + i0 + "]");
        i0 = i0 + 1;
    }
    var resolved = "";
    var i = arguments.length - 1;
    while (i >= 0) {
        var seg = arguments[i];
        if (seg.length > 0) {
            if (resolved.length === 0) {
                resolved = seg;
            } else {
                resolved = seg + "/" + resolved;
            }
            if (seg[0] === "/") break;
        }
        i = i - 1;
    }
    if (resolved.length === 0 || resolved[0] !== "/") {
        var cwd = process.cwd();
        if (resolved.length > 0) {
            resolved = cwd + "/" + resolved;
        } else {
            resolved = cwd;
        }
    }
    var normed = _normParts(_splitPath(resolved), true);
    if (normed.length === 0) return "/";
    return "/" + _rejoin(normed);
}

function dirname(p) {
    _validatePathString(p, "path");
    if (p.length === 0) return ".";
    // strip trailing slashes so dirname("/a/b/") == "/a" not "/a/b"
    while (p.length > 1 && p[p.length - 1] === "/") {
        p = p.slice(0, p.length - 1);
    }
    var lastSlash = -1;
    var i = 0;
    while (i < p.length) {
        if (p[i] === "/") lastSlash = i;
        i = i + 1;
    }
    if (lastSlash < 0) return ".";
    if (lastSlash === 0) return "/";
    return p.slice(0, lastSlash);
}

function basename(p, ext) {
    _validatePathString(p, "path");
    if (ext !== undefined && ext !== null) _validatePathString(ext, "ext");
    if (p.length === 0) return "";
    // strip trailing slashes
    while (p.length > 1 && p[p.length - 1] === "/") {
        p = p.slice(0, p.length - 1);
    }
    var lastSlash = -1;
    var i = 0;
    while (i < p.length) {
        if (p[i] === "/") lastSlash = i;
        i = i + 1;
    }
    var base = lastSlash >= 0 ? p.slice(lastSlash + 1) : p;
    if (typeof ext === "string" && ext.length > 0 && base.length > ext.length) {
        if (base.slice(base.length - ext.length) === ext) {
            base = base.slice(0, base.length - ext.length);
        }
    }
    return base;
}

function extname(p) {
    _validatePathString(p, "path");
    if (p.length === 0) return "";
    var lastSlash = -1;
    var lastDot = -1;
    var i = 0;
    while (i < p.length) {
        if (p[i] === "/") { lastSlash = i; lastDot = -1; }
        else if (p[i] === ".") { lastDot = i; }
        i = i + 1;
    }
    var baseStart = lastSlash + 1;
    if (lastDot <= baseStart) return "";
    return p.slice(lastDot);
}

function isAbsolute(p) {
    _validatePathString(p, "path");
    return p.length > 0 && p[0] === "/";
}

function relative(from, to) {
    _validatePathString(from, "from");
    _validatePathString(to, "to");
    var absFrom = resolve(from);
    var absTo = resolve(to);
    // Assign _splitPath results to locals first to avoid nested-call-as-argument VM bug
    var splitFrom = _splitPath(absFrom);
    var splitTo = _splitPath(absTo);
    var fromParts = _normParts(splitFrom, true);
    var toParts = _normParts(splitTo, true);

    // find common prefix length
    var common = 0;
    var maxC = fromParts.length < toParts.length ? fromParts.length : toParts.length;
    while (common < maxC && fromParts[common] === toParts[common]) {
        common = common + 1;
    }

    var result = [];
    var up = fromParts.length - common;
    var u = 0;
    while (u < up) { result.push(".."); u = u + 1; }
    var d = common;
    while (d < toParts.length) { result.push(toParts[d]); d = d + 1; }

    if (result.length === 0) return "";
    return _rejoin(result);
}

function parse(p) {
    _validatePathString(p, "path");
    var root = "";
    var dir = "";
    var base = "";
    var ext = "";
    var name = "";

    if (p.length > 0) {
        if (p[0] === "/") root = "/";

        var lastSlash = -1;
        var i = 0;
        while (i < p.length) {
            if (p[i] === "/") lastSlash = i;
            i = i + 1;
        }

        if (lastSlash >= 0) {
            dir = p.slice(0, lastSlash);
            if (dir.length === 0 && root.length > 0) dir = root;
            base = p.slice(lastSlash + 1);
        } else {
            base = p;
        }

        var lastDot = -1;
        var j = 0;
        while (j < base.length) {
            if (base[j] === ".") lastDot = j;
            j = j + 1;
        }
        if (lastDot > 0) {
            ext = base.slice(lastDot);
            name = base.slice(0, lastDot);
        } else {
            name = base;
        }
    }

    return { root: root, dir: dir, base: base, ext: ext, name: name };
}

function format(obj) {
    if (typeof obj !== "object" || obj === null) return "";
    var dir = obj.dir || "";
    var base = obj.base || "";
    var root = obj.root || "";
    var name = obj.name || "";
    var ext = obj.ext || "";

    if (base.length === 0) base = name + ext;

    if (dir.length > 0) {
        if (dir[dir.length - 1] === "/") return dir + base;
        return dir + "/" + base;
    }
    return root + base;
}

// POSIX: no namespace prefix. Windows would add `\\?\` for long paths.
function toNamespacedPath(p) {
    return p;
}

// ── exports ─────────────────────────────────────────────────────────────────

module.exports = {
    join: join,
    resolve: resolve,
    normalize: normalize,
    dirname: dirname,
    basename: basename,
    extname: extname,
    relative: relative,
    isAbsolute: isAbsolute,
    parse: parse,
    format: format,
    toNamespacedPath: toNamespacedPath,
    sep: "/",
    delimiter: ":"
};

// path.posix is a self-reference (we only support POSIX)
module.exports.posix = module.exports;

// path.win32 — minimal stub for cross-platform code that inspects win32.sep.
// On Linux all paths are POSIX; win32 functions are provided for compat only.
module.exports.win32 = {
    sep: "\\",
    delimiter: ";",
    join: join,
    resolve: resolve,
    normalize: normalize,
    dirname: dirname,
    basename: basename,
    extname: extname,
    relative: relative,
    isAbsolute: isAbsolute,
    parse: parse,
    format: format,
    toNamespacedPath: toNamespacedPath,
};

