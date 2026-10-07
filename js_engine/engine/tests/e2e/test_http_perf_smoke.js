// Non-functional smoke: 100 keep-alive GETs to local server (perf gate)
var http = require("http");

var _passed = 0;
var _failed = 0;
var TARGET = 100;
var MAX_MS = 30000;

function check(desc, cond) {
    if (cond) {
        console.log("OK  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + desc);
        _failed = _failed + 1;
    }
}

var server = http.createServer(function(req, res) {
    res.writeHead(200);
    res.end("pong");
});

var t0 = Date.now();
var finished = false;
server.listen(0, "127.0.0.1", function() {
    var port = server.address().port;
    var agent = new http.Agent({ keepAlive: true, maxSockets: 4 });
    var done = 0;
    var errors = 0;

    function next(i) {
        if (i >= TARGET) {
            finished = true;
            var elapsed = Date.now() - t0;
            check("completed " + TARGET + " requests", done === TARGET);
            check("no errors", errors === 0);
            check("under " + MAX_MS + "ms", elapsed < MAX_MS);
            agent.destroy();
            server.close();
            console.log("=== " + _passed + " passed, " + _failed + " failed ===");
            if (_failed > 0) { process.exit(1); }
            return;
        }
        var req = http.request({
            hostname: "127.0.0.1",
            port: port,
            path: "/",
            agent: agent
        }, function(res) {
            res.on("data", function() {});
            res.on("end", function() {
                done = done + 1;
                next(i + 1);
            });
        });
        req.on("error", function() {
            errors = errors + 1;
            next(i + 1);
        });
        req.end();
    }
    next(0);
});

setTimeout(function() {
    if (finished) { return; }
    console.log("FAIL perf smoke timeout");
    _failed = _failed + 1;
    console.log("=== " + _passed + " passed, " + _failed + " failed ===");
    server.close();
    process.exit(1);
}, MAX_MS + 2000);
