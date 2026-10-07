// ════════════════════════════════════════════════════════════════════════════
// test_tty.js — Tests for the `tty` module (Phase 5.12)
// ════════════════════════════════════════════════════════════════════════════

var passed = 0;
var failed = 0;

function assert(condition, msg) {
    if (condition) {
        passed = passed + 1;
    } else {
        failed = failed + 1;
        console.log("FAIL: " + msg);
    }
}

// ── require("tty") shape ────────────────────────────────────────────────────

var tty = require("tty");

assert(typeof tty === "object", "require('tty') returns object");
assert(typeof tty.isatty === "function", "tty.isatty is a function");
assert(typeof tty.ReadStream === "function", "tty.ReadStream is a function");
assert(typeof tty.WriteStream === "function", "tty.WriteStream is a function");

// ── require("node:tty") ─────────────────────────────────────────────────────

var tty2 = require("node:tty");
assert(typeof tty2.isatty === "function", "require('node:tty').isatty is a function");
assert(tty2.isatty === tty.isatty, "node:tty and tty return same isatty");

// ── tty.isatty() ────────────────────────────────────────────────────────────

// In test environment (piped), fds 0/1/2 may or may not be TTYs.
// We just verify the function returns booleans and doesn't crash.
var r0 = tty.isatty(0);
var r1 = tty.isatty(1);
var r2 = tty.isatty(2);

assert(typeof r0 === "boolean", "isatty(0) returns boolean");
assert(typeof r1 === "boolean", "isatty(1) returns boolean");
assert(typeof r2 === "boolean", "isatty(2) returns boolean");

// Invalid fd should return false
assert(tty.isatty(999) === false, "isatty(999) returns false");
assert(tty.isatty(-1) === false, "isatty(-1) returns false");
assert(tty.isatty("hello") === false, "isatty('hello') returns false");
assert(tty.isatty(undefined) === false, "isatty(undefined) returns false");
assert(tty.isatty(null) === false, "isatty(null) returns false");

// ── tty.ReadStream ──────────────────────────────────────────────────────────

var rs = new tty.ReadStream(0);

assert(typeof rs === "object", "new ReadStream(0) returns object");
assert(rs.fd === 0, "ReadStream.fd === 0");
assert(typeof rs.isTTY === "boolean", "ReadStream.isTTY is boolean");
assert(rs.isRaw === false, "ReadStream.isRaw starts false");
assert(typeof rs.setRawMode === "function", "ReadStream.setRawMode is function");

// setRawMode returns this for chaining
var ret = rs.setRawMode(true);
assert(rs.isRaw === true, "setRawMode(true) sets isRaw");
assert(ret === rs, "setRawMode returns this");
rs.setRawMode(false);
assert(rs.isRaw === false, "setRawMode(false) resets isRaw");

// ReadStream inherits from EventEmitter
assert(typeof rs.on === "function", "ReadStream has .on (EventEmitter)");
assert(typeof rs.emit === "function", "ReadStream has .emit (EventEmitter)");
assert(typeof rs.removeListener === "function", "ReadStream has .removeListener");

// ── tty.WriteStream ─────────────────────────────────────────────────────────

var ws = new tty.WriteStream(1);

assert(typeof ws === "object", "new WriteStream(1) returns object");
assert(ws.fd === 1, "WriteStream.fd === 1");
assert(typeof ws.isTTY === "boolean", "WriteStream.isTTY is boolean");
assert(typeof ws.columns === "number", "WriteStream.columns is number");
assert(typeof ws.rows === "number", "WriteStream.rows is number");
assert(ws.columns > 0, "WriteStream.columns > 0");
assert(ws.rows > 0, "WriteStream.rows > 0");

// getWindowSize
assert(typeof ws.getWindowSize === "function", "WriteStream.getWindowSize is function");
var size = ws.getWindowSize();
assert(size[0] === ws.columns, "getWindowSize()[0] === columns");
assert(size[1] === ws.rows, "getWindowSize()[1] === rows");

// hasColors
assert(typeof ws.hasColors === "function", "WriteStream.hasColors is function");
// In piped context, hasColors depends on isTTY
var hc = ws.hasColors();
assert(typeof hc === "boolean", "hasColors() returns boolean");

// getColorDepth
assert(typeof ws.getColorDepth === "function", "WriteStream.getColorDepth is function");
var cd = ws.getColorDepth();
assert(typeof cd === "number", "getColorDepth() returns number");

// clearLine, cursorTo, moveCursor — stubs
assert(typeof ws.clearLine === "function", "WriteStream.clearLine is function");
assert(typeof ws.cursorTo === "function", "WriteStream.cursorTo is function");
assert(typeof ws.moveCursor === "function", "WriteStream.moveCursor is function");
assert(ws.clearLine(0) === true, "clearLine returns true");
assert(ws.cursorTo(0, 0) === true, "cursorTo returns true");
assert(ws.moveCursor(1, 1) === true, "moveCursor returns true");

// WriteStream inherits from EventEmitter
assert(typeof ws.on === "function", "WriteStream has .on (EventEmitter)");
assert(typeof ws.emit === "function", "WriteStream has .emit (EventEmitter)");

// ── process.stdout.isTTY / process.stderr.isTTY consistency ─────────────────

// In piped test environment, these should be consistent with tty.isatty
var stdout_tty = process.stdout.isTTY;
var stderr_tty = process.stderr.isTTY;
// isTTY may be undefined (falsy) when not a TTY, or true when it is
assert(tty.isatty(1) === (stdout_tty === true), "isatty(1) consistent with process.stdout.isTTY");
assert(tty.isatty(2) === (stderr_tty === true), "isatty(2) consistent with process.stderr.isTTY");

// ── Summary ─────────────────────────────────────────────────────────────────

console.log("");
console.log("=== TTY tests: " + passed + " passed, " + failed + " failed ===");
