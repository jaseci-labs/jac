// Fetch tests — js_engine engine (Phase 6.3 + 6.4)
// In Node.js ≥18, fetch/Headers/Request/Response/AbortController/AbortSignal
// are globals — no require() needed.
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

// ── 1–15: Headers ───────────────────────────────────────────────────────────

var h = new Headers();
h.append("Content-Type", "text/html");
check(1, "Headers: case-insensitive get", h.get("content-type"), "text/html");

h.set("Content-Type", "application/json");
check(2, "Headers: set replaces", h.get("content-type"), "application/json");

check(3, "Headers: has (case-insensitive)", h.has("Content-Type"), true);
check(4, "Headers: has returns false for missing", h.has("x-missing"), false);

h.delete("Content-Type");
check(5, "Headers: delete removes header", h.has("content-type"), false);

h.append("Accept", "text/html");
h.append("Accept", "application/json");
check(6, "Headers: multi-value combined", h.get("accept"), "text/html, application/json");

var h2 = new Headers({"x-custom": "hello", "accept": "text/plain"});
check(7, "Headers: construct from object", h2.get("x-custom"), "hello");
check(8, "Headers: construct from object (2)", h2.get("accept"), "text/plain");

var h3 = new Headers(h2);
check(9, "Headers: copy constructor", h3.get("x-custom"), "hello");

var h4 = new Headers({"a": "1", "b": "2"});
check(10, "Headers: keys() returns all keys", h4.keys().length, 2);
check(11, "Headers: values() returns all values", h4.values().length, 2);
check(12, "Headers: entries() returns all pairs", h4.entries().length, 2);

var forEachResult = [];
h4.forEach(function(value, name) { forEachResult.push(name + "=" + value); });
check(13, "Headers: forEach iterates all entries", forEachResult.length, 2);

var h5 = new Headers({"host": "example.com"});
check(14, "Headers: _toRaw serializes correctly", h5._toRaw().indexOf("host: example.com") >= 0, true);

var h6 = new Headers();
h6._guard = "immutable";
var immutableThrew = false;
try { h6.append("foo", "bar"); } catch (e) { immutableThrew = true; }
check(15, "Headers: immutable guard throws on append", immutableThrew, true);

// ── 16–26: MIME types (internal helpers, not Node.js globals) ────────────
// MIME utilities are engine-internal; loaded via require for testing only.
var _mimeInternal = require("fetch");
var mimeFromExtension = _mimeInternal.mimeFromExtension;
var mimeFromPath = _mimeInternal.mimeFromPath;
var mimeIsText = _mimeInternal.mimeIsText;

check(16, "MIME: .json", mimeFromExtension(".json"), "application/json");
check(17, "MIME: .html", mimeFromExtension(".html"), "text/html");
check(18, "MIME: .ts", mimeFromExtension(".ts"), "application/typescript");
check(19, "MIME: unknown ext", mimeFromExtension(".unknown"), "application/octet-stream");
check(20, "MIME: without dot prefix", mimeFromExtension("json"), "application/json");
check(21, "MIME: path /index.html", mimeFromPath("/index.html"), "text/html");
check(22, "MIME: path .css", mimeFromPath("styles.css"), "text/css");
check(23, "MIME: no extension", mimeFromPath("noext"), "application/octet-stream");
check(24, "MIME: text/html is text", mimeIsText("text/html"), true);
check(25, "MIME: application/json is text", mimeIsText("application/json"), true);
check(26, "MIME: image/png is not text", mimeIsText("image/png"), false);

// ── 27–29: HTTP Method normalization ────────────────────────────────────────

check(27, "Request: method normalized to uppercase", new Request("https://example.com", { method: "get" }).method, "GET");
check(28, "Request: POST normalized", new Request("https://example.com", { method: "post" }).method, "POST");
check(29, "Request: default method is GET", new Request("https://example.com").method, "GET");

// ── 30–35: Request ──────────────────────────────────────────────────────────

var req4 = new Request("https://httpbin.org/get", {
    method: "GET",
    headers: { "X-Test": "hello" }
});
check(30, "Request: url set", req4.url, "https://httpbin.org/get");
check(31, "Request: headers set", req4.headers.get("x-test"), "hello");
check(32, "Request: default redirect=follow", req4.redirect, "follow");

var req5 = req4.clone();
check(33, "Request: clone preserves url", req5.url, "https://httpbin.org/get");
check(34, "Request: clone preserves method", req5.method, "GET");

// ── 35–44: Response ─────────────────────────────────────────────────────────

var resp1 = new Response("hello world", { status: 200 });
check(35, "Response: status 200", resp1.status, 200);
check(36, "Response: ok is true for 200", resp1.ok, true);
check(37, "Response: statusText auto-set", resp1.statusText, "OK");

var resp2 = new Response("not found", { status: 404 });
check(38, "Response: ok is false for 404", resp2.ok, false);

resp1.text().then(function(text) {
    check(39, "Response: text() returns body", text, "hello world");
});

var resp3 = new Response('{"key":"value"}', { status: 200 });
resp3.json().then(function(obj) {
    check(40, "Response: json() parses body", obj.key, "value");
});

var resp4 = new Response("clone me", { status: 201 });
var resp4c = resp4.clone();
check(41, "Response: clone preserves status", resp4c.status, 201);
resp4c.text().then(function(t) {
    check(42, "Response: clone preserves body", t, "clone me");
});

var resp5 = Response.json({ a: 1 });
check(43, "Response.json(): status 200", resp5.status, 200);
check(44, "Response.json(): content-type set", resp5.headers.get("content-type"), "application/json");

// ── 45–46: Response.redirect ────────────────────────────────────────────────

var resp6 = Response.redirect("https://example.com", 302);
check(45, "Response.redirect(): status 302", resp6.status, 302);
check(46, "Response.redirect(): location header", resp6.headers.get("location"), "https://example.com");

// ── 47–49: AbortController ──────────────────────────────────────────────────

var ac = new AbortController();
check(47, "AbortController: signal not aborted initially", ac.signal.aborted, false);

var abortFired = false;
ac.signal.addEventListener("abort", function() { abortFired = true; });
ac.abort();
check(48, "AbortController: signal.aborted=true after abort", ac.signal.aborted, true);
check(49, "AbortController: abort event listener fired", abortFired, true);

// ── 50: fetch with aborted signal ───────────────────────────────────────────

var ac2 = new AbortController();
ac2.abort();
fetch("https://httpbin.org/get", { signal: ac2.signal }).then(
    function() { check(50, "fetch: rejects with AbortError for aborted signal", false, true); },
    function(err) { check(50, "fetch: rejects with AbortError for aborted signal", err.name, "AbortError"); }
);

// ── 51–54: Live fetch() — HTTPS GET ────────────────────────────────────────

fetch("https://httpbin.org/get").then(function(response) {
    check(51, "fetch GET: status 200", response.status, 200);
    check(52, "fetch GET: ok is true", response.ok, true);
    check(53, "fetch GET: has content-type header", response.headers.has("content-type"), true);
    return response.json();
}).then(function(data) {
    check(54, "fetch GET: json body has correct url", data.url, "https://httpbin.org/get");
}).catch(function(err) {
    console.log("FAIL 51-54  fetch GET: " + (err.message || err));
    _failed = _failed + 4;
});

// ── 55–56: Live fetch() — HTTPS POST ───────────────────────────────────────

fetch("https://httpbin.org/post", {
    method: "POST",
    headers: { "Content-Type": "text/plain" },
    body: "hello from js_engine"
}).then(function(response) {
    check(55, "fetch POST: status 200", response.status, 200);
    return response.json();
}).then(function(data) {
    check(56, "fetch POST: echo body matches", data.data, "hello from js_engine");
}).catch(function(err) {
    console.log("FAIL 55-56  fetch POST: " + (err.message || err));
    _failed = _failed + 2;
});

// ── 57–58: Redirect handling ────────────────────────────────────────────────

fetch("https://httpbin.org/redirect-to?url=/get").then(function(response) {
    check(57, "fetch redirect: final status 200", response.status, 200);
    check(58, "fetch redirect: redirected flag set", response.redirected, true);
}).catch(function(err) {
    console.log("FAIL 57-58  fetch redirect: " + (err.message || err));
    _failed = _failed + 2;
});

// ── 59–62: AbortSignal.abort() static ───────────────────────────────────────

var preAborted = AbortSignal.abort();
check(59, "AbortSignal.abort(): aborted=true", preAborted.aborted, true);
check(60, "AbortSignal.abort(): reason is AbortError", preAborted.reason.name, "AbortError");

var preAborted2 = AbortSignal.abort("custom reason");
check(61, "AbortSignal.abort(reason): aborted=true", preAborted2.aborted, true);
check(62, "AbortSignal.abort(reason): reason preserved", preAborted2.reason, "custom reason");

// ── 63–64: AbortSignal.timeout() ────────────────────────────────────────────

var timeoutSig = AbortSignal.timeout(50);
check(63, "AbortSignal.timeout(): not aborted initially", timeoutSig.aborted, false);

// After 100ms the signal should have fired
setTimeout(function() {
    check(64, "AbortSignal.timeout(): aborted after delay", timeoutSig.aborted, true);
}, 100);

// ── 65–70: mimeCharset() ───────────────────────────────────────────────────

var _mimeInternal = require("fetch");
var mimeCharset = _mimeInternal.mimeCharset;

check(65, "mimeCharset: text/html; charset=utf-8", mimeCharset("text/html; charset=utf-8"), "utf-8");
check(66, "mimeCharset: quoted charset", mimeCharset('text/html; charset="iso-8859-1"'), "iso-8859-1");
check(67, "mimeCharset: no charset", mimeCharset("application/json"), "");
check(68, "mimeCharset: uppercase", mimeCharset("text/html; Charset=UTF-8"), "utf-8");
check(69, "mimeCharset: with extra params", mimeCharset("text/html; charset=utf-8; boundary=something"), "utf-8");
check(70, "mimeCharset: non-string", mimeCharset(42), "");

// ── Summary ─────────────────────────────────────────────────────────────────
console.log("\n=== Fetch tests: " + _passed + " passed, " + _failed + " failed ===");
