// Decompression tests — js_engine engine
var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

var net = globalThis.__net;
var CRLF = String.fromCharCode(13) + "\n";

// ── Test TCP server ─────────────────────────────────────────────────────────
var _serverHandle = 0;
var _serverPort = 0;

function startServer(cb) {
    _serverHandle = net.tcpListen("127.0.0.1", 0, 8);
    _serverPort = net.tcpListenerPort(_serverHandle);

    function acceptLoop() {
        net.tcpAcceptNb(_serverHandle, function(clientH, err) {
            if (clientH === 0) { return; }
            net.tcpReadNb(clientH, 4096, function(data) {
                var firstLine = data.split("\n")[0] || "";
                var path = firstLine.split(" ")[1] || "/";
                var response = "";

                if (path === "/plain") {
                    var body = "Hello from the test server!";
                    response = "HTTP/1.1 200 OK" + CRLF +
                               "Content-Type: text/plain" + CRLF +
                               "Content-Length: " + body.length + CRLF +
                               "Connection: close" + CRLF + CRLF + body;
                } else if (path === "/json") {
                    var jsonBody = '{"status":"ok","value":42}';
                    response = "HTTP/1.1 200 OK" + CRLF +
                               "Content-Type: application/json" + CRLF +
                               "Content-Length: " + jsonBody.length + CRLF +
                               "Connection: close" + CRLF + CRLF + jsonBody;
                } else if (path === "/empty") {
                    response = "HTTP/1.1 204 No Content" + CRLF +
                               "Connection: close" + CRLF + CRLF;
                } else if (path === "/chunked") {
                    var c1 = "Hello, ";
                    var c2 = "chunked world!";
                    var chunkedBody = c1.length.toString(16) + CRLF + c1 + CRLF +
                                     c2.length.toString(16) + CRLF + c2 + CRLF +
                                     "0" + CRLF + CRLF;
                    response = "HTTP/1.1 200 OK" + CRLF +
                               "Content-Type: text/plain" + CRLF +
                               "Transfer-Encoding: chunked" + CRLF +
                               "Connection: close" + CRLF + CRLF + chunkedBody;
                } else if (path === "/identity") {
                    var iBody = "Identity encoded body";
                    response = "HTTP/1.1 200 OK" + CRLF +
                               "Content-Type: text/plain" + CRLF +
                               "Content-Encoding: identity" + CRLF +
                               "Content-Length: " + iBody.length + CRLF +
                               "Connection: close" + CRLF + CRLF + iBody;
                } else if (path === "/large") {
                    var largeBody = "";
                    for (var i = 0; i < 200; i++) {
                        largeBody += "Line " + i + ": The quick brown fox jumps.\n";
                    }
                    response = "HTTP/1.1 200 OK" + CRLF +
                               "Content-Type: text/plain" + CRLF +
                               "Content-Length: " + largeBody.length + CRLF +
                               "Connection: close" + CRLF + CRLF + largeBody;
                } else if (path === "/redirect") {
                    response = "HTTP/1.1 302 Found" + CRLF +
                               "Location: /plain" + CRLF +
                               "Connection: close" + CRLF + CRLF;
                } else if (path === "/headers") {
                    var ae = "none";
                    var lines = data.split("\n");
                    for (var k = 0; k < lines.length; k++) {
                        var lc = lines[k].toLowerCase();
                        if (lc.indexOf("accept-encoding:") === 0) {
                            ae = lines[k].substring(16).trim();
                            break;
                        }
                    }
                    var hBody = '{"accept-encoding":"' + ae + '"}';
                    response = "HTTP/1.1 200 OK" + CRLF +
                               "Content-Type: application/json" + CRLF +
                               "Content-Length: " + hBody.length + CRLF +
                               "Connection: close" + CRLF + CRLF + hBody;
                } else if (path === "/gzip") {
                    var gzipBytes = [31,139,8,0,0,0,0,0,2,3,243,72,205,201,201,215,
                                     81,72,175,202,44,80,40,207,47,202,73,81,4,0,
                                     144,58,119,244,18,0,0,0];
                    var ghdr = "HTTP/1.1 200 OK" + CRLF +
                               "Content-Type: text/plain" + CRLF +
                               "Content-Encoding: gzip" + CRLF +
                               "Content-Length: " + gzipBytes.length + CRLF +
                               "Connection: close" + CRLF + CRLF;
                    net.tcpWrite(clientH, ghdr);
                    var gPtr = __buf.alloc(gzipBytes.length);
                    for (var gi = 0; gi < gzipBytes.length; gi++) { __buf.setByte(gPtr, gi, gzipBytes[gi]); }
                    net.tcpWriteRaw(clientH, gPtr, gzipBytes.length);
                    __buf.free(gPtr);
                    net.tcpClose(clientH);
                    return;
                } else if (path === "/gzip-json") {
                    var gjBytes = [31,139,8,0,0,0,0,0,2,3,171,86,202,207,86,178,42,
                                   41,42,77,213,81,74,204,43,46,79,45,82,178,50,49,
                                   170,5,0,35,163,255,96,23,0,0,0];
                    var gjhdr = "HTTP/1.1 200 OK" + CRLF +
                                "Content-Type: application/json" + CRLF +
                                "Content-Encoding: gzip" + CRLF +
                                "Content-Length: " + gjBytes.length + CRLF +
                                "Connection: close" + CRLF + CRLF;
                    net.tcpWrite(clientH, gjhdr);
                    var gjPtr = __buf.alloc(gjBytes.length);
                    for (var gji = 0; gji < gjBytes.length; gji++) { __buf.setByte(gjPtr, gji, gjBytes[gji]); }
                    net.tcpWriteRaw(clientH, gjPtr, gjBytes.length);
                    __buf.free(gjPtr);
                    net.tcpClose(clientH);
                    return;
                } else if (path === "/gzip-deflate") {
                    var dfBytes = [31,139,8,0,0,0,0,0,2,3,115,73,77,203,73,44,73,
                                   85,40,207,47,202,73,81,4,0,232,246,73,3,14,0,0,0];
                    var dfhdr = "HTTP/1.1 200 OK" + CRLF +
                                "Content-Type: text/plain" + CRLF +
                                "Content-Encoding: deflate" + CRLF +
                                "Content-Length: " + dfBytes.length + CRLF +
                                "Connection: close" + CRLF + CRLF;
                    net.tcpWrite(clientH, dfhdr);
                    var dfPtr = __buf.alloc(dfBytes.length);
                    for (var dfi = 0; dfi < dfBytes.length; dfi++) { __buf.setByte(dfPtr, dfi, dfBytes[dfi]); }
                    net.tcpWriteRaw(clientH, dfPtr, dfBytes.length);
                    __buf.free(dfPtr);
                    net.tcpClose(clientH);
                    return;
                } else if (path === "/gzip-chunked") {
                    var gcBytes = [31,139,8,0,0,0,0,0,2,3,243,72,205,201,201,215,
                                   81,72,175,202,44,80,40,207,47,202,73,81,4,0,
                                   144,58,119,244,18,0,0,0];
                    var gcHdr = "HTTP/1.1 200 OK" + CRLF +
                                "Content-Type: text/plain" + CRLF +
                                "Content-Encoding: gzip" + CRLF +
                                "Transfer-Encoding: chunked" + CRLF +
                                "Connection: close" + CRLF + CRLF;
                    net.tcpWrite(clientH, gcHdr);
                    net.tcpWrite(clientH, "14" + CRLF);
                    var gcPtr1 = __buf.alloc(20);
                    for (var gci = 0; gci < 20; gci++) { __buf.setByte(gcPtr1, gci, gcBytes[gci]); }
                    net.tcpWriteRaw(clientH, gcPtr1, 20);
                    __buf.free(gcPtr1);
                    net.tcpWrite(clientH, CRLF);
                    net.tcpWrite(clientH, "12" + CRLF);
                    var gcPtr2 = __buf.alloc(18);
                    for (var gci2 = 0; gci2 < 18; gci2++) { __buf.setByte(gcPtr2, gci2, gcBytes[20 + gci2]); }
                    net.tcpWriteRaw(clientH, gcPtr2, 18);
                    __buf.free(gcPtr2);
                    net.tcpWrite(clientH, CRLF);
                    net.tcpWrite(clientH, "0" + CRLF + CRLF);
                    net.tcpClose(clientH);
                    return;
                } else {
                    response = "HTTP/1.1 404 Not Found" + CRLF +
                               "Content-Length: 9" + CRLF +
                               "Connection: close" + CRLF + CRLF + "Not Found";
                }

                net.tcpWrite(clientH, response);
                net.tcpClose(clientH);
            });
            acceptLoop();
        });
    }
    acceptLoop();
    cb();
}

// ── Tests ───────────────────────────────────────────────────────────────────
function runTests() {
    var base = "http://127.0.0.1:" + _serverPort;

    // ── 1: Plain text Content-Length body ──────────────────────────────────
    fetch(base + "/plain").then(function(r) {
        return r.text();
    }).then(function(t) {
        check(1, "plain text via native reader", t, "Hello from the test server!");

        // ── 2: JSON parsing ───────────────────────────────────────────────
        return fetch(base + "/json");
    }).then(function(r) {
        return r.json();
    }).then(function(j) {
        check(2, "json status field", j.status, "ok");
        check(3, "json value field", j.value, 42);

        // ── 4: 204 No Content ─────────────────────────────────────────────
        return fetch(base + "/empty");
    }).then(function(r) {
        check(4, "204 status code", r.status, 204);
        return r.text().then(function(t) {
            check(5, "204 empty body", t, "");
            return fetch(base + "/chunked");
        });

    // ── 6: Chunked transfer encoding ──────────────────────────────────────
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        check(6, "chunked body decoded", t, "Hello, chunked world!");

        // ── 7: Identity encoding passthrough ──────────────────────────────
        return fetch(base + "/identity");
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        check(7, "identity encoding passthrough", t, "Identity encoded body");

        // ── 8: Large body (10KB+) ─────────────────────────────────────────
        return fetch(base + "/large");
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        var lines = t.split("\n");
        var lineCount = lines[lines.length - 1] === "" ? lines.length - 1 : lines.length;
        check(8, "large body line count === 200", lineCount, 200);
        check(9, "large body first line", lines[0], "Line 0: The quick brown fox jumps.");

        // ── 10: Redirect followed ─────────────────────────────────────────
        return fetch(base + "/redirect");
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        check(10, "redirect followed to /plain", t, "Hello from the test server!");

        // ── 11: Accept-Encoding header sent ───────────────────────────────
        return fetch(base + "/headers");
    }).then(function(r) {
        return r.json();
    }).then(function(j) {
        var ae = j["accept-encoding"];
        var hasGzip = ae.indexOf("gzip") >= 0;
        var hasDeflate = ae.indexOf("deflate") >= 0;
        check(11, "Accept-Encoding sent", hasGzip && hasDeflate, true);

        // ── 12: decompress:false still works ──────────────────────────────
        return fetch(base + "/plain", { decompress: false });
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        check(12, "decompress:false still works", t, "Hello from the test server!");

        // ── 13: 404 response ──────────────────────────────────────────────
        return fetch(base + "/nonexistent");
    }).then(function(r) {
        check(13, "404 status code", r.status, 404);
        return r.text();
    }).then(function(t) {
        check(14, "404 body", t, "Not Found");

        // ── 15: __zlib API availability ───────────────────────────────────
        check(15, "__zlib object exists", typeof __zlib === "object", true);
        check(16, "__zlib.open is function", typeof __zlib.open === "function", true);
        check(17, "__zlib.feed is function", typeof __zlib.feed === "function", true);
        check(18, "__zlib.close is function", typeof __zlib.close === "function", true);

        // ── 19: __zlib direct inflate of gzip bytes ───────────────────────
        var gzipBytes = [31,139,8,0,0,0,0,0,2,3,243,72,205,201,201,215,
                         81,72,175,202,44,80,40,207,47,202,73,81,4,0,
                         144,58,119,244,18,0,0,0];
        var zPtr = __buf.alloc(gzipBytes.length);
        for (var i = 0; i < gzipBytes.length; i++) { __buf.setByte(zPtr, i, gzipBytes[i]); }
        var zh = __zlib.open(31);
        var zOut = __zlib.feed(zh, zPtr, gzipBytes.length);
        __zlib.close(zh);
        __buf.free(zPtr);
        check(19, "__zlib gzip inflate", zOut, "Hello, gzip world!");

        // ── 20: binary API availability ───────────────────────────────────
        check(20, "net.tcpReadBinaryNb function", typeof net.tcpReadBinaryNb === "function", true);
        check(21, "net.tcpWriteRaw function", typeof net.tcpWriteRaw === "function", true);

        // ── 22: fetch auto-decompress gzip ────────────────────────────────
        return fetch(base + "/gzip");
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        check(22, "fetch auto-decompress gzip", t, "Hello, gzip world!");

        // ── 23: fetch auto-decompress gzip JSON ──────────────────────────
        return fetch(base + "/gzip-json");
    }).then(function(r) {
        return r.json();
    }).then(function(j) {
        check(23, "gzip JSON ok field", j.ok, true);
        check(24, "gzip JSON answer field", j.answer, 42);

        // ── 25: fetch deflate encoding ────────────────────────────────────
        return fetch(base + "/gzip-deflate");
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        check(25, "fetch deflate encoding (gzip payload)", t, "Deflate world!");

        // ── 26: fetch gzip + chunked transfer ─────────────────────────────
        return fetch(base + "/gzip-chunked");
    }).then(function(r) {
        return r.text();
    }).then(function(t) {
        check(26, "fetch gzip + chunked transfer", t, "Hello, gzip world!");

        // Done
        net.tcpListenerClose(_serverHandle);
        console.log("\n=== Decompression tests: " + _passed + " passed, " + _failed + " failed ===");
        if (_failed > 0) { process.exit(1); }
    }).catch(function(e) {
        console.log("FATAL: " + e.message);
        net.tcpListenerClose(_serverHandle);
        process.exit(1);
    });
}

startServer(runTests);
