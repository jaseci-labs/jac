// test_streaming.js — Phase 6.11: Streaming Response Bodies
// Tests ReadableStream API, Response.body, getReader(), async iteration,
// backpressure, and fetch() with streaming bodies.
//
// Uses a local TCP server for network-based tests (same pattern as
// test_fetch_async.js).  Unit tests run without a network.
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

var net  = globalThis.__net;
var CRLF = String.fromCharCode(13) + "\n";

// ── 1: ReadableStream constructor & lock ──────────────────────────────────────

// S-01: ReadableStream constructor
var rs1 = new ReadableStream();
check("S-01", "ReadableStream is an object", typeof rs1, "object");

// S-02: locked starts false
check("S-02", "locked is false initially", rs1.locked, false);

// S-03: getReader() returns a reader
var reader1 = rs1.getReader();
check("S-03", "getReader returns object", typeof reader1, "object");

// S-04: stream is locked after acquiring reader
check("S-04", "stream locked after getReader", rs1.locked, true);

// S-05: second getReader throws
var threw5 = false;
try { rs1.getReader(); } catch(e) { threw5 = true; }
check("S-05", "second getReader throws", threw5, true);

// S-06: releaseLock unlocks the stream
reader1.releaseLock();
check("S-06", "releaseLock unlocks stream", rs1.locked, false);

// ── 2: enqueue + read ─────────────────────────────────────────────────────────

// S-07 / S-08 / S-09: read() from pre-filled stream
var rs2 = new ReadableStream({
    start: function(ctrl) {
        ctrl.enqueue("hello");
        ctrl.enqueue("world");
        ctrl.close();
    }
});

var chunks7 = [];
var reader2 = rs2.getReader();

function pump7(done7) {
    reader2.read().then(function(r) {
        if (r.done) { done7(); return; }
        chunks7.push(r.value);
        pump7(done7);
    });
}

setTimeout(function() {
    check("S-07", "first chunk is hello", chunks7[0], "hello");
    check("S-08", "second chunk is world", chunks7[1], "world");
    check("S-09", "exactly two chunks", chunks7.length, 2);
}, 20);

pump7(function() {
    check("S-07b", "pump7 completed", true, true);
});

// ── 3: close signals done ─────────────────────────────────────────────────────

// S-10: done=true after close
var ctrl3;
var rs3b = new ReadableStream({
    start: function(c) { ctrl3 = c; }
});
var reader3b = rs3b.getReader();

reader3b.read().then(function(r) {
    check("S-10", "done=true after close", r.done, true);
});

setTimeout(function() { ctrl3.close(); }, 5);

// ── 4: error propagates ───────────────────────────────────────────────────────

// S-11: error rejects read()
var rs4ctrl;
var rs4 = new ReadableStream({ start: function(c) { rs4ctrl = c; } });
var reader4 = rs4.getReader();

reader4.read().then(null, function(e) {
    check("S-11", "error rejects read", e.message, "oops");
});

setTimeout(function() { rs4ctrl.error(new Error("oops")); }, 5);

// ── 5: _drainStream helper ────────────────────────────────────────────────────

// S-12: test via Response.text() on a streaming body
var rs12 = new ReadableStream({
    start: function(ctrl) {
        ctrl.enqueue("foo");
        ctrl.enqueue("bar");
        ctrl.enqueue("baz");
        ctrl.close();
    }
});
new Response(rs12, { status: 200 }).text().then(function(txt) {
    check("S-12", "_drainStream via text() concatenates", txt, "foobarbaz");
});

// ── 6: Response.body getter ───────────────────────────────────────────────────

// S-13: Response.body for string body returns ReadableStream
var resp13 = new Response("hello body");
var body13 = resp13.body;
check("S-13", "Response.body is ReadableStream", body13 instanceof ReadableStream, true);

// S-14 / S-15: reading the body reader
var reader13 = body13.getReader();
reader13.read().then(function(r) {
    check("S-14", "body reader yields string", r.value, "hello body");
    return reader13.read();
}).then(function(r) {
    check("S-15", "body reader done after string", r.done, true);
});

// S-16 / S-17: bodyUsed flag
var resp16 = new Response("data");
check("S-16", "bodyUsed starts false", resp16.bodyUsed, false);

resp16.text().then(function() {
    check("S-17", "bodyUsed true after text()", resp16.bodyUsed, true);
});

// S-18: text() drains streaming body
var rs18 = new ReadableStream({
    start: function(ctrl) {
        ctrl.enqueue("part1,");
        ctrl.enqueue("part2");
        ctrl.close();
    }
});
new Response(rs18, { status: 200 }).text().then(function(txt) {
    check("S-18", "text() drains stream", txt, "part1,part2");
});

// S-19: json() parses streaming body
var rs19 = new ReadableStream({
    start: function(ctrl) {
        ctrl.enqueue('{"x":42}');
        ctrl.close();
    }
});
new Response(rs19, { status: 200 }).json().then(function(obj) {
    check("S-19", "json() parses stream contents", obj.x, 42);
});

// S-20 / S-21: clone() on string-body Response
var resp20 = new Response("clone me", { status: 201 });
var clone20 = resp20.clone();
clone20.text().then(function(txt) {
    check("S-20", "clone text equals original", txt, "clone me");
    check("S-21", "clone status matches", clone20.status, 201);
});

// ── 7: async iteration ────────────────────────────────────────────────────────

// S-22: Symbol.asyncIterator exists on ReadableStream instances
var _rs22 = new ReadableStream();
check("S-22", "ReadableStream instance has asyncIterator", typeof _rs22[Symbol.asyncIterator], "function");

// S-23: for-await yields all chunks
async function test23() {
    var parts = [];
    var rs = new ReadableStream({
        start: function(ctrl) {
            ctrl.enqueue("a"); ctrl.enqueue("b"); ctrl.enqueue("c"); ctrl.close();
        }
    });
    for await (var chunk of rs) { parts.push(chunk); }
    check("S-23", "for-await yields all chunks", parts.join(""), "abc");
}
test23().then(null, function(e) { check("S-23-err", "for-await no error", String(e), ""); });

// ── 8: network tests via local server ─────────────────────────────────────────

var serverHandle = net.tcpListen("127.0.0.1", 0, 128);
var serverPort   = net.tcpListenerPort(serverHandle);

// Server helpers — do NOT call tcpRead before responding; the client's
// tcpWrite fires in a tcpConnectNb callback *after* timers, so reading
// here would deadlock the event loop.  Mirror the pattern from test_fetch_async.js.
function serveOnce(statusCode, body, extraHeaders) {
    var clientH = net.tcpAccept(serverHandle);
    if (clientH === 0) { return; }
    var resp = "HTTP/1.1 " + String(statusCode) + " OK" + CRLF;
    if (extraHeaders) { resp = resp + extraHeaders; }
    resp = resp + "Content-Length: " + String(body.length) + CRLF;
    resp = resp + "Connection: close" + CRLF + CRLF + body;
    net.tcpWrite(clientH, resp);
    net.tcpClose(clientH);
}

function serveChunked(chunks) {
    var clientH = net.tcpAccept(serverHandle);
    if (clientH === 0) { return; }
    var hdr = "HTTP/1.1 200 OK" + CRLF;
    hdr = hdr + "Transfer-Encoding: chunked" + CRLF;
    hdr = hdr + "Connection: close" + CRLF + CRLF;
    net.tcpWrite(clientH, hdr);
    var i = 0;
    while (i < chunks.length) {
        var c = chunks[i];
        net.tcpWrite(clientH, c.length.toString(16) + CRLF + c + CRLF);
        i = i + 1;
    }
    net.tcpWrite(clientH, "0" + CRLF + CRLF);
    net.tcpClose(clientH);
}

// S-24 / S-25: fetch() response.body is a ReadableStream, text() reads it
setTimeout(function() { serveOnce(200, "stream-me"); }, 0);

fetch("http://127.0.0.1:" + String(serverPort) + "/s24").then(function(r) {
    check("S-24", "fetch response.body is ReadableStream", r.body instanceof ReadableStream, true);
    return r.text();
}).then(function(txt) {
    check("S-25", "fetch text() reads body correctly", txt, "stream-me");
});

// S-26: getReader() pump on a self-contained ReadableStream
var rs26 = new ReadableStream({
    start: function(ctrl) {
        ctrl.enqueue("incremental-");
        ctrl.enqueue("body");
        ctrl.close();
    }
});
var reader26 = rs26.getReader();
var parts26  = [];
function pump26(done26) {
    reader26.read().then(function(res) {
        if (res.done) { reader26.releaseLock(); done26(parts26.join("")); return; }
        parts26.push(res.value);
        pump26(done26);
    });
}
pump26(function(txt) {
    check("S-26", "getReader pump concatenates chunks", txt, "incremental-body");
});

// S-26b: network-based getReader pump
setTimeout(function() { serveOnce(200, "net-reader-body"); }, 0);

fetch("http://127.0.0.1:" + String(serverPort) + "/s26b").then(function(r) {
    check("S-26b-is-stream", "fetch body is ReadableStream", r.body instanceof ReadableStream, true);
    var reader26b = r.body.getReader();
    var parts26b  = [];
    function pump26b() {
        return reader26b.read().then(function(res) {
            if (res.done) { reader26b.releaseLock(); return parts26b.join(""); }
            parts26b.push(res.value);
            return pump26b();
        });
    }
    return pump26b();
}).then(function(txt) {
    check("S-26b", "network getReader pump reads full body", txt, "net-reader-body");
});

// S-27: chunked transfer-encoding via text()
setTimeout(function() { serveChunked(["hello", " ", "world"]); }, 0);

fetch("http://127.0.0.1:" + String(serverPort) + "/s27").then(function(r) {
    return r.text();
}).then(function(txt) {
    check("S-27", "chunked body text() works", txt, "hello world");
});

// S-28: fetch POST with ReadableStream body
var reqStream28 = new ReadableStream({
    start: function(ctrl) { ctrl.enqueue("posted content"); ctrl.close(); }
});
setTimeout(function() { serveOnce(200, "ok"); }, 0);

fetch("http://127.0.0.1:" + String(serverPort) + "/s28", {
    method:  "POST",
    body:    reqStream28,
    headers: { "Content-Type": "text/plain" }
}).then(function(r) {
    return r.text();
}).then(function(txt) {
    check("S-28", "POST with ReadableStream body => 200", txt, "ok");
});

// ── Summary ───────────────────────────────────────────────────────────────────

setTimeout(function() {
    net.tcpClose(serverHandle);
    console.log("\n=== Streaming tests: " + _passed + " passed, " + _failed + " failed ===");
}, 500);
