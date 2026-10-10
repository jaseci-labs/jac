/**
 * repl.js — Node.js `repl` / `node:repl` (minimal MVP)
 */
'use strict';

var readline = require('readline');
var EventEmitter = require('events');
if (EventEmitter.EventEmitter) EventEmitter = EventEmitter.EventEmitter;

var REPL_MODE_SLOPPY = Symbol('repl-sloppy');
var REPL_MODE_STRICT = Symbol('repl-strict');

function _defaultEval(code, context, file, cb) {
    var err = null;
    var result;
    try {
        var vm;
        try { vm = require('vm'); } catch (_e) { vm = null; }
        if (vm && typeof vm.runInThisContext === 'function') {
            result = vm.runInThisContext(code, { filename: file });
        } else {
            // eslint-disable-next-line no-new-func
            result = Function('return (function(){ with(this){ return eval(' +
                JSON.stringify(code) + '); } })').call(context).call(context);
        }
    } catch (e) {
        err = e;
    }
    cb(err, result);
}

function _defaultWriter(output) {
    try {
        var util = require('util');
        if (util && typeof util.inspect === 'function') {
            return util.inspect(output);
        }
    } catch (_e) { /* ignore */ }
    return String(output);
}

function REPLServer(options) {
    EventEmitter.init.call(this);
    if (typeof options === 'string') {
        options = { prompt: options };
    }
    options = options || {};

    this.input = options.input || (typeof process !== 'undefined' ? process.stdin : null);
    this.output = options.output || (typeof process !== 'undefined' ? process.stdout : null);
    this.inputStream = this.input;
    this.outputStream = this.output;
    this.terminal = options.terminal !== undefined ? !!options.terminal : false;
    this.useGlobal = options.useGlobal === true;
    this.useColors = options.useColors === true;
    this.ignoreUndefined = options.ignoreUndefined === true;
    this.replMode = options.replMode || REPL_MODE_SLOPPY;
    this.historySize = options.historySize !== undefined ? options.historySize : 30;
    this.eval = typeof options.eval === 'function' ? options.eval : _defaultEval;
    this.writer = typeof options.writer === 'function' ? options.writer : _defaultWriter;
    this._prompt = options.prompt !== undefined ? String(options.prompt) : '> ';
    this.context = this.useGlobal && typeof globalThis !== 'undefined'
        ? globalThis
        : Object.create(null);
    this.context._ = undefined;
    this._closed = false;

    var self = this;
    this._interface = readline.createInterface({
        input: this.input,
        output: this.output,
        terminal: this.terminal,
        prompt: this._prompt
    });

    if (typeof this._interface.setPrompt === 'function') {
        this._interface.setPrompt(this._prompt);
    }
    if (typeof this._interface.prompt === 'function') {
        this._interface.prompt();
    }

    this._interface.on('line', function (line) {
        if (self._closed) return;
        self.eval(line, self.context, 'repl', function (err, result) {
            if (err) {
                if (self.output && typeof self.output.write === 'function') {
                    self.output.write(String(err) + '\n');
                }
            } else if (!(self.ignoreUndefined && result === undefined)) {
                self.context._ = result;
                if (self.output && typeof self.output.write === 'function') {
                    self.output.write(self.writer(result) + '\n');
                }
            }
            if (!self._closed && typeof self._interface.prompt === 'function') {
                self._interface.prompt();
            }
        });
    });

    this._interface.on('close', function () {
        self._closed = true;
        self.emit('exit');
        self.emit('close');
    });
}

REPLServer.prototype = Object.create(EventEmitter.prototype);
REPLServer.prototype.constructor = REPLServer;

REPLServer.prototype.setPrompt = function (prompt) {
    this._prompt = String(prompt);
    if (this._interface && typeof this._interface.setPrompt === 'function') {
        this._interface.setPrompt(this._prompt);
    }
};

REPLServer.prototype.displayPrompt = function () {
    if (this._interface && typeof this._interface.prompt === 'function') {
        this._interface.prompt();
    }
};

REPLServer.prototype.close = function () {
    if (this._closed) return;
    this._closed = true;
    if (this._interface && typeof this._interface.close === 'function') {
        this._interface.close();
    }
};

function start(options) {
    return new REPLServer(options);
}

module.exports = {
    REPLServer: REPLServer,
    start: start,
    REPL_MODE_SLOPPY: REPL_MODE_SLOPPY,
    REPL_MODE_STRICT: REPL_MODE_STRICT,
    writer: _defaultWriter
};

Object.defineProperty(module.exports, '_builtinLibs', {
    get: function () {
        try {
            var mod = require('module');
            return mod.builtinModules || [];
        } catch (_e) {
            return [];
        }
    },
    enumerable: false,
    configurable: true
});

Object.defineProperty(module.exports, 'builtinModules', {
    get: function () {
        try {
            var mod = require('module');
            return mod.builtinModules || [];
        } catch (_e) {
            return [];
        }
    },
    enumerable: false,
    configurable: true
});
