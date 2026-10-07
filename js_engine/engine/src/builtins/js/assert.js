// ────────────────────────────────────────────────────────────────────────────
// builtins/js/assert.js — Node.js `assert` module
//
// Pure JavaScript implementation of the assert API.
// Loaded by `require("assert")` / `require("node:assert")`.
//
// Node.js reference: https://nodejs.org/api/assert.html
// Bun reference:     bun/src/js/node/assert.ts
// ────────────────────────────────────────────────────────────────────────────

var util = require("util");

// ── AssertionError ──────────────────────────────────────────────────────────

class AssertionError extends Error {
    constructor(opts) {
        var options = opts || {};
        var msg;
        if (options.message !== undefined && options.message !== null) {
            msg = String(options.message);
        } else {
            msg = String(options.actual) + " " + (options.operator || "") + " " + String(options.expected);
        }
        super(msg);
        this.name = "AssertionError";
        this.actual = options.actual;
        this.expected = options.expected;
        this.operator = options.operator || "";
        this.code = "ERR_ASSERTION";
        this.generatedMessage = options.message === undefined || options.message === null;
    }
}

// ── Core assert function ────────────────────────────────────────────────────

function assert(value, message) {
    if (!value) {
        throw new AssertionError({
            message: message,
            actual: value,
            expected: true,
            operator: "=="
        });
    }
}

// ── assert.ok — alias for assert() ─────────────────────────────────────────

function ok(value, message) {
    if (!value) {
        throw new AssertionError({
            message: message,
            actual: value,
            expected: true,
            operator: "=="
        });
    }
}

// ── assert.equal (loose ==) ─────────────────────────────────────────────────

function equal(actual, expected, message) {
    if (actual != expected) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "=="
        });
    }
}

// ── assert.notEqual ─────────────────────────────────────────────────────────

function notEqual(actual, expected, message) {
    if (actual == expected) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "!="
        });
    }
}

// ── assert.strictEqual (===) ────────────────────────────────────────────────

function strictEqual(actual, expected, message) {
    if (actual !== expected) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "==="
        });
    }
}

// ── assert.notStrictEqual (!==) ─────────────────────────────────────────────

function notStrictEqual(actual, expected, message) {
    if (actual === expected) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "!=="
        });
    }
}

// ── Deep equality helpers ───────────────────────────────────────────────────

function _deepEqual(actual, expected, strict) {
    if (strict) {
        return util.isDeepStrictEqual(actual, expected);
    }
    // Loose deep equal: use isDeepStrictEqual as base but with == for primitives
    // For simplicity, we use the strict version (Node.js recommends strict anyway)
    return util.isDeepStrictEqual(actual, expected);
}

// ── assert.deepEqual ────────────────────────────────────────────────────────

function deepEqual(actual, expected, message) {
    if (!_deepEqual(actual, expected, false)) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "deepEqual"
        });
    }
}

// ── assert.deepStrictEqual ──────────────────────────────────────────────────

function deepStrictEqual(actual, expected, message) {
    if (!_deepEqual(actual, expected, true)) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "deepStrictEqual"
        });
    }
}

// ── assert.notDeepEqual ─────────────────────────────────────────────────────

function notDeepEqual(actual, expected, message) {
    if (_deepEqual(actual, expected, false)) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "notDeepEqual"
        });
    }
}

// ── assert.notDeepStrictEqual ───────────────────────────────────────────────

function notDeepStrictEqual(actual, expected, message) {
    if (_deepEqual(actual, expected, true)) {
        throw new AssertionError({
            message: message,
            actual: actual,
            expected: expected,
            operator: "notDeepStrictEqual"
        });
    }
}

// ── assert.throws ───────────────────────────────────────────────────────────

function throws(fn, errorOrMessage, message) {
    if (typeof fn !== "function") {
        throw new AssertionError({
            message: "assert.throws: first argument must be a function",
            actual: typeof fn,
            expected: "function",
            operator: "throws"
        });
    }

    var thrown = false;
    var caught = undefined;
    try {
        fn();
    } catch (e) {
        thrown = true;
        caught = e;
    }

    if (!thrown) {
        var msg = message || errorOrMessage;
        if (typeof errorOrMessage !== "string") { msg = message; }
        throw new AssertionError({
            message: msg || "Missing expected exception",
            actual: undefined,
            expected: errorOrMessage,
            operator: "throws"
        });
    }

    // Validate the thrown error if a validator is provided
    if (errorOrMessage !== undefined && errorOrMessage !== null) {
        if (typeof errorOrMessage === "function") {
            // errorOrMessage is a constructor or validator function
            if (errorOrMessage.prototype !== undefined && caught instanceof errorOrMessage) {
                return;
            }
            // Try as validator function
            if (errorOrMessage(caught) === true) {
                return;
            }
            throw new AssertionError({
                message: message || "Thrown error did not match validator",
                actual: caught,
                expected: errorOrMessage,
                operator: "throws"
            });
        } else if (typeof errorOrMessage === "object") {
            // Match properties (Node: RegExp values test against the actual string)
            var keys = Object.keys(errorOrMessage);
            var i = 0;
            while (i < keys.length) {
                var key = keys[i];
                var expectedVal = errorOrMessage[key];
                var actualVal = caught[key];
                var ok = false;
                if (expectedVal instanceof RegExp) {
                    ok = expectedVal.test(actualVal === undefined || actualVal === null ? "" : String(actualVal));
                } else if (typeof expectedVal === "function") {
                    ok = actualVal instanceof expectedVal;
                } else {
                    ok = actualVal === expectedVal;
                }
                if (!ok) {
                    throw new AssertionError({
                        message: message || "Thrown error property mismatch: " + key,
                        actual: actualVal,
                        expected: expectedVal,
                        operator: "throws"
                    });
                }
                i = i + 1;
            }
        }
        // string errorOrMessage is used as message (already handled above)
    }
}

// ── assert.doesNotThrow ─────────────────────────────────────────────────────

function doesNotThrow(fn, errorOrMessage, message) {
    if (typeof fn !== "function") {
        throw new AssertionError({
            message: "assert.doesNotThrow: first argument must be a function",
            actual: typeof fn,
            expected: "function",
            operator: "doesNotThrow"
        });
    }

    try {
        fn();
    } catch (e) {
        var msg = message;
        if (typeof errorOrMessage === "string") { msg = errorOrMessage; }
        throw new AssertionError({
            message: msg || "Got unwanted exception: " + (e && e.message ? e.message : String(e)),
            actual: e,
            expected: undefined,
            operator: "doesNotThrow"
        });
    }
}

// ── assert.rejects / assert.doesNotReject ───────────────────────────────────
// Port of Node's lib/assert.js waitForActual/expectsError/expectsNoError.

var _NO_EXCEPTION = {};

// Node internal/errors.js determineSpecificType — used verbatim in the
// ERR_INVALID_* message formats that test-assert-async asserts on.
function _determineSpecificType(value) {
    if (value === null) { return "null"; }
    if (value === undefined) { return "undefined"; }
    var type = typeof value;
    if (type === "function") { return "function " + value.name; }
    if (type === "object") {
        if (value.constructor && "name" in value.constructor) {
            return "an instance of " + value.constructor.name;
        }
        return util.inspect(value, { depth: -1 });
    }
    if (type === "string") {
        if (value.length > 28) { value = value.slice(0, 25) + "..."; }
        if (value.indexOf("'") === -1) { return "type string ('" + value + "')"; }
        return "type string (" + JSON.stringify(value) + ")";
    }
    if (type === "bigint") { return "type bigint (" + String(value) + "n)"; }
    var text = util.inspect(value, { colors: false });
    if (text.length > 28) { text = text.slice(0, 25) + "..."; }
    return "type " + type + " (" + text + ")";
}

function _errWithCode(err, code) {
    err.code = code;
    return err;
}

function _errInvalidPromiseFnArg(value) {
    return _errWithCode(new TypeError(
        'The "promiseFn" argument must be of type function or an instance of ' +
        "Promise. Received " + _determineSpecificType(value)), "ERR_INVALID_ARG_TYPE");
}

function _errInvalidErrorArg(value) {
    return _errWithCode(new TypeError(
        'The "error" argument must be of type function or an instance of Error, ' +
        "RegExp, or Object. Received " + _determineSpecificType(value)), "ERR_INVALID_ARG_TYPE");
}

function _checkIsPromise(obj) {
    // Accept native promises and promise look-alikes; reject thenables that use
    // a function as `obj` or that have no `catch` handler.
    return obj instanceof Promise ||
        (obj !== null && typeof obj === "object" &&
         typeof obj.then === "function" &&
         typeof obj.catch === "function");
}

async function _waitForActual(promiseFn) {
    var resultPromise;
    if (typeof promiseFn === "function") {
        // A synchronous throw from promiseFn propagates as this fn's rejection.
        resultPromise = promiseFn();
        if (!_checkIsPromise(resultPromise)) {
            throw _errWithCode(new TypeError(
                'Expected instance of Promise to be returned from the "promiseFn" ' +
                "function but got " + _determineSpecificType(resultPromise) + "."),
                "ERR_INVALID_RETURN_VALUE");
        }
    } else if (_checkIsPromise(promiseFn)) {
        resultPromise = promiseFn;
    } else {
        throw _errInvalidPromiseFnArg(promiseFn);
    }
    try {
        await resultPromise;
    } catch (e) {
        return e;
    }
    return _NO_EXCEPTION;
}

// Placeholder objects mirroring Node's Comparison class: only the compared
// keys appear in the AssertionError diff output.
function _comparisonSlice(obj, keys, actual) {
    var out = {};
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (key in obj) {
            if (actual !== undefined && typeof actual[key] === "string" &&
                obj[key] instanceof RegExp && obj[key].test(actual[key])) {
                out[key] = actual[key];
            } else {
                out[key] = obj[key];
            }
        }
    }
    return out;
}

function _compareExceptionKey(actual, expected, key, message, keys, fnName) {
    if (!(key in actual) || !util.isDeepStrictEqual(actual[key], expected[key])) {
        if (!message) {
            var err = new AssertionError({
                actual: _comparisonSlice(actual, keys),
                expected: _comparisonSlice(expected, keys, actual),
                operator: "deepStrictEqual"
            });
            err.actual = actual;
            err.expected = expected;
            err.operator = fnName;
            throw err;
        }
        throw new AssertionError({
            actual: actual,
            expected: expected,
            message: message,
            operator: fnName
        });
    }
}

function _expectedException(actual, expected, message, fnName) {
    var generatedMessage = false;
    var throwError = false;

    if (typeof expected !== "function") {
        if (expected instanceof RegExp) {
            var str = String(actual);
            if (expected.test(str)) { return; }
            if (!message) {
                generatedMessage = true;
                message = "The input did not match the regular expression " +
                    util.inspect(expected) + ". Input:\n\n" + util.inspect(str) + "\n";
            }
            throwError = true;
        } else if (typeof actual !== "object" || actual === null) {
            // Primitive actual vs object expected → plain deep-strict failure.
            var perr = new AssertionError({
                actual: actual,
                expected: expected,
                message: message,
                operator: "deepStrictEqual"
            });
            perr.operator = fnName;
            throw perr;
        } else {
            var keys = Object.keys(expected);
            // Errors compare name and message even though they're non-enumerable.
            if (expected instanceof Error) {
                keys.push("name", "message");
            } else if (keys.length === 0) {
                throw _errWithCode(new TypeError(
                    "The argument 'error' may not be an empty object. Received {}"),
                    "ERR_INVALID_ARG_VALUE");
            }
            for (var ki = 0; ki < keys.length; ki++) {
                var key = keys[ki];
                if (typeof actual[key] === "string" &&
                    expected[key] instanceof RegExp &&
                    expected[key].test(actual[key])) {
                    continue;
                }
                _compareExceptionKey(actual, expected, key, message, keys, fnName);
            }
            return;
        }
    } else if (expected.prototype !== undefined && actual instanceof expected) {
        return;
    } else if (Object.prototype.isPrototypeOf.call(Error, expected)) {
        if (!message) {
            generatedMessage = true;
            message = 'The error is expected to be an instance of "' +
                expected.name + '". Received ';
            if (actual instanceof Error) {
                var aname = (actual.constructor && actual.constructor.name) || actual.name;
                if (expected.name === aname) {
                    message += "an error with identical name but a different prototype.";
                } else {
                    message += '"' + aname + '"';
                }
                if (actual.message) {
                    message += "\n\nError message:\n\n" + actual.message;
                }
            } else {
                message += '"' + util.inspect(actual, { depth: -1 }) + '"';
            }
        }
        throwError = true;
    } else {
        // Validation function: anything but a strict `true` return is a failure.
        var res = expected.call({}, actual);
        if (res !== true) {
            if (!message) {
                generatedMessage = true;
                var vname = expected.name ? '"' + expected.name + '" ' : "";
                message = "The " + vname + "validation function is expected to return" +
                    ' "true". Received ' + util.inspect(res);
                if (actual instanceof Error) {
                    message += "\n\nCaught error:\n\n" + actual;
                }
            }
            throwError = true;
        }
    }

    if (throwError) {
        var terr = new AssertionError({
            actual: actual,
            expected: expected,
            message: message,
            operator: fnName
        });
        terr.generatedMessage = generatedMessage;
        throw terr;
    }
}

function _expectsError(fnName, actual, error, message, hasMessageArg) {
    if (typeof error === "string") {
        if (hasMessageArg) { throw _errInvalidErrorArg(error); }
        if (typeof actual === "object" && actual !== null) {
            if (actual.message === error) {
                throw _errWithCode(new TypeError(
                    'The "error/message" argument is ambiguous. ' +
                    'The error message "' + actual.message + '" is identical to the message.'),
                    "ERR_AMBIGUOUS_ARGUMENT");
            }
        } else if (actual === error) {
            throw _errWithCode(new TypeError(
                'The "error/message" argument is ambiguous. ' +
                'The error "' + actual + '" is identical to the message.'),
                "ERR_AMBIGUOUS_ARGUMENT");
        }
        message = error;
        error = undefined;
    } else if (error != null && typeof error !== "object" && typeof error !== "function") {
        throw _errInvalidErrorArg(error);
    }

    if (actual === _NO_EXCEPTION) {
        var details = "";
        if (error && error.name) { details += " (" + error.name + ")"; }
        details += message ? ": " + message : ".";
        var fnType = fnName === "rejects" ? "rejection" : "exception";
        throw new AssertionError({
            actual: undefined,
            expected: error,
            operator: fnName,
            message: "Missing expected " + fnType + details
        });
    }

    if (!error) { return; }
    _expectedException(actual, error, message, fnName);
}

function _hasMatchingError(actual, expected) {
    if (typeof expected !== "function") {
        if (expected instanceof RegExp) {
            return expected.test(String(actual));
        }
        throw _errWithCode(new TypeError(
            'The "expected" argument must be of type function or an instance of ' +
            "RegExp. Received " + _determineSpecificType(expected)), "ERR_INVALID_ARG_TYPE");
    }
    if (expected.prototype !== undefined && actual instanceof expected) {
        return true;
    }
    if (Object.prototype.isPrototypeOf.call(Error, expected)) {
        return false;
    }
    return expected.call({}, actual) === true;
}

function _expectsNoError(fnName, actual, error, message) {
    if (actual === _NO_EXCEPTION) { return; }

    if (typeof error === "string") {
        message = error;
        error = undefined;
    }

    if (!error || _hasMatchingError(actual, error)) {
        var details = message ? ": " + message : ".";
        var fnType = fnName === "doesNotReject" ? "rejection" : "exception";
        throw new AssertionError({
            actual: actual,
            expected: error,
            operator: fnName,
            message: "Got unwanted " + fnType + details + "\n" +
                'Actual message: "' + (actual && actual.message) + '"'
        });
    }
    throw actual;
}

async function rejects(promiseFn, error, message) {
    _expectsError("rejects", await _waitForActual(promiseFn), error, message,
                  arguments.length >= 3);
}

async function doesNotReject(promiseFn, error, message) {
    _expectsNoError("doesNotReject", await _waitForActual(promiseFn), error, message);
}

// ── assert.ifError ──────────────────────────────────────────────────────────

function ifError(value) {
    if (value !== null && value !== undefined) {
        throw new AssertionError({
            message: "ifError got unwanted exception: " + (value && value.message ? value.message : String(value)),
            actual: value,
            expected: null,
            operator: "ifError"
        });
    }
}

// ── assert.match ────────────────────────────────────────────────────────────

function match(string, regexp, message) {
    if (typeof regexp === "object" && typeof regexp.test === "function") {
        if (!regexp.test(string)) {
            throw new AssertionError({
                message: message || "String does not match pattern",
                actual: string,
                expected: regexp,
                operator: "match"
            });
        }
    } else {
        throw new AssertionError({
            message: "The 'regexp' argument must be a RegExp",
            actual: typeof regexp,
            expected: "RegExp",
            operator: "match"
        });
    }
}

// ── assert.fail ─────────────────────────────────────────────────────────────

function fail(message) {
    throw new AssertionError({
        message: message || "Failed",
        actual: undefined,
        expected: undefined,
        operator: "fail"
    });
}

// ── assert.CallTracker ──────────────────────────────────────────────────────

function _noop() {}

function CallTrackerContext(opts) {
    this._expected = opts.expected;
    this._name = opts.name;
    this._stackTrace = opts.stackTrace;
    this._calls = [];
}

CallTrackerContext.prototype.track = function (thisArg, args) {
    var argsClone = [];
    for (var i = 0; i < args.length; i++) argsClone.push(args[i]);
    if (typeof Object.freeze === "function") {
        try { Object.freeze(argsClone); } catch (_e) { /* ignore */ }
    }
    var entry = { thisArg: thisArg, arguments: argsClone };
    if (typeof Object.freeze === "function") {
        try { Object.freeze(entry); } catch (_e2) { /* ignore */ }
    }
    this._calls.push(entry);
};

CallTrackerContext.prototype.reset = function () {
    this._calls = [];
};

CallTrackerContext.prototype.getCalls = function () {
    var copy = this._calls.slice();
    if (typeof Object.freeze === "function") {
        try { Object.freeze(copy); } catch (_e) { /* ignore */ }
    }
    return copy;
};

Object.defineProperty(CallTrackerContext.prototype, "delta", {
    get: function () {
        return this._calls.length - this._expected;
    }
});

CallTrackerContext.prototype.report = function () {
    if (this.delta !== 0) {
        var message = "Expected the " + this._name + " function to be " +
            "executed " + this._expected + " time(s) but was " +
            "executed " + this._calls.length + " time(s).";
        return {
            message: message,
            actual: this._calls.length,
            expected: this._expected,
            exact: this._expected,
            operator: this._name,
            stack: this._stackTrace
        };
    }
};

function CallTracker() {
    this._callChecks = [];
    this._trackedFunctions = [];
}

CallTracker.prototype._getTracked = function (tracked) {
    for (var i = 0; i < this._trackedFunctions.length; i++) {
        if (this._trackedFunctions[i].fn === tracked) {
            return this._trackedFunctions[i].ctx;
        }
    }
    var err = new TypeError("The argument 'tracked' is not a tracked function. Received " + tracked);
    err.code = "ERR_INVALID_ARG_VALUE";
    throw err;
};

CallTracker.prototype.reset = function (tracked) {
    if (tracked === undefined) {
        for (var i = 0; i < this._callChecks.length; i++) {
            this._callChecks[i].reset();
        }
        return;
    }
    this._getTracked(tracked).reset();
};

CallTracker.prototype.getCalls = function (tracked) {
    return this._getTracked(tracked).getCalls();
};

CallTracker.prototype.calls = function (fn, expected) {
    if (typeof process !== "undefined" && process._exiting) {
        var exitErr = new Error("Cannot call this API during process exit");
        exitErr.code = "ERR_UNAVAILABLE_DURING_EXIT";
        throw exitErr;
    }
    if (typeof fn === "number") {
        expected = fn;
        fn = _noop;
    } else if (fn === undefined) {
        fn = _noop;
    }
    if (expected === undefined) expected = 1;
    if (typeof expected !== "number") {
        var tErr = new TypeError('The "expected" argument must be of type number.' +
            " Received type " + typeof expected);
        tErr.code = "ERR_INVALID_ARG_TYPE";
        throw tErr;
    }
    if (!Number.isInteger(expected) || expected < 1) {
        var rErr = new RangeError('The value of "expected" is out of range. It must be >= 1.' +
            " Received " + expected);
        rErr.code = "ERR_OUT_OF_RANGE";
        throw rErr;
    }

    var context = new CallTrackerContext({
        expected: expected,
        stackTrace: new Error(),
        name: fn.name || "calls"
    });

    // Node wraps the target in a Proxy (lib/internal/assert/calltracker.js) so
    // every own property — length/name/custom, including accessor-backed ones —
    // is served from the target without copying or invoking getters.  The
    // handler MUST be prototype-less: GetMethod on a handler walks its proto
    // chain, so a plain-object handler would pick up e.g. a user-installed
    // Object.prototype.get as its get trap.
    var handler = Object.create(null);
    handler.apply = function (target, thisArg, argList) {
        context.track(thisArg, argList);
        return Reflect.apply(target, thisArg, argList);
    };
    var tracked = new Proxy(fn, handler);

    this._callChecks.push(context);
    this._trackedFunctions.push({ fn: tracked, ctx: context });
    return tracked;
};

CallTracker.prototype.report = function () {
    var errors = [];
    for (var i = 0; i < this._callChecks.length; i++) {
        var message = this._callChecks[i].report();
        if (message !== undefined) errors.push(message);
    }
    return errors;
};

CallTracker.prototype.verify = function () {
    var errors = this.report();
    if (errors.length === 0) return;
    var message = errors.length === 1
        ? errors[0].message
        : "Functions were not called the expected number of times";
    throw new AssertionError({
        message: message,
        details: errors
    });
};

// ── Module exports ──────────────────────────────────────────────────────────

// The main export is the assert function itself (callable)
// with methods attached as properties.
assert.ok = ok;
assert.equal = equal;
assert.notEqual = notEqual;
assert.strictEqual = strictEqual;
assert.notStrictEqual = notStrictEqual;
assert.deepEqual = deepEqual;
assert.deepStrictEqual = deepStrictEqual;
assert.notDeepEqual = notDeepEqual;
assert.notDeepStrictEqual = notDeepStrictEqual;
assert.throws = throws;
assert.doesNotThrow = doesNotThrow;
assert.rejects = rejects;
assert.doesNotReject = doesNotReject;
assert.ifError = ifError;
assert.match = match;
assert.fail = fail;
assert.AssertionError = AssertionError;
assert.CallTracker = CallTracker;

// assert.strict is a callable wrapper where equal → strictEqual, deepEqual → deepStrictEqual
function strictAssert(value, message) {
    assert(value, message);
}
strictAssert.ok = ok;
strictAssert.equal = strictEqual;
strictAssert.notEqual = notStrictEqual;
strictAssert.strictEqual = strictEqual;
strictAssert.notStrictEqual = notStrictEqual;
strictAssert.deepEqual = deepStrictEqual;
strictAssert.deepStrictEqual = deepStrictEqual;
strictAssert.notDeepEqual = notDeepStrictEqual;
strictAssert.notDeepStrictEqual = notDeepStrictEqual;
strictAssert.throws = throws;
strictAssert.doesNotThrow = doesNotThrow;
strictAssert.rejects = rejects;
strictAssert.doesNotReject = doesNotReject;
strictAssert.ifError = ifError;
strictAssert.match = match;
strictAssert.fail = fail;
strictAssert.AssertionError = AssertionError;
strictAssert.CallTracker = CallTracker;
strictAssert.strict = strictAssert;

assert.strict = strictAssert;

module.exports = assert;
module.exports.CallTracker = CallTracker;
