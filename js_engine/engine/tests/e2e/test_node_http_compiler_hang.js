// Minimal repro: js_engine bytecode compiler hang (compile phase, no stdout).
// Do not add to run_reg.py — used when debugging the compiler.
// Trigger: preamble below + three separate listen() blocks (server10–12 pattern).

var http = require("http");

function check(id, desc, actual, expected) {
    if (actual !== expected) {
        console.log("FAIL " + id);
    }
}

// Preamble sized like test_node_http.js groups 1–9 (abbreviated).
var s2 = http.createServer(function(req, res) { res.end("x"); });
s2.listen(0, "127.0.0.1");
var s3 = http.createServer(function(req, res) { res.end("x"); });
s3.listen(0, "127.0.0.1", function() {
    http.get("http://127.0.0.1:" + s3.address().port + "/", function(res) {
        res.on("data", function() {});
        res.on("end", function() { s3.close(); });
    });
});
var reqCount9 = 0;
var server9 = http.createServer(function(req, res) {
    reqCount9 = reqCount9 + 1;
    res.end("r" + reqCount9);
});
server9.listen(0, "127.0.0.1", function() {
    var port = server9.address().port;
    function secondGet() {
        http.get("http://127.0.0.1:" + port + "/b", function(res2) {
            res2.on("data", function() {});
            res2.on("end", function() { server9.close(); });
        });
    }
    http.get("http://127.0.0.1:" + port + "/a", function(res) {
        res.on("data", function() {});
        res.on("end", function() { secondGet(); });
    });
});

var server10 = http.createServer(function(req, res) { res.end("ok"); });
server10.listen(0, "127.0.0.1", function() {
    var req = http.request({ hostname: "127.0.0.1", port: server10.address().port,
        path: "/", method: "GET" }, function(res) {
        res.on("data", function() {});
        res.on("end", function() { server10.close(); });
    });
    req.end();
});
var server11 = http.createServer(function(req, res) { res.writeHead(204); res.end(); });
server11.listen(0, "127.0.0.1", function() {
    http.get("http://127.0.0.1:" + server11.address().port + "/e", function(res) {
        res.on("data", function() {});
        res.on("end", function() { server11.close(); });
    });
});
var server12 = http.createServer(function(req, res) { res.end(req.url); });
server12.listen(0, "127.0.0.1", function() {
    http.get("http://127.0.0.1:" + server12.address().port + "/q", function(res) {
        res.on("data", function() {});
        res.on("end", function() { server12.close(); });
    });
});

console.log("compiled");
