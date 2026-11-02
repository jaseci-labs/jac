// node:console — Console class + re-export of the global console (Wave 19)

var util = require("util");

function _isWritableStream(s) {
    return s != null && typeof s === "object" && typeof s.write === "function";
}

function Console(stdout, stderr, ignoreErrors) {
    if (!(this instanceof Console)) {
        return new Console(stdout, stderr, ignoreErrors);
    }
    var options = stdout;
    if (options && typeof options === "object" && !options.write &&
        (options.stdout !== undefined || options.stderr !== undefined)) {
        stdout = options.stdout;
        stderr = options.stderr;
        ignoreErrors = options.ignoreErrors;
    }
    if (!_isWritableStream(stdout)) {
        var e1 = new TypeError(
            'The "stdout" argument must be an instance of a Writable stream'
        );
        e1.code = "ERR_CONSOLE_WRITABLE_STREAM";
        throw e1;
    }
    if (stderr === undefined) {
        stderr = stdout;
    } else if (!_isWritableStream(stderr)) {
        var e2 = new TypeError(
            'The "stderr" argument must be an instance of a Writable stream'
        );
        e2.code = "ERR_CONSOLE_WRITABLE_STREAM";
        throw e2;
    }
    this._stdout = stdout;
    this._stderr = stderr;
    this._ignoreErrors = ignoreErrors !== false;
    this._times = Object.create(null);
    this._counts = Object.create(null);
}

function _format(args) {
    if (args.length === 0) return "";
    if (typeof util.format === "function") {
        return util.format.apply(util, args);
    }
    var out = [];
    for (var i = 0; i < args.length; i++) {
        out.push(String(args[i]));
    }
    return out.join(" ");
}

function _write(stream, ignoreErrors, text) {
    try {
        stream.write(text);
    } catch (e) {
        if (!ignoreErrors) throw e;
    }
}

Console.prototype.log = function () {
    _write(this._stdout, this._ignoreErrors, _format(arguments) + "\n");
};
Console.prototype.info = Console.prototype.log;
Console.prototype.debug = Console.prototype.log;
Console.prototype.dirxml = Console.prototype.log;

Console.prototype.error = function () {
    _write(this._stderr, this._ignoreErrors, _format(arguments) + "\n");
};
Console.prototype.warn = Console.prototype.error;

Console.prototype.dir = function (obj, options) {
    var str = (util && util.inspect) ? util.inspect(obj, options) : String(obj);
    _write(this._stdout, this._ignoreErrors, str + "\n");
};

Console.prototype.time = function (label) {
    label = label === undefined ? "default" : String(label);
    this._times[label] = Date.now();
};

Console.prototype.timeEnd = function (label) {
    label = label === undefined ? "default" : String(label);
    var start = this._times[label];
    if (start === undefined) {
        _write(this._stderr, this._ignoreErrors, "No such label '" + label + "' for console.timeEnd\n");
        return;
    }
    delete this._times[label];
    _write(this._stdout, this._ignoreErrors, label + ": " + (Date.now() - start) + "ms\n");
};

Console.prototype.timeLog = function (label) {
    label = label === undefined ? "default" : String(label);
    var start = this._times[label];
    if (start === undefined) return;
    var args = Array.prototype.slice.call(arguments, 1);
    var msg = label + ": " + (Date.now() - start) + "ms";
    if (args.length) msg += " " + _format(args);
    _write(this._stdout, this._ignoreErrors, msg + "\n");
};

Console.prototype.count = function (label) {
    label = label === undefined ? "default" : String(label);
    this._counts[label] = (this._counts[label] || 0) + 1;
    _write(this._stdout, this._ignoreErrors, label + ": " + this._counts[label] + "\n");
};

Console.prototype.countReset = function (label) {
    label = label === undefined ? "default" : String(label);
    this._counts[label] = 0;
};

Console.prototype.assert = function (value) {
    if (value) return;
    var args = Array.prototype.slice.call(arguments, 1);
    var msg = args.length ? _format(args) : "Assertion failed";
    _write(this._stderr, this._ignoreErrors, "Assertion failed: " + msg + "\n");
};

Console.prototype.clear = function () {};
Console.prototype.group = function () {};
Console.prototype.groupCollapsed = function () {};
Console.prototype.groupEnd = function () {};
Console.prototype.table = function (data) {
    this.log(data);
};

Console.prototype.trace = function () {
    var err = new Error();
    err.name = "Trace";
    err.message = _format(arguments);
    Error.captureStackTrace && Error.captureStackTrace(err, Console.prototype.trace);
    _write(this._stderr, this._ignoreErrors, (err.stack || String(err)) + "\n");
};

// Make `globalThis.console instanceof Console` true (Node does this).
Object.defineProperty(Console, Symbol.hasInstance, {
    value: function (instance) {
        return instance === globalThis.console ||
            (instance != null && instance._stdout != null && instance._stderr != null &&
             typeof instance.log === "function");
    },
    configurable: true
});

var g = globalThis.console || {};
g.Console = Console;
globalThis.console = g;

module.exports = g;
