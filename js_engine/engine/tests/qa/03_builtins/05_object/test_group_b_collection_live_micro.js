// Group B root-cause micros — live Map/Set iteration and iterator closing.

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_group_b_collection_live_micro.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

(function map_iterator_observes_appended_entries() {
  var map = new Map([["a", 1], ["b", 2]]);
  var iterator = map.keys();
  assertEq(iterator.next().value, "a", "GB-MAP-LIVE-001: first key");
  map.delete("b");
  map.set("c", 3);
  assertEq(iterator.next().value, "c", "GB-MAP-LIVE-001: skips deleted and sees appended");
  assertEq(iterator.next().done, true, "GB-MAP-LIVE-001: iterator completes");
})();

(function set_delete_reinsert_moves_to_tail() {
  var set = new Set(["a", "b"]);
  var iterator = set.values();
  assertEq(iterator.next().value, "a", "GB-SET-LIVE-001: first value");
  set.delete("b");
  set.add("b");
  assertEq(iterator.next().value, "b", "GB-SET-LIVE-001: reinserted value visited at tail");
  assertEq(iterator.next().done, true, "GB-SET-LIVE-001: iterator completes");
})();

(function map_constructor_gets_adder_once() {
  var gets = 0;
  var original = Object.getOwnPropertyDescriptor(Map.prototype, "set");
  Object.defineProperty(Map.prototype, "set", {
    configurable: true,
    get: function () {
      gets++;
      return function (key, value) {
        return original.value.call(this, key, value);
      };
    }
  });
  try {
    var map = new Map([[1, 2], [3, 4]]);
    assertEq(map.size, 2, "GB-MAP-CTOR-001: entries consumed");
    assertEq(gets, 1, "GB-MAP-CTOR-001: adder retrieved once");
  } finally {
    Object.defineProperty(Map.prototype, "set", original);
  }
})();

(function map_iterator_done_latch() {
  var map = new Map([["a", 1]]);
  var it = map.keys();
  assertEq(it.next().value, "a", "GB-MAP-DONE-001: first");
  assertEq(it.next().done, true, "GB-MAP-DONE-001: exhausted");
  map.set("b", 2);
  assertEq(it.next().done, true, "GB-MAP-DONE-001: stays done after append");
})();

(function set_iterator_done_latch() {
  var set = new Set(["a"]);
  var it = set.values();
  assertEq(it.next().value, "a", "GB-SET-DONE-001: first");
  assertEq(it.next().done, true, "GB-SET-DONE-001: exhausted");
  set.add("b");
  assertEq(it.next().done, true, "GB-SET-DONE-001: stays done after append");
})();

(function map_foreach_is_live() {
  var map = new Map([["a", 1]]);
  var seen = [];
  map.forEach(function (v, k) {
    seen.push(k);
    if (k === "a") map.set("b", 2);
  });
  assertEq(seen.join(","), "a,b", "GB-MAP-FOREACH-001: sees appended entry");
})();

(function set_foreach_is_live() {
  var set = new Set(["a"]);
  var seen = [];
  set.forEach(function (v) {
    seen.push(v);
    if (v === "a") set.add("b");
  });
  assertEq(seen.join(","), "a,b", "GB-SET-FOREACH-001: sees appended value");
})();

(function map_size_and_tostringtag() {
  var desc = Object.getOwnPropertyDescriptor(Map.prototype, "size");
  assertEq(typeof desc.get, "function", "GB-MAP-SIZE-001: size is accessor");
  assertEq(desc.enumerable, false, "GB-MAP-SIZE-001: size non-enumerable");
  assertEq(desc.configurable, true, "GB-MAP-SIZE-001: size configurable");
  assertEq(Map.prototype[Symbol.toStringTag], "Map", "GB-MAP-TAG-001: @@toStringTag");
  assertEq(new Map([[1, 2]]).size, 1, "GB-MAP-SIZE-001: instance size");
})();

(function set_algebra_plain_set() {
  class MySet extends Set {}
  var a = new MySet([1, 2]);
  var b = new Set([2, 3]);
  var u = a.union(b);
  assertEq(u instanceof Set, true, "GB-SET-ALG-001: union is Set");
  assertEq(u instanceof MySet, false, "GB-SET-ALG-001: union is not subclass");
  assertEq(u.size, 3, "GB-SET-ALG-001: union size");
})();

(function weakmap_iterable_constructor() {
  var k1 = {};
  var k2 = {};
  var wm = new WeakMap([[k1, 1], [k2, 2]]);
  assertEq(wm.get(k1), 1, "GB-WM-CTOR-001: first entry");
  assertEq(wm.get(k2), 2, "GB-WM-CTOR-001: second entry");
  var threw = false;
  try { new WeakMap(1); } catch (e) { threw = e instanceof TypeError; }
  assertEq(threw, true, "GB-WM-CTOR-001: non-iterable throws");
})();

(function map_ctor_closes_on_set_failure() {
  var closed = 0;
  var iterable = {
    [Symbol.iterator]: function () {
      return {
        next: function () { return { value: [], done: false }; },
        return: function () { closed += 1; return { done: true }; }
      };
    }
  };
  var original = Map.prototype.set;
  Map.prototype.set = function () { throw new Error("set-fail"); };
  var threw = false;
  try { new Map(iterable); } catch (e) { threw = e.message === "set-fail"; }
  Map.prototype.set = original;
  assertEq(threw, true, "GB-MAP-CLOSE-001: set failure throws");
  assertEq(closed, 1, "GB-MAP-CLOSE-001: iterator closed");
})();

(function map_ctor_preserves_set_error_over_return() {
  var iterable = {
    [Symbol.iterator]: function () {
      return {
        next: function () { return { value: [], done: false }; },
        return: function () { throw new TypeError("ignore"); }
      };
    }
  };
  var original = Map.prototype.set;
  Map.prototype.set = function () { throw new Error("primary"); };
  var msg = null;
  try { new Map(iterable); } catch (e) { msg = e.message; }
  Map.prototype.set = original;
  assertEq(msg, "primary", "GB-MAP-CLOSE-002: primary error wins over return()");
})();

(function map_getorinsert() {
  var m = new Map();
  assertEq(m.getOrInsert("a", 1), 1, "GB-MAP-GOI-001: inserts");
  assertEq(m.getOrInsert("a", 9), 1, "GB-MAP-GOI-001: returns existing");
  assertEq(m.getOrInsertComputed("b", function (k) { return k + "!"; }), "b!", "GB-MAP-GOI-002: computed");
  assertEq(m.getOrInsertComputed("b", function () { return "nope"; }), "b!", "GB-MAP-GOI-002: computed existing");
})();

(function set_algebra_setrecord_keys() {
  var calls = 0;
  var other = {
    size: 2,
    has: function (v) { return v === 2 || v === 3; },
    keys: function () {
      calls++;
      var i = 0;
      var vals = [2, 3];
      return {
        next: function () {
          if (i < vals.length) return { value: vals[i++], done: false };
          return { done: true };
        }
      };
    }
  };
  var s = new Set([1, 2]);
  var u = s.union(other);
  assertEq(calls, 1, "GB-SET-REC-001: keys retrieved");
  assertEq(u instanceof Set, true, "GB-SET-REC-001: plain Set");
  assertEq(u.size, 3, "GB-SET-REC-001: union size");
})();

(function unbound_brand_checks() {
  var threw = false;
  try { Map.prototype.get.call({}, 1); } catch (e) { threw = e instanceof TypeError; }
  assertEq(threw, true, "GB-BRAND-001: Map.get brand");
  threw = false;
  try { Set.prototype.has.call([], 1); } catch (e) { threw = e instanceof TypeError; }
  assertEq(threw, true, "GB-BRAND-002: Set.has brand");
  var sizeDesc = Object.getOwnPropertyDescriptor(Set.prototype, "size");
  assertEq(typeof sizeDesc.get, "function", "GB-BRAND-003: Set.size accessor");
  assertEq(sizeDesc.enumerable, false, "GB-BRAND-003: Set.size non-enumerable");
  assertEq(Set.prototype[Symbol.toStringTag], "Set", "GB-BRAND-004: Set @@toStringTag");
})();

(function weakset_iterable_constructor() {
  var o1 = {};
  var o2 = {};
  var ws = new WeakSet([o1, o2]);
  assertEq(ws.has(o1), true, "GB-WS-CTOR-001: first");
  assertEq(ws.has(o2), true, "GB-WS-CTOR-001: second");
  var threw = false;
  try { new WeakSet(1); } catch (e) { threw = e instanceof TypeError; }
  assertEq(threw, true, "GB-WS-CTOR-001: non-iterable throws");
})();

(function weakmap_ctor_gets_set_once() {
  var gets = 0;
  var original = Object.getOwnPropertyDescriptor(WeakMap.prototype, "set");
  Object.defineProperty(WeakMap.prototype, "set", {
    configurable: true,
    get: function () {
      gets++;
      return function (key, value) {
        return original.value.call(this, key, value);
      };
    }
  });
  try {
    var k1 = {};
    var k2 = {};
    var wm = new WeakMap([[k1, 1], [k2, 2]]);
    assertEq(wm.get(k1), 1, "GB-WM-ADDER-001: entries");
    assertEq(gets, 1, "GB-WM-ADDER-001: set retrieved once");
  } finally {
    Object.defineProperty(WeakMap.prototype, "set", original);
  }
})();

(function map_has_same_value_zero() {
  var m = new Map();
  m.set(-0, "neg");
  assertEq(m.has(0), true, "GB-MAP-SVZ-001: +0 finds -0");
  assertEq(m.has(-0), true, "GB-MAP-SVZ-001: -0 finds -0");
  m.set(NaN, "nan");
  assertEq(m.has(NaN), true, "GB-MAP-SVZ-001: NaN");
})();

(function map_distinct_number_boolean_keys() {
  var m = new Map([[1, "one"], [true, "bool"]]);
  assertEq(m.size, 2, "GB-MAP-KEY-001: distinct primitive keys");
  assertEq(m.get(1), "one", "GB-MAP-KEY-001: get 1");
  assertEq(m.get(true), "bool", "GB-MAP-KEY-001: get true");
})();

(function weakmap_symbol_for_rejects_before_callback() {
  var calls = 0;
  var threw = false;
  try {
    WeakMap.prototype.getOrInsertComputed.call(new WeakMap(), 1, function () {
      calls++;
      return 1;
    });
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assertEq(threw, true, "GB-WM-GOI-001: CanBeHeldWeakly before callback");
  assertEq(calls, 0, "GB-WM-GOI-001: callback not invoked");
})();

(function weakmap_symbol_for_rejects_computed() {
  var calls = 0;
  var threw = false;
  try {
    WeakMap.prototype.getOrInsertComputed.call(new WeakMap(), Symbol.for("x"), function () {
      calls++;
      return 1;
    });
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assertEq(threw, true, "GB-WM-GOI-002: Symbol.for rejected");
  assertEq(calls, 0, "GB-WM-GOI-002: callback not invoked");
})();

(function setrecord_keys_drain() {
  var nextCalls = 0;
  var other = {
    size: 1,
    has: function () { return false; },
    keys: function () {
      var i = 0;
      return {
        next: function () {
          nextCalls++;
          if (i++ < 1) return { value: 99, done: false };
          return { done: true };
        }
      };
    }
  };
  // O.size (3) > other.size (1) → keys() path must drain to done.
  var s = new Set([1, 2, 3]);
  assertEq(s.isDisjointFrom(other), true, "GB-SET-DRAIN-001: disjoint");
  assertEq(nextCalls >= 2, true, "GB-SET-DRAIN-001: keys drained to done");
})();

(function set_union_drains_extra_keys() {
  // ES union consumes keys until done (size is not an add-cap); hang kit uses step ceiling.
  var extraNext = 0;
  var other = {
    size: 1,
    has: function (v) { return v === 2; },
    keys: function () {
      var i = 0;
      return {
        next: function () {
          extraNext++;
          if (i === 0) { i++; return { value: 2, done: false }; }
          if (i === 1) { i++; return { value: 3, done: false }; }
          return { done: true };
        }
      };
    }
  };
  var u = new Set([1]).union(other);
  assertEq(u.size, 3, "GB-SET-DRAIN-002: union adds all yielded keys");
  assertEq(extraNext >= 3, true, "GB-SET-DRAIN-002: union drains keys iterator");
})();

(function set_like_keys_next_cached_once() {
  var nextGets = 0;
  var other = {
    size: 2,
    has: function (v) { return v === 2 || v === 3; },
    keys: function () {
      var i = 0;
      var vals = [2, 3];
      return {
        get next() {
          nextGets++;
          var self = this;
          return function () {
            if (i < vals.length) return { value: vals[i++], done: false };
            return { done: true };
          };
        }
      };
    }
  };
  var u = new Set([1]).union(other);
  assertEq(u.size, 3, "GB-SET-NEXT-001: union size");
  assertEq(nextGets, 1, "GB-SET-NEXT-001: [[NextMethod]] cached (one Get of next)");
})();

__jacDone();
