// js_tests/test_querystring.js — Phase 5.8 node:querystring test suite

var qs = require("querystring");
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

function deepEq(a, b, msg) {
    if (JSON.stringify(a) !== JSON.stringify(b)) {
        throw new Error((msg || "DeepEqual") + ": " + JSON.stringify(a) + " !== " + JSON.stringify(b));
    }
}

// ── parse ───────────────────────────────────────────────────────────────────

test("parse simple key=value", function() {
    var r = qs.parse("a=1");
    eq(r.a, "1");
});

test("parse multiple pairs", function() {
    var r = qs.parse("a=1&b=2&c=3");
    eq(r.a, "1");
    eq(r.b, "2");
    eq(r.c, "3");
});

test("parse duplicate keys produce array", function() {
    var r = qs.parse("a=1&a=2&a=3");
    eq(Array.isArray(r.a), true);
    eq(r.a.length, 3);
    eq(r.a[0], "1");
    eq(r.a[1], "2");
    eq(r.a[2], "3");
});

test("parse with + decoded as space", function() {
    var r = qs.parse("greeting=hello+world");
    eq(r.greeting, "hello world");
});

test("parse empty string returns empty object", function() {
    var r = qs.parse("");
    eq(Object.keys(r).length, 0);
});

test("parse with custom separator", function() {
    var r = qs.parse("a=1;b=2", ";");
    eq(r.a, "1");
    eq(r.b, "2");
});

test("parse with custom equals", function() {
    var r = qs.parse("a:1&b:2", "&", ":");
    eq(r.a, "1");
    eq(r.b, "2");
});

test("parse key without value", function() {
    var r = qs.parse("foo&bar=baz");
    eq(r.foo, "");
    eq(r.bar, "baz");
});

test("parse percent-encoded values", function() {
    var r = qs.parse("name=%E4%B8%96%E7%95%8C");
    eq(r.name, "\u4e16\u754c");  // 世界
});

test("parse maxKeys option", function() {
    var r = qs.parse("a=1&b=2&c=3&d=4", undefined, undefined, { maxKeys: 2 });
    eq(r.a, "1");
    eq(r.b, "2");
    eq(r.c, undefined);
});

test("parse with percent-encoded key", function() {
    var r = qs.parse("hello%20world=1");
    eq(r["hello world"], "1");
});

// ── stringify ───────────────────────────────────────────────────────────────

test("stringify simple object", function() {
    var r = qs.stringify({ a: "1", b: "2" });
    // Order depends on Object.keys order
    eq(r.indexOf("a=1") >= 0, true);
    eq(r.indexOf("b=2") >= 0, true);
});

test("stringify with array values", function() {
    var r = qs.stringify({ a: ["1", "2"] });
    eq(r, "a=1&a=2");
});

test("stringify with custom separator", function() {
    var r = qs.stringify({ a: "1", b: "2" }, ";");
    eq(r.indexOf(";") >= 0, true);
    eq(r.indexOf("&") < 0, true);
});

test("stringify with custom equals", function() {
    var r = qs.stringify({ a: "1" }, "&", ":");
    eq(r, "a:1");
});

test("stringify encodes special characters", function() {
    var r = qs.stringify({ name: "hello world" });
    eq(r, "name=hello+world");
});

test("stringify null/undefined returns empty string", function() {
    eq(qs.stringify(null), "");
    eq(qs.stringify(undefined), "");
});

test("stringify empty object returns empty string", function() {
    eq(qs.stringify({}), "");
});

// ── escape ──────────────────────────────────────────────────────────────────

test("escape leaves alphanumeric unchanged", function() {
    eq(qs.escape("abc123"), "abc123");
});

test("escape converts space to +", function() {
    eq(qs.escape("hello world"), "hello+world");
});

test("escape encodes special chars", function() {
    var r = qs.escape("a=b&c=d");
    eq(r.indexOf("=") < 0, true);  // = should be encoded
    eq(r.indexOf("&") < 0, true);  // & should be encoded
});

test("escape preserves unreserved chars", function() {
    eq(qs.escape("-_.~!*'()"), "-_.~!*'()");
});

// ── unescape ────────────────────────────────────────────────────────────────

test("unescape decodes + to space", function() {
    eq(qs.unescape("hello+world"), "hello world");
});

test("unescape decodes percent", function() {
    eq(qs.unescape("hello%20world"), "hello world");
});

test("unescape passes through plain text", function() {
    eq(qs.unescape("hello"), "hello");
});

// ── decode/encode aliases ───────────────────────────────────────────────────

test("decode is alias for parse", function() {
    eq(qs.decode === qs.parse, true);
});

test("encode is alias for stringify", function() {
    eq(qs.encode === qs.stringify, true);
});

// ── roundtrip ───────────────────────────────────────────────────────────────

test("parse(stringify(obj)) roundtrip", function() {
    var obj = { x: "1", y: "hello world", z: "a&b" };
    var str = qs.stringify(obj);
    var result = qs.parse(str);
    eq(result.x, "1");
    eq(result.y, "hello world");
    eq(result.z, "a&b");
});

console.log("=== querystring tests: " + passed + " passed, " + failed + " failed ===");
