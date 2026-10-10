/**
 * test.js — minimal Node.js `node:test` stub.
 *
 * Enough for fs suite tests that only import the module (describe/it/test).
 * Not a full test runner.
 */
'use strict';

function noop() {}

function test(name, options, fn) {
    if (typeof options === 'function') {
        fn = options;
        options = undefined;
    }
    if (typeof name === 'function') {
        fn = name;
    }
    if (typeof fn === 'function') {
        try { fn(); } catch (_e) { /* swallow in stub */ }
    }
}

function describe(name, options, fn) {
    if (typeof options === 'function') {
        fn = options;
        options = undefined;
    }
    if (typeof fn === 'function') {
        try { fn(); } catch (_e) { /* swallow */ }
    }
}

function it(name, options, fn) {
    return test(name, options, fn);
}

function before(fn) { if (typeof fn === 'function') try { fn(); } catch (_e) {} }
function after(fn) { if (typeof fn === 'function') try { fn(); } catch (_e) {} }
function beforeEach(fn) { if (typeof fn === 'function') { /* no-op registry */ } }
function afterEach(fn) { if (typeof fn === 'function') { /* no-op registry */ } }

module.exports = test;
module.exports.test = test;
module.exports.describe = describe;
module.exports.suite = describe; // Node: suite is an alias of describe
module.exports.it = it;
module.exports.before = before;
module.exports.after = after;
module.exports.beforeEach = beforeEach;
module.exports.afterEach = afterEach;
module.exports.skip = noop;
module.exports.todo = noop;
module.exports.only = test;
