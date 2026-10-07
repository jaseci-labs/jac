// node:http module tests — js_engine engine (Phase 6.8)
//
// Tests http.createServer, http.request, http.get, http.IncomingMessage,
// http.ServerResponse, keep-alive, POST bodies, and http module exports.

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

var http = require("http");

// ═══════════════════════════════════════════════════════════════════════════
// Group 1 — Module exports
// ═══════════════════════════════════════════════════════════════════════════

check(1, "http.createServer is function", typeof http.createServer, "function");
check(2, "http.request is function", typeof http.request, "function");
check(3, "http.get is function", typeof http.get, "function");
check(4, "http.Server exists", typeof http.Server, "function");
check(5, "http.IncomingMessage exists", typeof http.IncomingMessage, "function");
check(6, "http.ServerResponse exists", typeof http.ServerResponse, "function");
check(7, "http.ClientRequest exists", typeof http.ClientRequest, "function");
check(8, "http.Agent exists", typeof http.Agent, "function");
checkTruthy(9, "http.globalAgent is Agent", http.globalAgent instanceof http.Agent);
checkTruthy(10, "http.STATUS_CODES has 200", http.STATUS_CODES[200] === "OK");
checkTruthy(11, "http.STATUS_CODES has 404", http.STATUS_CODES[404] === "Not Found");
checkTruthy(12, "http.METHODS is array", Array.isArray(http.METHODS));
checkTruthy(13, "http.METHODS includes GET", http.METHODS.indexOf("GET") >= 0);
check(14, "http.maxHeaderSize is 16384", http.maxHeaderSize, 16384);

// ═══════════════════════════════════════════════════════════════════════════
// Group 2 — createServer + listen + address + close
// ═══════════════════════════════════════════════════════════════════════════

var listeningEmitted = false;
var closeEmitted = false;

var server2 = http.createServer(function(req, res) {
    res.writeHead(200);
    res.end("hello");
});

server2.on("listening", function() { listeningEmitted = true; });

server2.listen(0, "127.0.0.1");

setTimeout(function() {
    check(15, "listening event emitted", listeningEmitted, true);
    var addr = server2.address();
    checkTruthy(16, "server address has port", addr && addr.port > 0);
    check(17, "server address host", addr.address, "127.0.0.1");

    server2.on("close", function() { closeEmitted = true; });
    server2.close();

    setTimeout(function() {
        check(18, "close event emitted", closeEmitted, true);
    }, 50);
}, 50);

// ═══════════════════════════════════════════════════════════════════════════
// Group 3 — Simple GET request/response round-trip
// ═══════════════════════════════════════════════════════════════════════════

var server3 = http.createServer(function(req, res) {
    check(19, "req.method is GET", req.method, "GET");
    check(20, "req.url is /test-path", req.url, "/test-path");
    checkTruthy(21, "req.headers is object", typeof req.headers === "object");
    checkTruthy(22, "req.headers has host", req.headers["host"] !== undefined);
    check(23, "req.httpVersion is 1.1", req.httpVersion, "1.1");

    res.writeHead(200, { "Content-Type": "text/plain", "X-Custom": "hello" });
    res.end("OK-body");
});

server3.listen(0, "127.0.0.1", function() {
    var port = server3.address().port;

    var responseData = "";
    var responseStatusCode = 0;
    var responseHeaders = null;

    var req = http.request({
        hostname: "127.0.0.1",
        port: port,
        path: "/test-path",
        method: "GET"
    }, function(res) {
        responseStatusCode = res.statusCode;
        responseHeaders = res.headers;
        res.on("data", function(chunk) {
            responseData = responseData + chunk;
        });
        res.on("end", function() {
            check(24, "response status 200", responseStatusCode, 200);
            check(25, "response body", responseData, "OK-body");
            checkTruthy(26, "response has content-type", responseHeaders["content-type"] === "text/plain");
            checkTruthy(27, "response has x-custom", responseHeaders["x-custom"] === "hello");
            check(28, "res.httpVersion", res.httpVersion, "1.1");
            check(29, "res.complete after end", res.complete, true);

            server3.close();
        });
    });

    req.end();
});

// ═══════════════════════════════════════════════════════════════════════════
// Group 4 — POST request with body
// ═══════════════════════════════════════════════════════════════════════════

var server4 = http.createServer(function(req, res) {
    var body = "";
    req.on("data", function(chunk) {
        body = body + chunk;
    });
    req.on("end", function() {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end('{"received":"' + body + '"}');
    });
});

server4.listen(0, "127.0.0.1", function() {
    var port = server4.address().port;

    var responseData = "";

    var req = http.request({
        hostname: "127.0.0.1",
        port: port,
        path: "/echo",
        method: "POST",
        headers: { "Content-Type": "text/plain" }
    }, function(res) {
        check(30, "POST response status 200", res.statusCode, 200);
        res.on("data", function(chunk) {
            responseData = responseData + chunk;
        });
        res.on("end", function() {
            check(31, "POST response body echoed", responseData, '{"received":"hello-post"}');
            server4.close();
        });
    });

    req.write("hello-post");
    req.end();
});


// ═══════════════════════════════════════════════════════════════════════════
// Group 5 — http.get shorthand
// ═══════════════════════════════════════════════════════════════════════════

var server5 = http.createServer(function(req, res) {
    res.writeHead(200);
    res.end("get-response");
});

server5.listen(0, "127.0.0.1", function() {
    var port = server5.address().port;

    http.get("http://127.0.0.1:" + port + "/shorthand", function(res) {
        var data = "";
        check(32, "http.get status 200", res.statusCode, 200);
        res.on("data", function(chunk) { data = data + chunk; });
        res.on("end", function() {
            check(33, "http.get body", data, "get-response");
            server5.close();
        });
    });
});


// ═══════════════════════════════════════════════════════════════════════════
// Group 6 — ServerResponse methods
// ═══════════════════════════════════════════════════════════════════════════

var server6 = http.createServer(function(req, res) {
    res.setHeader("X-First", "value1");
    check(34, "getHeader returns set value", res.getHeader("X-First"), "value1");
    check(35, "hasHeader returns true", res.hasHeader("X-First"), true);
    checkTruthy(36, "getHeaderNames includes x-first", res.getHeaderNames().indexOf("x-first") >= 0);

    res.setHeader("X-Remove", "toremove");
    res.removeHeader("X-Remove");
    check(37, "removeHeader removes header", res.hasHeader("X-Remove"), false);

    check(38, "statusCode default 200", res.statusCode, 200);
    res.statusCode = 201;
    check(39, "statusCode settable", res.statusCode, 201);

    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("sr-ok");
});

server6.listen(0, "127.0.0.1", function() {
    var port = server6.address().port;
    http.get("http://127.0.0.1:" + port + "/", function(res) {
        res.on("data", function() {});
        res.on("end", function() { server6.close(); });
    });
});


// ═══════════════════════════════════════════════════════════════════════════
// Group 7 — IncomingMessage properties (client response)
// ═══════════════════════════════════════════════════════════════════════════

var server7 = http.createServer(function(req, res) {
    res.writeHead(404, "Custom Not Found", { "X-Reason": "testing" });
    res.end("not found body");
});

server7.listen(0, "127.0.0.1", function() {
    var port = server7.address().port;

    http.get("http://127.0.0.1:" + port + "/missing", function(res) {
        check(40, "statusCode 404", res.statusCode, 404);
        check(41, "statusMessage", res.statusMessage, "Custom Not Found");
        checkTruthy(42, "rawHeaders is array", Array.isArray(res.rawHeaders));
        checkTruthy(43, "rawHeaders length > 0", res.rawHeaders.length > 0);
        checkTruthy(44, "has x-reason header", res.headers["x-reason"] === "testing");

        var data = "";
        res.on("data", function(ch) { data = data + ch; });
        res.on("end", function() {
            check(45, "404 response body", data, "not found body");
            server7.close();
        });
    });
});


// ═══════════════════════════════════════════════════════════════════════════
// Group 8 — Request with timeout
// ═══════════════════════════════════════════════════════════════════════════

var server8 = http.createServer(function(req, res) {
    // Don't respond — let client timeout
    setTimeout(function() {
        res.writeHead(200);
        res.end("late");
    }, 500);
});

server8.listen(0, "127.0.0.1", function() {
    var port = server8.address().port;
    var timeoutFired = false;

    var req = http.request({
        hostname: "127.0.0.1",
        port: port,
        path: "/slow",
        method: "GET"
    }, function(res) {
        res.on("data", function() {});
        res.on("end", function() {});
    });

    req.setTimeout(100, function() {
        timeoutFired = true;
        req.destroy();
    });
    req.on("error", function() {
        // Expected after destroy() on timeout (Node emits ECONNRESET).
    });
    req.end();

    setTimeout(function() {
        check(46, "request timeout fired", timeoutFired, true);
        server8.close();
    }, 400);
});


// ═══════════════════════════════════════════════════════════════════════════
// Group 9 — Multiple sequential requests via http.get
// ═══════════════════════════════════════════════════════════════════════════

var reqCount9 = 0;
var server9 = http.createServer(function(req, res) {
    reqCount9 = reqCount9 + 1;
    res.writeHead(200);
    res.end("resp-" + reqCount9);
});

server9.listen(0, "127.0.0.1", function() {
    var port = server9.address().port;

    function secondGet() {
        http.get("http://127.0.0.1:" + port + "/b", function(res2) {
            var d2 = "";
            res2.on("data", function(ch) { d2 = d2 + ch; });
            res2.on("end", function() {
                check(48, "second request body", d2, "resp-2");
                server9.close();
            });
        });
    }

    http.get("http://127.0.0.1:" + port + "/a", function(res) {
        var d = "";
        res.on("data", function(ch) { d = d + ch; });
        res.on("end", function() {
            check(47, "first request body", d, "resp-1");
            secondGet();
        });
    });
});


// ═══════════════════════════════════════════════════════════════════════════
// Groups 10–12 — one server, sequential clients
// (js_engine compiler can hang when groups 9+10+11+12 each add their own listen()
//  closure tree in the same file; see engine/tests/e2e/test_node_http_compiler_hang.js)
// ═══════════════════════════════════════════════════════════════════════════

var serverLate = http.createServer(function(req, res) {
    if (req.url === "/empty") {
        res.writeHead(204);
        res.end();
        return;
    }
    res.writeHead(200);
    res.end(req.url);
});

serverLate.listen(0, "127.0.0.1", function() {
    var port = serverLate.address().port;
    var socketEmitted = false;
    var finishEmitted = false;

    function runGroup12() {
        http.get("http://127.0.0.1:" + port + "/search?q=hello&page=1", function(res) {
            var d = "";
            res.on("data", function(ch) { d = d + ch; });
            res.on("end", function() {
                check(53, "req.url includes query string", d, "/search?q=hello&page=1");
                serverLate.close();
            });
        });
    }

    function runGroup11() {
        http.get("http://127.0.0.1:" + port + "/empty", function(res) {
            check(51, "204 status code", res.statusCode, 204);
            var d = "";
            res.on("data", function(ch) { d = d + ch; });
            res.on("end", function() {
                check(52, "204 empty body", d, "");
                runGroup12();
            });
        });
    }

    var req = http.request({
        hostname: "127.0.0.1",
        port: port,
        path: "/events",
        method: "GET"
    }, function(res) {
        res.on("data", function() {});
        res.on("end", function() {
            check(49, "socket event emitted", socketEmitted, true);
            check(50, "finish event emitted", finishEmitted, true);
            runGroup11();
        });
    });
    req.on("socket", function() { socketEmitted = true; });
    req.on("finish", function() { finishEmitted = true; });
    req.end();
});


// ═══════════════════════════════════════════════════════════════════════════
// Group 13 — Agent stub
// ═══════════════════════════════════════════════════════════════════════════

var agent = new http.Agent({ keepAlive: true, maxSockets: 10 });
check(54, "Agent keepAlive", agent.keepAlive, true);
check(55, "Agent maxSockets", agent.maxSockets, 10);
check(56, "Agent.createConnection is function", typeof agent.createConnection, "function");


// ═══════════════════════════════════════════════════════════════════════════
// Group 14 — require("node:http") alias
// ═══════════════════════════════════════════════════════════════════════════

var httpNodePrefix = require("node:http");
check(57, "require('node:http') works", typeof httpNodePrefix.createServer, "function");
check(58, "same module identity", httpNodePrefix.STATUS_CODES[200], "OK");


// ═══════════════════════════════════════════════════════════════════════════
// Summary
// ═══════════════════════════════════════════════════════════════════════════

setTimeout(function() {
    console.log("=== node:http tests: " + _passed + " passed, " + _failed + " failed ===");
    if (_failed > 0) { process.exit(1); }
}, 3000);
