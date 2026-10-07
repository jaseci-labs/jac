// RT-060 through RT-061: URL globals
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/06_url_globals/test_url_globals.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// RT-060: URL
assertEq(typeof URL, "function", "RT-060: typeof URL === 'function'");
var u = new URL("https://user:pass@example.com:8080/path?q=1&r=2#hash");
assertEq(u.protocol, "https:", "RT-060: URL.protocol");
assertEq(u.hostname, "example.com", "RT-060: URL.hostname");
assertEq(u.port, "8080", "RT-060: URL.port");
assertEq(u.pathname, "/path", "RT-060: URL.pathname");
assertEq(u.search, "?q=1&r=2", "RT-060: URL.search");
assertEq(u.hash, "#hash", "RT-060: URL.hash");
assertEq(u.username, "user", "RT-060: URL.username");
assertEq(u.password, "pass", "RT-060: URL.password");
assertEq(typeof u.toString(), "string", "RT-060: URL.toString() returns string");
assertEq(typeof u.toJSON(), "string", "RT-060: URL.toJSON() returns string");
assertEq(u.toString(), u.href, "RT-060: URL.toString() === URL.href");

// RT-061: URLSearchParams
assertEq(typeof URLSearchParams, "function", "RT-061: typeof URLSearchParams === 'function'");
var p = new URLSearchParams("a=1&b=2&a=3");
assertEq(p.get("a"), "1", "RT-061: URLSearchParams.get (first)");
assertEq(p.get("b"), "2", "RT-061: URLSearchParams.get");
p.set("c", "4");
assertEq(p.get("c"), "4", "RT-061: URLSearchParams.set");
p.append("d", "5");
assertEq(p.get("d"), "5", "RT-061: URLSearchParams.append");
assert(p.has("c"), "RT-061: URLSearchParams.has");
p.delete("c");
assert(!p.has("c"), "RT-061: URLSearchParams.delete");
p.sort();
var str = p.toString();
assertEq(typeof str, "string", "RT-061: URLSearchParams.toString() returns string");

// iteration
var keys = [];
for (var k of p.keys()) { keys.push(k); }
assert(keys.length > 0, "RT-061: URLSearchParams.keys() iteration works");

var vals = [];
for (var v of p.values()) { vals.push(v); }
assert(vals.length > 0, "RT-061: URLSearchParams.values() iteration works");

var entries = [];
for (var e of p.entries()) { entries.push(e); }
assert(entries.length > 0, "RT-061: URLSearchParams.entries() iteration works");

__jacDone();
