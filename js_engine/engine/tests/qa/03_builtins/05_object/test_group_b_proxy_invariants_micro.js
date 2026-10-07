// Group B root-cause micro — Proxy defineProperty / set / get / has / seal invariants

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_group_b_proxy_invariants_micro.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, Ctor, id) {
  try {
    fn();
    console.error("FAIL: " + id + ": expected " + Ctor.name);
    __reg.bump();
  } catch (err) {
    if (!(err instanceof Ctor)) {
      console.error("FAIL: " + id + ": wrong error | expected " + Ctor.name + " | got " + err);
      __reg.bump();
    }
  }
}

(function define_nonconfigurable_redefine_throws() {
  var t = {};
  Object.defineProperty(t, "x", { value: 1, writable: false, enumerable: true, configurable: false });
  var threw = false;
  try {
    Object.defineProperty(t, "x", { value: 2, writable: false, enumerable: true, configurable: false });
  } catch (e) {
    threw = true;
  }
  assert(threw, "GB-PROXY-001: redefining non-configurable data property throws");
})();

(function reflect_set_accessor_on_receiver() {
  var got = null;
  var target = {};
  Object.defineProperty(target, "x", {
    set(v) { got = v; },
    configurable: true,
    enumerable: true
  });
  var receiver = {};
  assertEq(Reflect.set(target, "x", 9, receiver), true, "GB-PROXY-002: Reflect.set returns true");
  assertEq(got, 9, "GB-PROXY-002: setter invoked with value");
})();

(function nested_proxy_get_null_trap() {
  var plain = { foo: 2 };
  Object.defineProperty(plain, "0", { get() { return 1; }, configurable: true });
  var mid = new Proxy(plain, {});
  var outer = new Proxy(mid, { get: undefined });
  assertEq(outer.foo, 2, "GB-PROXY-003: nested get forwards to target proxy");
  assertEq(Object.create(outer)[0], 1, "GB-PROXY-003: get via prototype chain hits nested proxy");
})();

(function nested_proxy_define_null_trap() {
  var arr = [];
  var mid = new Proxy(arr, {});
  var outer = new Proxy(mid, { defineProperty: undefined });
  Object.defineProperty(outer, "0", { value: 1 });
  assertEq(arr[0], 1, "GB-PROXY-004: nested defineProperty forwards into array target");
})();

(function get_accessor_without_get_throws() {
  var target = {};
  Object.defineProperty(target, "attr", { configurable: false, get: undefined });
  var p = new Proxy(target, { get() { return 2; } });
  assertThrows(function () { return p.attr; }, TypeError, "GB-PROXY-005");
})();

(function has_false_on_nonextensible_throws() {
  var target = {};
  Object.defineProperty(target, "attr", { configurable: true, value: 1 });
  Object.preventExtensions(target);
  var p = new Proxy(target, { has() { return false; } });
  assertThrows(function () { return "attr" in p; }, TypeError, "GB-PROXY-006");
})();

(function set_via_proxy_prototype_forwards() {
  var seen = null;
  var target = {};
  var proxy = new Proxy(target, {
    set(t, prop, value, receiver) {
      seen = { prop: prop, value: value, receiver: receiver, this: this };
      return true;
    }
  });
  var receiver = Object.create(proxy);
  receiver.prop = "value";
  assert(seen !== null, "GB-PROXY-007: set trap invoked via OrdinarySet prototype walk");
  assertEq(seen.prop, "prop", "GB-PROXY-007: property name");
  assertEq(seen.value, "value", "GB-PROXY-007: value");
  assertEq(seen.receiver, receiver, "GB-PROXY-007: receiver");
})();

(function set_dunder_proto_via_proxy_prototype() {
  var seenProp = null;
  var target = {};
  var proxy = new Proxy(target, {
    set(t, prop, value, receiver) {
      seenProp = prop;
      return true;
    }
  });
  var receiver = Object.create(proxy);
  var prop = "__proto__";
  var value = {};
  receiver[prop] = value;
  assertEq(seenProp, "__proto__", "GB-PROXY-008: __proto__ forwarded as property name to set trap");
})();

(function reflect_define_abrupt_property_key() {
  var p = {
    toString: function () { throw new Error("abrupt-key"); }
  };
  var threw = false;
  try {
    Reflect.defineProperty({}, p);
  } catch (e) {
    threw = e instanceof Error && e.message === "abrupt-key";
  }
  assert(threw, "GB-PROXY-009: Reflect.defineProperty abrupt ToPropertyKey with 2 args");
})();

(function seal_preserves_accessor_enumerable() {
  var obj = {};
  Object.defineProperty(obj, "foo", {
    get: function () { return 10; },
    set: function () {},
    enumerable: true,
    configurable: true
  });
  Object.seal(obj);
  var d = Object.getOwnPropertyDescriptor(obj, "foo");
  assertEq(d.enumerable, true, "GB-PROXY-010: seal preserves accessor enumerable");
  assertEq(d.configurable, false, "GB-PROXY-010: seal clears accessor configurable");
  var found = false;
  for (var k in obj) {
    if (k === "foo") found = true;
  }
  assert(found, "GB-PROXY-010: for-in enumerates sealed accessor");
})();

(function own_keys_extensible_trap_result() {
  var p = new Proxy({ attr: 42 }, {
    ownKeys: function () { return ["foo", "bar"]; }
  });
  var keys = Object.getOwnPropertyNames(p);
  assertEq(keys[0], "foo", "GB-PROXY-011: getOwnPropertyNames uses ownKeys trap");
  assertEq(keys[1], "bar", "GB-PROXY-011: second key");
  assertEq(keys.length, 2, "GB-PROXY-011: length");
})();

(function nested_proxy_apply_generator() {
  function* sum(arg) {
    yield this.foo;
    yield arg;
  }
  var mid = new Proxy(sum, {});
  var outer = new Proxy(mid, { apply: undefined });
  var gen = Reflect.apply(outer, { foo: 10 }, [1]);
  var out = Array.from(gen);
  assertEq(out[0], 10, "GB-PROXY-012: nested apply forwards generator this");
  assertEq(out[1], 1, "GB-PROXY-012: nested apply forwards generator arg");
})();

(function get_accessor_without_get_bracket() {
  var target = {};
  Object.defineProperty(target, "attr", { configurable: false, get: undefined });
  var d = Object.getOwnPropertyDescriptor(target, "attr");
  assert(d !== undefined, "GB-PROXY-013: GOPD sees get:undefined accessor");
  assertEq(typeof d.get, "undefined", "GB-PROXY-013: [[Get]] is undefined");
  assert(!("writable" in d), "GB-PROXY-013: accessor has no writable");
  var p = new Proxy(target, { get() { return 2; } });
  assertThrows(function () { return p["attr"]; }, TypeError, "GB-PROXY-013");
})();

(function nested_define_length_accessor_throws() {
  var array = [];
  var mid = new Proxy(array, {});
  var outer = new Proxy(mid, { defineProperty: undefined });
  Object.defineProperty(outer, "0", { value: 1 });
  assertEq(array[0], 1, "GB-PROXY-014: index define forwards");
  assertThrows(function () {
    Object.defineProperty(outer, "length", { get: function () {} });
  }, TypeError, "GB-PROXY-014");
})();

(function own_keys_must_report_nonconfigurable() {
  var target = {};
  Object.defineProperty(target, "x", { value: 1, configurable: false, writable: true, enumerable: true });
  var p = new Proxy(target, { ownKeys: function () { return []; } });
  assertThrows(function () { return Object.getOwnPropertyNames(p); }, TypeError, "GB-PROXY-015");
})();

(function delete_configurable_on_nonextensible_throws() {
  var trapCalls = 0;
  var p = new Proxy({ prop: 1 }, {
    deleteProperty: function (t) {
      Object.preventExtensions(t);
      trapCalls++;
      return true;
    }
  });
  assertThrows(function () { Reflect.deleteProperty(p, "prop"); }, TypeError, "GB-PROXY-016");
  assertEq(trapCalls, 1, "GB-PROXY-016: trap invoked");
  assert(Reflect.deleteProperty(p, "nonExistent"), "GB-PROXY-016: absent key ok after preventExtensions");
  assertEq(trapCalls, 2, "GB-PROXY-016: second trap call");
})();

(function gopd_undefined_on_nonextensible_throws() {
  var target = { foo: 1 };
  Object.preventExtensions(target);
  var p = new Proxy(target, {
    getOwnPropertyDescriptor: function () { return; }
  });
  assertThrows(function () {
    Object.getOwnPropertyDescriptor(p, "foo");
  }, TypeError, "GB-PROXY-017");
})();

(function gopd_nonconfigurable_while_target_configurable_throws() {
  var target = { bar: 1 };
  var p = new Proxy(target, {
    getOwnPropertyDescriptor: function (t, prop) {
      var foo = {};
      Object.defineProperty(foo, "bar", {
        configurable: false,
        enumerable: true,
        value: 1
      });
      return Object.getOwnPropertyDescriptor(foo, prop);
    }
  });
  assertThrows(function () {
    Object.getOwnPropertyDescriptor(p, "bar");
  }, TypeError, "GB-PROXY-018");
})();

(function nested_proxy_delete_null_trap() {
  var plain = { get foo() {}, bar: 1 };
  Object.defineProperty(plain, "bar", { configurable: false, value: 1 });
  var mid = new Proxy(plain, {});
  var outer = new Proxy(mid, { deleteProperty: null });
  assert(delete outer.foo, "GB-PROXY-019: nested delete forwards");
  assert(!Object.prototype.hasOwnProperty.call(plain, "foo"), "GB-PROXY-019: foo removed");
  assert(!Reflect.deleteProperty(outer, "bar"), "GB-PROXY-019: non-configurable stays");
})();

(function revoked_callable_proxy_typeof_function() {
  var revocable = Proxy.revocable(function () {}, {});
  revocable.revoke();
  var proxy = new Proxy(revocable.proxy, {});
  assertEq(typeof proxy, "function", "GB-PROXY-020: revoked callable target → typeof function");
  assertEq(typeof revocable.proxy, "function", "GB-PROXY-020: revoked proxy itself is function");
})();

(function with_has_invariant_is_typeerror() {
  var target = {};
  Object.defineProperty(target, "attr", { configurable: true, value: 1 });
  Object.preventExtensions(target);
  var p = new Proxy(target, { has: function () { return false; } });
  var kind = null;
  try {
    with (p) { (attr); }
  } catch (e) {
    kind = e instanceof TypeError ? "TypeError" : (e && e.name) || String(e);
  }
  assertEq(kind, "TypeError", "GB-PROXY-021: with+has invariant → TypeError not ReferenceError");
})();

(function samevalue_compatible_redefine_ok() {
  var t = {};
  Object.defineProperty(t, "x", { value: 1, writable: false, enumerable: true, configurable: false });
  Object.defineProperty(t, "x", { value: 1, writable: false, enumerable: true, configurable: false });
  assertEq(t.x, 1, "GB-PROXY-022: SameValue-compatible redefine succeeds");
  var threw = false;
  try {
    Object.defineProperty(t, "x", { value: 2, writable: false, enumerable: true, configurable: false });
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assert(threw, "GB-PROXY-022: incompatible value still throws");
})();

(function nested_gopd_null_trap_string_exotic() {
  var str = new String("xy");
  var mid = new Proxy(str, {});
  var outer = new Proxy(mid, { getOwnPropertyDescriptor: null });
  var d = Object.getOwnPropertyDescriptor(outer, "1");
  assert(d !== undefined, "GB-PROXY-023: nested GOPD forwards string exotic");
  assertEq(d.value, "y", "GB-PROXY-023: code unit value");
  assertEq(d.configurable, false, "GB-PROXY-023: index non-configurable");
})();

(function nested_proxy_array_own_keys_and_gopd() {
  var arr = [10, , 30];
  var mid = new Proxy(arr, {});
  var outer = new Proxy(mid, { ownKeys: null, getOwnPropertyDescriptor: null });
  var keys = Reflect.ownKeys(outer);
  assertEq(keys.indexOf("0") >= 0, true, "GB-PROXY-023b: array index 0 in ownKeys");
  assertEq(keys.indexOf("1") >= 0, true, "GB-PROXY-023b: virtual hole index 1 in ownKeys");
  assertEq(keys.indexOf("2") >= 0, true, "GB-PROXY-023b: array index 2 in ownKeys");
  assertEq(keys.indexOf("length") >= 0, true, "GB-PROXY-023b: length in ownKeys");
  var d0 = Object.getOwnPropertyDescriptor(outer, "0");
  assert(d0 !== undefined, "GB-PROXY-023b: GOPD index 0");
  assertEq(d0.value, 10, "GB-PROXY-023b: index 0 value");
  // Array exotic: ownKeys lists hole indices, but [[GetOwnProperty]] is undefined.
  var d1 = Object.getOwnPropertyDescriptor(outer, "1");
  assertEq(d1, undefined, "GB-PROXY-023b: GOPD hole index is undefined");
  assertEq(Object.prototype.hasOwnProperty.call(arr, "1"), false, "GB-PROXY-023b: hole not own");
})();

(function own_keys_proxy_target_nonconfigurable() {
  var innerTarget = {};
  Object.defineProperty(innerTarget, "x", { value: 1, configurable: false });
  var inner = new Proxy(innerTarget, {});
  var p = new Proxy(inner, { ownKeys: function () { return []; } });
  assertThrows(function () { return Object.getOwnPropertyNames(p); }, TypeError, "GB-PROXY-024");
})();

(function set_null_trap_gopd_on_absent_receiver() {
  var gopdCalls = 0;
  var target = {};
  var receiver = new Proxy({}, {
    getOwnPropertyDescriptor: function (t, p) { gopdCalls++; return undefined; },
    defineProperty: function () { return true; }
  });
  var outer = new Proxy(target, { set: null });
  assertEq(Reflect.set(outer, "newKey", 1, receiver), true, "GB-PROXY-025: Reflect.set ok");
  assertEq(gopdCalls, 1, "GB-PROXY-025: Receiver GOPD before define on absent target key");
})();

(function nested_defineProperty_null_forwards_index() {
  var plain = { foo: 1 };
  Object.defineProperty(plain, "0", { value: 2, configurable: true });
  var mid = new Proxy(plain, {});
  var outer = new Proxy(mid, { defineProperty: null });
  var d = Object.getOwnPropertyDescriptor(outer, "0");
  assert(d !== undefined, "GB-PROXY-026: nested GOPD after null defineProperty trap path");
  assertEq(d.value, 2, "GB-PROXY-026: forwarded index value");
})();

(function defineProperty_nonextensible_add_via_set_throws() {
  var target = Object.create(null);
  Object.preventExtensions(target);
  var p = new Proxy(target, {
    defineProperty: function () { return true; }
  });
  assertThrows(function () { p.prop = 1; }, TypeError, "GB-PROXY-027");
})();

(function nested_set_null_forwards_to_inner() {
  var seen = false;
  var inner = new Proxy({}, {
    set: function (t, p, v) { seen = (p === "x" && v === 1); return true; }
  });
  var outer = new Proxy(inner, { set: null });
  outer.x = 1;
  assert(seen, "GB-PROXY-028: nested null set trap forwards");
})();

(function nested_is_extensible_null_trap() {
  var plain = {};
  var mid = new Proxy(plain, {});
  var outer = new Proxy(mid, { isExtensible: null });
  assertEq(Reflect.isExtensible(outer), true, "GB-PROXY-029: nested isExtensible forwards");
  Object.preventExtensions(plain);
  assertEq(Reflect.isExtensible(outer), false, "GB-PROXY-029: nested isExtensible after PE");
})();

(function nested_prevent_extensions_null_trap() {
  var plain = {};
  var mid = new Proxy(plain, {});
  var outer = new Proxy(mid, { preventExtensions: null });
  Object.preventExtensions(outer);
  assertEq(Object.isExtensible(plain), false, "GB-PROXY-030: nested PE forwards to target");
})();

(function prevent_extensions_trap_false_throws() {
  var p = new Proxy({}, { preventExtensions: function () { return false; } });
  assertThrows(function () { Object.preventExtensions(p); }, TypeError, "GB-PROXY-031");
})();

(function gopd_one_arg_revoked_throws() {
  var r = Proxy.revocable({}, {});
  r.revoke();
  assertThrows(function () { Object.getOwnPropertyDescriptor(r.proxy); }, TypeError, "GB-PROXY-032");
})();

(function instanceof_uses_proxy_getPrototypeOf() {
  function C() {}
  var proto = {};
  C.prototype = proto;
  var obj = {};
  var p = new Proxy(obj, {
    getPrototypeOf: function () { return proto; }
  });
  assertEq(p instanceof C, true, "GB-PROXY-033: instanceof observes Proxy getPrototypeOf");
})();

(function nested_proxy_string_own_keys_null_trap() {
  var sym = Symbol("s");
  var str = new String("str");
  str[sym] = 1;
  var mid = new Proxy(str, {});
  var outer = new Proxy(mid, { ownKeys: null });
  var keys = Reflect.ownKeys(outer);
  assertEq(keys.indexOf("0") >= 0, true, "GB-PROXY-034: string index 0");
  assertEq(keys.indexOf("1") >= 0, true, "GB-PROXY-034: string index 1");
  assertEq(keys.indexOf("2") >= 0, true, "GB-PROXY-034: string index 2");
  assertEq(keys.indexOf("length") >= 0, true, "GB-PROXY-034: length key");
  assertEq(keys.indexOf(sym) >= 0, true, "GB-PROXY-034: symbol own key");
})();

__jacDone();
