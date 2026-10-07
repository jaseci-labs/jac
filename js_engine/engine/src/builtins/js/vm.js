/**
 * vm.js — Node.js `vm` / `node:vm`
 *
 * Contexts (createContext / isContext / runInContext / runInNewContext) and a
 * minimal Script are built on the engine primitives in `vm_native`:
 *
 *   createContext(sandbox)            contextify in place, seed ECMAScript
 *                                     intrinsics, return the SAME object
 *   isContext(obj)                    read the contextified marker back
 *   runInContext(code, ctx, filename) run `code` with `ctx` as the global object
 *   runInThisContext(code, filename)  run `code` in the host global scope
 *
 * The sandbox *is* the global object of the code it runs, per Node semantics —
 * so `process`, `require` and the embedder's top-level bindings are not
 * reachable from sandboxed code.
 */
'use strict';

var _native = require('vm_native');
var _errs = require('./internal/errors.js');

var errInvalidArgType = _errs.errInvalidArgType;

function _isObject(v) {
    return (typeof v === 'object' && v !== null) || typeof v === 'function';
}

/** Validate an `options` bag argument that Node requires to be an object. */
function _validateOptionsObject(name, options) {
    if (options === undefined) return {};
    if (!_isObject(options) || Array.isArray(options)) {
        throw errInvalidArgType(name, 'object', options);
    }
    return options;
}

/** Validate that `options[prop]`, when present, is a string. */
function _validateStringProp(options, optionsName, prop) {
    var val = options[prop];
    if (val === undefined) return;
    if (typeof val !== 'string') {
        throw errInvalidArgType(optionsName + '.' + prop, 'string', val);
    }
}

/**
 * Node accepts either a filename string or an options bag wherever a script is
 * run, so normalise both into { filename }.
 */
function _normalizeRunOptions(name, options) {
    if (typeof options === 'string') return { filename: options };
    var opts = _validateOptionsObject(name, options);
    _validateStringProp(opts, name, 'filename');
    return opts;
}

function _filenameOf(options) {
    return typeof options.filename === 'string' ? options.filename : '';
}

function createContext(contextObject, options) {
    if (contextObject === undefined) contextObject = {};
    if (!_isObject(contextObject)) {
        throw errInvalidArgType('contextObject', 'object', contextObject);
    }
    var opts = _validateOptionsObject('options', options);
    _validateStringProp(opts, 'options', 'name');
    _validateStringProp(opts, 'options', 'origin');
    return _native.createContext(contextObject);
}

function isContext(object) {
    if (!_isObject(object)) {
        throw errInvalidArgType('object', 'object', object);
    }
    return _native.isContext(object);
}

function runInContext(code, contextifiedObject, options) {
    if (typeof code !== 'string') {
        throw errInvalidArgType('code', 'string', code);
    }
    if (!_isObject(contextifiedObject) || !_native.isContext(contextifiedObject)) {
        throw errInvalidArgType('contextifiedObject', 'vm.Context', contextifiedObject);
    }
    var opts = _normalizeRunOptions('options', options);
    return _native.runInContext(code, contextifiedObject, _filenameOf(opts));
}

function runInNewContext(code, contextObject, options) {
    if (typeof code !== 'string') {
        throw errInvalidArgType('code', 'string', code);
    }
    var opts = _normalizeRunOptions('options', options);
    _validateStringProp(opts, 'options', 'contextName');
    _validateStringProp(opts, 'options', 'contextOrigin');
    var ctx = _native.createContext(_isObject(contextObject) ? contextObject : {});
    return _native.runInContext(code, ctx, _filenameOf(opts));
}

function runInThisContext(code, options) {
    if (typeof code !== 'string') {
        throw errInvalidArgType('code', 'string', code);
    }
    var opts = _normalizeRunOptions('options', options);
    return _native.runInThisContext(code, _filenameOf(opts));
}

/**
 * Minimal vm.Script: the source is re-compiled on every run (no cached data),
 * which is observationally equivalent apart from `cachedData` support.
 */
function Script(code, options) {
    if (!(this instanceof Script)) return new Script(code, options);
    if (typeof code !== 'string') {
        throw errInvalidArgType('code', 'string', code);
    }
    var opts = _normalizeRunOptions('options', options);
    this.code = code;
    this.filename = _filenameOf(opts);
    this.lineOffset = typeof opts.lineOffset === 'number' ? opts.lineOffset : 0;
    this.columnOffset = typeof opts.columnOffset === 'number' ? opts.columnOffset : 0;
    this.cachedDataRejected = undefined;
}

Script.prototype.runInThisContext = function (options) {
    var opts = _normalizeRunOptions('options', options);
    return _native.runInThisContext(this.code, _filenameOf(opts) || this.filename);
};

Script.prototype.runInContext = function (contextifiedObject, options) {
    if (!_isObject(contextifiedObject) || !_native.isContext(contextifiedObject)) {
        throw errInvalidArgType('contextifiedObject', 'vm.Context', contextifiedObject);
    }
    var opts = _normalizeRunOptions('options', options);
    return _native.runInContext(this.code, contextifiedObject,
                                _filenameOf(opts) || this.filename);
};

Script.prototype.runInNewContext = function (contextObject, options) {
    var opts = _normalizeRunOptions('options', options);
    var ctx = _native.createContext(_isObject(contextObject) ? contextObject : {});
    return _native.runInContext(this.code, ctx, _filenameOf(opts) || this.filename);
};

Script.prototype.createCachedData = function () {
    var err = new Error('vm.Script#createCachedData is not supported');
    err.code = 'ERR_NOT_SUPPORTED';
    throw err;
};

var _errsOutOfRange = _errs.errOutOfRange;
var INT32_MIN = -2147483648;
var INT32_MAX = 2147483647;

function _validateOffset(options, prop) {
    var val = options[prop];
    if (val === undefined) return 0;
    if (typeof val !== 'number') {
        throw errInvalidArgType('options.' + prop, 'number', val);
    }
    if (!Number.isInteger(val) || val < INT32_MIN || val > INT32_MAX) {
        throw _errsOutOfRange('options.' + prop,
            '>= ' + INT32_MIN + ' && <= ' + INT32_MAX, val);
    }
    return val;
}

/**
 * Minimal vm.compileFunction — wraps source in a function and returns it.
 * Honours filename / lineOffset / columnOffset range checks (Node parity).
 */
function compileFunction(code, params, options) {
    if (arguments.length < 1) {
        throw errInvalidArgType('code', 'string', code);
    }
    if (typeof code !== 'string') {
        throw errInvalidArgType('code', 'string', code);
    }
    var paramList = [];
    if (params !== undefined && params !== null) {
        if (!Array.isArray(params)) {
            throw errInvalidArgType('params', 'Array', params);
        }
        for (var i = 0; i < params.length; i++) {
            if (typeof params[i] !== 'string') {
                throw errInvalidArgType('params[' + i + ']', 'string', params[i]);
            }
            paramList.push(params[i]);
        }
    }
    var opts = _validateOptionsObject('options', options);
    _validateStringProp(opts, 'options', 'filename');
    _validateOffset(opts, 'lineOffset');
    _validateOffset(opts, 'columnOffset');
    var filename = _filenameOf(opts);
    var src = 'return function anonymous(' + paramList.join(',') + ') {\n' +
        code + '\n}';
    if (filename) {
        return _native.runInThisContext(src, filename)();
    }
    return _native.runInThisContext(src, '')();
}

// Experimental symbol used with importModuleDynamically (Node 20+).
var USE_MAIN_CONTEXT_DEFAULT_LOADER = Symbol('vm.USE_MAIN_CONTEXT_DEFAULT_LOADER');
var constants = {
    USE_MAIN_CONTEXT_DEFAULT_LOADER: USE_MAIN_CONTEXT_DEFAULT_LOADER
};

module.exports = {
    Script: Script,
    createContext: createContext,
    isContext: isContext,
    runInContext: runInContext,
    runInNewContext: runInNewContext,
    runInThisContext: runInThisContext,
    compileFunction: compileFunction,
    constants: constants,
    USE_MAIN_CONTEXT_DEFAULT_LOADER: USE_MAIN_CONTEXT_DEFAULT_LOADER
};
