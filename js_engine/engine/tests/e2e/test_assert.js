// js_tests/test_assert.js — Phase 5.7 node:assert test suite

var assert = require("assert");
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

// ── assert() / assert.ok() ─────────────────────────────────────────────────

test("assert(true) does not throw", function() {
    assert(true);
});

test("assert(1) does not throw", function() {
    assert(1);
});

test("assert('hello') does not throw", function() {
    assert("hello");
});

test("assert(false) throws", function() {
    var threw = false;
    try {
        assert(false);
    } catch (e) {
        threw = true;
        assert.strictEqual(e.name, "AssertionError");
    }
    if (!threw) { throw new Error("assert(false) did not throw"); }
});

test("assert(0) throws", function() {
    var threw = false;
    try {
        assert(0);
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("assert(0) did not throw"); }
});

test("assert.ok(true) does not throw", function() {
    assert.ok(true);
});

test("assert.ok(false) throws", function() {
    var threw = false;
    try {
        assert.ok(false);
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("assert.ok(false) did not throw"); }
});

// ── assert.equal / notEqual ─────────────────────────────────────────────────

test("assert.equal(1, 1) does not throw", function() {
    assert.equal(1, 1);
});

test("assert.equal(1, 1) does not throw", function() {
    assert.equal(1, 1);
});

test("assert.equal(1, 2) throws", function() {
    var threw = false;
    try {
        assert.equal(1, 2);
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "==");
    }
    if (!threw) { throw new Error("assert.equal(1, 2) did not throw"); }
});

test("assert.notEqual(1, 2) does not throw", function() {
    assert.notEqual(1, 2);
});

test("assert.notEqual(1, 1) throws", function() {
    var threw = false;
    try {
        assert.notEqual(1, 1);
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "!=");
    }
    if (!threw) { throw new Error("assert.notEqual(1, 1) did not throw"); }
});

// ── assert.strictEqual / notStrictEqual ─────────────────────────────────────

test("assert.strictEqual(1, 1) does not throw", function() {
    assert.strictEqual(1, 1);
});

test("assert.strictEqual('a', 'a') does not throw", function() {
    assert.strictEqual("a", "a");
});

test("assert.strictEqual(1, '1') throws", function() {
    var threw = false;
    try {
        assert.strictEqual(1, "1");
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "===");
        assert.strictEqual(e.actual, 1);
        assert.strictEqual(e.expected, "1");
    }
    if (!threw) { throw new Error("assert.strictEqual(1, '1') did not throw"); }
});

test("assert.strictEqual(1, 2) throws", function() {
    var threw = false;
    try {
        assert.strictEqual(1, 2);
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("assert.notStrictEqual(1, '1') does not throw", function() {
    assert.notStrictEqual(1, "1");
});

test("assert.notStrictEqual(1, 1) throws", function() {
    var threw = false;
    try {
        assert.notStrictEqual(1, 1);
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "!==");
    }
    if (!threw) { throw new Error("did not throw"); }
});

// ── assert.deepEqual / deepStrictEqual / notDeep* ───────────────────────────

test("assert.deepEqual({a:1}, {a:1}) does not throw", function() {
    assert.deepEqual({a: 1}, {a: 1});
});

test("assert.deepEqual({a:1}, {a:2}) throws", function() {
    var threw = false;
    try {
        assert.deepEqual({a: 1}, {a: 2});
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "deepEqual");
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("assert.deepStrictEqual([1,2,3], [1,2,3]) does not throw", function() {
    assert.deepStrictEqual([1, 2, 3], [1, 2, 3]);
});

test("assert.deepStrictEqual({x:'y'}, {x:'y'}) does not throw", function() {
    assert.deepStrictEqual({x: "y"}, {x: "y"});
});

test("assert.deepStrictEqual([1], [2]) throws", function() {
    var threw = false;
    try {
        assert.deepStrictEqual([1], [2]);
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "deepStrictEqual");
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("assert.notDeepEqual({a:1}, {a:2}) does not throw", function() {
    assert.notDeepEqual({a: 1}, {a: 2});
});

test("assert.notDeepEqual({a:1}, {a:1}) throws", function() {
    var threw = false;
    try {
        assert.notDeepEqual({a: 1}, {a: 1});
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("assert.notDeepStrictEqual([1], [2]) does not throw", function() {
    assert.notDeepStrictEqual([1], [2]);
});

test("assert.notDeepStrictEqual([1], [1]) throws", function() {
    var threw = false;
    try {
        assert.notDeepStrictEqual([1], [1]);
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("did not throw"); }
});

// ── assert.throws / doesNotThrow ────────────────────────────────────────────

test("assert.throws catches expected exception", function() {
    assert.throws(function() {
        throw new Error("boom");
    });
});

test("assert.throws with validator function", function() {
    assert.throws(
        function() { throw new Error("boom"); },
        function(err) { return err.message === "boom"; }
    );
});

test("assert.throws with Error constructor", function() {
    assert.throws(
        function() { throw new Error("oops"); },
        Error
    );
});

test("assert.throws throws when no exception", function() {
    var threw = false;
    try {
        assert.throws(function() { /* no throw */ });
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "throws");
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("assert.doesNotThrow with non-throwing function", function() {
    assert.doesNotThrow(function() {
        var x = 42;
    });
});

test("assert.doesNotThrow throws when function throws", function() {
    var threw = false;
    try {
        assert.doesNotThrow(function() {
            throw new Error("unexpected");
        });
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "doesNotThrow");
    }
    if (!threw) { throw new Error("did not throw"); }
});

// ── assert.ifError ──────────────────────────────────────────────────────────

test("assert.ifError(null) does not throw", function() {
    assert.ifError(null);
});

test("assert.ifError(undefined) does not throw", function() {
    assert.ifError(undefined);
});

test("assert.ifError(new Error('x')) throws", function() {
    var threw = false;
    try {
        assert.ifError(new Error("x"));
    } catch (e) {
        threw = true;
        assert.strictEqual(e.operator, "ifError");
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("assert.ifError(1) throws", function() {
    var threw = false;
    try {
        assert.ifError(1);
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("did not throw"); }
});

// ── assert.fail ─────────────────────────────────────────────────────────────

test("assert.fail() always throws", function() {
    var threw = false;
    try {
        assert.fail();
    } catch (e) {
        threw = true;
        assert.strictEqual(e.name, "AssertionError");
        assert.strictEqual(e.operator, "fail");
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("assert.fail('custom msg') throws with message", function() {
    var threw = false;
    try {
        assert.fail("custom msg");
    } catch (e) {
        threw = true;
        assert.strictEqual(e.message, "custom msg");
    }
    if (!threw) { throw new Error("did not throw"); }
});

// ── AssertionError properties ───────────────────────────────────────────────

test("AssertionError has actual, expected, operator", function() {
    var threw = false;
    try {
        assert.strictEqual(1, 2);
    } catch (e) {
        threw = true;
        assert.strictEqual(e.actual, 1);
        assert.strictEqual(e.expected, 2);
        assert.strictEqual(e.operator, "===");
        assert.strictEqual(e.name, "AssertionError");
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("AssertionError is instanceof Error", function() {
    var threw = false;
    try {
        assert.fail("test");
    } catch (e) {
        threw = true;
        assert.ok(e instanceof Error);
    }
    if (!threw) { throw new Error("did not throw"); }
});

test("AssertionError with custom message", function() {
    var threw = false;
    try {
        assert.strictEqual(1, 2, "values must match");
    } catch (e) {
        threw = true;
        assert.strictEqual(e.message, "values must match");
    }
    if (!threw) { throw new Error("did not throw"); }
});

// ── assert.strict ───────────────────────────────────────────────────────────

test("assert.strict is the assert function", function() {
    assert.strictEqual(typeof assert.strict, "function");
});

test("assert.strict.equal is strictEqual", function() {
    assert.strictEqual(assert.strict.equal, assert.strictEqual);
});

test("assert.strict.deepEqual is deepStrictEqual", function() {
    assert.strictEqual(assert.strict.deepEqual, assert.deepStrictEqual);
});

// ── require with node: prefix ───────────────────────────────────────────────

test("require('node:assert') works", function() {
    var assert2 = require("node:assert");
    assert.strictEqual(typeof assert2, "function");
    assert.strictEqual(typeof assert2.strictEqual, "function");
});

// ── Edge cases ──────────────────────────────────────────────────────────────

test("assert(null) throws", function() {
    var threw = false;
    try {
        assert(null);
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("assert(null) should throw"); }
});

test("assert(undefined) throws", function() {
    var threw = false;
    try {
        assert(undefined);
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("assert(undefined) should throw"); }
});

test("assert('') throws (empty string is falsy)", function() {
    var threw = false;
    try {
        assert("");
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("assert('') should throw"); }
});

test("assert.strictEqual(null, null) does not throw", function() {
    assert.strictEqual(null, null);
});

test("assert.strictEqual(undefined, undefined) does not throw", function() {
    assert.strictEqual(undefined, undefined);
});

test("assert.deepStrictEqual nested objects", function() {
    assert.deepStrictEqual(
        {a: {b: {c: 1}}},
        {a: {b: {c: 1}}}
    );
});

test("assert.deepStrictEqual nested objects mismatch throws", function() {
    var threw = false;
    try {
        assert.deepStrictEqual(
            {a: {b: {c: 1}}},
            {a: {b: {c: 2}}}
        );
    } catch (e) {
        threw = true;
    }
    if (!threw) { throw new Error("did not throw"); }
});

console.log("=== assert tests: " + passed + " passed, " + failed + " failed ===");
