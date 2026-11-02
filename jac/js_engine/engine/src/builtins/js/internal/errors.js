// internal/errors.js — shared Node-shaped Error factories for builtins.
'use strict';

function _receivedSuffix(actual) {
    if (actual === null || actual === undefined) {
        return ' Received ' + actual;
    }
    if (typeof actual === 'function') {
        return ' Received function ' + (actual.name || '');
    }
    if (typeof actual === 'bigint') {
        return ' Received type bigint (' + String(actual) + 'n)';
    }
    if (typeof actual === 'symbol') {
        return ' Received type symbol';
    }
    if (typeof actual === 'string') {
        return " Received type string ('" + actual + "')";
    }
    if (typeof actual === 'object') {
        var ctor = actual.constructor && actual.constructor.name;
        return ctor ? (' Received an instance of ' + ctor) : ' Received [Object]';
    }
    return ' Received type ' + typeof actual + ' (' + String(actual) + ')';
}

/**
 * Create ERR_INVALID_ARG_TYPE.
 * `expected` may be a string or array of type/class names.
 * Strings starting with "of type" / "an instance of" / "string or" are used as-is
 * (after ensuring a leading "of type" where Node expects it).
 */
function errInvalidArgType(name, expected, actual) {
    var types;
    if (Array.isArray(expected)) {
        types = expected;
    } else {
        types = [expected];
    }

    var mustBe;
    if (types.length === 1 && typeof types[0] === 'string') {
        var e = types[0];
        if (e.indexOf('of type ') === 0 || e.indexOf('an instance of ') === 0) {
            mustBe = e;
        } else if (e.indexOf('string or an instance') === 0 || e.indexOf('string or ') === 0) {
            mustBe = 'of type ' + e;
        } else if (e.indexOf(' or an instance of ') !== -1) {
            mustBe = 'of type ' + e;
        } else if (
            e === 'Buffer or Uint8Array' ||
            e === 'Buffer or ArrayBuffer' ||
            e.indexOf('Buffer or Uint8Array') === 0 ||
            (e.charAt(0) >= 'A' && e.charAt(0) <= 'Z' && e.indexOf(' ') === -1)
        ) {
            mustBe = 'an instance of ' + e;
        } else if (e === 'Object' || e === 'Array') {
            mustBe = 'an instance of ' + e;
        } else {
            mustBe = 'of type ' + e;
        }
    } else {
        // Multiple: "of type A or B" vs "an instance of A or B"
        var allLower = true;
        for (var i = 0; i < types.length; i++) {
            var t = String(types[i]);
            if (t.charAt(0) >= 'A' && t.charAt(0) <= 'Z') {
                allLower = false;
                break;
            }
        }
        var joined;
        if (types.length === 2) {
            joined = types[0] + ' or ' + types[1];
        } else {
            joined = types.slice(0, -1).join(', ') + ', or ' + types[types.length - 1];
        }
        // Node uses "one of type A or B" for multiple primitive types.
        mustBe = allLower ? ('one of type ' + joined) : ('an instance of ' + joined);
    }

    var msg = 'The "' + name + '" argument must be ' + mustBe + '.' + _receivedSuffix(actual);
    var err = new TypeError(msg);
    err.code = 'ERR_INVALID_ARG_TYPE';
    return err;
}

function errInvalidArgValue(name, value, reason) {
    var msg = "The argument '" + name + "' " + (reason || 'is invalid') +
        '. Received ' + String(value);
    var err = new TypeError(msg);
    err.code = 'ERR_INVALID_ARG_VALUE';
    return err;
}

function errOutOfRange(name, range, actual) {
    var msg = 'The value of "' + name + '" is out of range. It must be ' + range +
        '. Received ' + String(actual);
    var err = new RangeError(msg);
    err.code = 'ERR_OUT_OF_RANGE';
    return err;
}

function errUnavailableDuringExit() {
    var err = new Error('Cannot call this API during process exit');
    err.code = 'ERR_UNAVAILABLE_DURING_EXIT';
    return err;
}

module.exports = {
    errInvalidArgType: errInvalidArgType,
    errInvalidArgValue: errInvalidArgValue,
    errOutOfRange: errOutOfRange,
    errUnavailableDuringExit: errUnavailableDuringExit
};
