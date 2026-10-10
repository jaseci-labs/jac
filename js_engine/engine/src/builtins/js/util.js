// ────────────────────────────────────────────────────────────────────────────
// builtins/js/util.js — Node.js `util` module
//
// Pure JavaScript implementation of the util API.
// Loaded by `require("util")` / `require("node:util")`.
//
// Node.js reference: https://nodejs.org/api/util.html
// Bun reference:     bun/src/js/node/util.ts
// ────────────────────────────────────────────────────────────────────────────

// ── util.inspect ─────────────────────────────────────────────────────────────

/**
 * Returns a string representation of `val` for debugging.
 *
 * Options:
 *   depth    {number}  Maximum recursion depth (default 2, null = unlimited)
 *   colors   {boolean} ANSI escape codes (default false)
 *   showHidden {boolean} Show non-enumerable properties (default false)
 */
function inspect(val, opts) {
    var depth    = (opts && opts.depth    !== undefined) ? opts.depth    : 2;
    var colors   = (opts && opts.colors   !== undefined) ? opts.colors   : false;
    var showHidden = (opts && opts.showHidden !== undefined) ? opts.showHidden : false;

    return _inspect(val, depth, colors, []);
}

var _inspectCustom = typeof Symbol !== "undefined"
    ? Symbol.for("nodejs.util.inspect.custom")
    : null;

function _inspect(val, depth, colors, seen) {
    var t = typeof val;

    // ── Primitives ──────────────────────────────────────────────────────────
    if (val === null)      { return "null"; }
    if (val === undefined) { return "undefined"; }
    if (t === "boolean")   { return val ? "true" : "false"; }
    if (t === "number")    { return _format_number(val); }
    if (t === "string")    { return "'" + _escape_string(val) + "'"; }
    if (t === "symbol")    {
        var sdesc = val.toString ? val.toString() : "Symbol()";
        return sdesc;
    }
    if (t === "bigint")    { return val.toString() + "n"; }

    // ── Function ────────────────────────────────────────────────────────────
    if (t === "function") {
        var fname = val.name || "(anonymous)";
        return "[Function: " + fname + "]";
    }

    // ── Circular detection ──────────────────────────────────────────────────
    for (var ci = 0; ci < seen.length; ci++) {
        if (seen[ci] === val) { return "[Circular *1]"; }
    }

    // ── Custom inspect (Node util.inspect.custom) ────────────────────────────
    if (val !== null && t === "object" && _inspectCustom &&
        typeof val[_inspectCustom] === "function") {
        try {
            var customOut = val[_inspectCustom](depth, { depth: depth, colors: colors });
            if (typeof customOut === "string") return customOut;
            if (customOut !== val) return _inspect(customOut, depth, colors, seen);
        } catch (_ce) { /* fall through */ }
    }

    // ── Depth limit ─────────────────────────────────────────────────────────
    // Check emptiness BEFORE depth limit so inspect({}, {depth:0}) => '{}'
    // (an empty container has nothing to recurse into regardless of depth).
    if (depth !== null && depth <= 0) {
        if (Array.isArray(val) && val.length === 0) { return "[]"; }
        if (Array.isArray(val))                     { return "[Array]"; }
        var _ekeys = Object.keys(val);
        if (_ekeys.length === 0)                    { return "{}"; }
        return "[Object]";
    }

    var nextDepth = (depth === null) ? null : depth - 1;
    var newSeen = seen.slice();
    newSeen.push(val);

    // ── Error ────────────────────────────────────────────────────────────────
    if (val instanceof Error) {
        var ename = val.name || "Error";
        var emsg  = val.message || "";
        return ename + ": " + emsg;
    }

    // ── Array ────────────────────────────────────────────────────────────────
    if (Array.isArray(val)) {
        if (val.length === 0) { return "[]"; }
        var aitems = [];
        for (var ai = 0; ai < val.length; ai++) {
            aitems.push(_inspect(val[ai], nextDepth, colors, newSeen));
        }
        return "[ " + aitems.join(", ") + " ]";
    }

    // ── Map ──────────────────────────────────────────────────────────────────
    if (val instanceof Map) {
        if (val.size === 0) { return "Map(0) {}"; }
        var mentries = [];
        val.forEach(function(v, k) {
            mentries.push(_inspect(k, nextDepth, colors, newSeen) + " => " + _inspect(v, nextDepth, colors, newSeen));
        });
        return "Map(" + val.size + ") { " + mentries.join(", ") + " }";
    }

    // ── Set ──────────────────────────────────────────────────────────────────
    if (val instanceof Set) {
        if (val.size === 0) { return "Set(0) {}"; }
        var sitems = [];
        val.forEach(function(v) {
            sitems.push(_inspect(v, nextDepth, colors, newSeen));
        });
        return "Set(" + val.size + ") { " + sitems.join(", ") + " }";
    }

    // ── Date ─────────────────────────────────────────────────────────────────
    if (val instanceof Date) {
        return val.toISOString ? val.toISOString() : val.toString();
    }

    // ── Promise ──────────────────────────────────────────────────────────────
    if (val instanceof Promise) {
        return "Promise { <pending> }";
    }

    // ── RegExp ───────────────────────────────────────────────────────────────
    if (val instanceof RegExp) {
        return val.toString();
    }

    // ── Plain Object ─────────────────────────────────────────────────────────
    var keys = Object.keys(val);
    if (keys.length === 0) { return "{}"; }
    var oitems = [];
    for (var oi = 0; oi < keys.length; oi++) {
        var k = keys[oi];
        // NOTE: Regex not yet supported in this engine — use manual identifier check
        // TODO: replace with /^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(k) once RegExp is supported
        var kp = _is_identifier(k) ? k : "'" + k + "'";
        oitems.push(kp + ": " + _inspect(val[k], nextDepth, colors, newSeen));
    }
    return "{ " + oitems.join(", ") + " }";
}

// TODO: remove once RegExp is supported — replace manual check with regex literal
function _is_identifier(s) {
    if (s.length === 0) { return false; }
    var c0 = s[0];
    if (!((c0 >= "a" && c0 <= "z") || (c0 >= "A" && c0 <= "Z") || c0 === "_" || c0 === "$")) {
        return false;
    }
    for (var ii = 1; ii < s.length; ii++) {
        var ci = s[ii];
        if (!((ci >= "a" && ci <= "z") || (ci >= "A" && ci <= "Z") ||
              (ci >= "0" && ci <= "9") || ci === "_" || ci === "$")) {
            return false;
        }
    }
    return true;
}

function _format_number(n) {
    if (n !== n) { return "NaN"; }
    if (n === Infinity)  { return "Infinity"; }
    if (n === -Infinity) { return "-Infinity"; }
    return "" + n;
}

function _escape_string(s) {
    var out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s[i];
        if (c === "'")  { out += "\\'"; }
        else if (c === "\\") { out += "\\\\"; }
        else if (c === "\n") { out += "\\n"; }
        else if (c === "\r") { out += "\\r"; }
        else if (c === "\t") { out += "\\t"; }
        else { out += c; }
    }
    return out;
}

// ── util.format ──────────────────────────────────────────────────────────────

/**
 * Node-style extra argument string (primitives + null/undefined as String;
 * objects and functions go through inspect).
 */
function _formatExtraArg(a) {
    if (a === null || a === undefined) { return String(a); }
    var t = typeof a;
    if (t === "object" || t === "function") { return inspect(a); }
    return String(a);
}

/**
 * Returns a formatted string using printf-style substitutions.
 * Supported: %s, %d, %i, %f, %j, %o, %O, %%
 */
function format() {
    if (arguments.length === 0) { return ""; }

    var first = arguments[0];
    if (typeof first !== "string") {
        // No format string — join all args with spaces
        var parts = [];
        for (var n = 0; n < arguments.length; n++) {
            parts.push(_formatExtraArg(arguments[n]));
        }
        return parts.join(" ");
    }

    var fmt  = first;
    var idx  = 1;
    var out  = "";
    var fi   = 0;

    while (fi < fmt.length) {
        var ch = fmt[fi];
        if (ch === "%" && fi + 1 < fmt.length) {
            var spec = fmt[fi + 1];
            if (spec === "s") {
                out += idx < arguments.length ? "" + arguments[idx] : "%s";
                idx++;
                fi += 2;
                continue;
            } else if (spec === "d") {
                // %d: ToNumber then trunc — use unary + to coerce strings first
                out += idx < arguments.length ? "" + Math.trunc(+arguments[idx]) : "%d";
                idx++;
                fi += 2;
                continue;
            } else if (spec === "i") {
                // %i: parse as integer (supports string inputs like '42')
                out += idx < arguments.length ? "" + parseInt(arguments[idx], 10) : "%i";
                idx++;
                fi += 2;
                continue;
            } else if (spec === "f") {
                out += idx < arguments.length ? "" + parseFloat(arguments[idx]) : "%f";
                idx++;
                fi += 2;
                continue;
            } else if (spec === "j") {
                out += idx < arguments.length ? JSON.stringify(arguments[idx]) : "%j";
                idx++;
                fi += 2;
                continue;
            } else if (spec === "o" || spec === "O") {
                out += idx < arguments.length ? inspect(arguments[idx]) : ("%" + spec);
                idx++;
                fi += 2;
                continue;
            } else if (spec === "%") {
                out += "%";
                fi += 2;
                continue;
            }
        }
        out += ch;
        fi++;
    }

    // Append any extra arguments not consumed by format string
    while (idx < arguments.length) {
        out += " " + _formatExtraArg(arguments[idx]);
        idx++;
    }

    return out;
}

// ── util.promisify ────────────────────────────────────────────────────────────

var promisify_custom = Symbol ? Symbol.for("nodejs.util.promisify.custom") : null;

/**
 * Takes a function following the Node.js error-first callback style and
 * returns a version that returns a Promise.
 *
 *   fs.readFile(path, encoding, callback)
 *   → util.promisify(fs.readFile)(path, encoding) → Promise
 */
function promisify(original) {
    if (typeof original !== "function") {
        throw new TypeError("The \"original\" argument must be of type Function");
    }

    // Node.js custom promisify support
    if (promisify_custom && original[promisify_custom]) {
        var fn2 = original[promisify_custom];
        if (typeof fn2 !== "function") {
            throw new TypeError("The util.promisify.custom property must be of type Function");
        }
        return fn2;
    }

    function promisified() {
        var args = [];
        for (var pi = 0; pi < arguments.length; pi++) {
            args.push(arguments[pi]);
        }
        return new Promise(function(resolve, reject) {
            args.push(function(err, value) {
                if (err) { reject(err); }
                else { resolve(value); }
            });
            original.apply(this, args);
        });
    }

    return promisified;
}

if (promisify_custom) {
    promisify.custom = promisify_custom;
}

// ── util.callbackify ──────────────────────────────────────────────────────────

/**
 * Takes an async function (one that returns a Promise) and returns a function
 * following the error-first callback style.
 */
function callbackify(original) {
    if (typeof original !== "function") {
        throw new TypeError("The \"original\" argument must be of type Function");
    }

    function callbackified() {
        var args = [];
        for (var ci = 0; ci < arguments.length - 1; ci++) {
            args.push(arguments[ci]);
        }
        var cb = arguments[arguments.length - 1];
        if (typeof cb !== "function") {
            throw new TypeError("The last argument must be of type Function");
        }
        var p = original.apply(this, args);
        // Wrap non-Promise returns in a resolved Promise (matches Node.js behaviour)
        if (p === null || p === undefined || typeof p.then !== "function") {
            p = Promise.resolve(p);
        }
        p.then(
            function(val) { cb(null, val); },
            function(err) { cb(err); }
        );
    }

    return callbackified;
}

// ── util.inherits ─────────────────────────────────────────────────────────────

/**
 * Inherit the prototype methods from one constructor into another. The
 * prototype of `constructor` will be set to a new object created from
 * `superConstructor`.
 */
function inherits(constructor, superConstructor) {
    if (constructor === undefined || constructor === null) {
        throw new TypeError("The \"constructor\" argument must be of type Function");
    }
    if (superConstructor === undefined || superConstructor === null) {
        throw new TypeError("The \"superConstructor\" argument must be of type Function");
    }
    if (typeof superConstructor.prototype !== "object") {
        throw new TypeError("The \"superConstructor.prototype\" property must be of type Object");
    }
    constructor.super_ = superConstructor;

    // Create a new prototype from superConstructor.prototype
    var F = function() {};
    F.prototype = superConstructor.prototype;
    constructor.prototype = new F();
    constructor.prototype.constructor = constructor;
}

// ── util.deprecate ────────────────────────────────────────────────────────────

var _deprecate_warned = {};

/**
 * Marks a function as deprecated, emitting a warning to stderr on first call.
 */
function deprecate(fn, msg, code) {
    if (typeof process !== "undefined" && process.noDeprecation) {
        return fn;
    }

    var warned = false;
    function deprecated() {
        if (!warned) {
            warned = true;
            var warnMsg = "DeprecationWarning: " + msg;
            if (code) { warnMsg += " [" + code + "]"; }
            if (typeof process !== "undefined" && process.emitWarning) {
                process.emitWarning(warnMsg, "DeprecationWarning");
            } else if (typeof console !== "undefined" && console.error) {
                console.error(warnMsg);
            }
        }
        return fn.apply(this, arguments);
    }
    return deprecated;
}

// ── util.types ────────────────────────────────────────────────────────────────

/**
 * Type predicate functions.
 * All functions return a boolean.
 */
var types = {
    isDate: function(v) {
        return v instanceof Date;
    },
    isRegExp: function(v) {
        return v instanceof RegExp;
    },
    isMap: function(v) {
        return v instanceof Map;
    },
    isSet: function(v) {
        return v instanceof Set;
    },
    isWeakMap: function(v) {
        return v instanceof WeakMap;
    },
    isWeakSet: function(v) {
        return v instanceof WeakSet;
    },
    isPromise: function(v) {
        return v instanceof Promise;
    },
    isArrayBuffer: function(v) {
        if (typeof ArrayBuffer !== "undefined" && v instanceof ArrayBuffer) { return true; }
        return Object.prototype.toString.call(v) === "[object ArrayBuffer]";
    },
    isTypedArray: function(v) {
        if (v === null || v === undefined || typeof v !== "object") { return false; }
        if (typeof Uint8Array !== "undefined" && v instanceof Uint8Array) { return true; }
        if (typeof Int8Array !== "undefined" && v instanceof Int8Array) { return true; }
        if (typeof Uint16Array !== "undefined" && v instanceof Uint16Array) { return true; }
        if (typeof Int16Array !== "undefined" && v instanceof Int16Array) { return true; }
        if (typeof Uint32Array !== "undefined" && v instanceof Uint32Array) { return true; }
        if (typeof Int32Array !== "undefined" && v instanceof Int32Array) { return true; }
        if (typeof Float32Array !== "undefined" && v instanceof Float32Array) { return true; }
        if (typeof Float64Array !== "undefined" && v instanceof Float64Array) { return true; }
        if (typeof Uint8ClampedArray !== "undefined" && v instanceof Uint8ClampedArray) { return true; }
        var tag = Object.prototype.toString.call(v);
        return tag === "[object Uint8Array]"   ||
               tag === "[object Int8Array]"    ||
               tag === "[object Uint16Array]"  ||
               tag === "[object Int16Array]"   ||
               tag === "[object Uint32Array]"  ||
               tag === "[object Int32Array]"   ||
               tag === "[object Float32Array]" ||
               tag === "[object Float64Array]";
    },
    isNativeError: function(v) {
        return v instanceof Error && (
            v instanceof TypeError     ||
            v instanceof RangeError    ||
            v instanceof ReferenceError ||
            v instanceof SyntaxError   ||
            v instanceof URIError      ||
            v instanceof EvalError     ||
            v instanceof Error
        );
    },
    isGeneratorFunction: function(v) {
        // Generators not implemented in our engine; always false
        return false;
    },
    isGeneratorObject: function(v) {
        return false;
    },
    isAsyncFunction: function(v) {
        return false;
    },
    isProxy: function(v) {
        return false;
    },
    isArgumentsObject: function(v) {
        return Object.prototype.toString.call(v) === "[object Arguments]";
    },
    isBoxedPrimitive: function(v) {
        var tag = Object.prototype.toString.call(v);
        return tag === "[object Number]"  ||
               tag === "[object String]"  ||
               tag === "[object Boolean]" ||
               tag === "[object Symbol]"  ||
               tag === "[object BigInt]";
    },
    isExternal: function(v) {
        return false;
    },
    // node:crypto installs the brand check once it is first required; until
    // then no KeyObject can exist.
    isKeyObject: function(v) {
        var probe = globalThis.__isKeyObject;
        return typeof probe === "function" ? probe(v) === true : false;
    },
    isCryptoKey: function(v) {
        return false;
    },
    isModule: function(v) {
        return false;
    },
    // Module Namespace Exotic Objects report @@toStringTag === "Module".
    isModuleNamespaceObject: function(v) {
        return Object.prototype.toString.call(v) === "[object Module]";
    },
    isBigInt64Array: function(v) {
        return Object.prototype.toString.call(v) === "[object BigInt64Array]";
    },
    isBigUint64Array: function(v) {
        return Object.prototype.toString.call(v) === "[object BigUint64Array]";
    },
    isFloat32Array: function(v) {
        if (typeof Float32Array !== "undefined" && v instanceof Float32Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Float32Array]";
    },
    isFloat64Array: function(v) {
        if (typeof Float64Array !== "undefined" && v instanceof Float64Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Float64Array]";
    },
    isInt8Array: function(v) {
        if (typeof Int8Array !== "undefined" && v instanceof Int8Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Int8Array]";
    },
    isInt16Array: function(v) {
        if (typeof Int16Array !== "undefined" && v instanceof Int16Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Int16Array]";
    },
    isInt32Array: function(v) {
        if (typeof Int32Array !== "undefined" && v instanceof Int32Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Int32Array]";
    },
    isUint8Array: function(v) {
        if (typeof Uint8Array !== "undefined" && v instanceof Uint8Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Uint8Array]";
    },
    isUint8ClampedArray: function(v) {
        if (typeof Uint8ClampedArray !== "undefined" && v instanceof Uint8ClampedArray) { return true; }
        return Object.prototype.toString.call(v) === "[object Uint8ClampedArray]";
    },
    isUint16Array: function(v) {
        if (typeof Uint16Array !== "undefined" && v instanceof Uint16Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Uint16Array]";
    },
    isUint32Array: function(v) {
        if (typeof Uint32Array !== "undefined" && v instanceof Uint32Array) { return true; }
        return Object.prototype.toString.call(v) === "[object Uint32Array]";
    },
    isSharedArrayBuffer: function(v) {
        if (typeof SharedArrayBuffer !== "undefined" && v instanceof SharedArrayBuffer) { return true; }
        return Object.prototype.toString.call(v) === "[object SharedArrayBuffer]";
    },
    isDataView: function(v) {
        if (typeof DataView !== "undefined" && v instanceof DataView) { return true; }
        return Object.prototype.toString.call(v) === "[object DataView]";
    },
    isNumberObject: function(v) {
        return Object.prototype.toString.call(v) === "[object Number]";
    },
    isStringObject: function(v) {
        return Object.prototype.toString.call(v) === "[object String]";
    },
    isBooleanObject: function(v) {
        return Object.prototype.toString.call(v) === "[object Boolean]";
    },
    isSymbolObject: function(v) {
        return Object.prototype.toString.call(v) === "[object Symbol]";
    },
    isBigIntObject: function(v) {
        return Object.prototype.toString.call(v) === "[object BigInt]";
    }
};

// ── util.isDeepStrictEqual ────────────────────────────────────────────────────

/**
 * Deep strict equality comparison (as defined by Node.js assert.deepStrictEqual).
 *
 * Rules:
 *  - Primitives: `===`
 *  - Objects: same prototype, same own enumerable keys, recursively equal values
 *  - Arrays: same length, recursively equal elements
 *  - Date: same time value
 *  - NaN === NaN (unlike ===)
 */
function isDeepStrictEqual(a, b) {
    return _deep_equal(a, b, []);
}

function _deep_equal(a, b, seen) {
    // Strict primitives (handle NaN; use Object.is semantics: +0 !== -0)
    if (a === b) {
        // Distinguish +0 from -0: 1/+0 === Infinity, 1/-0 === -Infinity
        if (a === 0) { return (1/a) === (1/b); }
        return true;
    }
    // NaN check must come before the typeof guard (typeof NaN === 'number', not 'object')
    if (typeof a === "number" && typeof b === "number" && a !== a && b !== b) { return true; }
    if (typeof a !== typeof b) { return false; }
    if (a === null || b === null) { return false; }  // one must be non-null given ===
    if (typeof a !== "object" && typeof a !== "function") { return false; }

    // Date
    if (a instanceof Date && b instanceof Date) {
        return a.getTime() === b.getTime();
    }
    if ((a instanceof Date) !== (b instanceof Date)) { return false; }

    // RegExp
    if (a instanceof RegExp && b instanceof RegExp) {
        return a.source === b.source && a.flags === b.flags;
    }
    if ((a instanceof RegExp) !== (b instanceof RegExp)) { return false; }

    // Array
    if (Array.isArray(a) !== Array.isArray(b)) { return false; }
    if (Array.isArray(a)) {
        if (a.length !== b.length) { return false; }
        for (var ai = 0; ai < a.length; ai++) {
            if (!_deep_equal(a[ai], b[ai], seen)) { return false; }
        }
        return true;
    }

    // Map
    if ((a instanceof Map) && (b instanceof Map)) {
        if (a.size !== b.size) { return false; }
        var ok = true;
        a.forEach(function(v, k) {
            if (!b.has(k))                    { ok = false; }
            else if (!_deep_equal(v, b.get(k), seen)) { ok = false; }
        });
        return ok;
    }
    if ((a instanceof Map) !== (b instanceof Map)) { return false; }

    // Set
    if ((a instanceof Set) && (b instanceof Set)) {
        if (a.size !== b.size) { return false; }
        var sok = true;
        a.forEach(function(v) {
            if (!b.has(v)) { sok = false; }
        });
        return sok;
    }
    if ((a instanceof Set) !== (b instanceof Set)) { return false; }

    // Circular detection
    for (var si = 0; si < seen.length; si += 2) {
        if (seen[si] === a && seen[si + 1] === b) { return true; }
    }
    seen.push(a);
    seen.push(b);

    // Plain objects
    var ak = Object.keys(a);
    var bk = Object.keys(b);
    if (ak.length !== bk.length) { return false; }
    for (var ki = 0; ki < ak.length; ki++) {
        var key = ak[ki];
        if (!Object.prototype.hasOwnProperty.call(b, key)) { return false; }
        if (!_deep_equal(a[key], b[key], seen)) { return false; }
    }
    return true;
}

// ── util.debuglog ─────────────────────────────────────────────────────────────

/**
 * Returns a logging function that writes to stderr when the NODE_DEBUG
 * environment variable includes `section`.  Otherwise returns a no-op.
 */
function debuglog(section) {
    var envDebug = (typeof process !== "undefined" && process.env && process.env.NODE_DEBUG) || "";
    var upper = section.toUpperCase();
    var enabled = envDebug.indexOf(upper) !== -1;
    if (enabled) {
        return function() {
            var msg = format.apply(null, arguments);
            if (typeof process !== "undefined" && process.stderr) {
                process.stderr.write(upper + " " + process.pid + ": " + msg + "\n");
            }
        };
    }
    return function() {};
}

// ── util.parseArgs (Node.js 18.3+) ───────────────────────────────────────────

/**
 * Minimal implementation of util.parseArgs.
 * Options: { args?, options?, strict?, allowPositionals? }
 * Returns: { values: {}, positionals: [] }
 */
function parseArgs(config) {
    config = config || {};
    var argv = config.args || (typeof process !== "undefined" ? process.argv.slice(2) : []);
    var optDefs = config.options || {};
    var strict = config.strict !== false;
    var allowPositionals = config.allowPositionals !== false;

    var values = {};
    var positionals = [];

    // Initialize defaults
    var dkeys = Object.keys(optDefs);
    for (var di = 0; di < dkeys.length; di++) {
        var dk = dkeys[di];
        var def = optDefs[dk];
        if (def.default !== undefined) {
            values[dk] = def.default;
        }
    }

    var i = 0;
    while (i < argv.length) {
        var arg = argv[i];
        if (arg === "--") {
            i++;
            while (i < argv.length) { positionals.push(argv[i]); i++; }
            break;
        } else if (arg.length > 2 && arg[0] === "-" && arg[1] === "-") {
            var long = arg.slice(2);
            var eqPos = long.indexOf("=");
            var name2, value2;
            if (eqPos !== -1) {
                name2 = long.slice(0, eqPos);
                value2 = long.slice(eqPos + 1);
            } else {
                name2 = long;
                value2 = undefined;
            }
            var def2 = optDefs[name2];
            if (def2) {
                if (def2.type === "string") {
                    values[name2] = value2 !== undefined ? value2 : (argv[i + 1] || "");
                    if (value2 === undefined) { i++; }
                } else {
                    values[name2] = true;
                }
            } else if (strict) {
                throw new Error("Unknown option: --" + name2);
            }
        } else if (arg.length > 1 && arg[0] === "-" && arg[1] !== "-") {
            var short = arg[1];
            // Short options: look up alias
            var found = false;
            var skeys = Object.keys(optDefs);
            for (var sk = 0; sk < skeys.length; sk++) {
                var sdef = optDefs[skeys[sk]];
                if (sdef.short === short) {
                    if (sdef.type === "string") {
                        var sval = arg.length > 2 ? arg.slice(2) : argv[i + 1];
                        values[skeys[sk]] = sval || "";
                        if (arg.length <= 2) { i++; }
                    } else {
                        values[skeys[sk]] = true;
                    }
                    found = true;
                    break;
                }
            }
            if (!found && strict) {
                throw new Error("Unknown option: -" + short);
            }
        } else {
            if (!allowPositionals && strict) {
                throw new Error("Unexpected argument: " + arg);
            }
            positionals.push(arg);
        }
        i++;
    }

    return { values: values, positionals: positionals };
}

// ── util.styleText (Node.js v20.12+) ─────────────────────────────────────────

/**
 * ANSI SGR open/close codes for each style name.
 * Format: [openCode, closeCode]
 */
var _STYLE_CODES = {
    // modifiers
    reset:         [0,   0],
    bold:          [1,  22],
    dim:           [2,  22],
    italic:        [3,  23],
    underline:     [4,  24],
    blink:         [5,  25],
    overline:      [53, 55],
    inverse:       [7,  27],
    hidden:        [8,  28],
    strikethrough: [9,  29],
    // foreground colours
    black:         [30, 39],
    red:           [31, 39],
    green:         [32, 39],
    yellow:        [33, 39],
    blue:          [34, 39],
    magenta:       [35, 39],
    cyan:          [36, 39],
    white:         [37, 39],
    gray:          [90, 39],
    grey:          [90, 39],
    blackBright:   [90, 39],
    redBright:     [91, 39],
    greenBright:   [92, 39],
    yellowBright:  [93, 39],
    blueBright:    [94, 39],
    magentaBright: [95, 39],
    cyanBright:    [96, 39],
    whiteBright:   [97, 39],
    // background colours
    bgBlack:         [40, 49],
    bgRed:           [41, 49],
    bgGreen:         [42, 49],
    bgYellow:        [43, 49],
    bgBlue:          [44, 49],
    bgMagenta:       [45, 49],
    bgCyan:          [46, 49],
    bgWhite:         [47, 49],
    bgGray:          [100, 49],
    bgGrey:          [100, 49],
    bgBlackBright:   [100, 49],
    bgRedBright:     [101, 49],
    bgGreenBright:   [102, 49],
    bgYellowBright:  [103, 49],
    bgBlueBright:    [104, 49],
    bgMagentaBright: [105, 49],
    bgCyanBright:    [106, 49],
    bgWhiteBright:   [107, 49]
};

/**
 * Returns `text` wrapped in ANSI escape codes for the given style(s).
 *
 * @param {string|string[]} format  Style name or array of style names.
 * @param {string}          text    The string to format.
 * @param {object}          [opts]  Optional. { stream } — if stream.hasColors()
 *                                  returns false, ANSI codes are omitted.
 * @returns {string}
 */
function styleText(format, text, opts) {
    // Colour support check: if a stream is passed and it has no colour support,
    // return the plain string.
    if (opts && opts.stream && typeof opts.stream.hasColors === "function") {
        if (!opts.stream.hasColors()) { return String(text); }
    }

    var formats = Array.isArray(format) ? format : [format];
    var open  = "";
    var close = "";
    for (var fi = 0; fi < formats.length; fi++) {
        var codes = _STYLE_CODES[formats[fi]];
        if (!codes) {
            throw new TypeError("The provided value '" + formats[fi] + "' is not a valid style");
        }
        open  += "\x1b[" + codes[0] + "m";
        close  = "\x1b[" + codes[1] + "m" + close;
    }
    return open + String(text) + close;
}

// ── util.parseEnv ─────────────────────────────────────────────────────────────

/**
 * Parses a `.env`-style string into a plain object.
 * Rules (Node.js v20.12 behaviour):
 *   - Lines starting with # are comments.
 *   - Empty / whitespace-only lines are ignored.
 *   - KEY=VALUE  (no quoting expansion — values are taken as-is, trimmed).
 *   - Keys with no '=' are ignored.
 *   - Quoted values: single or double quotes around value are stripped.
 */
function parseEnv(content) {
    var result = {};
    if (typeof content !== "string") { return result; }
    var lines = content.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        // Strip trailing \r
        if (line.length > 0 && line[line.length - 1] === "\r") {
            line = line.slice(0, line.length - 1);
        }
        // Trim leading whitespace
        var start = 0;
        while (start < line.length && (line[start] === " " || line[start] === "\t")) { start++; }
        line = line.slice(start);
        // Skip comments and empty lines
        if (line.length === 0 || line[0] === "#") { continue; }
        // Find '='
        var eq = line.indexOf("=");
        if (eq < 0) { continue; }
        var key = line.slice(0, eq);
        var val = line.slice(eq + 1);
        // Trim key
        var ke = key.length;
        while (ke > 0 && (key[ke - 1] === " " || key[ke - 1] === "\t")) { ke--; }
        key = key.slice(0, ke);
        if (key.length === 0) { continue; }
        // Strip matching outer quotes from value
        if (val.length >= 2) {
            var q = val[0];
            if ((q === '"' || q === "'") && val[val.length - 1] === q) {
                val = val.slice(1, val.length - 1);
            }
        }
        result[key] = val;
    }
    return result;
}

// ── util.formatWithOptions ────────────────────────────────────────────────────

/**
 * Like util.format() but the first argument is an inspectOptions object
 * that controls how objects are rendered via util.inspect().
 * util.formatWithOptions(inspectOptions, format, ...args)
 */
function formatWithOptions(inspectOptions) {
    var args = [];
    for (var i = 1; i < arguments.length; i++) { args.push(arguments[i]); }
    if (args.length === 0) { return ""; }

    var first = args[0];
    if (typeof first !== "string") {
        var parts = [];
        for (var n = 0; n < args.length; n++) {
            var av = args[n];
            if (av !== null && (typeof av === "object" || typeof av === "function")) {
                parts.push(inspect(av, inspectOptions));
            } else {
                parts.push(_formatExtraArg(av));
            }
        }
        return parts.join(" ");
    }

    var fmt = first;
    var idx = 1;
    var out = "";
    var fi  = 0;
    while (fi < fmt.length) {
        var ch = fmt[fi];
        if (ch === "%" && fi + 1 < fmt.length) {
            var spec = fmt[fi + 1];
            if (spec === "s") {
                out += idx < args.length ? "" + args[idx] : "%s"; idx++; fi += 2; continue;
            } else if (spec === "d") {
                out += idx < args.length ? "" + Math.trunc(+args[idx]) : "%d"; idx++; fi += 2; continue;
            } else if (spec === "i") {
                out += idx < args.length ? "" + parseInt(args[idx], 10) : "%i"; idx++; fi += 2; continue;
            } else if (spec === "f") {
                out += idx < args.length ? "" + parseFloat(args[idx]) : "%f"; idx++; fi += 2; continue;
            } else if (spec === "j") {
                out += idx < args.length ? JSON.stringify(args[idx]) : "%j"; idx++; fi += 2; continue;
            } else if (spec === "o" || spec === "O") {
                out += idx < args.length ? inspect(args[idx], inspectOptions) : ("%" + spec); idx++; fi += 2; continue;
            } else if (spec === "%") {
                out += "%"; fi += 2; continue;
            }
        }
        out += ch; fi++;
    }
    while (idx < args.length) {
        var ea = args[idx];
        if (ea !== null && (typeof ea === "object" || typeof ea === "function")) {
            out += " " + inspect(ea, inspectOptions);
        } else {
            out += " " + _formatExtraArg(ea);
        }
        idx++;
    }
    return out;
}

// ── util.stripVTControlCharacters ────────────────────────────────────────────

/**
 * Strips ANSI / VT100 escape sequences from a string.
 * Removes CSI sequences (\x1b[...m), OSC sequences (\x1b]...\x07 or ST),
 * and other single-char Fe escape sequences.
 */
function stripVTControlCharacters(str) {
    if (typeof str !== "string") {
        throw new TypeError("The \"str\" argument must be of type string. Received type " + typeof str);
    }
    var out = "";
    var i = 0;
    while (i < str.length) {
        var c = str.charCodeAt(i);
        // ESC (0x1b)
        if (c === 0x1b) {
            i++;
            if (i >= str.length) { break; }
            var next = str.charCodeAt(i);
            // CSI sequence: ESC [ ... (final byte 0x40–0x7e)
            if (next === 0x5b) { // '['
                i++;
                while (i < str.length) {
                    var b = str.charCodeAt(i);
                    i++;
                    if (b >= 0x40 && b <= 0x7e) { break; }
                }
            // OSC sequence: ESC ] ... BEL or ESC\
            } else if (next === 0x5d) { // ']'
                i++;
                while (i < str.length) {
                    var ob = str.charCodeAt(i);
                    if (ob === 0x07) { i++; break; }
                    if (ob === 0x1b && i + 1 < str.length && str.charCodeAt(i + 1) === 0x5c) {
                        i += 2; break;
                    }
                    i++;
                }
            // Other Fe sequences (2-char): ESC + one byte
            } else {
                i++; // consume the second byte
            }
        // C1 control codes 0x80–0x9f
        } else if (c >= 0x80 && c <= 0x9f) {
            i++;
        } else {
            out += str[i];
            i++;
        }
    }
    return out;
}

// ── util.TextEncoder / util.TextDecoder (deferred stub) ───────────────────────

// Deferred to Phase 5.5 (buffer) — they depend on Buffer for binary data.
// For now expose the global TextEncoder/TextDecoder if available.
var TextEncoder = (typeof globalThis !== "undefined" && globalThis.TextEncoder) || undefined;
var TextDecoder = (typeof globalThis !== "undefined" && globalThis.TextDecoder) || undefined;

/**
 * util.getCallSites([frameCount][, options]) — Node.js call-site frames.
 * Best-effort parse of `Error().stack` for harnesses (test/common.mustNotCall).
 */
function getCallSites(frameCount, options) {
    if (typeof frameCount === 'object' && frameCount !== null) {
        options = frameCount;
        frameCount = undefined;
    }
    var max = typeof frameCount === 'number' && frameCount > 0 ? frameCount : 10;
    var err = new Error();
    var stack = typeof err.stack === 'string' ? err.stack : '';
    var lines = stack.split('\n');
    var sites = [];
    for (var i = 0; i < lines.length && sites.length < max + 2; i++) {
        var line = lines[i].trim();
        // "at fn (file:line:col)" or "at file:line:col"
        if (line.indexOf('at ') !== 0) continue;
        var rest = line.slice(3);
        var fnName = '';
        var loc = rest;
        var paren = rest.lastIndexOf('(');
        if (paren >= 0 && rest.charAt(rest.length - 1) === ')') {
            fnName = rest.slice(0, paren).trim();
            loc = rest.slice(paren + 1, rest.length - 1);
        }
        var parts = loc.split(':');
        var col = 0;
        var lineNo = 0;
        var script = loc;
        if (parts.length >= 3) {
            col = parseInt(parts[parts.length - 1], 10) || 0;
            lineNo = parseInt(parts[parts.length - 2], 10) || 0;
            script = parts.slice(0, parts.length - 2).join(':');
        } else if (parts.length === 2) {
            lineNo = parseInt(parts[1], 10) || 0;
            script = parts[0];
        }
        sites.push({
            functionName: fnName,
            scriptId: '0',
            scriptName: script,
            lineNumber: lineNo,
            columnNumber: col,
            column: col
        });
    }
    // Drop getCallSites frame itself
    if (sites.length > 0) sites = sites.slice(1);
    if (sites.length > max) sites = sites.slice(0, max);
    return sites;
}

// ── Module exports ────────────────────────────────────────────────────────────

module.exports = {
    inspect:                    inspect,
    format:                     format,
    formatWithOptions:          formatWithOptions,
    promisify:                  promisify,
    callbackify:                callbackify,
    inherits:                   inherits,
    deprecate:                  deprecate,
    debuglog:                   debuglog,
    parseArgs:                  parseArgs,
    parseEnv:                   parseEnv,
    isDeepStrictEqual:          isDeepStrictEqual,
    styleText:                  styleText,
    stripVTControlCharacters:   stripVTControlCharacters,
    getCallSites:               getCallSites,
    types:               types,
    TextEncoder:         TextEncoder,
    TextDecoder:         TextDecoder,

    // Legacy Node.js top-level predicates (deprecated in Node 4 but still exist)
    isNull:      function(v) { return v === null; },
    isUndefined: function(v) { return v === undefined; },
    isBoolean:   function(v) { return typeof v === "boolean"; },
    isNumber:    function(v) { return typeof v === "number"; },
    isString:    function(v) { return typeof v === "string"; },
    isSymbol:    function(v) { return typeof v === "symbol"; },
    isObject:    function(v) { return v !== null && typeof v === "object"; },
    isFunction:  function(v) { return typeof v === "function"; },
    isArray:     Array.isArray,
    isDate:      function(v) { return v instanceof Date; },
    isRegExp:    function(v) { return v instanceof RegExp; },
    isError:     function(v) { return v instanceof Error; },
    isPrimitive: function(v) {
        var t = typeof v;
        return v === null || t === "boolean" || t === "number" || t === "string" || t === "symbol" || t === "bigint" || t === "undefined";
    }
};
