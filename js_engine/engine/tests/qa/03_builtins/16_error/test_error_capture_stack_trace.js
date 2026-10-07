// ECS-001 through ECS-005: Error.captureStackTrace (V8/Node API, stubbed in
// builtins_stubs.js). Bundled Node libraries call it unconditionally in custom
// error constructors — `Error.captureStackTrace(this, this.constructor)`.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/16_error/test_error_capture_stack_trace.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ECS-001: present and callable
assertEq(typeof Error.captureStackTrace, "function", "ECS-001: Error.captureStackTrace is a function");

// ECS-002: installs a writable own string `stack` on an arbitrary target
var target = {};
Error.captureStackTrace(target);
assert(Object.prototype.hasOwnProperty.call(target, "stack"), "ECS-002: own stack property installed");
assertEq(typeof target.stack, "string", "ECS-002: stack is a string");
target.stack = "overwritten";
assertEq(target.stack, "overwritten", "ECS-002: stack is writable");

// ECS-003: the createErrorType pattern (readable-stream / Vite vendored deps)
function CustomError(message) {
    Error.captureStackTrace(this, this.constructor);
    this.message = message;
    this.code = "E_CUSTOM";
}
CustomError.prototype = Object.create(Error.prototype);
var e = new CustomError("boom");
assertEq(e.message, "boom", "ECS-003: message survives");
assertEq(e.code, "E_CUSTOM", "ECS-003: own props survive");
assertEq(typeof e.stack, "string", "ECS-003: instance has a string stack");

// ECS-004: second arg (constructorOpt) is accepted without throwing
var t2 = {};
Error.captureStackTrace(t2, CustomError);
assertEq(typeof t2.stack, "string", "ECS-004: constructorOpt accepted");

// ECS-005: installed non-enumerably on Error, with function metadata
var d = Object.getOwnPropertyDescriptor(Error, "captureStackTrace");
assert(d && d.enumerable === false, "ECS-005: non-enumerable on Error");
assertEq(Error.captureStackTrace.name, "captureStackTrace", "ECS-005: function name");

__jacDone();
