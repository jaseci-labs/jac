// Group B root-cause micro — IteratorClose on abrupt completion

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_group_b_iterator_close_micro.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

(function map_ctor_closes_on_set_throw() {
  var closed2 = false;
  var badIter = {
    [Symbol.iterator]() { return this; },
    n: 0,
    next() {
      if (this.n++ === 0) return { value: "not-entry", done: false };
      return { value: undefined, done: true };
    },
    return() {
      closed2 = true;
      return { value: undefined, done: true };
    }
  };
  try { new Map(badIter); } catch (_) {}
  assert(closed2, "GB-ITER-001: Map constructor closes iterator on bad entry");
})();

(function map_ctor_closes_on_entry_get_abrupt() {
  var closed = 0;
  var item = ["foo", "bar"];
  Object.defineProperty(item, "0", {
    get: function () { throw new Error("entry0"); }
  });
  var iterable = {
    [Symbol.iterator]: function () {
      return {
        next: function () { return { value: item, done: false }; },
        return: function () { closed += 1; return { done: true }; }
      };
    }
  };
  var threw = false;
  try { new Map(iterable); } catch (e) { threw = e.message === "entry0"; }
  assert(threw, "GB-ITER-003: entry Get abrupt throws");
  assertEq(closed, 1, "GB-ITER-003: IteratorClose on entry abrupt");
})();

(function map_ctor_next_failure_no_close() {
  var closed = 0;
  var iterable = {
    [Symbol.iterator]: function () {
      return {
        next: function () { throw new Error("next-boom"); },
        return: function () { closed += 1; return { done: true }; }
      };
    }
  };
  var threw = false;
  try { new Map(iterable); } catch (e) { threw = e.message === "next-boom"; }
  assert(threw, "GB-ITER-004: next failure throws");
  assertEq(closed, 0, "GB-ITER-004: no IteratorClose on next throw");
})();

(function set_ctor_closes_on_add_failure() {
  var closed = 0;
  var iterable = {
    [Symbol.iterator]: function () {
      return {
        next: function () { return { value: 1, done: false }; },
        return: function () { closed += 1; return { done: true }; }
      };
    }
  };
  var original = Set.prototype.add;
  Set.prototype.add = function () { throw new Error("add-fail"); };
  var threw = false;
  try { new Set(iterable); } catch (e) { threw = e.message === "add-fail"; }
  Set.prototype.add = original;
  assert(threw, "GB-ITER-005: Set add failure throws");
  assertEq(closed, 1, "GB-ITER-005: Set IteratorClose on add failure");
})();

(function array_from_throws_before_materializing() {
  var steps = 0;
  var iter = {
    [Symbol.iterator]() { return this; },
    next() {
      steps++;
      if (steps === 3) throw new RangeError("boom");
      return { value: steps, done: false };
    }
  };
  try {
    Array.from(iter);
  } catch (e) {
    assertEq(e.message, "boom", "GB-ITER-002: abrupt from sync iterator");
    assertEq(steps, 3, "GB-ITER-002: stopped at throw");
  }
})();

(function frozen_length_push_throws() {
  var a = [1, 2];
  Object.freeze(a);
  var threw = false;
  try { a.push(3); } catch (e) { threw = e instanceof TypeError; }
  assert(threw, "GB-ARR-LEN-001: push on frozen length throws TypeError");
  assertEq(a.length, 2, "GB-ARR-LEN-001: length unchanged");
})();

(function frozen_length_unshift_throws() {
  var a = [1, 2];
  Object.freeze(a);
  var threw = false;
  try { a.unshift(0); } catch (e) { threw = e instanceof TypeError; }
  assert(threw, "GB-ARR-LEN-002: unshift on frozen length throws TypeError");
  assertEq(a.length, 2, "GB-ARR-LEN-002: length unchanged");
})();

(function frozen_length_pop_throws() {
  var a = [1, 2];
  Object.freeze(a);
  var threw = false;
  try { a.pop(); } catch (e) { threw = e instanceof TypeError; }
  assert(threw, "GB-ARR-LEN-003: pop on frozen length throws TypeError");
  assertEq(a.length, 2, "GB-ARR-LEN-003: length unchanged");
})();

(function frozen_length_shift_throws() {
  var a = [1, 2];
  Object.freeze(a);
  var threw = false;
  try { a.shift(); } catch (e) { threw = e instanceof TypeError; }
  assert(threw, "GB-ARR-LEN-004: shift on frozen length throws TypeError");
  assertEq(a.length, 2, "GB-ARR-LEN-004: length unchanged");
})();

(function map_distinct_number_and_boolean_keys() {
  var m = new Map();
  m.set(1, "one");
  m.set(true, "bool");
  assertEq(m.size, 2, "GB-MAP-KEY-001: 1 and true are distinct");
  assertEq(m.get(1), "one", "GB-MAP-KEY-001: number key");
  assertEq(m.get(true), "bool", "GB-MAP-KEY-001: boolean key");
})();

(function string_object_iterator_chars() {
  // fromAsync boxes strings via ToObject; String exotic must yield code points.
  var chars = Array.from(Object("xy"));
  assertEq(chars.join(""), "xy", "GB-STR-ITER-001: String object yields characters");
})();

(function weakmap_ctor_closes_on_set_failure() {
  var closed = 0;
  var iterable = {
    [Symbol.iterator]: function () {
      return {
        next: function () { return { value: [{}], done: false }; },
        return: function () { closed += 1; return { done: true }; }
      };
    }
  };
  var original = WeakMap.prototype.set;
  WeakMap.prototype.set = function () { throw new Error("wm-set-fail"); };
  var threw = false;
  try { new WeakMap(iterable); } catch (e) { threw = e.message === "wm-set-fail"; }
  WeakMap.prototype.set = original;
  assert(threw, "GB-WM-CLOSE-001: set failure throws");
  assertEq(closed, 1, "GB-WM-CLOSE-001: IteratorClose on set failure");
})();

(function array_species_non_constructor_throws() {
  // ArraySpeciesCreate path (slice/map/…) — toReversed uses ArrayCreate and ignores species.
  var a = [1, 2];
  Object.defineProperty(a, "constructor", {
    configurable: true,
    value: { [Symbol.species]: Math.sin }
  });
  var threw = false;
  try { a.slice(); } catch (e) { threw = e instanceof TypeError; }
  assert(threw, "GB-ARR-SPC-001: non-constructor species throws");
})();

(function fromAsync_getmethod_async_reject_and_close() {
  if (typeof Array.fromAsync !== "function") {
    assert(true, "GB-FA-002: Array.fromAsync unavailable — skip");
    __jacDone();
    return;
  }
  var oAsync = {};
  Object.defineProperty(oAsync, Symbol.asyncIterator, { value: 1, configurable: true });
  Array.fromAsync(oAsync).then(
    function () {
      console.error("FAIL: GB-FA-002: expected async rejection");
      __reg.bump();
      return Promise.reject(new Error("abort"));
    },
    function (e) {
      assert(e instanceof TypeError, "GB-FA-002: non-callable @@asyncIterator rejects");
      // GetMethod: nullish @@iterator falls through to array-like; use a
      // non-callable non-nullish value to force async TypeError reject.
      var oSync = { length: 1, 0: 99 };
      Object.defineProperty(oSync, Symbol.iterator, { value: 1, configurable: true });
      return Array.fromAsync(oSync);
    }
  ).then(
    function () {
      console.error("FAIL: GB-FA-003: expected async rejection");
      __reg.bump();
      return Promise.reject(new Error("abort"));
    },
    function (e) {
      assert(e instanceof TypeError, "GB-FA-003: non-callable @@iterator rejects (not array-like)");
      var closed = false;
      var iterator = {
        next: function () { return { value: 1, done: false }; },
        return: function () { closed = true; return { done: true }; },
        [Symbol.iterator]: function () { return this; }
      };
      return Array.fromAsync(iterator, async function () {
        throw new Error("mapfn throws");
      }).then(
        function () {
          console.error("FAIL: GB-FA-001: expected rejection");
          __reg.bump();
        },
        function () {
          assert(closed, "GB-FA-001: async mapfn reject closes sync iterator");
        }
      );
    }
  ).then(function () { __jacDone(); }, function () { __jacDone(); });
})();
