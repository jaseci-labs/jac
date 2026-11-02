// fs/validators.js — Node-style argument validation for fs APIs.
'use strict';

var errors = require('./errors.js');

var ENCODING_ALIASES = {
    'utf8': 'utf8',
    'utf-8': 'utf8',
    'ucs2': 'utf16le',
    'ucs-2': 'utf16le',
    'utf16le': 'utf16le',
    'utf-16le': 'utf16le',
    'latin1': 'latin1',
    'binary': 'latin1',
    'ascii': 'ascii',
    'hex': 'hex',
    'base64': 'base64',
    'base64url': 'base64url',
    'buffer': 'buffer'
};

function validateString(value, name) {
    if (typeof value !== 'string') {
        throw errors.errInvalidArgType(name, 'string', value);
    }
}

function validateFunction(value, name) {
    if (typeof value !== 'function') {
        throw errors.errInvalidArgType(name, 'function', value);
    }
}

function validateObject(value, name) {
    if (value === null || typeof value !== 'object') {
        throw errors.errInvalidArgType(name, 'Object', value);
    }
}

function validateBoolean(value, name) {
    if (typeof value !== 'boolean') {
        throw errors.errInvalidArgType(name, 'boolean', value);
    }
}

function validateInteger(value, name, min, max) {
    // Node defaults: MIN_SAFE_INTEGER..MAX_SAFE_INTEGER, so NaN/±Infinity/floats
    // and unsafe integers are all ERR_OUT_OF_RANGE.
    if (min === undefined) min = -9007199254740991;
    if (max === undefined) max = 9007199254740991;
    if (typeof value !== 'number') {
        throw errors.errInvalidArgType(name, 'number', value);
    }
    if (!Number.isInteger(value)) {
        throw errors.errOutOfRange(name, 'an integer', value);
    }
    if (value < min || value > max) {
        throw errors.errOutOfRange(name, '>= ' + min + ' && <= ' + max, value);
    }
}

// Node internal/fs/utils validatePosition: number → integer >= -1; bigint →
// -1n..(2^63-1 - length); anything else ERR_INVALID_ARG_TYPE.
function validatePosition(position, name, length) {
    if (typeof position === 'number') {
        validateInteger(position, name, -1);
    } else if (typeof position === 'bigint') {
        var maxPosition = (BigInt(2) ** BigInt(63)) - BigInt(1) - BigInt(length);
        if (!(position >= BigInt(-1) && position <= maxPosition)) {
            throw errors.errOutOfRange(name, '>= -1 && <= ' + maxPosition, position);
        }
    } else {
        throw errors.errInvalidArgType(name, 'integer or bigint', position);
    }
}

// ES-observable "options must be a plain-ish object": rejects arrays and
// functions (Node validateObject default flags) but allows boxed primitives.
function validateOptionsObject(value, name) {
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
        throw errors.errInvalidArgType(name, 'Object', value);
    }
}

function validateBufferArray(buffers, name) {
    name = name || 'buffers';
    if (!Array.isArray(buffers)) {
        throw errors.errInvalidArgType(name, 'ArrayBufferView[]', buffers);
    }
    for (var i = 0; i < buffers.length; i++) {
        if (!ArrayBuffer.isView(buffers[i])) {
            throw errors.errInvalidArgType(name, 'ArrayBufferView[]', buffers);
        }
    }
    return buffers;
}

function validateOffsetLengthRead(offset, length, bufferLength) {
    if (offset < 0) {
        throw errors.errOutOfRange('offset', '>= 0', offset);
    }
    if (length < 0) {
        throw errors.errOutOfRange('length', '>= 0', length);
    }
    if (offset + length > bufferLength) {
        throw errors.errOutOfRange('length', '<= ' + (bufferLength - offset), length);
    }
}

function validateOffsetLengthWrite(offset, length, byteLength) {
    if (offset > byteLength) {
        throw errors.errOutOfRange('offset', '<= ' + byteLength, offset);
    }
    var max = byteLength > 2147483647 ? 2147483647 : byteLength;
    if (length > max - offset) {
        throw errors.errOutOfRange('length', '<= ' + (max - offset), length);
    }
    if (length < 0) {
        throw errors.errOutOfRange('length', '>= 0', length);
    }
}

function validateFd(fd, name) {
    name = name || 'fd';
    if (typeof fd !== 'number') {
        throw errors.errInvalidArgType(name, 'number', fd);
    }
    if (!Number.isInteger(fd) || fd < 0) {
        throw errors.errOutOfRange(name, '>= 0 && <= 2147483647', fd);
    }
}

function validateBuffer(buffer, name) {
    name = name || 'buffer';
    if (!ArrayBuffer.isView(buffer)) {
        throw errors.errInvalidArgType(
            name, 'an instance of Buffer, TypedArray, or DataView', buffer);
    }
}

function validateNullBytes(str, name) {
    if (typeof str !== 'string') return;
    if (str.indexOf('\0') !== -1) {
        throw errors.errInvalidArgValue(name || 'path', str, 'must be a string without null bytes');
    }
}

function validatePath(path, name) {
    name = name || 'path';
    if (typeof path === 'string') {
        validateNullBytes(path, name);
        return;
    }
    if (path && typeof path === 'object' && typeof path.href === 'string') {
        // Literal NULs in href; %00 checked after fileURLToPath in _fsPathArg.
        validateNullBytes(path.href, name);
        return;
    }
    // Buffer path
    var B = globalThis.Buffer;
    if (B && B.isBuffer && B.isBuffer(path)) {
        for (var i = 0; i < path.length; i++) {
            if (path[i] === 0) {
                throw errors.errInvalidArgValue(name, path, 'must be a Buffer without null bytes');
            }
        }
        return;
    }
    throw errors.errInvalidArgType(name, 'string or an instance of Buffer or URL', path);
}

function validateEncoding(encoding, name) {
    name = name || 'encoding';
    if (encoding === undefined || encoding === null) return 'utf8';
    if (typeof encoding !== 'string') {
        throw errors.errInvalidArgType(name, 'string', encoding);
    }
    var key = encoding.toLowerCase();
    var mapped = ENCODING_ALIASES[key];
    if (!mapped) {
        // Node fs encoding checks use ERR_INVALID_ARG_VALUE (not ERR_UNKNOWN_ENCODING).
        throw errors.errInvalidArgValue(name, encoding, 'is invalid encoding');
    }
    return mapped;
}

function makeCallback(cb) {
    if (cb === undefined || cb === null) {
        throw errors.errInvalidArgType('callback', 'function', cb);
    }
    if (typeof cb !== 'function') {
        throw errors.errInvalidArgType('callback', 'function', cb);
    }
    return cb;
}

function makeStatsCallback(cb) {
    cb = makeCallback(cb);
    return function (err, stats) {
        if (err) return cb(err);
        return cb(null, stats);
    };
}

function validateUidGid(id, name) {
    if (typeof id !== 'number') {
        throw errors.errInvalidArgType(name, 'number', id);
    }
    // -1 means "leave unchanged" (Node validateInteger(id, name, -1, kMaxUserId)).
    if (!Number.isInteger(id) || id < -1 || id > 0xffffffff) {
        throw errors.errOutOfRange(name, '>= -1 && <= 4294967295', id);
    }
}

function validateMode(mode, name) {
    name = name || 'mode';
    if (mode === undefined || mode === null) return mode;
    if (typeof mode === 'number') {
        if (!Number.isInteger(mode) || mode < 0 || mode > 0o77777777) {
            throw errors.errOutOfRange(name, '>= 0 && <= 33554431', mode);
        }
        return mode;
    }
    if (typeof mode !== 'string') {
        throw errors.errInvalidArgType(name, 'number or string', mode);
    }
    // Node parseFileMode: only pure octal digit strings (/^[0-7]+$/).
    if (!/^[0-7]+$/.test(mode)) {
        throw errors.errInvalidArgValue(name, mode);
    }
    var parsed = parseInt(mode, 8);
    if (parsed > 0o77777777) {
        throw errors.errOutOfRange(name, '>= 0 && <= 33554431', mode);
    }
    return parsed;
}

module.exports = {
    ENCODING_ALIASES: ENCODING_ALIASES,
    validateString: validateString,
    validateFunction: validateFunction,
    validateObject: validateObject,
    validateOptionsObject: validateOptionsObject,
    validateBoolean: validateBoolean,
    validateInteger: validateInteger,
    validatePosition: validatePosition,
    validateFd: validateFd,
    validateBuffer: validateBuffer,
    validateBufferArray: validateBufferArray,
    validateOffsetLengthRead: validateOffsetLengthRead,
    validateOffsetLengthWrite: validateOffsetLengthWrite,
    validateNullBytes: validateNullBytes,
    validatePath: validatePath,
    validateEncoding: validateEncoding,
    validateUidGid: validateUidGid,
    validateMode: validateMode,
    makeCallback: makeCallback,
    makeStatsCallback: makeStatsCallback
};
