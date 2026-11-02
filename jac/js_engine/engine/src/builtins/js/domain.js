/**
 * domain.js — Node.js `domain` / `node:domain` (deprecated API, MVP compat)
 */
'use strict';

var EventEmitter = require('events');
if (EventEmitter.EventEmitter) EventEmitter = EventEmitter.EventEmitter;

var _stack = [];
var _active = null;

function _setActive(d) {
    _active = d;
    try {
        if (typeof process !== 'undefined') process.domain = d;
    } catch (_e) { /* ignore */ }
}

function Domain() {
    EventEmitter.init.call(this);
    this.members = [];
}
Domain.prototype = Object.create(EventEmitter.prototype);
Domain.prototype.constructor = Domain;

Domain.prototype.enter = function () {
    _stack.push(this);
    _setActive(this);
    return this;
};

Domain.prototype.exit = function () {
    var idx = -1;
    for (var i = _stack.length - 1; i >= 0; i--) {
        if (_stack[i] === this) { idx = i; break; }
    }
    if (idx === -1) return this;
    _stack.splice(idx, _stack.length - idx);
    var top = _stack.length > 0 ? _stack[_stack.length - 1] : null;
    _setActive(top);
    return this;
};

Domain.prototype.run = function (fn) {
    var args = [];
    for (var i = 1; i < arguments.length; i++) args.push(arguments[i]);
    this.enter();
    try {
        return fn.apply(null, args);
    } catch (err) {
        this.emit('error', err);
    } finally {
        this.exit();
    }
};

Domain.prototype.add = function (ee) {
    if (!ee || typeof ee.on !== 'function') return this;
    if (ee.domain === this) return this;
    if (ee.domain && typeof ee.domain.remove === 'function') {
        ee.domain.remove(ee);
    }
    try {
        Object.defineProperty(ee, 'domain', {
            value: this,
            configurable: true,
            enumerable: false,
            writable: true
        });
    } catch (_e) {
        ee.domain = this;
    }
    this.members.push(ee);
    return this;
};

Domain.prototype.remove = function (ee) {
    if (!ee) return this;
    var idx = this.members.indexOf(ee);
    if (idx !== -1) this.members.splice(idx, 1);
    if (ee.domain === this) {
        try {
            Object.defineProperty(ee, 'domain', {
                value: undefined,
                configurable: true,
                enumerable: false,
                writable: true
            });
        } catch (_e) {
            ee.domain = undefined;
        }
    }
    return this;
};

Domain.prototype.bind = function (fn) {
    var self = this;
    return function bound() {
        var args = [];
        for (var i = 0; i < arguments.length; i++) args.push(arguments[i]);
        self.enter();
        try {
            return fn.apply(this, args);
        } catch (err) {
            self.emit('error', err);
        } finally {
            self.exit();
        }
    };
};

Domain.prototype.intercept = function (fn) {
    var self = this;
    return function intercepted(err) {
        if (err) {
            self.emit('error', err);
            return;
        }
        var args = [];
        for (var i = 1; i < arguments.length; i++) args.push(arguments[i]);
        self.enter();
        try {
            return fn.apply(this, args);
        } catch (e) {
            self.emit('error', e);
        } finally {
            self.exit();
        }
    };
};

function create() {
    return new Domain();
}

function createDomain() {
    return new Domain();
}

var domainExports = {
    Domain: Domain,
    create: create,
    createDomain: createDomain
};

Object.defineProperty(domainExports, '_stack', {
    get: function () { return _stack; },
    enumerable: true,
    configurable: true
});

Object.defineProperty(domainExports, 'active', {
    get: function () { return _active; },
    set: function (v) { _active = v; },
    enumerable: true,
    configurable: true
});

module.exports = domainExports;
