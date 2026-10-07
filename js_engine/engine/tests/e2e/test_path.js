// ────────────────────────────────────────────────────────────────────────────
// test_path.js — Tests for `require("path")` / `require("node:path")`
//
// Tests all POSIX path methods: join, resolve, normalize, dirname, basename,
// extname, isAbsolute, relative, parse, format, sep, delimiter, posix.
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

var path = require("path");

// ── 1. Module shape ─────────────────────────────────────────────────────────
check(1, "require('path') returns object", typeof path, "object");
check(2, "path.join is a function", typeof path.join, "function");
check(3, "path.resolve is a function", typeof path.resolve, "function");

// ── 2. require("node:path") returns same object ─────────────────────────────
var path2 = require("node:path");
check(4, "require('node:path') === require('path')", path === path2, true);

// ── 3. path.sep and path.delimiter ──────────────────────────────────────────
check(5, "path.sep === '/'", path.sep, "/");
check(6, "path.delimiter === ':'", path.delimiter, ":");

// ── 4. path.join ────────────────────────────────────────────────────────────
check(7, "join('a','b','c') === 'a/b/c'", path.join("a", "b", "c"), "a/b/c");
check(8, "join('/a','..','b') === '/b'", path.join("/a", "..", "b"), "/b");
check(9, "join('a','./b') === 'a/b'", path.join("a", "./b"), "a/b");
check(10, "join('/') === '/'", path.join("/"), "/");
check(11, "join() === '.'", path.join(), ".");

// ── 5. path.normalize ──────────────────────────────────────────────────────
check(12, "normalize('/a/b/../c') === '/a/c'", path.normalize("/a/b/../c"), "/a/c");
check(13, "normalize('a/./b') === 'a/b'", path.normalize("a/./b"), "a/b");
check(14, "normalize('') === '.'", path.normalize(""), ".");

// ── 6. path.dirname ─────────────────────────────────────────────────────────
check(15, "dirname('/a/b/c.js') === '/a/b'", path.dirname("/a/b/c.js"), "/a/b");
check(16, "dirname('/a') === '/'", path.dirname("/a"), "/");
check(17, "dirname('file.js') === '.'", path.dirname("file.js"), ".");

// ── 7. path.basename ────────────────────────────────────────────────────────
check(18, "basename('/a/b/c.js') === 'c.js'", path.basename("/a/b/c.js"), "c.js");
check(19, "basename('/a/b/c.js','.js') === 'c'", path.basename("/a/b/c.js", ".js"), "c");
check(20, "basename('file') === 'file'", path.basename("file"), "file");

// ── 8. path.extname ─────────────────────────────────────────────────────────
check(21, "extname('file.tar.gz') === '.gz'", path.extname("file.tar.gz"), ".gz");
check(22, "extname('file') === ''", path.extname("file"), "");
check(23, "extname('/a/b/c.js') === '.js'", path.extname("/a/b/c.js"), ".js");

// ── 9. path.isAbsolute ──────────────────────────────────────────────────────
check(24, "isAbsolute('/foo') === true", path.isAbsolute("/foo"), true);
check(25, "isAbsolute('foo') === false", path.isAbsolute("foo"), false);
check(26, "isAbsolute('') === false", path.isAbsolute(""), false);

// ── 10. path.resolve ────────────────────────────────────────────────────────
// resolve("/a", "b") should give "/a/b"
check(27, "resolve('/a','b') === '/a/b'", path.resolve("/a", "b"), "/a/b");
// resolve("/a/b", "..") should give "/a"
check(28, "resolve('/a/b','..') === '/a'", path.resolve("/a/b", ".."), "/a");
// resolve("foo") should start with "/" (absolute)
check(29, "resolve('foo') starts with /", path.resolve("foo")[0], "/");

// ── 11. path.relative ───────────────────────────────────────────────────────
check(30, "relative('/a/b','/a/c') === '../c'", path.relative("/a/b", "/a/c"), "../c");
check(31, "relative('/a/b/c','/a/b/c') === ''", path.relative("/a/b/c", "/a/b/c"), "");
check(32, "relative('/a','/a/b/c') === 'b/c'", path.relative("/a", "/a/b/c"), "b/c");

// ── 12. path.parse ──────────────────────────────────────────────────────────
var parsed = path.parse("/home/user/file.txt");
check(33, "parse root === '/'", parsed.root, "/");
check(34, "parse dir === '/home/user'", parsed.dir, "/home/user");
check(35, "parse base === 'file.txt'", parsed.base, "file.txt");
check(36, "parse ext === '.txt'", parsed.ext, ".txt");
check(37, "parse name === 'file'", parsed.name, "file");

// ── 13. path.format ─────────────────────────────────────────────────────────
var formatted = path.format({ root: "/", dir: "/home/user", base: "file.txt" });
check(38, "format returns '/home/user/file.txt'", formatted, "/home/user/file.txt");

// ── 14. path.posix self-reference ───────────────────────────────────────────
check(39, "path.posix === path", path.posix === path, true);

// ── Summary ──────────────────────────────────────────────────────────────────
console.log("\n=== Path tests: " + _passed + " passed, " + _failed + " failed ===");
