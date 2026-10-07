// internal/validators.js — shared Node-style argument validators for builtins.
'use strict';

var errors = require('./errors.js');

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
    if (typeof value !== 'number') {
        throw errors.errInvalidArgType(name, 'number', value);
    }
    if (!Number.isInteger(value)) {
        throw errors.errOutOfRange(name, 'an integer', value);
    }
    if (min !== undefined && value < min) {
        throw errors.errOutOfRange(name, '>= ' + min, value);
    }
    if (max !== undefined && value > max) {
        throw errors.errOutOfRange(name, '<= ' + max, value);
    }
}

function validateBuffer(buffer, name) {
    name = name || 'buffer';
    var B = globalThis.Buffer;
    var ok = false;
    if (B && B.isBuffer && B.isBuffer(buffer)) ok = true;
    else if (typeof Uint8Array !== 'undefined' && buffer instanceof Uint8Array) ok = true;
    else if (buffer && typeof buffer === 'object' && typeof buffer.length === 'number' &&
             buffer.buffer !== undefined) ok = true;
    if (!ok) {
        throw errors.errInvalidArgType(name, 'Buffer or Uint8Array', buffer);
    }
}

function validateUint8Array(buffer, name) {
    name = name || 'buffer';
    if (typeof Uint8Array === 'undefined' || !(buffer instanceof Uint8Array)) {
        var B = globalThis.Buffer;
        if (!(B && B.isBuffer && B.isBuffer(buffer))) {
            throw errors.errInvalidArgType(name, 'Buffer or Uint8Array', buffer);
        }
    }
}

module.exports = {
    validateString: validateString,
    validateFunction: validateFunction,
    validateObject: validateObject,
    validateBoolean: validateBoolean,
    validateInteger: validateInteger,
    validateBuffer: validateBuffer,
    validateUint8Array: validateUint8Array
};
