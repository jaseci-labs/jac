// node:net module tests — js_engine engine (Phase 6.7)
//
// Tests net.Socket, net.Server, net.isIP, net.createServer, net.connect.
// Uses a loopback TCP echo pattern: server accepts, echoes back, client verifies.

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

var net = require("net");
var rawNet = globalThis.__net;

/**
 * Helper: retry rawNet.tcpAccept up to 20 times with 10ms intervals.
 * Needed because listener sockets are non-blocking (O_NONBLOCK).
 */
function tryAccept(listener, cb) {
    var attempts = 0;
    function poll() {
        var h = rawNet.tcpAccept(listener);
        if (h !== 0) {
            cb(h);
        } else {
            attempts = attempts + 1;
            if (attempts < 20) {
                setTimeout(poll, 10);
            }
        }
    }
    poll();
}

// ═══════════════════════════════════════════════════════════════════════════
// Group 1 — Utility functions (synchronous, no I/O)
// ═══════════════════════════════════════════════════════════════════════════

// ── isIP ────────────────────────────────────────────────────────────────────
check(1, "isIP('127.0.0.1') === 4", net.isIP("127.0.0.1"), 4);
check(2, "isIP('::1') === 6", net.isIP("::1"), 6);
check(3, "isIP('not-ip') === 0", net.isIP("not-ip"), 0);
check(4, "isIP('') === 0", net.isIP(""), 0);
check(5, "isIPv4('192.168.1.1')", net.isIPv4("192.168.1.1"), true);
check(6, "isIPv4('::1') false", net.isIPv4("::1"), false);
check(7, "isIPv6('::1')", net.isIPv6("::1"), true);
check(8, "isIPv6('1.2.3.4') false", net.isIPv6("1.2.3.4"), false);
check(9, "isIP('0.0.0.0') === 4", net.isIP("0.0.0.0"), 4);
check(10, "isIP('255.255.255.255') === 4", net.isIP("255.255.255.255"), 4);
check(11, "isIP('999.0.0.1') === 0", net.isIP("999.0.0.1"), 0);

// ═══════════════════════════════════════════════════════════════════════════
// Group 2 — Module exports
// ═══════════════════════════════════════════════════════════════════════════

check(12, "net.Socket is a function", typeof net.Socket, "function");
check(13, "net.Server is a function", typeof net.Server, "function");
check(14, "net.createServer is a function", typeof net.createServer, "function");
check(15, "net.connect is a function", typeof net.connect, "function");
check(16, "net.createConnection is a function", typeof net.createConnection, "function");

// ═══════════════════════════════════════════════════════════════════════════
// Group 3 — Socket constructor and readyState
// ═══════════════════════════════════════════════════════════════════════════

var plainSock = new net.Socket();
check(17, "new Socket() readyState closed", plainSock.readyState, "closed");
check(18, "new Socket() readable false", plainSock.readable, false);
check(19, "new Socket() writable false", plainSock.writable, false);
check(20, "new Socket() bytesRead 0", plainSock.bytesRead, 0);
check(21, "new Socket() bytesWritten 0", plainSock.bytesWritten, 0);

// ═══════════════════════════════════════════════════════════════════════════
// Group 4 — Server: listen + address + close
// ═══════════════════════════════════════════════════════════════════════════

var listenEmitted = false;
var closeEmitted = false;
var serverAddr = null;

var server = net.createServer();
server.on("listening", function() { listenEmitted = true; });

server.listen(0, "127.0.0.1");

// Schedule checks after listen completes
setTimeout(function() {
    check(22, "listening event emitted", listenEmitted, true);

    serverAddr = server.address();
    checkTruthy(23, "server address has port", serverAddr && serverAddr.port > 0);
    check(24, "server address host", serverAddr.address, "127.0.0.1");

    // Close server
    server.on("close", function() { closeEmitted = true; });
    server.close();

    setTimeout(function() {
        check(25, "close event emitted", closeEmitted, true);
    }, 50);
}, 50);


// ═══════════════════════════════════════════════════════════════════════════
// Group 5 — Echo server: createServer + connect + data round-trip
// ═══════════════════════════════════════════════════════════════════════════

// Use net.createServer for the echo server (fully non-blocking)
var echoServer5 = net.createServer(function(sock) {
    sock.on("data", function(chunk) {
        sock.write("echo:" + chunk);
        sock.end();
    });
});

echoServer5.listen(0, "127.0.0.1");

var connectEmitted = false;
var readyEmitted = false;
var dataReceived = "";
var endEmitted = false;
var closeEmitted2 = false;
var drainEmitted = false;

setTimeout(function() {
    var echoPort = echoServer5.address().port;
    var client = net.connect({ port: echoPort, host: "127.0.0.1" }, function() {
        connectEmitted = true;
    });

    client.on("ready", function() { readyEmitted = true; });
    client.on("drain", function() { drainEmitted = true; });

    client.on("connect", function() {
        client.write("hello-net");
    });

    client.on("data", function(chunk) {
        dataReceived = dataReceived + chunk;
    });

    client.on("end", function() {
        endEmitted = true;
    });

    client.on("close", function() {
        closeEmitted2 = true;
    });

    // Check results after enough time for round-trip
    setTimeout(function() {
        check(26, "connect event emitted", connectEmitted, true);
        check(27, "ready event emitted", readyEmitted, true);
        check(28, "received echo data", dataReceived, "echo:hello-net");
        check(29, "end event emitted", endEmitted, true);
        check(30, "close event emitted", closeEmitted2, true);
        check(31, "drain event emitted", drainEmitted, true);
        checkTruthy(32, "bytesRead > 0", client.bytesRead > 0);
        checkTruthy(33, "bytesWritten > 0", client.bytesWritten > 0);
        check(34, "readyState closed after end", client.readyState, "closed");

        echoServer5.close();
    }, 500);
}, 100);


// ═══════════════════════════════════════════════════════════════════════════
// Group 6 — Socket properties after connect
// ═══════════════════════════════════════════════════════════════════════════

var echoListener2 = rawNet.tcpListen("127.0.0.1", 0, 128);
var echoPort2 = rawNet.tcpListenerPort(echoListener2);

tryAccept(echoListener2, function(ch) {
    rawNet.tcpClose(ch);
});

var propClient = net.connect({ port: echoPort2, host: "127.0.0.1" });
propClient.on("connect", function() {
    check(35, "remoteAddress after connect", propClient.remoteAddress, "127.0.0.1");
    check(36, "remotePort after connect", propClient.remotePort, echoPort2);
    check(37, "remoteFamily after connect", propClient.remoteFamily, "IPv4");
    checkTruthy(38, "localAddress defined", propClient.localAddress !== undefined);
    checkTruthy(39, "localPort > 0", propClient.localPort > 0);
    check(40, "readyState open", propClient.readyState, "open");
});

propClient.on("close", function() {
    rawNet.tcpListenerClose(echoListener2);
});


// ═══════════════════════════════════════════════════════════════════════════
// Group 7 — Socket.destroy and error events
// ═══════════════════════════════════════════════════════════════════════════

var echoListener3 = rawNet.tcpListen("127.0.0.1", 0, 128);
var echoPort3 = rawNet.tcpListenerPort(echoListener3);

tryAccept(echoListener3, function(ch) {
    // Keep connection open for a bit
    setTimeout(function() { rawNet.tcpClose(ch); }, 200);
});

var destroyCloseEmitted = false;
var destroyErrEmitted = false;

var destroyClient = net.connect({ port: echoPort3, host: "127.0.0.1" });
destroyClient.on("connect", function() {
    var err = new Error("test destroy");
    destroyClient.destroy(err);
});
destroyClient.on("error", function(e) {
    destroyErrEmitted = true;
    check(41, "destroy error message", e.message, "test destroy");
});
destroyClient.on("close", function(hadError) {
    destroyCloseEmitted = true;
    check(42, "close hadError true", hadError, true);
});

setTimeout(function() {
    check(43, "destroy emits error", destroyErrEmitted, true);
    check(44, "destroy emits close", destroyCloseEmitted, true);
    rawNet.tcpListenerClose(echoListener3);
}, 300);


// ═══════════════════════════════════════════════════════════════════════════
// Group 8 — net.createServer with connectionListener
// ═══════════════════════════════════════════════════════════════════════════

var connListenerCalled = false;
var serverEchoData = "";

var echoServer = net.createServer(function(sock) {
    connListenerCalled = true;
    sock.on("data", function(chunk) {
        sock.write("srv:" + chunk);
        sock.end();
    });
});

echoServer.listen(0, "127.0.0.1");

setTimeout(function() {
    var srvPort = echoServer.address().port;

    var c = net.connect({ port: srvPort, host: "127.0.0.1" });
    c.on("connect", function() {
        c.write("ping");
    });
    c.on("data", function(chunk) {
        serverEchoData = serverEchoData + chunk;
    });
    c.on("close", function() {
        check(45, "connectionListener called", connListenerCalled, true);
        check(46, "server echoed data", serverEchoData, "srv:ping");
        echoServer.close();
    });
}, 200);


// ═══════════════════════════════════════════════════════════════════════════
// Group 9 — setTimeout on socket
// ═══════════════════════════════════════════════════════════════════════════

var echoListener4 = rawNet.tcpListen("127.0.0.1", 0, 128);
var echoPort4 = rawNet.tcpListenerPort(echoListener4);

tryAccept(echoListener4, function(ch) {
    // Keep open — don't send, don't close. Let timeout fire.
    setTimeout(function() { rawNet.tcpClose(ch); }, 500);
});

var timeoutFired = false;
var timeoutClient = net.connect({ port: echoPort4, host: "127.0.0.1" });
timeoutClient.setTimeout(100, function() {
    timeoutFired = true;
    timeoutClient.destroy();
});

setTimeout(function() {
    check(47, "setTimeout fires timeout event", timeoutFired, true);
    rawNet.tcpListenerClose(echoListener4);
}, 400);


// ═══════════════════════════════════════════════════════════════════════════
// Group 10 — Socket.end without data
// ═══════════════════════════════════════════════════════════════════════════

var finishEmitted = false;
var endSrv = net.createServer(function(sock) {
    // Keep connection open so client can end cleanly
    setTimeout(function() { sock.destroy(); }, 200);
});
endSrv.listen(0, "127.0.0.1", function() {
    var endPort = endSrv.address().port;
    var endClient = net.connect({ port: endPort, host: "127.0.0.1" });
    endClient.on("connect", function() {
        endClient.end();
    });
    endClient.on("finish", function() {
        finishEmitted = true;
    });
    endClient.on("close", function() {
        endSrv.close();
    });

    setTimeout(function() {
        check(48, "end() emits finish", finishEmitted, true);
    }, 100);
});


// ═══════════════════════════════════════════════════════════════════════════
// Summary
// ═══════════════════════════════════════════════════════════════════════════

setTimeout(function() {
    console.log("=== node:net tests: " + _passed + " passed, " + _failed + " failed ===");
    if (_failed > 0) { process.exit(1); }
}, 3000);
