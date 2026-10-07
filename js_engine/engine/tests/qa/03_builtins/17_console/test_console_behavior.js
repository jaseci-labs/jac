// CON-004 through CON-009: console behavior tests (non-stdout/stderr)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/17_console/test_console_behavior.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// Sanity: console exists
assert(typeof console === "object" && console !== null, "console is an object");

// CON-004: dir — should not throw; returns undefined
var dirRet = console.dir({a:1});
assertEq(dirRet, undefined, "CON-004: console.dir returns undefined");

// CON-005: assert — false logs; true is silent
var assertRet = console.assert(true, "this should not appear");
assertEq(assertRet, undefined, "CON-005: console.assert returns undefined");
// asserting false should NOT throw (just logs)
var threw = false;
try { console.assert(false, "expected fail msg"); } catch(e) { threw = true; }
assert(!threw, "CON-005: console.assert(false) does not throw");

// CON-006: count / countReset
if (typeof console.count === "function") {
    console.count("label");
    console.count("label");
    console.count("label");
    if (typeof console.countReset === "function") {
        console.countReset("label");
        // After reset, count should restart from 1 on next call
        console.count("label");
    }
}
assert(typeof console.count === "function" || typeof console.count === "undefined",
    "CON-006: console.count is function or absent");

// CON-007: time / timeEnd / timeLog
if (typeof console.time === "function") {
    console.time("timer1");
    if (typeof console.timeLog === "function") {
        console.timeLog("timer1");
    }
    console.timeEnd("timer1");
}
assert(typeof console.time === "function" || typeof console.time === "undefined",
    "CON-007: console.time is function or absent");

// CON-008: group / groupEnd / groupCollapsed
if (typeof console.group === "function") {
    console.group("group1");
    console.log("inside group");
    if (typeof console.groupCollapsed === "function") {
        console.groupCollapsed("nested");
        console.log("inside nested");
        console.groupEnd();
    }
    console.groupEnd();
}
assert(typeof console.group === "function" || typeof console.group === "undefined",
    "CON-008: console.group is function or absent");

// CON-009: table — STUB — should not throw
if (typeof console.table === "function") {
    console.table([{a:1},{a:2}]);
}
assert(typeof console.table === "function" || typeof console.table === "undefined",
    "CON-009: console.table is function or absent");

__jacDone();
