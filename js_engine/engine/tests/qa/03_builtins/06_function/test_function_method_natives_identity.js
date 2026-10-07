// FN-NATIVE-001..006: built-in methods the engine materialises on demand
// (fn.call/apply/bind/toString, gen.next, (1).toFixed, str[Symbol.iterator])
// are ONE object per kind, as in the spec. Regression: a fresh native was
// created on every property read and natives are never swept — every
// `exec.call(rx, s)` in the regexp shims leaked 96 bytes for the life of the
// process (4.2M live natives after 2M calls).
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/06_function/test_function_method_natives_identity.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assert(cond, msg) { __reg.assert(cond, msg); }

function f() {} class C {} function* g() { yield 1; }
assert(f.call === f.call && f.call === C.call && f.call === Function.prototype.call, "FN-NATIVE-001: fn.call identity (closure and class)");
assert(f.apply === C.apply && f.bind === C.bind, "FN-NATIVE-002: apply/bind identity");
assert(RegExp.prototype.exec.call === Math.max.call, "FN-NATIVE-003: .call on native functions is the same object");
var it = g(); assert(it.next === it.next && it.return === it.return, "FN-NATIVE-004: generator next/return identity");
assert((1).toFixed === (2.5).toFixed && (1).toString === (2).toString, "FN-NATIVE-005: Number method identity across receivers");
assert("a"[Symbol.iterator] === "b"[Symbol.iterator] && true.toString === false.toString, "FN-NATIVE-006: string iterator / bool toString identity");
var r = /x/y, seg = "abc".repeat(50), k = 0;
for (var i = 0; i < 200000; i++) { r.lastIndex = 5; if (RegExp.prototype.exec.call(r, seg) === null) k++; }
assert(k === 200000, "FN-NATIVE-006: 200k exec.call round trips behave");
__jacDone();
