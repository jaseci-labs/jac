// FUNCTION_COMPREHENSIVE_TEST_PLAN §9–10 — call, apply
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/06_function/test_function_call_apply.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

function greet(greeting, punct) {
    return greeting + ", " + this.name + punct;
}

// FN-CALL-001
var person = { name: "Alice" };
assertEq(greet.call(person, "Hello", "!"), "Hello, Alice!", "FN-CALL-001: call with this and args");
assertEq(greet.call({ name: "Bob" }, "Hi", "."), "Hi, Bob.", "FN-CALL-001: different this");

// FN-CALL-004
function retArg(x) {
    return x;
}
assertEq(retArg.call(null, 42), 42, "FN-CALL-004: return value forwarded");

// FN-CALL-003 non-strict — null/undefined → globalThis
function returnThisSloppy() {
    return this;
}
var tNull = returnThisSloppy.call(null);
assert(tNull !== null && tNull !== undefined, "FN-CALL-003: call(null) this is global object in sloppy");

// FN-CALL-002 strict — omitted thisArg stays undefined; property access throws
var callStrictThrew = false;
try {
    Function('"use strict"; function display() { return this.globProp; } display.call();')();
} catch (e) {
    callStrictThrew = e instanceof TypeError;
}
assert(callStrictThrew, "FN-CALL-002: strict call() without thisArg → TypeError on this access");

// FN-CALL-005 generic slice
var slice = Array.prototype.slice;
var like = { 0: "a", 1: "b", length: 2 };
assertEq(Function.prototype.call.call(slice, like, 0).join("-"), "a-b", "FN-CALL-005: call.call slice on array-like");

// FN-APP-001
assertEq(Math.max.apply(null, [1, 2, 3]), 3, "FN-APP-001: Math.max.apply");
assertEq(Math.min.apply(null, [5, 6, 2]), 2, "FN-APP-001: Math.min.apply");

// FN-APP-002
function joinThis() {
    return this.sep + Array.prototype.join.call(arguments, this.sep);
}
var j = joinThis.apply({ sep: "|" }, { length: 2, 0: "eat", 1: "bananas" });
assertEq(j, "|eat|bananas", "FN-APP-002: array-like args");

// FN-APP-003
function sumArgs() {
    var s = 0;
    for (var i = 0; i < arguments.length; i++) s += arguments[i];
    return s;
}
assertEq(sumArgs.apply(null, null), 0, "FN-APP-003: null argsArray");
assertEq(sumArgs.apply(null, undefined), 0, "FN-APP-003: undefined argsArray");

// FN-APP-004
var tUndef = returnThisSloppy.apply(undefined);
assert(tUndef !== undefined, "FN-APP-004: sloppy apply(undefined) uses global");

// FN-APP-005
var arr = ["a", "b"];
var els = [0, 1, 2];
Array.prototype.push.apply(arr, els);
assertEq(arr.join(","), "a,b,0,1,2", "FN-APP-005: push.apply spread elements");

// FN-APP-006
var appBad = false;
try {
    Math.max.apply(null, 42);
} catch (e) {
    appBad = e instanceof TypeError;
}
assert(appBad, "FN-APP-006: non-array-like args throws TypeError");

__jacDone();
