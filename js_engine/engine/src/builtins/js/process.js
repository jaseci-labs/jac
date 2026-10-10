/**
 * process.js — thin JS validation wrappers over the native `process` object
 * (Wave 21). Keeps process.na.jac untouched; validates seteuid/setegid/setuid/
 * setgid argument types/shapes before delegating.
 */
'use strict';

var errors = require('./internal/errors.js');

var proc = globalThis.process;
if (!proc || typeof proc !== 'object') {
    module.exports = proc;
} else {
    function _resolveCredential(id, kind) {
        if (typeof id === 'number') {
            if (!Number.isInteger(id)) {
                throw errors.errOutOfRange('id', 'an integer', id);
            }
            return id;
        }
        if (typeof id === 'string') {
            if (id.length > 0 && /^\d+$/.test(id)) {
                return parseInt(id, 10);
            }
            // No getpwnam/getgrnam bridge yet — unknown names fail like Node.
            var label = kind === 'group' ? 'Group' : 'User';
            var err = new Error(label + ' identifier does not exist: ' + id);
            err.code = 'ERR_UNKNOWN_CREDENTIAL';
            throw err;
        }
        throw errors.errInvalidArgType('id', ['number', 'string'], id);
    }

    function _wrapSetter(nativeFn, kind) {
        if (typeof nativeFn !== 'function') return nativeFn;
        return function wrappedSetter(id) {
            if (arguments.length < 1) {
                throw errors.errInvalidArgType('id', ['number', 'string'], undefined);
            }
            var resolved = _resolveCredential(id, kind);
            return nativeFn.call(proc, resolved);
        };
    }

    if (typeof proc.seteuid === 'function') {
        proc.seteuid = _wrapSetter(proc.seteuid.bind(proc), 'user');
    }
    if (typeof proc.setegid === 'function') {
        proc.setegid = _wrapSetter(proc.setegid.bind(proc), 'group');
    }
    if (typeof proc.setuid === 'function') {
        proc.setuid = _wrapSetter(proc.setuid.bind(proc), 'user');
    }
    if (typeof proc.setgid === 'function') {
        proc.setgid = _wrapSetter(proc.setgid.bind(proc), 'group');
    }

    // Node: Object.prototype.toString.call(process) === '[object process]'
    if (typeof Symbol !== 'undefined' && Symbol.toStringTag !== undefined) {
        try {
            Object.defineProperty(proc, Symbol.toStringTag, {
                value: 'process',
                configurable: true,
                enumerable: false,
                writable: true
            });
        } catch (_e) { /* ignore */ }
    }

    // process.execArgv is built during native bootstrap before Array.prototype
    // is wired, so re-home it onto a real Array for .includes/.map/etc.
    if (proc.execArgv != null && typeof proc.execArgv === 'object') {
        try {
            proc.execArgv = Array.prototype.slice.call(proc.execArgv);
        } catch (_e2) { /* ignore */ }
    }

    // Minimal process.report stub (named export used by esm process tests).
    if (proc.report === undefined) {
        proc.report = {
            getReport: function () { return {}; },
            writeReport: function () { return ''; },
            directory: '',
            filename: '',
            compact: false,
            signal: 'SIGUSR2',
            reportOnFatalError: false,
            reportOnSignal: false,
            reportOnUncaughtException: false
        };
    }

    module.exports = proc;
}
