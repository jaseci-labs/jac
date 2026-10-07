// test_tls_server.js — TLS server integration tests (Phase 6.14)
// Tests: tls.createServer, tls.connect, TLS handshake, data exchange,
//        ALPN, cert validation, secureConnection event, error propagation,
//        half-close (end vs close semantics)

var tls = require("tls");
var passed = 0;
var failed = 0;

function assert(cond, msg) {
    if (cond) {
        passed++;
    } else {
        failed++;
        console.log("FAIL: " + msg);
    }
}

var CERT = __dirname + "/test_cert.pem";
var KEY  = __dirname + "/test_key.pem";

// Gate: count of async test groups still pending
var pending = 6;
function finish() {
    pending--;
    if (pending === 0) {
        console.log("\n=== TLS Server tests: " + passed + " passed, " + failed + " failed ===");
        if (failed > 0) { process.exit(1); }
        process.exit(0);
    }
}

// ── T-01: tls.createServer returns Server instance ──────────────────────────
var srv = tls.createServer({ cert: CERT, key: KEY });
assert(typeof srv === "object", "T-01a createServer returns object");
assert(typeof srv.listen === "function", "T-01b has listen()");
assert(typeof srv.close === "function", "T-01c has close()");
assert(typeof srv.address === "function", "T-01d has address()");

// ── T-02: Server requires cert & key ────────────────────────────────────────
var errSrv = tls.createServer({});
errSrv.on("error", function(e) {
    assert(e.code === "ERR_TLS_CERT_KEY_REQUIRED", "T-02 createServer without cert/key emits error");
    finish();
});
errSrv.listen(0); // triggers async error

// ── T-03 through T-11: Full server lifecycle ────────────────────────────────
var serverSocket = null; // track server-side socket for close gating
var server = tls.createServer({ cert: CERT, key: KEY }, function(socket) {
    serverSocket = socket;

    // T-06: secureConnection event fires — socket is a TLSSocket
    assert(socket.encrypted === true, "T-06a socket.encrypted is true");
    assert(socket.readable === true, "T-06b socket.readable");
    assert(socket.writable === true, "T-06c socket.writable");
    assert(typeof socket.remoteAddress === "string", "T-06d remoteAddress is string");
    assert(socket.remotePort > 0, "T-06e remotePort > 0");

    // Echo server: read data and send it back
    socket.on("data", function(chunk) {
        socket.write("echo:" + chunk);
    });

    socket.on("end", function() {
        socket.end();
    });
});

server.listen(0, function() {
    var addr = server.address();

    // T-03: server.address() returns correct info
    assert(addr !== null, "T-03a address() not null while listening");
    assert(typeof addr.port === "number" && addr.port > 0, "T-03b port > 0");
    assert(addr.address === "0.0.0.0", "T-03c address is 0.0.0.0");

    // T-04: server is listening
    assert(server.listening === true, "T-04 server.listening is true");

    // T-05: connect a TLS client to the server
    var client = tls.connect({
        host: "127.0.0.1",
        port: addr.port,
        rejectUnauthorized: false
    }, function() {
        // T-05: secureConnect event
        assert(client.encrypted === true, "T-05a client.encrypted");
        assert(client.destroyed === false, "T-05b client not destroyed after connect");

        // T-07: send data and check echo
        client.write("hello");
    });

    // Collect response — use indexOf, not ===, because TLS is a stream
    // and data may arrive fragmented across multiple chunks.
    var response = "";
    var sentWorld = false;
    client.on("data", function(chunk) {
        response = response + chunk;

        if (!sentWorld && response.indexOf("echo:hello") !== -1) {
            // T-07: echo received correctly
            assert(true, "T-07 echo response received");
            sentWorld = true;

            // T-08: send second message
            client.write("world");
        }

        if (sentWorld && response.indexOf("echo:world") !== -1) {
            assert(true, "T-08 second echo received");
            client.end();
        }
    });

    client.on("close", function() {
        // T-09: client closed cleanly
        assert(client.destroyed === true, "T-09 client destroyed after close");

        // Wait for server-side socket to close before stopping the server,
        // so _connections is decremented by the "close" handler.
        function afterServerSocketClosed() {
            server.close(function() {
                assert(server.listening === false, "T-10a server stopped listening");
                assert(server.address() === null, "T-10b address() is null after close");

                // ── T-11: server.getConnections ──────────────────────────
                server.getConnections(function(err, count) {
                    assert(err === null, "T-11a getConnections no error");
                    assert(count === 0, "T-11b connections is 0 after close");
                    finish();
                });
            });
        }

        // Gate on server-side socket "close" event
        if (serverSocket && !serverSocket.destroyed) {
            serverSocket.on("close", afterServerSocketClosed);
        } else {
            afterServerSocketClosed();
        }
    });

    client.on("error", function(e) {
        console.log("FAIL: client error: " + e.message);
        failed++;
    });
});

server.on("error", function(e) {
    console.log("FAIL: server error: " + e.message);
    failed++;
    finish();
});

// ── T-12: Certificate validation failure (rejectUnauthorized: true) ─────────
(function() {
    var cvServer = tls.createServer({ cert: CERT, key: KEY }, function(socket) {
        socket.on("error", function() {}); // swallow
    });
    cvServer.listen(0, function() {
        var cvAddr = cvServer.address();
        var cvClient = tls.connect({
            host: "127.0.0.1",
            port: cvAddr.port,
            rejectUnauthorized: true
        });

        var errorFired = false;
        cvClient.on("error", function(e) {
            if (!errorFired) {
                errorFired = true;
                assert(true, "T-12a rejectUnauthorized client emits error");
                assert(e.code === "UNABLE_TO_VERIFY_LEAF_SIGNATURE",
                       "T-12b error code is UNABLE_TO_VERIFY_LEAF_SIGNATURE (got " + e.code + ")");
                assert(e.message.indexOf("unable to verify") !== -1,
                       "T-12c error message mentions verification failure");
                cvServer.close(function() { finish(); });
            }
        });

        cvClient.on("secureConnect", function() {
            assert(false, "T-12 secureConnect should not fire for rejected cert");
            cvServer.close(function() { finish(); });
        });
    });
})();

// ── T-13: ALPN negotiation ──────────────────────────────────────────────────
(function() {
    var serverAlpnOk = false;
    var alpnServer = tls.createServer({
        cert: CERT,
        key: KEY,
        ALPNProtocols: ["h2", "http/1.1"]
    }, function(socket) {
        assert(socket.alpnProtocol === "http/1.1",
               "T-13a server-side ALPN is http/1.1");
        serverAlpnOk = true;
        socket.write("ok");
        socket.end();
    });
    alpnServer.listen(0, function() {
        var aAddr = alpnServer.address();
        var alpnClient = tls.connect({
            host: "127.0.0.1",
            port: aAddr.port,
            rejectUnauthorized: false,
            ALPNProtocols: ["http/1.1"]
        }, function() {
            assert(alpnClient.alpnProtocol === "http/1.1",
                   "T-13b client-side ALPN is http/1.1");
        });

        alpnClient.on("data", function() {
            // Server sent data + ended; we can close now
            alpnClient.end();
        });

        alpnClient.on("close", function() {
            alpnServer.close(function() { finish(); });
        });

        alpnClient.on("error", function(e) {
            console.log("FAIL: T-13 ALPN client error: " + e.message);
            failed++;
            alpnServer.close(function() { finish(); });
        });
    });
})();

// ── T-14: Explicit secureConnection event (not via callback) ────────────────
(function() {
    var scServer = tls.createServer({ cert: CERT, key: KEY });

    scServer.on("secureConnection", function(socket) {
        assert(socket.encrypted === true, "T-14a secureConnection socket.encrypted");
        assert(typeof socket.write === "function", "T-14b socket has write()");
        socket.write("hello");
        socket.end();
    });

    scServer.listen(0, function() {
        var scAddr = scServer.address();
        var scClient = tls.connect({
            host: "127.0.0.1",
            port: scAddr.port,
            rejectUnauthorized: false
        });

        scClient.on("data", function(chunk) {
            // secureConnection event must have fired on server for us to get data
            assert(chunk === "hello", "T-14c server sent data via secureConnection handler");
            scClient.end();
        });

        scClient.on("close", function() {
            scServer.close(function() { finish(); });
        });

        scClient.on("error", function(e) {
            console.log("FAIL: T-14 client error: " + e.message);
            failed++;
            scServer.close(function() { finish(); });
        });
    });
})();

// ── T-15: Half-close behavior (end fires before close) ─────────────────────
(function() {
    var hcServer = tls.createServer({ cert: CERT, key: KEY }, function(socket) {
        socket.on("data", function() {
            socket.end(); // half-close from server side
        });
    });
    hcServer.listen(0, function() {
        var hcAddr = hcServer.address();
        var hcClient = tls.connect({
            host: "127.0.0.1",
            port: hcAddr.port,
            rejectUnauthorized: false
        }, function() {
            hcClient.write("ping");
        });

        var endFired = false;
        hcClient.on("end", function() {
            endFired = true;
            hcClient.end(); // complete the close
        });

        hcClient.on("close", function() {
            assert(endFired, "T-15a end fired before close");
            assert(hcClient.destroyed === true, "T-15b destroyed at close event");
            hcServer.close(function() { finish(); });
        });

        hcClient.on("error", function(e) {
            console.log("FAIL: T-15 client error: " + e.message);
            failed++;
            hcServer.close(function() { finish(); });
        });
    });
})();
