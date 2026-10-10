/**
 * structured_clone.js — global structuredClone (Vite V-17)
 *
 * Minimal WHATWG structured clone: primitives, arrays, plain objects, cycles.
 * Loaded after fetch.js (DOMException for DataCloneError).
 */

function _dataCloneError(message) {
    var msg = message || "Failed to execute 'structuredClone' on the global scope: The object could not be cloned.";
    if (typeof DOMException !== "undefined") {
        return new DOMException(msg, "DataCloneError");
    }
    var err = new TypeError(msg);
    err.name = "DataCloneError";
    return err;
}

function _isPlainObject(val) {
    if (val === null || typeof val !== "object") {
        return false;
    }
    var proto = Object.getPrototypeOf(val);
    return proto === Object.prototype || proto === null;
}

function _cloneValue(value, map) {
    if (value === null || value === undefined) {
        return value;
    }
    var t = typeof value;
    if (t === "string" || t === "number" || t === "boolean" || t === "bigint") {
        return value;
    }
    if (t === "symbol" || t === "function") {
        throw _dataCloneError();
    }
    if (map.has(value)) {
        return map.get(value);
    }
    if (Array.isArray(value)) {
        var arrOut = [];
        map.set(value, arrOut);
        for (var i = 0; i < value.length; i++) {
            arrOut[i] = _cloneValue(value[i], map);
        }
        return arrOut;
    }
    if (_isPlainObject(value)) {
        var objOut = {};
        map.set(value, objOut);
        var keys = Object.keys(value);
        for (var k = 0; k < keys.length; k++) {
            var key = keys[k];
            objOut[key] = _cloneValue(value[key], map);
        }
        return objOut;
    }
    throw _dataCloneError();
}

function structuredClone(value, options) {
    if (options !== undefined && options !== null && options.transfer !== undefined) {
        var transfer = options.transfer;
        if (transfer !== null && transfer !== undefined && typeof transfer.indexOf === "function") {
            if (typeof ArrayBuffer !== "undefined" && value instanceof ArrayBuffer) {
                if (transfer.indexOf(value) !== -1) {
                    var moved = value.slice(0);
                    value._byteLength = 0;
                    return moved;
                }
            }
            if (typeof Uint8Array !== "undefined" && value instanceof Uint8Array) {
                var ab = value.buffer;
                if (ab instanceof ArrayBuffer && transfer.indexOf(ab) !== -1) {
                    var copyBuf = ab.slice(0);
                    var out = new Uint8Array(copyBuf);
                    ab._byteLength = 0;
                    return out;
                }
            }
        }
    }
    return _cloneValue(value, new Map());
}

globalThis.structuredClone = structuredClone;
