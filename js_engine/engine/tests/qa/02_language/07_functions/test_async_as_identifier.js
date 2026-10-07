// FN-ASYNC-ID-*: `async` is only a keyword in front of a function/arrow/method. As a
// property name or a binding it is an ordinary identifier. Regressions:
//  - `{ async(...args) {} }` (a shorthand method NAMED async) was a SyntaxError —
//    Babel's @babel/core/lib/gensync-utils/async.js failed to load, and every
//    `.jsx` in the Vite dev server (plugin-react) died with "makeError is not a
//    function";
//  - `async(x)` calling a binding named async was parsed as an async-arrow head and
//    the statement was dropped ("Expected token 43 but got 31").
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/07_functions/test_async_as_identifier.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

var o = { sync(...a) { return "s" + a.length; }, async(...a) { return "a" + a.length; } };
assertEq(o.sync(1) + o.async(1, 2), "s1a2", "FN-ASYNC-ID-001: shorthand method named async");
var o2 = { async() { return 7; } };
assertEq(o2.async(), 7, "FN-ASYNC-ID-001: zero-arg method named async");
var o3 = { async *gen() { yield 1; }, async m() { return 2; } };
assertEq(typeof o3.gen + "," + typeof o3.m, "function,function", "FN-ASYNC-ID-002: async modifier still works");
var { async = 4 } = {};
assertEq(async, 4, "FN-ASYNC-ID-003: shorthand destructuring default named async");

var async2 = null;
(function () {
    var async = function () { return Array.prototype.slice.call(arguments).join("+"); };
    async2 = async(1, 2) + "|" + async(...[3, 4]) + "|" + (true ? async(5) : 0);
})();
assertEq(async2, "1+2|3+4|5", "FN-ASYNC-ID-004: calling a binding named async");

var got = [];
var f1 = async (a, b) => a + b;
var f2 = async (...r) => r.length;
var f3 = async ([a], { b }) => a + b;
var f4 = async x => x * 2;
Promise.all([f1(1, 2), f2(1, 2, 3), f3([4], { b: 5 }), f4(6)]).then(function (v) {
    assertEq(v.join(), "3,3,9,12", "FN-ASYNC-ID-005: async arrows still parse (params, rest, patterns, bare)");
    __jacDone();
});
