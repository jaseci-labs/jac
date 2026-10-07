// node:https module tests — js_engine engine (Phase 6.8)
//
// Tests https.get, https.request, https.Agent, module exports.
// Uses real TLS connections to external hosts.

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + String(expected));
        console.log("     actual:   " + String(actual));
        _failed = _failed + 1;
    }
}

function checkTruthy(id, desc, actual) {
    if (actual) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected truthy, got: " + String(actual));
        _failed = _failed + 1;
    }
}

var https = require("https");
var http = require("http");

// ═══════════════════════════════════════════════════════════════════════════
// Group 1 — Module exports
// ═══════════════════════════════════════════════════════════════════════════

check(1, "https.request is function", typeof https.request, "function");
check(2, "https.get is function", typeof https.get, "function");
check(3, "https.Agent exists", typeof https.Agent, "function");
check(4, "https.Server exists", typeof https.Server, "function");
check(5, "https.createServer is function", typeof https.createServer, "function");
checkTruthy(6, "https.globalAgent exists", https.globalAgent instanceof https.Agent);
checkTruthy(7, "https.STATUS_CODES has 200", https.STATUS_CODES[200] === "OK");
checkTruthy(8, "https.METHODS includes GET", https.METHODS.indexOf("GET") >= 0);

// ═══════════════════════════════════════════════════════════════════════════
// Group 2 — require("node:https") alias
// ═══════════════════════════════════════════════════════════════════════════

var httpsNode = require("node:https");
check(9, "require('node:https') works", typeof httpsNode.get, "function");
check(10, "same STATUS_CODES", httpsNode.STATUS_CODES[200], "OK");

// ═══════════════════════════════════════════════════════════════════════════
// Group 3 — Agent constructor
// ═══════════════════════════════════════════════════════════════════════════

var agent = new https.Agent({ keepAlive: true, maxSockets: 5 });
check(11, "Agent keepAlive", agent.keepAlive, true);
check(12, "Agent maxSockets", agent.maxSockets, 5);
check(13, "Agent.createConnection is function", typeof agent.createConnection, "function");

// ═══════════════════════════════════════════════════════════════════════════
// Group 4 — https.get to local HTTPS echo server (avoids flaky externals)
// ═══════════════════════════════════════════════════════════════════════════

var CERT = __dirname + "/test_cert.pem";
var KEY  = __dirname + "/test_key.pem";

var echoServer = https.createServer({ cert: CERT, key: KEY }, function(req, res) {
    var body = JSON.stringify({ url: req.url, headers: req.headers });
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(body);
});

echoServer.listen(0, function() {
    var addr = echoServer.address();
    https.get({
        hostname: "127.0.0.1",
        port: addr.port,
        path: "/get",
        rejectUnauthorized: false
    }, function(res) {
        check(14, "status 200 from local echo", res.statusCode, 200);
        checkTruthy(15, "httpVersion set", res.httpVersion === "1.1" || res.httpVersion === "1.0");
        checkTruthy(16, "headers is object", typeof res.headers === "object");
        checkTruthy(17, "has content-type", res.headers["content-type"] !== undefined);

        var data = "";
        res.on("data", function(chunk) { data = data + chunk; });
        res.on("end", function() {
            checkTruthy(18, "body is non-empty", data.length > 10);
            checkTruthy(19, "body contains url field", data.indexOf('"url"') !== -1);
            check(20, "res.complete after end", res.complete, true);
            echoServer.close();
        });
    });
});

// ═══════════════════════════════════════════════════════════════════════════
// Group 5 — https.request with options object
// ═══════════════════════════════════════════════════════════════════════════

var req5 = https.request({
    hostname: "httpbin.org",
    port: 443,
    path: "/user-agent",
    method: "GET",
    headers: { "User-Agent": "js_engine-test/1.0" }
}, function(res) {
    check(21, "request() status 200", res.statusCode, 200);
    var body = "";
    res.on("data", function(chunk) { body = body + chunk; });
    res.on("end", function() {
        checkTruthy(22, "body contains user-agent", body.indexOf("js_engine-test") !== -1);
    });
});
req5.end();

// ═══════════════════════════════════════════════════════════════════════════
// Group 6 — https.get with URL query string
// ═══════════════════════════════════════════════════════════════════════════

https.get("https://httpbin.org/get?foo=bar&baz=42", function(res) {
    check(23, "query string status 200", res.statusCode, 200);
    var body = "";
    res.on("data", function(chunk) { body = body + chunk; });
    res.on("end", function() {
        checkTruthy(24, "body contains foo arg", body.indexOf('"foo"') !== -1);
        checkTruthy(25, "body contains baz arg", body.indexOf('"baz"') !== -1);
    });
});

// ═══════════════════════════════════════════════════════════════════════════
// Group 7 — ClientRequest events (socket, finish)
// ═══════════════════════════════════════════════════════════════════════════

var socketFired7 = false;

var req7 = https.request({
    hostname: "httpbin.org",
    port: 443,
    path: "/status/204",
    method: "GET"
}, function(res) {
    check(26, "204 status code", res.statusCode, 204);
    res.on("data", function() {});
    res.on("end", function() {
        check(27, "socket event fired", socketFired7, true);
    });
});
req7.on("socket", function() { socketFired7 = true; });
req7.end();

// ═══════════════════════════════════════════════════════════════════════════
// Group 8 — https.request POST
// ═══════════════════════════════════════════════════════════════════════════

var req8 = https.request({
    hostname: "httpbin.org",
    port: 443,
    path: "/post",
    method: "POST",
    headers: { "Content-Type": "application/json" }
}, function(res) {
    check(28, "POST status 200", res.statusCode, 200);
    var body = "";
    res.on("data", function(chunk) { body = body + chunk; });
    res.on("end", function() {
        checkTruthy(29, "POST body echoed", body.indexOf("hello-https") !== -1);
    });
});
req8.write('{"msg":"hello-https"}');
req8.end();

// ═══════════════════════════════════════════════════════════════════════════
// Summary
// ═══════════════════════════════════════════════════════════════════════════

setTimeout(function() {
    console.log("=== node:https tests: " + _passed + " passed, " + _failed + " failed ===");
    if (_failed > 0) { process.exit(1); }
}, 10000);
