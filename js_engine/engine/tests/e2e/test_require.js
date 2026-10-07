// ────────────────────────────────────────────────────────────────────────────
// test_require.js — Module system tests
//
// Tests:
//   1. require() built-in modules (fs, process)
//   2. require() with node: prefix
//   3. require() user CJS module (module.exports = {...})
//   4. require() user module with default export
//   5. require() caching (same object reference)
//   6. import { named } syntax
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

// ── 1. Built-in modules ──────────────────────────────────────────────────────
var fs_mod = require("fs");
check(1, "require('fs') returns object", typeof fs_mod, "object");

var proc_mod = require("process");
check(2, "require('process') returns object", typeof proc_mod, "object");

// ── 2. node: prefix ─────────────────────────────────────────────────────────
var fs_node = require("node:fs");
check(3, "require('node:fs') returns object", typeof fs_node, "object");

// ── 3. User CJS module ──────────────────────────────────────────────────────
var math = require("./helper_math.js");
check(4, "require('./helper_math.js') returns object", typeof math, "object");
check(5, "math.add(2, 3) === 5", math.add(2, 3), 5);
check(6, "math.mul(4, 5) === 20", math.mul(4, 5), 20);

// ── 4. User module with default export ───────────────────────────────────────
var greeting = require("./helper_default.js");
check(7, "require('./helper_default.js') default export", greeting, "hello from helper");

// ── 5. Module caching ───────────────────────────────────────────────────────
var math2 = require("./helper_math.js");
check(8, "require cache returns same object", math === math2, true);

// ── 6. import { named } syntax ──────────────────────────────────────────────
import { PI, double } from "./helper_named.js";
check(9, "import { PI } = 3.14159", PI, 3.14159);
check(10, "import { double } double(7) === 14", double(7), 14);

// ── 7. __dirname / __filename inside required module ─────────────────────────
var dirinfo = require("./helper_dirname.js");
// __dirname should be a string (the directory path)
check(11, "__dirname is a string", typeof dirinfo.dir, "string");
// __filename should be a string (the file path)
check(12, "__filename is a string", typeof dirinfo.file, "string");
// __filename should end with helper_dirname.js
var fname = dirinfo.file;
var ends_right = fname.indexOf("helper_dirname.js") !== -1;
check(13, "__filename contains helper_dirname.js", ends_right, true);

// ── 8. dynamic import() returns a promise ────────────────────────────────────
var dyn_promise = import("./helper_math.js");
check(14, "import() returns object (promise)", typeof dyn_promise, "object");

// ── Summary ──────────────────────────────────────────────────────────────────
console.log("\n=== Require tests: " + _passed + " passed, " + _failed + " failed ===");
