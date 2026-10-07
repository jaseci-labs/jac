// Group B residual micro-regressions — TypedArray ctor / iterator / ArrayBuffer.detached

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_typed_arrays/test_group_b_typedarray_micro.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

(function iterator_is_values() {
  assertEq(
    Uint8Array.prototype[Symbol.iterator],
    Uint8Array.prototype.values,
    "GB-TA-001: @@iterator === values"
  );
})();

(function ctor_without_callee() {
  "use strict";
  var a = new Uint8Array([1, 2, 3]);
  assertEq(a.length, 3, "GB-TA-002: strict-mode TypedArray ctor works");
  assertEq(a[0], 1, "GB-TA-002: element 0");
  assertEq(Object.getPrototypeOf(a), Uint8Array.prototype, "GB-TA-002: prototype chain");
})();

(function ab_detached_accessor() {
  var ab = new ArrayBuffer(8);
  assertEq(typeof Object.getOwnPropertyDescriptor(ArrayBuffer.prototype, "detached").get, "function",
    "GB-AB-001: detached is an accessor");
  assertEq(ab.detached, false, "GB-AB-001: initially not detached");
  if (typeof $262 !== "undefined" && typeof $262.detachArrayBuffer === "function") {
    $262.detachArrayBuffer(ab);
    assertEq(ab.detached, true, "GB-AB-001: detached after detachArrayBuffer");
  }
})();

(function ab_tostringtag() {
  assertEq(
    Object.prototype.toString.call(new ArrayBuffer(0)),
    "[object ArrayBuffer]",
    "GB-AB-002: @@toStringTag"
  );
})();

(function species_configurable() {
  var d = Object.getOwnPropertyDescriptor(ArrayBuffer, Symbol.species);
  assert(d && typeof d.get === "function", "GB-AB-003: species is accessor");
  assertEq(d.configurable, true, "GB-AB-003: species configurable");
  assertEq(d.enumerable, false, "GB-AB-003: species non-enumerable");
})();

(function oob_get_undefined() {
  var buf = new ArrayBuffer(8, { maxByteLength: 16 });
  var ta = new Uint8Array(buf, 0, 4);
  buf.resize(2);
  assertEq(ta.length, 0, "GB-TA-003: OOB length is 0");
  assertEq(ta[0], undefined, "GB-TA-003: OOB get is undefined");
  buf.resize(8);
  assertEq(ta.length, 4, "GB-TA-003: fixed view returns in-bounds after grow");
  ta[0] = 9;
  assertEq(ta[0], 9, "GB-TA-003: element access restored after grow");
})();

(function oob_define_own_property() {
  var ta = new Uint8Array(2);
  assertEq(
    Reflect.defineProperty(ta, "999", { value: 1, writable: true, enumerable: true, configurable: true }),
    false,
    "GB-TA-004: OOB defineOwnProperty returns false"
  );
  assertEq(ta[999], undefined, "GB-TA-004: no ordinary OOB property");
  assertEq(
    Reflect.defineProperty(ta, "-0", { value: 1, writable: true, enumerable: true, configurable: true }),
    false,
    "GB-TA-004: invalid index defineOwnProperty returns false"
  );
  assertEq(Object.getOwnPropertyNames(ta).indexOf("-0"), -1, "GB-TA-004: no -0 ordinary key");
})();

(function fromCharCode_zero() {
  assertEq(String.fromCharCode(0), "\0", "GB-STR-001: fromCharCode(0) is NUL");
  assertEq(String.fromCharCode(0).length, 1, "GB-STR-001: length 1");
})();

(function dataview_revalidates_after_resize_coercion() {
  var buf = new ArrayBuffer(8, { maxByteLength: 16 });
  var view = new DataView(buf);
  var offset = {
    valueOf: function () {
      buf.resize(1);
      return 1;
    }
  };
  var threw = false;
  try {
    view.getUint16(offset);
  } catch (err) {
    threw = err instanceof RangeError;
  }
  assert(threw, "GB-DV-WITNESS-001: resize during offset coercion is revalidated");
})();

(function oversized_digit_index_is_ordinary() {
  var ta = new Uint8Array(2);
  var key = "1000000000000000000000";
  assertEq(
    Reflect.defineProperty(ta, key, { value: 1, writable: true, enumerable: true, configurable: true }),
    true,
    "GB-TA-005: oversized digit key is ordinary (not canonical integer index)"
  );
  assertEq(ta[key], 1, "GB-TA-005: ordinary property stored");
})();

(function predicate_iterates_captured_length() {
  var ta = new Uint8Array([1, 2, 3, 4]);
  var calls = 0;
  ta.every(function () { calls++; return true; });
  assertEq(calls, 4, "GB-TA-006: every visits captured length");
  calls = 0;
  ta.some(function () { calls++; return false; });
  assertEq(calls, 4, "GB-TA-006: some visits captured length");
})();

(function change_by_copy_ignores_species() {
  class MyTA extends Uint8Array {
    static get [Symbol.species]() { throw new Error("species should be ignored"); }
  }
  var m = new MyTA([1, 2, 3]);
  var r = m.toReversed();
  assert(r instanceof Uint8Array, "GB-TA-007: toReversed is Uint8Array");
  assert(!(r instanceof MyTA), "GB-TA-007: toReversed ignores species");
  assertEq(r[0], 3, "GB-TA-007: reversed content");
})();

(function iterator_brand_is_array_iterator() {
  var tag = Object.prototype.toString.call(new Uint8Array(1).values());
  assertEq(tag, "[object Array Iterator]", "GB-TA-008: values() is Array Iterator");
})();

(function resizable_ignores_detach() {
  var ab = new ArrayBuffer(8, { maxByteLength: 16 });
  assertEq(ab.resizable, true, "GB-AB-004: resizable true");
  if (typeof $262 !== "undefined" && typeof $262.detachArrayBuffer === "function") {
    $262.detachArrayBuffer(ab);
    assertEq(ab.resizable, true, "GB-AB-004: resizable still true when detached");
  }
})();

(function integer_index_configurable_polarity() {
  var ta = new Uint8Array([7]);
  var d = Object.getOwnPropertyDescriptor(ta, "0");
  assert(d, "GB-TA-009: index descriptor exists");
  assertEq(d.configurable, true, "GB-TA-009: ES2023 integer index is configurable");
  assertEq(
    Reflect.defineProperty(ta, "0", { value: 9, writable: true, enumerable: true, configurable: true }),
    true,
    "GB-TA-009: define with configurable:true succeeds"
  );
  assertEq(ta[0], 9, "GB-TA-009: value updated");
  assertEq(
    Reflect.defineProperty(ta, "0", { value: 1, writable: true, enumerable: true, configurable: false }),
    false,
    "GB-TA-009: define with configurable:false rejected"
  );
})();

(function clamp_ties_to_even() {
  var u = new Uint8ClampedArray(4);
  u[0] = 0.5;
  u[1] = 1.5;
  u[2] = 0.50000001;
  u[3] = 2.5;
  assertEq(u[0], 0, "GB-TA-010: 0.5 ties to even → 0");
  assertEq(u[1], 2, "GB-TA-010: 1.5 ties to even → 2");
  assertEq(u[2], 1, "GB-TA-010: 0.50000001 rounds up → 1");
  assertEq(u[3], 2, "GB-TA-010: 2.5 ties to even → 2");
})();

(function indexOf_strict_equality_and_negzero() {
  var ta = new Float64Array([0, NaN, 1]);
  assertEq(ta.indexOf(NaN), -1, "GB-TA-011: indexOf uses === (NaN never matches)");
  var idx = ta.indexOf(0, -0);
  assertEq(idx, 0, "GB-TA-011: indexOf finds 0 at index 0");
  assert(Object.is(idx, 0) && !Object.is(idx, -0),
    "GB-TA-011: indexOf with -0 fromIndex returns +0 not -0");
  assertEq(ta.includes(NaN), true, "GB-TA-011: includes uses SameValueZero");
})();

(function length_brand_check() {
  var threw = false;
  try {
    Uint8Array.prototype.length;
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assert(threw, "GB-TA-012: length getter requires TypedArray brand");
})();

(function toInteger_observes_valueOf() {
  var calls = 0;
  var ta = new Uint8Array([1, 2, 3, 4, 5]);
  var from = {
    valueOf: function () { calls++; return 2; }
  };
  assertEq(ta.indexOf(4, from), 3, "GB-TA-013: ToInteger via valueOf");
  assertEq(calls, 1, "GB-TA-013: valueOf observed once");
})();

(function canonical_decimal_index_string() {
  var ta = new Uint8Array(2);
  assertEq(
    Reflect.defineProperty(ta, "0.000001", { value: 1, writable: true, enumerable: true, configurable: true }),
    false,
    "GB-TA-014: canonical decimal NumberToString key is integer-index (rejected)"
  );
  assertEq(ta["0.000001"], undefined, "GB-TA-014: no ordinary property for 0.000001");
})();

(function base64_roundtrip() {
  assertEq(Uint8Array.fromBase64("Zg==")[0], 102, "GB-TA-015: fromBase64 Zg==");
  assertEq(Uint8Array.fromBase64("Zm9v").length, 3, "GB-TA-015: fromBase64 Zm9v length");
  assertEq(new Uint8Array([102, 111, 111]).toBase64(), "Zm9v", "GB-TA-015: toBase64");
})();

(function number_tolocalestring_brand() {
  assertEq((123).toLocaleString(), "123", "GB-NUM-TLS-001: number toLocaleString");
  var threw = false;
  try {
    Number.prototype.toLocaleString.call({});
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assert(threw, "GB-NUM-TLS-001: brand check TypeError");
})();

(function length_tracking_oob_after_shrink() {
  var buf = new ArrayBuffer(8, { maxByteLength: 16 });
  var ta = new Uint8Array(buf, 0, 4); // fixed-length view
  assertEq(ta.length, 4, "GB-TA-016: fixed length 4");
  buf.resize(2);
  assertEq(ta.length, 0, "GB-TA-016: OOB length 0 after shrink");
  assertEq(ta[0], undefined, "GB-TA-016: OOB get undefined");
})();

(function from_uses_length_of_array_like() {
  var calls = 0;
  var src = {
    get length() { calls++; return 2; },
    0: 10,
    1: 20
  };
  var a = Uint8Array.from(src);
  assertEq(a.length, 2, "GB-TA-017: from LengthOfArrayLike");
  assertEq(a[0], 10, "GB-TA-017: elem0");
  assert(calls >= 1, "GB-TA-017: length getter observed");
})();

(function set_passthrough_typeerror() {
  var ta = new Float64Array(1);
  var bad = {
    valueOf: function () { return {}; },
    toString: function () { return {}; }
  };
  var threw = false;
  try {
    ta[0] = bad;
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assert(threw, "GB-TA-018: IntegerIndexedElementSet OrdinaryToPrimitive TypeError");
})();

(function set_receiver_not_ta() {
  var ta = new Uint8Array([1, 2]);
  var recv = {};
  assertEq(Reflect.set(ta, "0", 9, recv), true, "GB-TA-019: Reflect.set with foreign Receiver");
  assertEq(ta[0], 1, "GB-TA-019: TypedArray not written when Receiver !== O");
  assertEq(recv[0], 9, "GB-TA-019: value defined on Receiver");
})();

(function set_coerce_before_oob() {
  var ta = new Uint8Array(0);
  var calls = 0;
  var v = {
    valueOf: function () { calls++; return 7; }
  };
  ta[0] = v;
  assertEq(calls, 1, "GB-TA-020: ToNumber runs even when length is 0");
})();

(function from_of_inherited_only() {
  assertEq(Object.prototype.hasOwnProperty.call(Uint8Array, "from"), false,
    "GB-TA-021: Uint8Array has no own from");
  assertEq(Object.prototype.hasOwnProperty.call(Uint8Array, "of"), false,
    "GB-TA-021: Uint8Array has no own of");
  var base = Object.getPrototypeOf(Uint8Array);
  assertEq(Uint8Array.from, base.from, "GB-TA-021: from inherited from %TypedArray%");
  assertEq(Uint8Array.of, base.of, "GB-TA-021: of inherited from %TypedArray%");
})();

(function fill_no_recoerce() {
  var ta = new Float64Array(4);
  var calls = 0;
  var v = {
    valueOf: function () { calls++; return 3; }
  };
  ta.fill(v);
  assertEq(calls, 1, "GB-TA-022: fill coerces value once");
  assertEq(ta[0], 3, "GB-TA-022: fill wrote coerced value");
  assertEq(ta[3], 3, "GB-TA-022: fill wrote all elements");
})();

(function fill_non_numeric_typeerror() {
  var ta = new Float64Array(2);
  var bad = {
    valueOf: function () { return {}; },
    toString: function () { return {}; }
  };
  var threw = false;
  try {
    ta.fill(bad);
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assert(threw, "GB-TA-023: fill OrdinaryToPrimitive TypeError (no stack overflow)");
})();

(function base64_illegal_and_brand() {
  var threw = false;
  try { Uint8Array.fromBase64("Zm9v^"); } catch (e) { threw = e instanceof SyntaxError; }
  assert(threw, "GB-TA-024: fromBase64 illegal trailing char SyntaxError");
  threw = false;
  try { Uint8Array.fromBase64("ZXhhZg", { lastChunkHandling: "strict" }); } catch (e) {
    threw = e instanceof SyntaxError;
  }
  assert(threw, "GB-TA-024: strict unpadded last chunk SyntaxError");
  threw = false;
  try { Uint8Array.prototype.toBase64.call(new Float64Array(2)); } catch (e) {
    threw = e instanceof TypeError;
  }
  assert(threw, "GB-TA-024: toBase64 brand TypeError on Float64Array");
})();

(function search_soft_detach() {
  if (typeof $262 === "undefined" || typeof $262.detachArrayBuffer !== "function") {
    return;
  }
  var ta = new Int32Array(1);
  var fromIndex = {
    valueOf: function () {
      $262.detachArrayBuffer(ta.buffer);
      return 0;
    }
  };
  assertEq(ta.indexOf(undefined, fromIndex), -1, "GB-TA-025: indexOf soft -1 after detach");
  assertEq(ta.includes(undefined, fromIndex), false, "GB-TA-025: includes soft false after detach");
})();

(function ctor_buffer_byte_length_modulo() {
  var threw = false;
  try { new BigInt64Array(new ArrayBuffer(1)); } catch (e) { threw = e instanceof RangeError; }
  assert(threw, "GB-TA-026: buffer byteLength % elementSize RangeError");
})();

(function copywithin_finite_clamp() {
  var a = new Uint8Array([0, 1, 2, 3]);
  a.copyWithin(0, 1, -1);
  assertEq(a[0], 1, "GB-TA-027: copyWithin negative end");
  assertEq(a[1], 2, "GB-TA-027: copyWithin middle");
  assertEq(a[2], 2, "GB-TA-027: copyWithin preserved");
})();

__jacDone();
