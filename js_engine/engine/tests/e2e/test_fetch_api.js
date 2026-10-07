// Fetch API tests — js_engine engine
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

// ── 1: DOMException extends Error ─────────────────────────────────────────
var de1 = new DOMException("test msg", "AbortError");
check(1, "DOMException extends Error", de1 instanceof Error, true);

// ── 2: DOMException.message ───────────────────────────────────────────────
check(2, "DOMException.message", de1.message, "test msg");

// ── 3: DOMException.name ──────────────────────────────────────────────────
check(3, "DOMException.name", de1.name, "AbortError");

// ── 4: DOMException.code for AbortError ───────────────────────────────────
check(4, "DOMException.code = 20 for AbortError", de1.code, 20);

// ── 5: DOMException.code for TimeoutError ─────────────────────────────────
var de2 = new DOMException("timed out", "TimeoutError");
check(5, "DOMException.code = 23 for TimeoutError", de2.code, 23);

// ── 6: DOMException.code for unknown name ─────────────────────────────────
var de3 = new DOMException("custom", "CustomError");
check(6, "DOMException.code = 0 for unknown name", de3.code, 0);

// ── 7: AbortSignal.any not aborted initially ──────────────────────────────
var ac1 = new AbortController();
var ac2 = new AbortController();
var composite = AbortSignal.any([ac1.signal, ac2.signal]);
check(7, "AbortSignal.any not aborted initially", composite.aborted, false);

// ── 8: AbortSignal.any aborted after abort ────────────────────────────────
ac1.abort("reason1");
check(8, "AbortSignal.any aborted after ac1.abort", composite.aborted, true);

// ── 9: AbortSignal.any reason matches ─────────────────────────────────────
check(9, "AbortSignal.any.reason matches", composite.reason, "reason1");

// ── 10: AbortSignal.any with pre-aborted signal ──────────────────────────
var preAborted = AbortSignal.abort("already");
var comp2 = AbortSignal.any([preAborted, ac2.signal]);
check(10, "AbortSignal.any with pre-aborted signal", comp2.aborted, true);

// ── 11: Pre-aborted reason matches ────────────────────────────────────────
check(11, "pre-aborted reason matches", comp2.reason, "already");

// ── 12: signal.onabort is function ────────────────────────────────────────
var ac3 = new AbortController();
var onabortFired = false;
ac3.signal.onabort = function() { onabortFired = true; };
check(12, "onabort is function", typeof ac3.signal.onabort, "function");

// ── 13: onabort handler fires ─────────────────────────────────────────────
ac3.abort();
check(13, "onabort handler fired", onabortFired, true);

// ── 14: onabort replacement ───────────────────────────────────────────────
var ac4 = new AbortController();
var count = 0;
ac4.signal.onabort = function() { count = count + 10; };
ac4.signal.onabort = function() { count = count + 1; };
ac4.abort();
check(14, "onabort replacement: old removed, new fires once", count, 1);

// ── 15: throwIfAborted on non-aborted signal ──────────────────────────────
var ac5 = new AbortController();
var threw = false;
try { ac5.signal.throwIfAborted(); }
catch(e) { threw = true; }
check(15, "throwIfAborted on non-aborted doesn't throw", threw, false);

// ── 16: throwIfAborted on aborted signal ──────────────────────────────────
ac5.abort("stop!");
threw = false;
var threwReason = null;
try { ac5.signal.throwIfAborted(); }
catch(e) { threw = true; threwReason = e; }
check(16, "throwIfAborted on aborted signal throws", threw, true);

// ── 17: throwIfAborted reason ─────────────────────────────────────────────
check(17, "throwIfAborted reason", threwReason, "stop!");

// ── 18: Headers iterator count ────────────────────────────────────────────
var h = new Headers({"Content-Type": "text/plain", "X-Foo": "bar"});
var iterResult = [];
for (var pair of h) { iterResult.push(pair[0] + "=" + pair[1]); }
check(18, "Headers iterator yields 2 entries", iterResult.length, 2);

// ── 19: Headers iterator first entry ──────────────────────────────────────
check(19, "Headers iterator first entry", iterResult[0], "content-type=text/plain");

// ── 20: Headers iterator second entry ─────────────────────────────────────
check(20, "Headers iterator second entry", iterResult[1], "x-foo=bar");

// ── 21: getSetCookie returns array ────────────────────────────────────────
var h2 = new Headers();
h2.append("Set-Cookie", "a=1; Path=/");
h2.append("Set-Cookie", "b=2; HttpOnly");
h2.append("Content-Type", "text/html");
var cookies = h2.getSetCookie();
check(21, "getSetCookie returns array", Array.isArray(cookies), true);

// ── 22: getSetCookie returns 2 cookies ────────────────────────────────────
check(22, "getSetCookie returns 2 cookies", cookies.length, 2);

// ── 23: getSetCookie first cookie ─────────────────────────────────────────
check(23, "getSetCookie first cookie", cookies[0], "a=1; Path=/");

// ── 24: getSetCookie second cookie ────────────────────────────────────────
check(24, "getSetCookie second cookie", cookies[1], "b=2; HttpOnly");

// ── 25-57: Async tests (Response body methods, Request, static methods) ──
var r1 = new Response("hello");
r1.arrayBuffer().then(function(ab) {
    // ── 25: Response.arrayBuffer returns ArrayBuffer ──────────────────
    check(25, "arrayBuffer returns ArrayBuffer", ab instanceof ArrayBuffer, true);
    check(26, "arrayBuffer byteLength = 5", ab.byteLength, 5);
    var u8 = new Uint8Array(ab);
    check(27, "arrayBuffer first byte is 'h' (104)", u8[0], 104);
    check(28, "arrayBuffer last byte is 'o' (111)", u8[4], 111);

    // ── 29: Response.bytes ────────────────────────────────────────────
    var r2 = new Response("ABC");
    return r2.bytes();
}).then(function(u8) {
    check(29, "bytes() returns Uint8Array", u8 instanceof Uint8Array, true);
    check(30, "bytes() length = 3", u8.length, 3);
    check(31, "bytes() first byte is 'A' (65)", u8[0], 65);

    // ── 32: Response.blob ─────────────────────────────────────────────
    var r3 = new Response("data", { headers: { "Content-Type": "application/octet-stream" } });
    return r3.blob();
}).then(function(blob) {
    check(32, "blob.size = 4", blob.size, 4);
    check(33, "blob.type", blob.type, "application/octet-stream");
    return blob.text();
}).then(function(txt) {
    check(34, "blob.text() returns original string", txt, "data");

    // ── 35: Response.bytes with stream body ───────────────────────────
    var rs = new ReadableStream({
        start: function(ctrl) { ctrl.enqueue("XYZ"); ctrl.close(); }
    });
    var r4 = new Response(rs);
    return r4.bytes();
}).then(function(u8) {
    check(35, "stream body bytes() returns Uint8Array", u8 instanceof Uint8Array, true);
    check(36, "stream body bytes() length = 3", u8.length, 3);
    check(37, "stream body bytes() first byte is 'X' (88)", u8[0], 88);

    // ── 38: Request properties ────────────────────────────────────────
    var req = new Request("https://example.com", {
        method: "POST",
        mode: "no-cors",
        referrer: "https://ref.example.com",
        referrerPolicy: "no-referrer",
        integrity: "sha256-abc",
        keepalive: true
    });
    check(38, "Request.mode", req.mode, "no-cors");
    check(39, "Request.referrer", req.referrer, "https://ref.example.com");
    check(40, "Request.referrerPolicy", req.referrerPolicy, "no-referrer");
    check(41, "Request.integrity", req.integrity, "sha256-abc");
    check(42, "Request.keepalive", req.keepalive, true);

    // ── 43: Request defaults ──────────────────────────────────────────
    var req2 = new Request("https://example.com");
    check(43, "Request.mode default = cors", req2.mode, "cors");
    check(44, "Request.referrer default", req2.referrer, "about:client");
    check(45, "Request.referrerPolicy default", req2.referrerPolicy, "");
    check(46, "Request.integrity default", req2.integrity, "");
    check(47, "Request.keepalive default", req2.keepalive, false);

    // ── 48: Response.json() ───────────────────────────────────────────
    var rj = Response.json({ key: "val" });
    check(48, "Response.json status 200", rj.status, 200);
    check(49, "Response.json content-type", rj.headers.get("content-type"), "application/json");
    return rj.text();
}).then(function(jsonTxt) {
    check(50, "Response.json body", jsonTxt, '{"key":"val"}');

    // ── 51: Response.redirect ─────────────────────────────────────────
    var rr = Response.redirect("https://example.com", 301);
    check(51, "Response.redirect status", rr.status, 301);
    check(52, "Response.redirect location", rr.headers.get("location"), "https://example.com");

    // ── 53: Response.error ────────────────────────────────────────────
    var re = Response.error();
    check(53, "Response.error type", re.type, "error");
    check(54, "Response.error status = 0", re.status, 0);

    // ── 55: AbortSignal.any with timeout ──────────────────────────────
    return new Promise(function(res) {
        var tSig = AbortSignal.timeout(50);
        var mSig = new AbortController().signal;
        var comp = AbortSignal.any([tSig, mSig]);
        setTimeout(function() {
            check(55, "composite with timeout aborts", comp.aborted, true);
            check(56, "reason is DOMException", comp.reason instanceof DOMException, true);
            check(57, "reason.name = TimeoutError", comp.reason.name, "TimeoutError");
            res();
        }, 150);
    });
}).then(function() {
    console.log("\n=== Fetch API tests: " + _passed + " passed, " + _failed + " failed ===");
});
