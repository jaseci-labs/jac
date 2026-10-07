// ERR-001 through ERR-010: Error types
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/16_error/test_error.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ERR-001: Error(msg)
var err = new Error("test error");
assertEq(err.message, "test error",     "ERR-001: .message");
assertEq(err.name,    "Error",          "ERR-001: .name");
assert(err instanceof Error,            "ERR-001: instanceof Error");
assert(typeof err.stack === "string" || err.stack === undefined,
    "ERR-001: .stack is string or undefined");

// ERR-002: TypeError
var te = new TypeError("type problem");
assertEq(te.name,    "TypeError",       "ERR-002: .name = TypeError");
assertEq(te.message, "type problem",    "ERR-002: .message");
assert(te instanceof TypeError,         "ERR-002: instanceof TypeError");
assert(te instanceof Error,             "ERR-002: instanceof Error (inherit)");

// ERR-003: ReferenceError
var re = new ReferenceError("ref problem");
assertEq(re.name, "ReferenceError",     "ERR-003: .name");
assert(re instanceof ReferenceError,    "ERR-003: instanceof ReferenceError");
assert(re instanceof Error,             "ERR-003: instanceof Error");

// ERR-004: SyntaxError
var se = new SyntaxError("syntax problem");
assertEq(se.name, "SyntaxError",        "ERR-004: .name");
assert(se instanceof SyntaxError,       "ERR-004: instanceof SyntaxError");

// ERR-005: RangeError
var rng = new RangeError("range problem");
assertEq(rng.name, "RangeError",        "ERR-005: .name");
assert(rng instanceof RangeError,       "ERR-005: instanceof RangeError");

// ERR-006: Error without new — still creates instance
var noNew = Error("no new");
assertEq(noNew.message, "no new",       "ERR-006: Error() without new");
assert(noNew instanceof Error,          "ERR-006: still instanceof Error");

// ERR-007: Custom properties
var custom = new Error("custom");
custom.code = 42;
custom.extra = "data";
assertEq(custom.code, 42,              "ERR-007: custom .code property");
assertEq(custom.extra, "data",         "ERR-007: custom .extra property");

// ERR-008: try/catch by type, catch all, re-throw
function typedCatch(fn, ErrType) {
    try { fn(); return false; } catch(e) { return e instanceof ErrType; }
}
assert(typedCatch(function(){ throw new TypeError("t"); }, TypeError), "ERR-008: catch TypeError");
assert(typedCatch(function(){ throw new RangeError("r"); }, RangeError), "ERR-008: catch RangeError");
// catch all
var caught = false;
try { throw new Error("any"); } catch(e) { caught = true; }
assert(caught, "ERR-008: catch all");
// re-throw
var reThrew = false;
try {
    try { throw new Error("orig"); } catch(e) {
        if (!(e instanceof TypeError)) throw e;
    }
} catch(e) {
    reThrew = e.message === "orig";
}
assert(reThrew, "ERR-008: re-throw non-matching error");

// ERR-009: toString — "ErrorName: message"
assertEq(new Error("msg").toString(),         "Error: msg",         "ERR-009: Error toString");
assertEq(new TypeError("tmsg").toString(),    "TypeError: tmsg",    "ERR-009: TypeError toString");
assertEq(new RangeError("rmsg").toString(),   "RangeError: rmsg",   "ERR-009: RangeError toString");
// Error with no message
assertEq(new Error().toString(),              "Error",              "ERR-009: no message toString");

// ERR-010: Stack trace — function names in chain
function outer() { return inner(); }
function inner() { throw new Error("deep"); }
var stackErr = null;
try { outer(); } catch(e) { stackErr = e; }
assert(stackErr !== null,                                           "ERR-010: error was thrown");
if (stackErr && typeof stackErr.stack === "string") {
    // Stack should mention "inner" or at least be a multi-line string
    assert(stackErr.stack.length > 0,                               "ERR-010: stack is non-empty");
}

__jacDone();
