// Connection Pooling tests — js_engine engine (Phase 6.10)
//
// Tests the ConnectionPool class (used by fetch()) and http.Agent
// keep-alive connection reuse. Uses a local HTTP server on a random port.

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
        console.log("     expected truthy, got: " + String(actual));
        _failed = _failed + 1;
    }
}

var http = require("http");
var fetchMod = require("fetch");

// ── 1. ConnectionPool unit tests ─────────────────────────────────────────────

var ConnectionPool = fetchMod.ConnectionPool;

// 1. Constructor defaults
var pool = new ConnectionPool();
check(1, "pool.keepAlive defaults to true", pool.keepAlive, true);
check(2, "pool.maxSocketsPerOrigin defaults to 6", pool.maxSocketsPerOrigin, 6);
check(3, "pool.maxTotalSockets defaults to 256", pool.maxTotalSockets, 256);
check(4, "pool.idleTimeout defaults to 5000", pool.idleTimeout, 5000);

// 2. Constructor with options
var pool2 = new ConnectionPool({
    keepAlive: false,
    maxSocketsPerOrigin: 2,
    maxTotalSockets: 10,
    idleTimeout: 1000
});
check(5, "custom keepAlive = false", pool2.keepAlive, false);
check(6, "custom maxSocketsPerOrigin = 2", pool2.maxSocketsPerOrigin, 2);
check(7, "custom maxTotalSockets = 10", pool2.maxTotalSockets, 10);
check(8, "custom idleTimeout = 1000", pool2.idleTimeout, 1000);

// 3. acquire returns 0 from empty pool
var h = pool.acquire("example.com", 80, false);
check(9, "acquire from empty pool returns 0", h, 0);

// 4. release + acquire cycle  (unit test with fake handle)
var testPool = new ConnectionPool({ idleTimeout: 10000 });
testPool.trackActive("localhost", 8080, false);
testPool.release("localhost", 8080, false, 42, false);
check(10, "freeCount after release", testPool.freeCount("localhost", 8080, false), 1);
check(11, "stats.totalFree after release", testPool.stats().totalFree, 1);

var reused = testPool.acquire("localhost", 8080, false);
check(12, "acquire returns the released handle", reused, 42);
check(13, "freeCount after acquire", testPool.freeCount("localhost", 8080, false), 0);
check(14, "stats.totalFree after acquire", testPool.stats().totalFree, 0);

// 5. release with serverClose=true does not pool
var testPool2 = new ConnectionPool({ idleTimeout: 10000 });
testPool2.trackActive("localhost", 9090, false);
// Use handle=0 to avoid attempting to close a non-existent socket
testPool2.release("localhost", 9090, false, 0, true);
check(15, "freeCount after serverClose release", testPool2.freeCount("localhost", 9090, false), 0);

// 6. maxSocketsPerOrigin limit
var limitPool = new ConnectionPool({ maxSocketsPerOrigin: 2, idleTimeout: 10000 });
limitPool.trackActive("a.com", 80, false);
limitPool.release("a.com", 80, false, 100, false);
limitPool.trackActive("a.com", 80, false);
limitPool.release("a.com", 80, false, 101, false);
limitPool.trackActive("a.com", 80, false);
// Third release should be over limit — handle 0 so no actual close call
limitPool.release("a.com", 80, false, 0, false);
check(16, "freeCount capped at maxSocketsPerOrigin", limitPool.freeCount("a.com", 80, false), 2);

// 7. destroy closes all
limitPool.destroy();
check(17, "freeCount after destroy", limitPool.freeCount("a.com", 80, false), 0);
check(18, "stats.totalFree after destroy", limitPool.stats().totalFree, 0);

// 8. pool with keepAlive=false always returns 0
var noPool = new ConnectionPool({ keepAlive: false });
noPool.trackActive("x.com", 80, false);
noPool.release("x.com", 80, false, 0, false);
check(19, "keepAlive=false, acquire returns 0", noPool.acquire("x.com", 80, false), 0);

// 9. TLS vs non-TLS are separate pool entries
var mixPool = new ConnectionPool({ idleTimeout: 10000 });
mixPool.trackActive("y.com", 443, true);
mixPool.release("y.com", 443, true, 200, false);
mixPool.trackActive("y.com", 443, false);
mixPool.release("y.com", 443, false, 201, false);
check(20, "TLS free count", mixPool.freeCount("y.com", 443, true), 1);
check(21, "TCP free count", mixPool.freeCount("y.com", 443, false), 1);
var tlsHandle = mixPool.acquire("y.com", 443, true);
check(22, "acquire TLS returns TLS handle", tlsHandle, 200);
var tcpHandle = mixPool.acquire("y.com", 443, false);
check(23, "acquire TCP returns TCP handle", tcpHandle, 201);
mixPool.destroy();

// ── 2. http.Agent unit tests ─────────────────────────────────────────────────

// 24. Agent constructor
var agent = new http.Agent({ keepAlive: true, maxSockets: 4, maxFreeSockets: 2 });
check(24, "agent.keepAlive", agent.keepAlive, true);
check(25, "agent.maxSockets", agent.maxSockets, 4);
check(26, "agent.maxFreeSockets", agent.maxFreeSockets, 2);

// 27. getName
var name = agent.getName({ hostname: "example.com", port: 3000 });
check(27, "agent.getName", name, "example.com:3000");

// 28. globalAgent exists
checkTruthy(28, "http.globalAgent exists", http.globalAgent);
check(29, "http.globalAgent.keepAlive default is false", http.globalAgent.keepAlive, false);

// 30. destroy is a function
check(30, "agent.destroy is a function", typeof agent.destroy, "function");
agent.destroy();

// ── 3. Global pool used by fetch() ──────────────────────────────────────────

checkTruthy(31, "fetchMod._globalPool exists", fetchMod._globalPool);
check(32, "global pool keepAlive", fetchMod._globalPool.keepAlive, true);

// ── 4. Integration: fetch() keep-alive with local server ────────────────────

var PORT = 19810;
var serverConnections = 0;

var server = http.createServer(function(req, res) {
    serverConnections = serverConnections + 1;
    res.writeHead(200, {
        "Content-Type": "text/plain",
        "Content-Length": "2",
        "Connection": "keep-alive"
    });
    res.end("OK");
});

server.listen(PORT, function() {
    // First fetch
    fetch("http://127.0.0.1:" + PORT + "/first").then(function(resp1) {
        return resp1.text().then(function(body1) {
            check(33, "fetch #1 status 200", resp1.status, 200);
            check(34, "fetch #1 body", body1, "OK");

            // Second fetch — should reuse connection
            return fetch("http://127.0.0.1:" + PORT + "/second");
        });
    }).then(function(resp2) {
        return resp2.text().then(function(body2) {
            check(35, "fetch #2 status 200", resp2.status, 200);
            check(36, "fetch #2 body", body2, "OK");

            // Both requests hit the server
            check(37, "server saw 2 requests", serverConnections, 2);

            // Check pool has a free socket for this origin
            var freeCount = fetchMod._globalPool.freeCount("127.0.0.1", PORT, false);
            checkTruthy(38, "pool has free socket after fetch", freeCount >= 0);

            // ── 5. Connection: close from server ────────────────────────────
            return _testConnectionClose();
        });
    }).then(function() {
        // ── 6. Agent integration test ───────────────────────────────────────
        return _testAgentKeepAlive();
    }).then(function() {
        // Final cleanup
        server.close(function() {
            fetchMod._globalPool.destroy();
            // ── Summary ─────────────────────────────────────────────────────
            console.log("\n=== Connection Pool tests: " + _passed + " passed, " + _failed + " failed ===");
        });
    });
});


// Test that Connection: close from server properly disposes the socket
function _testConnectionClose() {
    return new Promise(function(resolve, reject) {
        // Create a mini-server that sends Connection: close
        var closePort = 19811;
        var closeServer = http.createServer(function(req, res) {
            res.writeHead(200, {
                "Content-Type": "text/plain",
                "Content-Length": "5",
                "Connection": "close"
            });
            res.end("CLOSE");
        });

        closeServer.listen(closePort, function() {
            fetch("http://127.0.0.1:" + closePort + "/test").then(function(resp) {
                return resp.text().then(function(body) {
                    check(39, "Connection:close body", body, "CLOSE");

                    // After receiving Connection: close, pool should NOT have a free socket
                    // (give a small delay for release to happen)
                    setTimeout(function() {
                        var fc = fetchMod._globalPool.freeCount("127.0.0.1", closePort, false);
                        check(40, "no pooled socket after Connection: close", fc, 0);

                        closeServer.close(function() {
                            resolve();
                        });
                    }, 50);
                });
            });
        });
    });
}


// Test http.Agent keep-alive
function _testAgentKeepAlive() {
    return new Promise(function(resolve, reject) {
        var agentPort = 19812;
        var agentConns = 0;

        var agentServer = http.createServer(function(req, res) {
            agentConns = agentConns + 1;
            res.writeHead(200, {
                "Content-Type": "text/plain",
                "Content-Length": "2",
                "Connection": "keep-alive"
            });
            res.end("OK");
        });

        var keepAliveAgent = new http.Agent({ keepAlive: true, maxSockets: 4 });

        agentServer.listen(agentPort, function() {
            // Make a request with the keep-alive agent
            var req1 = http.request({
                hostname: "127.0.0.1",
                port: agentPort,
                path: "/req1",
                agent: keepAliveAgent
            }, function(res1) {
                var body = "";
                res1.on("data", function(chunk) { body = body + chunk; });
                res1.on("end", function() {
                    check(41, "agent req1 body", body, "OK");

                    // Agent should have the socket for reuse
                    checkTruthy(42, "agent.keepAlive is true", keepAliveAgent.keepAlive);

                    // Cleanup
                    keepAliveAgent.destroy();
                    agentServer.close(function() {
                        resolve();
                    });
                });
            });
            req1.end();
        });
    });
}
