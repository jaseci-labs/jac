// RT-100 through RT-104: Module-scoped variables
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/11_module_scope/test_module_scope.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-100: __filename
assertEq(typeof __filename, "string", "RT-100: typeof __filename === 'string'");
assert(__filename.length > 0, "RT-100: __filename is non-empty");
assert(__filename.indexOf("test_module_scope") !== -1,
    "RT-100: __filename contains this file's name");

// RT-101: __dirname
assertEq(typeof __dirname, "string", "RT-101: typeof __dirname === 'string'");
assert(__dirname.length > 0, "RT-101: __dirname is non-empty");
assert(__filename.indexOf(__dirname) === 0,
    "RT-101: __filename starts with __dirname");

// RT-102: module
assertEq(typeof module, "object", "RT-102: typeof module === 'object'");
assert(module !== null, "RT-102: module is not null");
assert("exports" in module, "RT-102: module.exports exists");

// RT-103: exports
assertEq(typeof exports, "object", "RT-103: typeof exports === 'object'");
assert(exports === module.exports, "RT-103: exports === module.exports initially");

// RT-104: require
assertEq(typeof require, "function", "RT-104: typeof require === 'function'");
var path = require("path");
assert(path !== null && typeof path === "object", "RT-104: require loads built-in module 'path'");
assert(typeof path.join === "function", "RT-104: required 'path' module is functional");

__jacDone();
