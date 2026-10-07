// HTTP Server tests — js_engine engine (Phase 6.5)
//
// Testing strategy for blocking I/O:
//   1. Start server (tcpListen)
//   2. Client connects to server port (goes into kernel backlog)
//   3. Client sends request data
//   4. Server calls accept() — returns immediately since connection is queued
//   5. Server reads request, calls fetch handler, writes response
//   6. Client reads response
//
// This works because TCP connect() completes when the SYN-ACK is received
// from the listening socket (before accept is called). Data can be sent
// before accept too — it sits in the kernel receive buffer.

var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + JSON.stringify(expected));
        console.log("     actual:   " + JSON.stringify(actual));
        _failed = _failed + 1;
    }
}

function checkTruthy(id, desc, actual) {
    if (actual) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected truthy, got: " + JSON.stringify(actual));
        _failed = _failed + 1;
    }
}

var net = globalThis.__net;
var CRLF = String.fromCharCode(13) + "\n";

// ─── Helper: send raw HTTP request via TCP and read response ────────────────

function rawHTTPRequest(port, method, path, headers, body) {
    var handle = net.tcpConnect("127.0.0.1", port);
    if (handle === 0) { return null; }

    var req = method + " " + path + " HTTP/1.1" + CRLF;
    req = req + "Host: 127.0.0.1:" + port + CRLF;

    if (headers) {
        var keys = Object.keys(headers);
        var i = 0;
        while (i < keys.length) {
            req = req + keys[i] + ": " + headers[keys[i]] + CRLF;
            i = i + 1;
        }
    }

    if (body) {
        req = req + "Content-Length: " + body.length + CRLF;
        req = req + CRLF + body;
    } else {
        req = req + CRLF;
    }

    net.tcpWrite(handle, req);
    return handle;
}

function readResponse(handle) {
    var data = "";
    var attempts = 0;
    while (attempts < 20) {
        var chunk = net.tcpRead(handle, 65536);
        if (chunk === "") { break; }
        data = data + chunk;
        // Check if we have a complete response (headers + body)
        var headerEnd = data.indexOf(CRLF + CRLF);
        if (headerEnd !== -1) {
            // Check Content-Length
            var clMatch = data.toLowerCase().indexOf("content-length: ");
            if (clMatch !== -1) {
                var clEnd = data.indexOf(CRLF, clMatch);
                var clStr = data.substring(clMatch + 16, clEnd);
                var cl = parseInt(clStr, 10);
                var bodyStart = headerEnd + 4;
                if (data.length >= bodyStart + cl) { break; }
            } else {
                // Check for Connection: close
                var connClose = data.toLowerCase().indexOf("connection: close");
                if (connClose !== -1) {
                    // Read until EOF
                    var more = net.tcpRead(handle, 65536);
                    if (more === "") { break; }
                    data = data + more;
                } else {
                    break;
                }
            }
        }
        attempts = attempts + 1;
    }
    net.tcpClose(handle);
    return data;
}

/**
 * Parse raw HTTP response into {status, statusText, headers, body}.
 */
function parseRawResponse(raw) {
    var headerEnd = raw.indexOf(CRLF + CRLF);
    if (headerEnd === -1) { return null; }

    var headerSection = raw.substring(0, headerEnd);
    var bodyStart = headerEnd + 4;

    var lines = [];
    var pos = 0;
    while (pos < headerSection.length) {
        var nl = headerSection.indexOf(CRLF, pos);
        if (nl === -1) {
            lines.push(headerSection.substring(pos));
            break;
        }
        lines.push(headerSection.substring(pos, nl));
        pos = nl + 2;
    }

    if (lines.length === 0) { return null; }

    // Parse status line: "HTTP/1.1 200 OK"
    var statusLine = lines[0];
    var sp1 = statusLine.indexOf(" ");
    var sp2 = statusLine.indexOf(" ", sp1 + 1);
    var status = parseInt(statusLine.substring(sp1 + 1, sp2), 10);
    var statusText = statusLine.substring(sp2 + 1);

    // Parse headers
    var headers = {};
    var i = 1;
    while (i < lines.length) {
        var colon = lines[i].indexOf(":");
        if (colon > 0) {
            var name = lines[i].substring(0, colon).toLowerCase();
            var value = lines[i].substring(colon + 1);
            while (value.length > 0 && value[0] === " ") { value = value.substring(1); }
            headers[name] = value;
        }
        i = i + 1;
    }

    // Extract body
    var body = raw.substring(bodyStart);
    if (headers["content-length"]) {
        var cl = parseInt(headers["content-length"], 10);
        body = raw.substring(bodyStart, bodyStart + cl);
    }

    return { status: status, statusText: statusText, headers: headers, body: body };
}

// ─── Internal parser tests (no server needed) ──────────────────────────────

var httpMod = require("http_server");

// Test 1-5: _parseHTTPRequest
var rawReq = "GET /hello HTTP/1.1" + CRLF +
    "Host: localhost:3000" + CRLF +
    "Accept: */*" + CRLF +
    CRLF;

var parsed = httpMod._parseHTTPRequest(rawReq);
check(1, "parseHTTPRequest: method", parsed.method, "GET");
check(2, "parseHTTPRequest: url", parsed.url, "/hello");
check(3, "parseHTTPRequest: version", parsed.httpVersion, "HTTP/1.1");
check(4, "parseHTTPRequest: host header", parsed.headers.get("host"), "localhost:3000");
check(5, "parseHTTPRequest: body empty", parsed.body, "");

// Test 6-8: POST with body
var rawPost = "POST /data HTTP/1.1" + CRLF +
    "Content-Length: 13" + CRLF +
    "Content-Type: application/json" + CRLF +
    CRLF +
    '{"key":"val"}';

var parsedPost = httpMod._parseHTTPRequest(rawPost);
check(6, "parseHTTPRequest POST: method", parsedPost.method, "POST");
check(7, "parseHTTPRequest POST: body", parsedPost.body, '{"key":"val"}');
check(8, "parseHTTPRequest POST: content-type", parsedPost.headers.get("content-type"), "application/json");

// Test 9: incomplete request returns null
var incomplete = "GET /foo HTTP/1.1" + CRLF + "Host: x";
check(9, "parseHTTPRequest: incomplete returns null", httpMod._parseHTTPRequest(incomplete), null);

// Test 10-11: _serializeResponse
var testResp = new Response("Hello World", { status: 200, headers: { "X-Custom": "test" } });
var serialized = httpMod._serializeResponse(testResp, false);
checkTruthy(10, "serializeResponse: starts with HTTP/1.1 200", serialized.indexOf("HTTP/1.1 200 OK") === 0);
checkTruthy(11, "serializeResponse: contains custom header", serialized.indexOf("x-custom: test") !== -1);

// Test 12: serializeResponse includes Content-Length
checkTruthy(12, "serializeResponse: has Content-Length", serialized.indexOf("Content-Length: 11") !== -1);

// Test 13: serializeResponse includes body
checkTruthy(13, "serializeResponse: body at end", serialized.indexOf("Hello World") !== -1);

// Test 14: serializeResponse Connection: close
checkTruthy(14, "serializeResponse: Connection close", serialized.indexOf("Connection: close") !== -1);

// Test 15: serializeResponse Connection: keep-alive
var serializedKA = httpMod._serializeResponse(testResp, true);
checkTruthy(15, "serializeResponse: Connection keep-alive", serializedKA.indexOf("Connection: keep-alive") !== -1);

// Test 16: STATUS_CODES
check(16, "STATUS_CODES[200]", httpMod.STATUS_CODES[200], "OK");
check(17, "STATUS_CODES[404]", httpMod.STATUS_CODES[404], "Not Found");
check(18, "STATUS_CODES[500]", httpMod.STATUS_CODES[500], "Internal Server Error");

// ─── Server creation tests ──────────────────────────────────────────────────

// Test 19: Server constructor
var srv = Bun.serve({
    port: 0,  // OS picks a free port
    fetch: function(req) {
        return new Response("test");
    }
});
checkTruthy(19, "Server: port assigned", srv.port > 0);
checkTruthy(20, "Server: running", srv._running);

// Test 21-23: Basic GET request via loopback
// Step 1: Client connects and sends request (goes into kernel backlog)
var clientHandle = rawHTTPRequest(srv.port, "GET", "/", null, null);
checkTruthy(21, "Client: connected to server", clientHandle !== null && clientHandle > 0);

// Step 2: Server accepts and handles the connection
srv._handleOne();

// Step 3: Client reads response
var rawResp = readResponse(clientHandle);
var resp = parseRawResponse(rawResp);
check(22, "GET /: status 200", resp.status, 200);
check(23, "GET /: body 'test'", resp.body, "test");

// Test 24-26: POST request with body
var srv2 = Bun.serve({
    port: 0,
    fetch: function(req) {
        // Echo the method and a static body
        return new Response("method=" + req.method, { status: 200 });
    }
});

var postHandle = rawHTTPRequest(srv2.port, "POST", "/submit", { "Content-Type": "text/plain" }, "hello");
checkTruthy(24, "POST client: connected", postHandle > 0);
srv2._handleOne();
var postResp = parseRawResponse(readResponse(postHandle));
check(25, "POST /submit: status 200", postResp.status, 200);
check(26, "POST /submit: body echoes method", postResp.body, "method=POST");
srv2.stop();

// Test 27-29: Different paths routing
var srv3 = Bun.serve({
    port: 0,
    fetch: function(req) {
        var url = new URL(req.url);
        if (url.pathname === "/hello") {
            return new Response("Hello!", { status: 200 });
        }
        if (url.pathname === "/json") {
            return Response.json({ message: "ok" });
        }
        return new Response("Not Found", { status: 404 });
    }
});

var h1 = rawHTTPRequest(srv3.port, "GET", "/hello", null, null);
srv3._handleOne();
var r1 = parseRawResponse(readResponse(h1));
check(27, "GET /hello: body", r1.body, "Hello!");

var h2 = rawHTTPRequest(srv3.port, "GET", "/json", null, null);
srv3._handleOne();
var r2 = parseRawResponse(readResponse(h2));
check(28, "GET /json: status 200", r2.status, 200);
checkTruthy(29, "GET /json: body contains message", r2.body.indexOf('"message"') !== -1);

// Test 30: 404 for unknown route
var h3 = rawHTTPRequest(srv3.port, "GET", "/unknown", null, null);
srv3._handleOne();
var r3 = parseRawResponse(readResponse(h3));
check(30, "GET /unknown: status 404", r3.status, 404);
srv3.stop();

// Test 31-33: Custom response headers
var srv4 = Bun.serve({
    port: 0,
    fetch: function(req) {
        return new Response("ok", {
            status: 200,
            headers: {
                "X-Request-Id": "abc123",
                "X-Powered-By": "js_engine"
            }
        });
    }
});

var h4 = rawHTTPRequest(srv4.port, "GET", "/", null, null);
srv4._handleOne();
var r4 = parseRawResponse(readResponse(h4));
check(31, "Custom header: status 200", r4.status, 200);
check(32, "Custom header: X-Request-Id", r4.headers["x-request-id"], "abc123");
check(33, "Custom header: X-Powered-By", r4.headers["x-powered-by"], "js_engine");
srv4.stop();

// Test 34-36: Error handler
var srv5 = Bun.serve({
    port: 0,
    fetch: function(req) {
        throw new Error("intentional error");
    },
    error: function(err) {
        return new Response("Error: " + err.message, { status: 500 });
    }
});

var h5 = rawHTTPRequest(srv5.port, "GET", "/", null, null);
srv5._handleOne();
var r5 = parseRawResponse(readResponse(h5));
check(34, "Error handler: status 500", r5.status, 500);
checkTruthy(35, "Error handler: body contains error", r5.body.indexOf("intentional error") !== -1);
srv5.stop();

// Test 36: Error without handler gives 500
var srv6 = Bun.serve({
    port: 0,
    fetch: function(req) {
        throw new Error("crash");
    }
});

var h6 = rawHTTPRequest(srv6.port, "GET", "/", null, null);
srv6._handleOne();
var r6 = parseRawResponse(readResponse(h6));
check(36, "Default error: status 500", r6.status, 500);
srv6.stop();

// Test 37-38: Response.json() static
var srv7 = Bun.serve({
    port: 0,
    fetch: function(req) {
        return Response.json({ items: [1, 2, 3], count: 3 });
    }
});

var h7 = rawHTTPRequest(srv7.port, "GET", "/api", null, null);
srv7._handleOne();
var r7 = parseRawResponse(readResponse(h7));
check(37, "Response.json: status 200", r7.status, 200);
var jsonBody = JSON.parse(r7.body);
check(38, "Response.json: count field", jsonBody.count, 3);
srv7.stop();

// Test 39-40: Response with no body (204)
var srv8 = Bun.serve({
    port: 0,
    fetch: function(req) {
        return new Response(null, { status: 204 });
    }
});

var h8 = rawHTTPRequest(srv8.port, "GET", "/", null, null);
srv8._handleOne();
var r8 = parseRawResponse(readResponse(h8));
check(39, "204: status", r8.status, 204);
check(40, "204: empty body", r8.body, "");
srv8.stop();

// Test 41: Server.port reports correct port
var srv9 = Bun.serve({ port: 0, fetch: function(req) { return new Response("ok"); } });
checkTruthy(41, "Server.port > 1024 (ephemeral)", srv9.port > 1024);
srv9.stop();

// Test 42-43: Bun.serve requires fetch handler
var threw = false;
try {
    Bun.serve({ port: 0 });
} catch (e) {
    threw = true;
}
check(42, "Bun.serve without fetch throws", threw, true);

threw = false;
try {
    Bun.serve({ port: 0, fetch: "not a function" });
} catch (e) {
    threw = true;
}
check(43, "Bun.serve with non-function fetch throws", threw, true);

// Test 44-45: handleN serves exactly N requests
var srv10 = Bun.serve({
    port: 0,
    fetch: function(req) { return new Response("handled"); }
});

var clients = [];
clients.push(rawHTTPRequest(srv10.port, "GET", "/1", null, null));
clients.push(rawHTTPRequest(srv10.port, "GET", "/2", null, null));
clients.push(rawHTTPRequest(srv10.port, "GET", "/3", null, null));

var handled = srv10.handleN(3);
check(44, "handleN(3): returned 3", handled, 3);

var allOk = true;
var ci = 0;
while (ci < clients.length) {
    var cr = parseRawResponse(readResponse(clients[ci]));
    if (!cr || cr.status !== 200 || cr.body !== "handled") {
        allOk = false;
    }
    ci = ci + 1;
}
check(45, "handleN(3): all responses correct", allOk, true);
srv10.stop();

// Test 46: server.stop() prevents further accepts
check(46, "Server.stop: _running is false", srv10._running, false);

// Test 47-48: createServer (Node.js compat)
var nodeSrv = httpMod.createServer(function(req, res) {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("Hello from Node compat");
});
nodeSrv.listen(0);
checkTruthy(47, "createServer: listening", nodeSrv._listening);
checkTruthy(48, "createServer: port assigned", nodeSrv.port > 0);

var nh1 = rawHTTPRequest(nodeSrv.port, "GET", "/", null, null);
nodeSrv.handleN(1);
var nr1 = parseRawResponse(readResponse(nh1));
check(49, "createServer GET: status 200", nr1.status, 200);
check(50, "createServer GET: body", nr1.body, "Hello from Node compat");
nodeSrv.close();

// ── Cleanup: stop first server ──────────────────────────────────────────────
srv.stop();

// ── Summary ─────────────────────────────────────────────────────────────────

console.log("=== HTTP Server tests: " + _passed + " passed, " + _failed + " failed ===");
if (_failed > 0) { process.exit(1); }
