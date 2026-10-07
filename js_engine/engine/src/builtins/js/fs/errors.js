// fs/errors.js — Node-shaped Error factories for the fs JS surface.
'use strict';

function errInvalidArgType(name, expected, actual) {
    // Match Node message shape used by fs type-check tests:
    //   The "path" argument must be of type string or an instance of Buffer or URL. Received type boolean (false)
    // Primitive values are rendered inspect-style (strings quoted, truncated at
    // 25 chars) — tests compare against common.invalidArgTypeHelper verbatim.
    var suffix;
    if (actual === null || actual === undefined) {
        suffix = ' Received ' + actual;
    } else if (typeof actual === 'function') {
        suffix = ' Received function ' + (actual.name || '');
    } else if (typeof actual === 'object') {
        var ctor = actual.constructor && actual.constructor.name;
        suffix = ctor ? (' Received an instance of ' + ctor) : ' Received [Object]';
    } else {
        var inspected;
        if (typeof actual === 'string') {
            inspected = "'" + actual + "'";
        } else if (typeof actual === 'bigint') {
            inspected = String(actual) + 'n';
        } else {
            inspected = String(actual);
        }
        if (inspected.length > 28) { inspected = inspected.slice(0, 25) + '...'; }
        suffix = ' Received type ' + typeof actual + ' (' + inspected + ')';
    }
    // `expected` is either a bare type ("number"), a pre-worded phrase
    // ("an instance of X" / "of type …"), or an alternative list ("number or string").
    var mustBe;
    if (expected.indexOf('an instance of') === 0 || expected.indexOf('of type ') === 0) {
        mustBe = expected;
    } else {
        mustBe = 'of type ' + expected;
    }
    var msg = 'The "' + name + '" argument must be ' + mustBe + '.' + suffix;
    var err = new TypeError(msg);
    err.code = 'ERR_INVALID_ARG_TYPE';
    return err;
}

function errInvalidArgValue(name, value, reason) {
    var rendered = typeof value === 'string' ? ("'" + value + "'") : String(value);
    var msg = 'The argument \'' + name + '\' ' + (reason || 'is invalid') +
        '. Received ' + rendered;
    var err = new TypeError(msg);
    err.code = 'ERR_INVALID_ARG_VALUE';
    return err;
}

function errOutOfRange(name, range, value) {
    var msg = 'The value of "' + name + '" is out of range. It must be ' + range +
        '. Received ' + String(value);
    var err = new RangeError(msg);
    err.code = 'ERR_OUT_OF_RANGE';
    return err;
}

function errnoException(code, syscall, path, dest, message) {
    var msg = message;
    if (!msg) {
        msg = code + ': ' + (syscall || 'fs');
        if (path !== undefined && path !== null) {
            msg += " '" + path + "'";
        }
        if (dest !== undefined && dest !== null) {
            msg += " -> '" + dest + "'";
        }
    }
    var err = new Error(msg);
    err.code = code;
    err.errno = typeof code === 'string' ? undefined : code;
    if (typeof code === 'string') {
        // Map common codes to negative errno-ish values when known
        var table = {
            ENOENT: -2, EACCES: -13, EEXIST: -17, EINVAL: -22,
            EISDIR: -21, ENOTDIR: -20, EBADF: -9, EPERM: -1,
            ENOTEMPTY: -39, ELOOP: -40, ENAMETOOLONG: -36
        };
        if (table[code] !== undefined) err.errno = table[code];
    }
    if (syscall) err.syscall = syscall;
    if (path !== undefined && path !== null) err.path = path;
    if (dest !== undefined && dest !== null) err.dest = dest;
    return err;
}

function uvException(uvCode, syscall, path, dest) {
    // uvCode is negative libuv errno or a string code
    var code = uvCode;
    var errno = uvCode;
    if (typeof uvCode === 'number') {
        var names = {
            '-1': 'EPERM', '-2': 'ENOENT', '-13': 'EACCES', '-17': 'EEXIST',
            '-20': 'ENOTDIR', '-21': 'EISDIR', '-22': 'EINVAL', '-9': 'EBADF',
            '-39': 'ENOTEMPTY', '-40': 'ELOOP', '-36': 'ENAMETOOLONG',
            '-11': 'EAGAIN', '-4': 'EINTR', '-5': 'EIO', '-14': 'EFAULT',
            '-28': 'ENOSPC', '-30': 'EROFS', '-16': 'EBUSY'
        };
        code = names[String(uvCode)] || ('E' + String(-uvCode));
        errno = uvCode;
    }
    var err = errnoException(code, syscall, path, dest);
    err.errno = errno;
    return err;
}

module.exports = {
    errInvalidArgType: errInvalidArgType,
    errInvalidArgValue: errInvalidArgValue,
    errOutOfRange: errOutOfRange,
    errnoException: errnoException,
    uvException: uvException
};
