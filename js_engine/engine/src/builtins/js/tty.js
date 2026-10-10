// ────────────────────────────────────────────────────────────────────────────
// builtins/js/tty.js — Node.js `tty` module
//
// Provides TTY detection and stream wrappers for terminal I/O.
//
// require("tty").isatty(fd) — check if fd refers to a terminal
// require("tty").ReadStream  — TTY readable stream class (stub)
// require("tty").WriteStream — TTY writable stream class (stub)
//
// Node.js reference: https://nodejs.org/api/tty.html
// ────────────────────────────────────────────────────────────────────────────

var EventEmitter = require("events");

// ── isatty(fd) ──────────────────────────────────────────────────────────────
// Uses the __tty_info map populated at bootstrap time from C isatty().
// For known fds (0, 1, 2) we have exact results; others default to false.

function isatty(fd) {
    if (typeof fd !== "number") {
        return false;
    }
    var info = globalThis.__tty_info;
    if (info === undefined) {
        return false;
    }
    var key = "" + fd;
    var val = info[key];
    if (val === undefined) {
        return false;
    }
    return val;
}

// ── ReadStream ──────────────────────────────────────────────────────────────
// Minimal stub: extends EventEmitter (full net.Socket not available yet).
// Enough for `process.stdin instanceof tty.ReadStream` pattern and
// basic property checks.

function ReadStream(fd) {
    EventEmitter.init.call(this);
    this.fd = fd !== undefined ? fd : 0;
    this.isTTY = isatty(this.fd);
    this.isRaw = false;
}

ReadStream.prototype = Object.create(EventEmitter.prototype);
ReadStream.prototype.constructor = ReadStream;

ReadStream.prototype.setRawMode = function(mode) {
    this.isRaw = !!mode;
    return this;
};

// ── WriteStream ─────────────────────────────────────────────────────────────
// Minimal stub: extends EventEmitter.
// Exposes `.columns`, `.rows`, `.isTTY` for terminal dimension queries.

function WriteStream(fd) {
    EventEmitter.init.call(this);
    this.fd = fd !== undefined ? fd : 1;
    this.isTTY = isatty(this.fd);

    // Terminal dimensions — read from env or use sensible defaults.
    // In Node.js these come from uv_tty_get_winsize; we approximate.
    var cols = 80;
    var rows = 24;
    if (typeof process !== "undefined" && process.env) {
        if (process.env.COLUMNS !== undefined) {
            var c = parseInt(process.env.COLUMNS, 10);
            if (c > 0) { cols = c; }
        }
        if (process.env.LINES !== undefined) {
            var r = parseInt(process.env.LINES, 10);
            if (r > 0) { rows = r; }
        }
    }
    this.columns = cols;
    this.rows = rows;
}

WriteStream.prototype = Object.create(EventEmitter.prototype);
WriteStream.prototype.constructor = WriteStream;

WriteStream.prototype.getWindowSize = function() {
    return [this.columns, this.rows];
};

WriteStream.prototype.hasColors = function(count) {
    if (!this.isTTY) { return false; }
    // Basic color support detection: assume 256 colors for TTYs
    if (count === undefined) { count = 16; }
    return count <= 256;
};

WriteStream.prototype.getColorDepth = function() {
    if (!this.isTTY) { return 1; }
    // Assume 8-bit (256 colors) for TTY
    return 8;
};

WriteStream.prototype.clearLine = function(dir, callback) {
    // No-op stub — real implementation requires ANSI escape sequences
    if (typeof callback === "function") { callback(); }
    return true;
};

WriteStream.prototype.cursorTo = function(x, y, callback) {
    if (typeof callback === "function") { callback(); }
    return true;
};

WriteStream.prototype.moveCursor = function(dx, dy, callback) {
    if (typeof callback === "function") { callback(); }
    return true;
};

// ── Module exports ──────────────────────────────────────────────────────────

module.exports = {
    isatty: isatty,
    ReadStream: ReadStream,
    WriteStream: WriteStream
};
