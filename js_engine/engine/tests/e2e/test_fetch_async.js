// Async fetch tests — js_engine engine (Phase 6.6)
// Tests non-blocking HTTP fetch via tcpConnectNb + tcpReadNb.
//
// Design: server writes response immediately after accept (no request read),
// avoiding blocking the event loop while the async client progresses.
//
// IMPORTANT — accept queue ordering: ALL fetch() calls during sync code create
// connections in FIFO order.  Server timer callbacks must accept in the same
// order.  Redirect follow-up connects arrive LATER (not in the sync queue).
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

var net = globalThis.__net;
var serverHandle = net.tcpListen("127.0.0.1", 0, 128);
var serverPort = net.tcpListenerPort(serverHandle);
var CRLF = String.fromCharCode(13) + "\n";

function serveImmediate(statusCode, body, extraHeaders) {
    var clientH = net.tcpAccept(serverHandle);
    if (clientH === 0) { return; }
    var statusText = (statusCode === 200) ? "OK" :
                     (statusCode === 404) ? "Not Found" :
                     (statusCode === 204) ? "No Content" :
                     (statusCode === 301) ? "Moved Permanently" : "OK";
    var resp = "HTTP/1.1 " + String(statusCode) + " " + statusText + CRLF;
    if (extraHeaders) { resp = resp + extraHeaders; }
    resp = resp + "Content-Length: " + String(body.length) + CRLF;
    resp = resp + "Connection: close" + CRLF + CRLF + body;
    net.tcpWrite(clientH, resp);
    net.tcpClose(clientH);
}

// ═══════════════════════════════════════════════════════════════════════════
// Sync-issued fetches create connections in this order in the accept queue:
//   1. /test1         (test 1-2)
//   2. /missing       (test 3-5)
//   3. /empty         (test 6-7)
//   4. /big           (test 8)
//   5. /timeout-test  (test 9: abort — accepted+discarded later)
//   6. /redir         (test 10-12: redirect — initial connection)
//
// port-1 (test conn-refused) goes to a different port, not our server.
// Redirect follow-up for test 10 arrives AFTER the sync queue.
// ═══════════════════════════════════════════════════════════════════════════

// ── Test 0: Connection refused ──────────────────────────────────────────────
fetch("http://127.0.0.1:1/should-refuse").then(function() {
    check(0, "refused should reject", false, true);
}).catch(function(err) {
    check(0, "connection refused rejects", err instanceof TypeError, true);
});

// ── Test 1-2: Basic async HTTP fetch ────────────────────────────────────────
// Accept queue position: 1
setTimeout(function() { serveImmediate(200, "hello async", ""); }, 10);

fetch("http://127.0.0.1:" + String(serverPort) + "/test1").then(function(resp) {
    check(1, "async fetch status 200", resp.status, 200);
    return resp.text();
}).then(function(body) {
    check(2, "async fetch body", body, "hello async");
}).catch(function(err) {
    check(1, "async fetch error: " + String(err), false, true);
});

// ── Test 3-5: 404 status ────────────────────────────────────────────────────
// Accept queue position: 2
setTimeout(function() { serveImmediate(404, "not found", ""); }, 50);

fetch("http://127.0.0.1:" + String(serverPort) + "/missing").then(function(resp) {
    check(3, "404 status code", resp.status, 404);
    check(4, "404 ok is false", resp.ok, false);
    return resp.text();
}).then(function(body) {
    check(5, "404 body", body, "not found");
}).catch(function(err) {
    check(3, "404 error: " + String(err), false, true);
});

// ── Test 6-7: 204 No Content ────────────────────────────────────────────────
// Accept queue position: 3
setTimeout(function() { serveImmediate(204, "", ""); }, 100);

fetch("http://127.0.0.1:" + String(serverPort) + "/empty").then(function(resp) {
    check(6, "204 status", resp.status, 204);
    return resp.text();
}).then(function(body) {
    check(7, "204 empty body", body, "");
}).catch(function(err) {
    check(6, "204 error: " + String(err), false, true);
});

// ── Test 8: Large body ──────────────────────────────────────────────────────
// Accept queue position: 4
var bigBody = "";
for (var i = 0; i < 1000; i++) { bigBody = bigBody + "ABCDEFGHIJ"; }

setTimeout(function() { serveImmediate(200, bigBody, ""); }, 150);

fetch("http://127.0.0.1:" + String(serverPort) + "/big").then(function(resp) {
    return resp.text();
}).then(function(body) {
    check(8, "large body length", body.length, 10000);
}).catch(function(err) {
    check(8, "large body error: " + String(err), false, true);
});

// ── Test 9: AbortSignal.timeout ─────────────────────────────────────────────
// Accept queue position: 5 (accepted+discarded at 300ms)
fetch("http://127.0.0.1:" + String(serverPort) + "/timeout-test", {
    signal: AbortSignal.timeout(100)
}).then(function() {
    check(9, "abort should reject", false, true);
}).catch(function(err) {
    var isAbort = (err.name === "TimeoutError" || err.name === "AbortError");
    check(9, "abort timeout rejects", isAbort, true);
});

setTimeout(function() {
    var stale = net.tcpAccept(serverHandle);
    if (stale !== 0) { net.tcpClose(stale); }
}, 300);

// ── Test 10-12: Redirect (301 → 200) ───────────────────────────────────────
// Accept queue position: 6 (initial /redir connection)
// The redirect follow-up connect arrives later (NOT in the sync queue).
var redirectLoc = "http://127.0.0.1:" + String(serverPort) + "/redirected";
var redir301Hdr = "Location: " + redirectLoc + CRLF;

// Serve 301 at 400ms (accepts position 6 = /redir)
setTimeout(function() { serveImmediate(301, "", redir301Hdr); }, 400);

// Serve the redirect target at 600ms (accepts the NEW follow-up connection)
setTimeout(function() { serveImmediate(200, "redirected body", ""); }, 600);

fetch("http://127.0.0.1:" + String(serverPort) + "/redir", { redirect: "follow" }).then(function(resp) {
    check(10, "redirect: final status 200", resp.status, 200);
    check(11, "redirect: redirected flag", resp.redirected, true);
    return resp.text();
}).then(function(body) {
    check(12, "redirect: final body", body, "redirected body");
}).catch(function(err) {
    check(10, "redirect error: " + String(err), false, true);
});

// ── Cleanup ─────────────────────────────────────────────────────────────────
setTimeout(function() {
    net.tcpListenerClose(serverHandle);
    console.log("");
    console.log("=== fetch_async tests: " + String(_passed) + " passed, " + String(_failed) + " failed ===");
    if (_failed > 0) { process.exit(1); }
}, 1200);
