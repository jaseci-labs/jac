// Spread of a user iterable whose iterator throws — the exception must propagate
// (ReturnIfAbrupt), not spin into an infinite loop / OOM. Regression coverage for
// the A12 fix in _op_spread: previously a next() (or [Symbol.iterator]()) that threw
// left the drain loop's `done` flag false forever, allocating undefined until the
// process exhausted memory. Covers array-literal spread, call spread, and new spread.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/15_iteration/test_iteration_spread_throwing_iterator.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// A marker error type so we can distinguish the propagated throw from an engine error.
function Boom(tag) { this.tag = tag; }

// Iterable whose next() throws on the first step.
function makeNextThrows(tag) {
  var o = {};
  o[Symbol.iterator] = function () {
    return { next: function () { throw new Boom(tag); } };
  };
  return o;
}

// Iterable whose [Symbol.iterator]() itself throws.
function makeIterThrows(tag) {
  var o = {};
  o[Symbol.iterator] = function () { throw new Boom(tag); };
  return o;
}

// ── §1 next() throws — array-literal spread ────────────────────────────────
(function () {
  var threw = false;
  try {
    var a = [0, ...makeNextThrows("arr-next")];
    assert(false, "array spread: should have thrown, got length " + a.length);
  } catch (e) {
    threw = e instanceof Boom && e.tag === "arr-next";
  }
  assert(threw, "array-literal spread propagates next() throw");
})();

// ── §2 next() throws — call spread ─────────────────────────────────────────
(function () {
  function f() { return arguments.length; }
  var threw = false;
  try {
    f(0, ...makeNextThrows("call-next"));
    assert(false, "call spread: should have thrown");
  } catch (e) {
    threw = e instanceof Boom && e.tag === "call-next";
  }
  assert(threw, "call spread propagates next() throw");
})();

// ── §3 next() throws — new spread ──────────────────────────────────────────
(function () {
  function C() {}
  var threw = false;
  try {
    new C(0, ...makeNextThrows("new-next"));
    assert(false, "new spread: should have thrown");
  } catch (e) {
    threw = e instanceof Boom && e.tag === "new-next";
  }
  assert(threw, "new spread propagates next() throw");
})();

// ── §4 [Symbol.iterator]() throws — array-literal spread ───────────────────
(function () {
  var threw = false;
  try {
    var a = [...makeIterThrows("arr-iter")];
    assert(false, "array spread: should have thrown on iterator-getter");
  } catch (e) {
    threw = e instanceof Boom && e.tag === "arr-iter";
  }
  assert(threw, "array-literal spread propagates [Symbol.iterator]() throw");
})();

// ── §5 super(...iterable) where next() throws — throw must escape ctor ──────
(function () {
  var iter = makeNextThrows("super-next");
  class Parent { constructor() {} }
  class Child extends Parent {
    constructor() { super(0, ...iter); }
  }
  var threw = false;
  try {
    new Child();
    assert(false, "super spread: should have thrown");
  } catch (e) {
    threw = e instanceof Boom && e.tag === "super-next";
  }
  assert(threw, "super(...) spread propagates next() throw");
})();

// ── §6 Regression guard: normal (non-throwing) spreads still work ──────────
(function () {
  var s = new Set([1, 2, 3]);
  assertEq([0, ...s, 4].join(","), "0,1,2,3,4", "normal Set spread in array literal");

  function* g() { yield 1; yield 2; }
  assertEq([...g()].join(","), "1,2", "normal generator spread");

  function sum() {
    var t = 0;
    for (var i = 0; i < arguments.length; i++) t += arguments[i];
    return t;
  }
  assertEq(sum(...[1, 2, 3, 4]), 10, "normal call spread");

  // A custom iterable that completes normally must drain fully.
  var custom = {};
  custom[Symbol.iterator] = function () {
    var i = 0;
    return { next: function () { return i < 3 ? { value: i++, done: false } : { value: undefined, done: true }; } };
  };
  assertEq([...custom].join(","), "0,1,2", "normal custom iterable spread");
})();

// ── §7 A throw mid-iteration (after some values) still propagates ──────────
(function () {
  var partial = {};
  partial[Symbol.iterator] = function () {
    var i = 0;
    return {
      next: function () {
        if (i < 2) return { value: i++, done: false };
        throw new Boom("mid");
      }
    };
  };
  var threw = false;
  try {
    var a = [...partial];
    assert(false, "mid-iteration spread: should have thrown, got length " + a.length);
  } catch (e) {
    threw = e instanceof Boom && e.tag === "mid";
  }
  assert(threw, "spread propagates a throw that occurs mid-iteration");
})();

__jacDone();
