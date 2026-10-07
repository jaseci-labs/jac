// RT-050 through RT-055: Fetch API globals
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/05_fetch_api/test_fetch_api.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-050: fetch
assertEq(typeof fetch, "function", "RT-050: typeof fetch === 'function'");
var fetchResult = fetch("http://localhost:0/nonexistent");
assert(fetchResult !== null && typeof fetchResult === "object",
    "RT-050: fetch returns a Promise-like object");
assert(typeof fetchResult.then === "function", "RT-050: fetch result has .then");
// prevent unhandled rejection noise
fetchResult.catch(function() {});

// RT-051: Headers
assertEq(typeof Headers, "function", "RT-051: typeof Headers === 'function'");
var headers = new Headers();
headers.set("Content-Type", "text/plain");
assertEq(headers.get("content-type"), "text/plain", "RT-051: Headers get/set (case-insensitive)");
assert(headers.has("Content-Type"), "RT-051: Headers.has");
headers.append("X-Foo", "a");
headers.append("X-Foo", "b");
headers.delete("X-Foo");
assert(!headers.has("X-Foo"), "RT-051: Headers.delete");
assert(typeof headers.forEach === "function", "RT-051: Headers.forEach exists");
assert(typeof headers.entries === "function", "RT-051: Headers.entries exists");

// RT-052: Request
assertEq(typeof Request, "function", "RT-052: typeof Request === 'function'");
var req = new Request("https://example.com/api", { method: "POST" });
assertEq(req.method, "POST", "RT-052: Request.method");
assertEq(req.url, "https://example.com/api", "RT-052: Request.url");
assert(req.headers instanceof Headers, "RT-052: Request.headers is Headers");

// RT-053: Response
assertEq(typeof Response, "function", "RT-053: typeof Response === 'function'");
var res = new Response("body text", { status: 201 });
assertEq(res.status, 201, "RT-053: Response.status");
assert(typeof res.ok === "boolean", "RT-053: Response.ok is boolean");
assert(res.headers instanceof Headers, "RT-053: Response.headers is Headers");
assert(typeof res.text === "function", "RT-053: Response.text() exists");
assert(typeof res.json === "function", "RT-053: Response.json() exists");

// RT-054: AbortController
assertEq(typeof AbortController, "function", "RT-054: typeof AbortController === 'function'");
var ac = new AbortController();
assert(ac.signal !== undefined, "RT-054: AbortController.signal exists");
assertEq(ac.signal.aborted, false, "RT-054: signal.aborted starts false");
ac.abort();
assertEq(ac.signal.aborted, true, "RT-054: signal.aborted is true after abort()");

// RT-055: AbortSignal
assertEq(typeof AbortSignal, "function", "RT-055: typeof AbortSignal === 'function'");
var sig = AbortSignal.abort("reason");
assertEq(sig.aborted, true, "RT-055: AbortSignal.abort() returns aborted signal");
assert(typeof sig.throwIfAborted === "function", "RT-055: signal.throwIfAborted exists");
var threw = false;
try { sig.throwIfAborted(); } catch(e) { threw = true; }
assert(threw, "RT-055: throwIfAborted throws when aborted");
assert(typeof AbortSignal.timeout === "function", "RT-055: AbortSignal.timeout exists");

__jacDone();
