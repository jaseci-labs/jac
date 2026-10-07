// node:tls module tests — js_engine engine (Phase 6.7)
//
// Tests tls.TLSSocket, tls.connect, constants, stubs.
// Uses HTTPS connections to public servers for TLS handshake verification.

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

var tls = require("tls");

// ═══════════════════════════════════════════════════════════════════════════
// Group 1 — Module exports and constants
// ═══════════════════════════════════════════════════════════════════════════

check(1, "tls.TLSSocket is a function", typeof tls.TLSSocket, "function");
check(2, "tls.connect is a function", typeof tls.connect, "function");
check(3, "tls.createSecureContext is a function", typeof tls.createSecureContext, "function");
check(4, "tls.createServer is a function", typeof tls.createServer, "function");
check(5, "DEFAULT_MIN_VERSION", tls.DEFAULT_MIN_VERSION, "TLSv1.2");
check(6, "DEFAULT_MAX_VERSION", tls.DEFAULT_MAX_VERSION, "TLSv1.3");
check(7, "rootCertificates is array", Array.isArray(tls.rootCertificates), true);

// ═══════════════════════════════════════════════════════════════════════════
// Group 2 — TLSSocket constructor
// ═══════════════════════════════════════════════════════════════════════════

var sock = new tls.TLSSocket(null, { servername: "example.com" });
check(8, "new TLSSocket encrypted", sock.encrypted, true);
check(9, "new TLSSocket authorized false", sock.authorized, false);
check(10, "new TLSSocket readyState closed", sock.readyState, "closed");
check(11, "new TLSSocket bytesRead 0", sock.bytesRead, 0);
check(12, "new TLSSocket bytesWritten 0", sock.bytesWritten, 0);
check(13, "new TLSSocket readable", sock.readable, true);
check(14, "new TLSSocket writable", sock.writable, true);

// ═══════════════════════════════════════════════════════════════════════════
// Group 3 — Stub methods
// ═══════════════════════════════════════════════════════════════════════════

var peerCert = sock.getPeerCertificate();
check(15, "getPeerCertificate returns object", typeof peerCert, "object");

var cipher = sock.getCipher();
check(16, "getCipher returns object", typeof cipher, "object");
checkTruthy(17, "getCipher has name", cipher.name !== undefined);
checkTruthy(18, "getCipher has version", cipher.version !== undefined);

var proto = sock.getProtocol();
check(19, "getProtocol returns string", typeof proto, "string");

// ═══════════════════════════════════════════════════════════════════════════
// Group 4 — createSecureContext (stub)
// ═══════════════════════════════════════════════════════════════════════════

var ctx = tls.createSecureContext({ minVersion: "TLSv1.2" });
check(20, "createSecureContext returns object", typeof ctx, "object");
checkTruthy(21, "context has options", ctx.options !== undefined);

// ═══════════════════════════════════════════════════════════════════════════
// Group 5 — createServer returns a Server instance
// ═══════════════════════════════════════════════════════════════════════════

var srv = tls.createServer();
check(22, "createServer returns object", typeof srv, "object");

// ═══════════════════════════════════════════════════════════════════════════
// Group 6 — tls.connect to real HTTPS server
// ═══════════════════════════════════════════════════════════════════════════

var secureConnectEmitted = false;
var connectEmitted = false;
var readyEmitted = false;
var tlsDataReceived = "";
var tlsCloseEmitted = false;

var tlsSock = tls.connect({ host: "example.com", port: 443, servername: "example.com" });

tlsSock.on("secureConnect", function() {
    secureConnectEmitted = true;

    // Check post-handshake properties
    check(23, "authorized true after handshake", tlsSock.authorized, true);
    check(24, "encrypted true", tlsSock.encrypted, true);
    checkTruthy(25, "remoteAddress set", tlsSock.remoteAddress !== undefined);
    check(26, "remotePort 443", tlsSock.remotePort, 443);

    // Send an HTTP request over TLS
    var CRLF = String.fromCharCode(13) + "\n";
    tlsSock.write("GET / HTTP/1.1" + CRLF + "Host: example.com" + CRLF + "Connection: close" + CRLF + CRLF);
});

tlsSock.on("connect", function() {
    connectEmitted = true;
});

tlsSock.on("ready", function() {
    readyEmitted = true;
});

tlsSock.on("data", function(chunk) {
    tlsDataReceived = tlsDataReceived + chunk;
});

tlsSock.on("close", function() {
    tlsCloseEmitted = true;
});

// Check results after handshake + HTTP round-trip
setTimeout(function() {
    check(27, "secureConnect emitted", secureConnectEmitted, true);
    check(28, "connect emitted", connectEmitted, true);
    check(29, "ready emitted", readyEmitted, true);
    checkTruthy(30, "received TLS data", tlsDataReceived.length > 0);

    // Verify the HTTP response
    var hasHTTP = tlsDataReceived.indexOf("HTTP/1.1") >= 0;
    checkTruthy(31, "response contains HTTP/1.1", hasHTTP);

    var hasHTML = tlsDataReceived.indexOf("</html>") >= 0 || tlsDataReceived.indexOf("</HTML>") >= 0;
    checkTruthy(32, "response contains HTML", hasHTML);

    // Socket should eventually close (Connection: close)
    // Give it a bit more time if not yet closed
    setTimeout(function() {
        check(33, "TLS close event emitted", tlsCloseEmitted, true);
        checkTruthy(34, "TLS bytesRead > 0", tlsSock.bytesRead > 0);
        checkTruthy(35, "TLS bytesWritten > 0", tlsSock.bytesWritten > 0);
    }, 500);
}, 3000);


// ═══════════════════════════════════════════════════════════════════════════
// Group 7 — tls.connect connection refused
// ═══════════════════════════════════════════════════════════════════════════

var refusedErrEmitted = false;
var refusedCloseEmitted = false;

var refSock = tls.connect({ host: "127.0.0.1", port: 1, servername: "localhost" });
refSock.on("error", function(err) {
    refusedErrEmitted = true;
});
refSock.on("close", function(hadError) {
    refusedCloseEmitted = true;
    check(36, "refused close hadError true", hadError, true);
});

setTimeout(function() {
    check(37, "refused error emitted", refusedErrEmitted, true);
    check(38, "refused close emitted", refusedCloseEmitted, true);
}, 1000);


// ═══════════════════════════════════════════════════════════════════════════
// Group 8 — TLSSocket.setTimeout
// ═══════════════════════════════════════════════════════════════════════════

// We can test the timeout mechanism on a socket that hasn't connected
var timeoutSock = new tls.TLSSocket(null, {});
var timeoutFiredCount = 0;

// setTimeout should not crash even on unconnected socket
timeoutSock.setTimeout(100, function() {
    timeoutFiredCount = timeoutFiredCount + 1;
});
// Clearing timeout should work
timeoutSock.setTimeout(0);
check(39, "setTimeout(0) clears timeout", timeoutSock._timeoutMs, 0);

// ═══════════════════════════════════════════════════════════════════════════
// Group 9 — TLSSocket methods (pause/resume/setEncoding/ref/unref)
// ═══════════════════════════════════════════════════════════════════════════

var methodSock = new tls.TLSSocket(null, {});
check(40, "pause returns this", methodSock.pause() === methodSock, true);
check(41, "resume returns this", methodSock.resume() === methodSock, true);
check(42, "setEncoding returns this", methodSock.setEncoding() === methodSock, true);
check(43, "ref returns this", methodSock.ref() === methodSock, true);
check(44, "unref returns this", methodSock.unref() === methodSock, true);

var addr = methodSock.address();
check(45, "address returns object", typeof addr, "object");


// ═══════════════════════════════════════════════════════════════════════════
// Summary
// ═══════════════════════════════════════════════════════════════════════════

setTimeout(function() {
    console.log("=== node:tls tests: " + _passed + " passed, " + _failed + " failed ===");
    if (_failed > 0) { process.exit(1); }
}, 5000);
