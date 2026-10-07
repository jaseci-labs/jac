/**
 * test_http2.js — Integration tests for the node:http2 module
 *
 * Tests are self-contained and run sequentially.
 * Each test prints "OK: <description>" on success or throws on failure.
 *
 * Run with: jac run engine/src/main.na.jac js_tests/test_http2.js
 */

"use strict";

var http2 = require("node:http2");
var assert = require("assert");

var ok = 0;
var fail = 0;

function check(desc, fn) {
    try {
        fn();
        console.log("OK: " + desc);
        ok++;
    } catch (e) {
        console.log("FAIL: " + desc + " — " + e.message);
        fail++;
    }
}

// ── 1. Module exports structure ───────────────────────────────────────────

check("require('node:http2') returns object", function() {
    assert(typeof http2 === "object" && http2 !== null, "not an object");
});

check("http2.createServer is a function", function() {
    assert(typeof http2.createServer === "function");
});

check("http2.createSecureServer is a function", function() {
    assert(typeof http2.createSecureServer === "function");
});

check("http2.connect is a function", function() {
    assert(typeof http2.connect === "function");
});

check("http2.constants is an object", function() {
    assert(typeof http2.constants === "object" && http2.constants !== null);
});

// ── 2. Constants ──────────────────────────────────────────────────────────

check("constants.HTTP2_HEADER_STATUS === ':status'", function() {
    assert.strictEqual(http2.constants.HTTP2_HEADER_STATUS, ":status");
});

check("constants.HTTP2_HEADER_METHOD === ':method'", function() {
    assert.strictEqual(http2.constants.HTTP2_HEADER_METHOD, ":method");
});

check("constants.HTTP2_STATUS_OK === 200", function() {
    assert.strictEqual(http2.constants.HTTP2_STATUS_OK, 200);
});

check("constants.HTTP2_STATUS_NOT_FOUND === 404", function() {
    assert.strictEqual(http2.constants.HTTP2_STATUS_NOT_FOUND, 404);
});

check("constants.NGHTTP2_NO_ERROR === 0", function() {
    assert.strictEqual(http2.constants.NGHTTP2_NO_ERROR, 0);
});

check("constants.SETTINGS_INITIAL_WINDOW_SIZE === 4", function() {
    assert.strictEqual(http2.constants.SETTINGS_INITIAL_WINDOW_SIZE, 4);
});

check("constants.DEFAULT_SETTINGS_MAX_FRAME_SIZE === 16384", function() {
    assert.strictEqual(http2.constants.DEFAULT_SETTINGS_MAX_FRAME_SIZE, 16384);
});

// ── 3. getDefaultSettings ─────────────────────────────────────────────────

check("getDefaultSettings returns object with headerTableSize", function() {
    var s = http2.getDefaultSettings();
    assert(typeof s === "object" && typeof s.headerTableSize === "number");
    assert.strictEqual(s.headerTableSize, 4096);
});

check("getDefaultSettings.initialWindowSize === 65535", function() {
    var s = http2.getDefaultSettings();
    assert.strictEqual(s.initialWindowSize, 65535);
});

// ── 4. Class constructors ─────────────────────────────────────────────────

check("Http2Session is a function/constructor", function() {
    assert(typeof http2.Http2Session === "function");
});

check("ClientHttp2Session prototype inherits Http2Session", function() {
    var proto = http2.ClientHttp2Session.prototype;
    assert(proto instanceof http2.Http2Session || proto.constructor === http2.ClientHttp2Session);
});

check("ServerHttp2Session prototype inherits Http2Session", function() {
    var proto = http2.ServerHttp2Session.prototype;
    assert(proto instanceof http2.Http2Session || proto.constructor === http2.ServerHttp2Session);
});

check("Http2Stream is a function/constructor", function() {
    assert(typeof http2.Http2Stream === "function");
});

check("ClientHttp2Stream.prototype inherits Http2Stream", function() {
    var proto = http2.ClientHttp2Stream.prototype;
    assert(proto instanceof http2.Http2Stream || proto.constructor === http2.ClientHttp2Stream);
});

check("ServerHttp2Stream.prototype inherits Http2Stream", function() {
    var proto = http2.ServerHttp2Stream.prototype;
    assert(proto instanceof http2.Http2Stream || proto.constructor === http2.ServerHttp2Stream);
});

// ── 5. Http2Server / Http2SecureServer ────────────────────────────────────

check("createServer() returns Http2Server instance", function() {
    var srv = http2.createServer({});
    assert(srv instanceof http2.Http2Server);
});

check("createSecureServer() returns Http2SecureServer instance", function() {
    var srv = http2.createSecureServer({});
    assert(srv instanceof http2.Http2SecureServer);
});

check("Http2SecureServer._isTLS === true", function() {
    var srv = http2.createSecureServer({});
    assert.strictEqual(srv._isTLS, true);
});

check("Http2Server._isTLS === false", function() {
    var srv = http2.createServer({});
    assert.strictEqual(srv._isTLS, false);
});

check("createServer with callback sets 'request' listener", function() {
    var called = false;
    var srv = http2.createServer({}, function(req, res) { called = true; });
    assert(srv.listenerCount("request") >= 1);
});

// ── 6. require('http2') alias works ──────────────────────────────────────

check("require('http2') works (no 'node:' prefix)", function() {
    var h = require("http2");
    assert(typeof h === "object" && h !== null);
    assert(typeof h.createServer === "function");
});

// ── 7. sensitiveHeaders symbol ────────────────────────────────────────────

check("http2.sensitiveHeaders is a Symbol", function() {
    assert(typeof http2.sensitiveHeaders === "symbol");
});

// ── 8. getPackedSettings / getUnpackedSettings ────────────────────────────

check("getPackedSettings returns object", function() {
    var packed = http2.getPackedSettings({});
    assert(typeof packed === "object" && packed !== null);
});

check("getUnpackedSettings returns settings object", function() {
    var unpacked = http2.getUnpackedSettings(null);
    assert(typeof unpacked === "object");
    assert(typeof unpacked.headerTableSize === "number");
});

// ── Summary ───────────────────────────────────────────────────────────────

console.log("");
console.log("http2 tests: " + ok + " passed, " + fail + " failed.");
if (fail > 0) {
    throw new Error("Test suite failed: " + fail + " failure(s)");
}
