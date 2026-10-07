// js_tests/test_url.js — Phase 5.8 node:url & URL/URLSearchParams test suite

var url = require("url");
var URL = url.URL;
var URLSearchParams = url.URLSearchParams;
var passed = 0;
var failed = 0;

function test(name, fn) {
    try {
        fn();
        passed = passed + 1;
    } catch (e) {
        failed = failed + 1;
        console.log("FAIL: " + name + " — " + (e.message || String(e)));
    }
}

function eq(a, b, msg) {
    if (a !== b) {
        throw new Error((msg || "AssertionError") + ": " + JSON.stringify(a) + " !== " + JSON.stringify(b));
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  URL class
// ═══════════════════════════════════════════════════════════════════════════

test("URL parse full https URL", function() {
    var u = new URL("https://user:pass@example.com:8080/path/to?query=1#hash");
    eq(u.protocol, "https:");
    eq(u.username, "user");
    eq(u.password, "pass");
    eq(u.hostname, "example.com");
    eq(u.port, "8080");
    eq(u.pathname, "/path/to");
    eq(u.search, "?query=1");
    eq(u.hash, "#hash");
});

test("URL hostname extraction", function() {
    var u = new URL("https://example.com:8080/path?q=1#hash");
    eq(u.hostname, "example.com");
});

test("URL port extraction", function() {
    var u = new URL("https://example.com:8080/path");
    eq(u.port, "8080");
});

test("URL default port suppression (https 443)", function() {
    var u = new URL("https://example.com:443/path");
    eq(u.port, "");
    eq(u.host, "example.com");
});

test("URL default port suppression (http 80)", function() {
    var u = new URL("http://example.com:80/path");
    eq(u.port, "");
});

test("URL pathname extraction", function() {
    var u = new URL("https://example.com/path/to/resource");
    eq(u.pathname, "/path/to/resource");
});

test("URL search extraction", function() {
    var u = new URL("https://example.com/path?q=1&r=2");
    eq(u.search, "?q=1&r=2");
});

test("URL hash extraction", function() {
    var u = new URL("https://example.com/path#section");
    eq(u.hash, "#section");
});

test("URL origin", function() {
    var u = new URL("https://example.com:8080/path");
    eq(u.origin, "https://example.com:8080");
});

test("URL origin with default port", function() {
    var u = new URL("https://example.com/path");
    eq(u.origin, "https://example.com");
});

test("URL host includes port", function() {
    var u = new URL("http://example.com:3000/");
    eq(u.host, "example.com:3000");
});

test("URL host without port", function() {
    var u = new URL("http://example.com/");
    eq(u.host, "example.com");
});

test("URL href roundtrip", function() {
    var input = "https://example.com:8080/path?q=1#hash";
    var u = new URL(input);
    eq(u.href, input);
});

test("URL toString() returns href", function() {
    var u = new URL("https://example.com/path");
    eq(u.toString(), u.href);
});

test("URL toJSON() returns href", function() {
    var u = new URL("https://example.com/path");
    eq(u.toJSON(), u.href);
});

test("URL with no path gets /", function() {
    var u = new URL("https://example.com");
    eq(u.pathname, "/");
});

test("URL with userinfo but no password", function() {
    var u = new URL("https://user@example.com/");
    eq(u.username, "user");
    eq(u.password, "");
});

test("URL protocol is lowercase", function() {
    var u = new URL("HTTPS://EXAMPLE.COM/path");
    eq(u.protocol, "https:");
    eq(u.hostname, "example.com");
});

test("URL with base - relative path", function() {
    var u = new URL("bar", "https://example.com/foo/");
    eq(u.pathname, "/foo/bar");
    eq(u.hostname, "example.com");
});

test("URL with base - absolute path", function() {
    var u = new URL("/new/path", "https://example.com/old/path");
    eq(u.pathname, "/new/path");
});

test("URL with base - query only", function() {
    var u = new URL("?newquery=1", "https://example.com/path?oldquery=1");
    eq(u.search, "?newquery=1");
    eq(u.pathname, "/path");
});

test("URL with base - hash only", function() {
    var u = new URL("#newhash", "https://example.com/path#oldhash");
    eq(u.hash, "#newhash");
});

test("URL invalid throws TypeError", function() {
    var threw = false;
    try {
        new URL("not a url");
    } catch (e) {
        threw = true;
    }
    eq(threw, true, "Invalid URL should throw");
});

test("URL.canParse valid", function() {
    eq(URL.canParse("https://example.com"), true);
});

test("URL.canParse invalid", function() {
    eq(URL.canParse("not a url"), false);
});

// ── URL property setters ────────────────────────────────────────────────────

test("URL set hostname", function() {
    var u = new URL("https://old.com/path");
    u.hostname = "new.com";
    eq(u.hostname, "new.com");
    eq(u.href.indexOf("new.com") >= 0, true);
});

test("URL set port", function() {
    var u = new URL("https://example.com/path");
    u.port = "9090";
    eq(u.port, "9090");
    eq(u.host, "example.com:9090");
});

test("URL set pathname", function() {
    var u = new URL("https://example.com/old");
    u.pathname = "/new";
    eq(u.pathname, "/new");
});

test("URL set search", function() {
    var u = new URL("https://example.com/path");
    u.search = "?x=1";
    eq(u.search, "?x=1");
});

test("URL set hash", function() {
    var u = new URL("https://example.com/path");
    u.hash = "#section";
    eq(u.hash, "#section");
});

test("URL set protocol", function() {
    var u = new URL("http://example.com/path");
    u.protocol = "https:";
    eq(u.protocol, "https:");
});

// ═══════════════════════════════════════════════════════════════════════════
//  URLSearchParams
// ═══════════════════════════════════════════════════════════════════════════

test("URLSearchParams from string", function() {
    var sp = new URLSearchParams("a=1&b=2");
    eq(sp.get("a"), "1");
    eq(sp.get("b"), "2");
});

test("URLSearchParams from string with leading ?", function() {
    var sp = new URLSearchParams("?a=1");
    eq(sp.get("a"), "1");
});

test("URLSearchParams from object", function() {
    var sp = new URLSearchParams({ x: "10", y: "20" });
    eq(sp.get("x"), "10");
    eq(sp.get("y"), "20");
});

test("URLSearchParams from array", function() {
    var sp = new URLSearchParams([["a", "1"], ["b", "2"]]);
    eq(sp.get("a"), "1");
    eq(sp.get("b"), "2");
});

test("URLSearchParams.append", function() {
    var sp = new URLSearchParams();
    sp.append("key", "val1");
    sp.append("key", "val2");
    eq(sp.getAll("key").length, 2);
    eq(sp.getAll("key")[0], "val1");
    eq(sp.getAll("key")[1], "val2");
});

test("URLSearchParams.delete", function() {
    var sp = new URLSearchParams("a=1&b=2&a=3");
    sp.delete("a");
    eq(sp.has("a"), false);
    eq(sp.get("b"), "2");
});

test("URLSearchParams.delete with value", function() {
    var sp = new URLSearchParams("a=1&a=2&a=3");
    sp.delete("a", "2");
    var all = sp.getAll("a");
    eq(all.length, 2);
    eq(all[0], "1");
    eq(all[1], "3");
});

test("URLSearchParams.get returns first match", function() {
    var sp = new URLSearchParams("a=1&a=2");
    eq(sp.get("a"), "1");
});

test("URLSearchParams.get returns null for missing", function() {
    var sp = new URLSearchParams("a=1");
    eq(sp.get("b"), null);
});

test("URLSearchParams.has", function() {
    var sp = new URLSearchParams("a=1");
    eq(sp.has("a"), true);
    eq(sp.has("b"), false);
});

test("URLSearchParams.has with value", function() {
    var sp = new URLSearchParams("a=1&a=2");
    eq(sp.has("a", "1"), true);
    eq(sp.has("a", "3"), false);
});

test("URLSearchParams.set", function() {
    var sp = new URLSearchParams("a=1&a=2&b=3");
    sp.set("a", "99");
    eq(sp.get("a"), "99");
    eq(sp.getAll("a").length, 1);
    eq(sp.get("b"), "3");
});

test("URLSearchParams.size", function() {
    var sp = new URLSearchParams("a=1&b=2&c=3");
    eq(sp.size, 3);
});

test("URLSearchParams.toString", function() {
    var sp = new URLSearchParams("a=1&b=2");
    eq(sp.toString(), "a=1&b=2");
});

test("URLSearchParams.toString encodes spaces as +", function() {
    var sp = new URLSearchParams();
    sp.append("key", "hello world");
    eq(sp.toString(), "key=hello+world");
});

test("URLSearchParams.sort", function() {
    var sp = new URLSearchParams("c=3&a=1&b=2");
    sp.sort();
    eq(sp.toString(), "a=1&b=2&c=3");
});

test("URLSearchParams.forEach", function() {
    var sp = new URLSearchParams("a=1&b=2");
    var keys = [];
    var vals = [];
    sp.forEach(function(value, key) {
        keys.push(key);
        vals.push(value);
    });
    eq(keys.length, 2);
    eq(keys[0], "a");
    eq(vals[0], "1");
});

test("URLSearchParams.entries iterator", function() {
    var sp = new URLSearchParams("x=10");
    var iter = sp.entries();
    var r = iter.next();
    eq(r.done, false);
    eq(r.value[0], "x");
    eq(r.value[1], "10");
    var r2 = iter.next();
    eq(r2.done, true);
});

test("URLSearchParams.keys iterator", function() {
    var sp = new URLSearchParams("a=1&b=2");
    var iter = sp.keys();
    eq(iter.next().value, "a");
    eq(iter.next().value, "b");
    eq(iter.next().done, true);
});

test("URLSearchParams.values iterator", function() {
    var sp = new URLSearchParams("a=1&b=2");
    var iter = sp.values();
    eq(iter.next().value, "1");
    eq(iter.next().value, "2");
    eq(iter.next().done, true);
});

// ── URL ↔ URLSearchParams integration ───────────────────────────────────────

test("URL.searchParams.get works", function() {
    var u = new URL("https://example.com/path?q=1&r=2");
    eq(u.searchParams.get("q"), "1");
    eq(u.searchParams.get("r"), "2");
});

test("URL.searchParams.append updates URL.search", function() {
    var u = new URL("https://example.com/path?a=1");
    u.searchParams.append("b", "2");
    eq(u.searchParams.get("b"), "2");
    eq(u.search.indexOf("b=2") >= 0, true);
});

test("URL.searchParams.set updates URL.search", function() {
    var u = new URL("https://example.com/path?a=1");
    u.searchParams.set("a", "99");
    eq(u.search, "?a=99");
});

test("URL.searchParams.delete updates URL.search", function() {
    var u = new URL("https://example.com/path?a=1&b=2");
    u.searchParams.delete("a");
    eq(u.searchParams.has("a"), false);
    eq(u.search.indexOf("a=") < 0, true);
});

// ═══════════════════════════════════════════════════════════════════════════
//  Legacy url.parse()
// ═══════════════════════════════════════════════════════════════════════════

test("url.parse full URL", function() {
    var r = url.parse("http://user:pass@host.com:8080/p/a/t/h?query=string#hash");
    eq(r.protocol, "http:");
    eq(r.auth, "user:pass");
    eq(r.hostname, "host.com");
    eq(r.port, "8080");
    eq(r.pathname, "/p/a/t/h");
    eq(r.search, "?query=string");
    eq(r.hash, "#hash");
});

test("url.parse query as string by default", function() {
    var r = url.parse("http://example.com/?a=1&b=2");
    eq(r.query, "a=1&b=2");
});

test("url.parse query as object when parseQueryString=true", function() {
    var r = url.parse("http://example.com/?a=1&b=2", true);
    eq(typeof r.query, "object");
    eq(r.query.a, "1");
    eq(r.query.b, "2");
});

test("url.parse path includes pathname + search", function() {
    var r = url.parse("http://example.com/path?q=1");
    eq(r.path, "/path?q=1");
});

test("url.parse slashes is true for http", function() {
    var r = url.parse("http://example.com");
    eq(r.slashes, true);
});

test("url.parse no port returns null port", function() {
    var r = url.parse("http://example.com/path");
    eq(r.port, null);
});

test("url.parse host = hostname:port", function() {
    var r = url.parse("http://example.com:3000/");
    eq(r.host, "example.com:3000");
});

test("url.parse host = hostname when no port", function() {
    var r = url.parse("http://example.com/");
    eq(r.host, "example.com");
});

// ── url.format() ────────────────────────────────────────────────────────────

test("url.format from parsed object", function() {
    var parsed = url.parse("http://example.com:3000/path?q=1#hash");
    var result = url.format(parsed);
    eq(result.indexOf("http://") === 0, true);
    eq(result.indexOf("example.com:3000") >= 0, true);
    eq(result.indexOf("/path") >= 0, true);
    eq(result.indexOf("?q=1") >= 0, true);
    eq(result.indexOf("#hash") >= 0, true);
});

test("url.format from manual object", function() {
    var result = url.format({
        protocol: "https:",
        hostname: "example.com",
        pathname: "/path",
        search: "?q=1"
    });
    eq(result, "https://example.com/path?q=1");
});

// ── url.resolve() ───────────────────────────────────────────────────────────

test("url.resolve absolute path", function() {
    var result = url.resolve("http://example.com/a/b", "/c/d");
    eq(result, "http://example.com/c/d");
});

test("url.resolve relative path", function() {
    var result = url.resolve("http://example.com/a/b", "c");
    eq(result, "http://example.com/a/c");
});

test("url.resolve with ..", function() {
    var result = url.resolve("http://example.com/a/b/c", "../d");
    eq(result, "http://example.com/a/d");
});

test("url.resolve full URL overrides", function() {
    var result = url.resolve("http://example.com/a", "https://other.com/b");
    eq(result, "https://other.com/b");
});

test("url.resolve query-only", function() {
    var result = url.resolve("http://example.com/path?old=1", "?new=2");
    eq(result, "http://example.com/path?new=2");
});

// ── URLSearchParams Symbol.iterator ─────────────────────────────────────────

test("URLSearchParams Symbol.iterator (for...of)", function() {
    var sp = new URLSearchParams("a=1&b=2&c=3");
    var keys = [];
    var vals = [];
    for (var pair of sp) {
        keys.push(pair[0]);
        vals.push(pair[1]);
    }
    eq(keys.join(","), "a,b,c");
    eq(vals.join(","), "1,2,3");
});

// ── require("node:url") works ───────────────────────────────────────────────

test("require('node:url') returns same module", function() {
    var url2 = require("node:url");
    eq(url2.parse !== undefined, true);
    eq(url2.URL !== undefined, true);
});

console.log("=== url tests: " + passed + " passed, " + failed + " failed ===");
