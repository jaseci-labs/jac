// Group B residual micro-regressions — descriptor presence, seal enumerable, Reflect.setPrototypeOf

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_group_b_descriptor_micro.js");
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

(function desc_undefined_value_is_existing() {
  var o = {};
  Object.defineProperty(o, "x", { value: undefined, writable: true, enumerable: true, configurable: true });
  Object.defineProperty(o, "x", { enumerable: false });
  var d = Object.getOwnPropertyDescriptor(o, "x");
  assertEq(d.value, undefined, "GB-DESC-001: existing undefined value preserved");
  assertEq(d.enumerable, false, "GB-DESC-001: enumerable updated");
  assertEq(d.writable, true, "GB-DESC-001: writable preserved on generic update");
  assertEq(d.configurable, true, "GB-DESC-001: configurable preserved on generic update");
})();

(function seal_preserves_enumerable() {
  var o = {};
  Object.defineProperty(o, "foo", {
    value: 1, writable: true, enumerable: true, configurable: true
  });
  Object.defineProperty(o, "bar", {
    get: function() { return 2; }, enumerable: true, configurable: true
  });
  Object.seal(o);
  assertEq(Object.getOwnPropertyDescriptor(o, "foo").enumerable, true, "GB-SEAL-001: data enumerable preserved");
  assertEq(Object.getOwnPropertyDescriptor(o, "bar").enumerable, true, "GB-SEAL-001: accessor enumerable preserved");
  assertEq(Object.getOwnPropertyDescriptor(o, "foo").configurable, false, "GB-SEAL-001: data non-configurable");
  assertEq(Object.getOwnPropertyDescriptor(o, "bar").configurable, false, "GB-SEAL-001: accessor non-configurable");
})();

(function set_prototype_same_on_nonextensible() {
  var p = {};
  var o = Object.create(p);
  Object.preventExtensions(o);
  assertEq(Reflect.setPrototypeOf(o, p), true, "GB-PROTO-001: same proto on non-extensible returns true");
  assertEq(Reflect.setPrototypeOf(o, {}), false, "GB-PROTO-001: different proto on non-extensible returns false");
})();

(function create_symbol_key_props() {
  var s = Symbol("k");
  var o = Object.create(null, {
    [s]: { value: 7, writable: true, enumerable: true, configurable: true }
  });
  assertEq(o[s], 7, "GB-CREATE-001: Object.create installs symbol-keyed descriptor");
})();

(function live_entries_mutation() {
  var o = { a: 1, b: 2, c: 3 };
  Object.defineProperty(o, "a", {
    get: function() {
      Object.defineProperty(o, "b", { enumerable: false });
      return 1;
    },
    enumerable: true,
    configurable: true
  });
  var e = Object.entries(o);
  assertEq(e.length, 2, "GB-ENTRIES-001: live enumeration drops key made non-enumerable");
})();

(function descriptor_fields_are_read_once_in_spec_order() {
  var order = [];
  var desc = {};
  ["enumerable", "configurable", "value", "writable"].forEach(function (name) {
    Object.defineProperty(desc, name, {
      enumerable: true,
      configurable: true,
      get: function () {
        order.push(name);
        return name === "value" ? 42 : true;
      }
    });
  });
  var target = {};
  Object.defineProperty(target, "x", desc);
  assertEq(
    order.join(","),
    "enumerable,configurable,value,writable",
    "GB-DESC-ORDER-001: ToPropertyDescriptor read order and cardinality"
  );
  assertEq(target.x, 42, "GB-DESC-ORDER-001: descriptor value applied");
})();

(function accessor_descriptor_order_and_cardinality() {
  var order = [];
  var getter = function () { return 7; };
  var desc = {};
  ["enumerable", "configurable", "get", "set"].forEach(function (name) {
    Object.defineProperty(desc, name, {
      configurable: true,
      get: function () {
        order.push(name);
        if (name === "get") return getter;
        if (name === "set") return undefined;
        return true;
      }
    });
  });
  var target = {};
  Object.defineProperty(target, "x", desc);
  assertEq(
    order.join(","),
    "enumerable,configurable,get,set",
    "GB-DESC-ORDER-002: accessor fields read once in spec order"
  );
  assertEq(target.x, 7, "GB-DESC-ORDER-002: getter installed");
})();

(function define_properties_collects_before_mutating() {
  var target = {};
  var descriptors = {};
  Object.defineProperty(descriptors, "first", {
    enumerable: true,
    value: { value: 1, configurable: true }
  });
  Object.defineProperty(descriptors, "second", {
    enumerable: true,
    get: function () { throw new Error("collect fail"); }
  });
  var threw = false;
  try {
    Object.defineProperties(target, descriptors);
  } catch (err) {
    threw = err && err.message === "collect fail";
  }
  assert(threw, "GB-DESC-ATOMIC-001: later descriptor abrupt completion propagates");
  assertEq(
    Object.prototype.hasOwnProperty.call(target, "first"),
    false,
    "GB-DESC-ATOMIC-001: target unchanged before collection completes"
  );
})();

(function gopd_to_object_nullish_and_primitives() {
  assertThrows(function () { Object.getOwnPropertyDescriptor(undefined, "x"); }, TypeError, "GB-GOPD-001: undefined");
  assertThrows(function () { Object.getOwnPropertyDescriptor(null, "x"); }, TypeError, "GB-GOPD-002: null");
  assertEq(Object.getOwnPropertyDescriptor(true, "x"), undefined, "GB-GOPD-003: boolean boxes");
  assertEq(Object.getOwnPropertyDescriptor(1, "x"), undefined, "GB-GOPD-004: number boxes");
  var sd = Object.getOwnPropertyDescriptor("foo", "0");
  assert(sd && sd.value === "f", "GB-GOPD-005: string exotic index value");
  assertEq(sd.writable, false, "GB-GOPD-005: string index non-writable");
  assertEq(sd.enumerable, true, "GB-GOPD-005: string index enumerable");
  assertEq(sd.configurable, false, "GB-GOPD-005: string index non-configurable");
  var ld = Object.getOwnPropertyDescriptor("foo", "length");
  assertEq(ld.value, 3, "GB-GOPD-006: string length");
  assertEq(ld.enumerable, false, "GB-GOPD-006: length non-enumerable");
})();

(function nonconfigurable_kind_change_leaves_enumerable() {
  var o = {};
  Object.defineProperty(o, "x", {
    value: 1, writable: true, enumerable: true, configurable: false
  });
  var threw = false;
  try {
    Object.defineProperty(o, "x", {
      get: function () { return 2; },
      enumerable: false
    });
  } catch (err) {
    threw = err instanceof TypeError;
  }
  assert(threw, "GB-DESC-KIND-001: accessor overwrite of non-configurable data throws");
  var d = Object.getOwnPropertyDescriptor(o, "x");
  assertEq(d.value, 1, "GB-DESC-KIND-001: value intact");
  assertEq(d.enumerable, true, "GB-DESC-KIND-001: enumerable intact after rejected kind change");
  assertEq(d.configurable, false, "GB-DESC-KIND-001: configurable intact");
})();

(function create_props_to_object_and_function_bag() {
  var proto = {};
  var empty = Object.create(proto, true);
  assertEq(Object.getPrototypeOf(empty), proto, "GB-CREATE-002: boolean Properties ToObject");
  assertEq(Object.getOwnPropertyNames(empty).length, 0, "GB-CREATE-002: no keys from boolean");

  var props = function () {};
  props.prop = { value: 12, enumerable: true, writable: true, configurable: true };
  var created = Object.create({}, props);
  assertEq(created.prop, 12, "GB-CREATE-003: Function PropertiesObject own data desc");

  assertThrows(function () { Object.create({}, "hello"); }, TypeError, "GB-CREATE-004: non-empty string Properties throws");
})();

(function define_property_attributes_abrupt_before_mutate() {
  var target = {};
  Object.defineProperty(target, "keep", { value: 1, configurable: true });
  var order = [];
  var desc = {};
  Object.defineProperty(desc, "enumerable", {
    enumerable: true,
    get: function () {
      order.push("enumerable");
      return true;
    }
  });
  Object.defineProperty(desc, "configurable", {
    enumerable: true,
    get: function () {
      order.push("configurable");
      throw new Error("attr boom");
    }
  });
  Object.defineProperty(desc, "value", {
    enumerable: true,
    get: function () {
      order.push("value");
      return 99;
    }
  });
  var threw = false;
  try {
    Object.defineProperty(target, "keep", desc);
  } catch (err) {
    threw = err && err.message === "attr boom";
  }
  assert(threw, "GB-DESC-ABRUPT-001: Attributes getter throw propagates");
  assertEq(order.join(","), "enumerable,configurable", "GB-DESC-ABRUPT-001: stops before value after abrupt");
  assertEq(target.keep, 1, "GB-DESC-ABRUPT-001: target not mutated");
})();

(function assign_copies_enumerable_symbol_keys() {
  var sym = Symbol("assignSym");
  var src = Object.create(null);
  src[sym] = 99;
  src.visible = 1;
  var tgt = {};
  Object.assign(tgt, src);
  assertEq(tgt[sym], 99, "GB-ASSIGN-001: Object.assign copies enumerable symbol own props");
  assertEq(tgt.visible, 1, "GB-ASSIGN-001: string keys copied");
})();

(function assign_null_proto_has_own_enumerable() {
  var a = Object.create(null);
  Object.defineProperty(a, "x", { value: 1, enumerable: true, writable: true, configurable: true });
  var b = Object.create(null);
  Object.assign(b, a);
  assertEq(Object.prototype.hasOwnProperty.call(b, "x"), true, "GB-ASSIGN-002: null-proto target receives own prop");
  assertEq(b.x, 1, "GB-ASSIGN-002: value copied");
})();

(function assign_create_data_property_or_throw_on_non_extensible() {
  var tgt = Object.preventExtensions({});
  var src = { y: 2 };
  var threw = false;
  try {
    Object.assign(tgt, src);
  } catch (err) {
    threw = err instanceof TypeError;
  }
  assert(threw, "GB-ASSIGN-003: assign throws when CreateDataPropertyOrThrow fails");
})();

(function key_order_purge_on_delete_readd() {
  var o = { a: 1, b: 2, c: 3 };
  delete o.b;
  o.b = 4;
  assertEq(Object.keys(o).join(","), "a,c,b", "GB-KEYS-001: delete+readd appends at end");
})();

(function math_json_tostringtag() {
  assertEq(Object.prototype.toString.call(Math), "[object Math]", "GB-TAG-001: Math @@toStringTag");
  assertEq(Object.prototype.toString.call(JSON), "[object JSON]", "GB-TAG-002: JSON @@toStringTag");
})();

(function object_prototype_attrs() {
  var d = Object.getOwnPropertyDescriptor(Object, "prototype");
  assert(d, "GB-OBJ-PROTO-001: descriptor exists");
  assertEq(d.writable, false, "GB-OBJ-PROTO-001: writable false");
  assertEq(d.enumerable, false, "GB-OBJ-PROTO-001: enumerable false");
  assertEq(d.configurable, false, "GB-OBJ-PROTO-001: configurable false");
})();

(function bigint_object_brand() {
  var boxed = Object(0n);
  assertEq(typeof boxed, "object", "GB-BI-001: Object(0n) is object");
  assertEq(boxed.valueOf(), 0n, "GB-BI-001: valueOf returns 0n");
  assertEq(Object.prototype.toString.call(boxed), "[object BigInt]", "GB-BI-001: @@toStringTag");
})();

(function fromEntries_string_object_entry() {
  var result = Object.fromEntries([Object("ab")]);
  assertEq(result.a, "b", "GB-FROMENT-001: String object entry Get(0)/Get(1)");
})();

(function defineProperty_samevalue_redefine() {
  var o = {};
  Object.defineProperty(o, "x", { value: 1, writable: false, enumerable: true, configurable: false });
  Object.defineProperty(o, "x", { value: 1, writable: false, enumerable: true, configurable: false });
  assertEq(o.x, 1, "GB-DEFP-001: SameValue redefine of non-configurable succeeds");
})();

(function bigint_tostring_undefined_radix() {
  assertEq((100n).toString(undefined), "100", "GB-BI-002: toString(undefined) uses radix 10");
  var threw = false;
  try {
    (0n).toString(null);
  } catch (e) {
    threw = e instanceof RangeError;
  }
  assert(threw, "GB-BI-003: toString(null) → RangeError");
})();

(function assign_array_index_grows_length() {
  var arr = [1];
  Object.assign(arr, { 2: 0 });
  assertEq(arr.length, 3, "GB-ASSIGN-004: assign high index grows array");
  assertEq(arr[1], undefined, "GB-ASSIGN-004: hole at index 1");
  assertEq(arr[2], 0, "GB-ASSIGN-004: assigned value at index 2");
})();

(function promise_tostring_tag_from_prototype() {
  var p = new Promise(function () {});
  assertEq(Object.prototype.toString.call(p), "[object Promise]", "GB-TAG-001: Promise @@toStringTag");
  delete Promise.prototype[Symbol.toStringTag];
  assertEq(Object.prototype.toString.call(p), "[object Object]", "GB-TAG-001: without tag → Object");
})();

__jacDone();
