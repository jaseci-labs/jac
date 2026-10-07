// ────────────────────────────────────────────────────────────────────────────
// test_module_require.js — module.require() method tests
//
// Regression for: CALL_METHOD with NATIVE_KIND_BOUND_REQUIRE was not handled,
// causing module.require(specifier) to always return undefined.
//
// Tests:
//   1. module.require() returns a valid module object (not undefined)
//   2. module.require("path") gives the same surface as require("path")
//   3. module.require() works for built-in modules (fs, os, path)
//   4. module.require() with node: prefix
//   5. module.require() result is cached (same object as require())
//   6. module.require() for a user CJS module
// ────────────────────────────────────────────────────────────────────────────

var _passed = 0;
var _failed = 0;
function check(id, desc, actual, expected) {
    if (actual === expected) {
        _passed = _passed + 1;
        console.log("OK " + id + " " + desc);
    } else {
        _failed = _failed + 1;
        console.log("FAIL " + id + " " + desc + "  got=" + actual + "  expected=" + expected);
    }
}

// ── 1. module.require() does not return undefined ────────────────────────────
var pathViaMr = module.require("path");
check(1, "module.require('path') is not undefined", pathViaMr !== undefined, true);
check(2, "module.require('path') returns object", typeof pathViaMr, "object");

// ── 2. module.require("path") exposes path.join ──────────────────────────────
check(3, "module.require('path').join is function", typeof pathViaMr.join, "function");
check(4, "module.require('path').join works", pathViaMr.join("/a", "b"), "/a/b");
check(5, "module.require('path').isAbsolute works", pathViaMr.isAbsolute("/foo"), true);

// ── 3. Built-in modules via module.require ───────────────────────────────────
var fsViaMr = module.require("fs");
check(6, "module.require('fs') returns object", typeof fsViaMr, "object");
check(7, "module.require('fs').readFileSync is function", typeof fsViaMr.readFileSync, "function");

var osViaMr = module.require("os");
check(8, "module.require('os') returns object", typeof osViaMr, "object");
check(9, "module.require('os').platform is function", typeof osViaMr.platform, "function");

// ── 4. node: prefix via module.require ───────────────────────────────────────
var pathNode = module.require("node:path");
check(10, "module.require('node:path') returns object", typeof pathNode, "object");
check(11, "module.require('node:path').join is function", typeof pathNode.join, "function");

// ── 5. Result matches require() — same cached exports object ─────────────────
var pathViaDirect = require("path");
check(12, "module.require('path') === require('path')", pathViaMr === pathViaDirect, true);

var fsViaDirect = require("fs");
check(13, "module.require('fs') === require('fs')", fsViaMr === fsViaDirect, true);

// ── 6. User CJS module via module.require ────────────────────────────────────
var math = module.require("./helper_math.js");
check(14, "module.require('./helper_math.js') returns object", typeof math, "object");
check(15, "math.add(2, 3) === 5", math.add(2, 3), 5);
check(16, "math.mul(4, 5) === 20", math.mul(4, 5), 20);

// ── Summary ──────────────────────────────────────────────────────────────────
if (_failed > 0) {
    console.log("RESULT: " + _failed + " test(s) FAILED, " + _passed + " passed");
    process.exit(1);
} else {
    console.log("RESULT: all " + _passed + " tests passed");
}
