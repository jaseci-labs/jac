// Group B root-cause micro — species / GetPrototypeFromConstructor

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_typed_arrays/test_group_b_species_micro.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

(function species_accessor_non_enumerable() {
  var d = Object.getOwnPropertyDescriptor(Uint8Array, Symbol.species);
  assert(d && typeof d.get === "function", "GB-SPECIES-001: species is accessor");
  assertEq(d.enumerable, false, "GB-SPECIES-001: non-enumerable");
  assertEq(d.configurable, true, "GB-SPECIES-001: configurable");
})();

(function slice_bad_species_ctor_throws() {
  // ES §23.2.4.1 TypedArraySpeciesCreate → TypedArrayCreate: a species
  // constructor whose result is not a TypedArray is a TypeError (node/V8:
  // "called on incompatible receiver"). This used to expect an intrinsic
  // fallback, which only "worked" because `Uint8Array[Symbol.species]` (a
  // computed accessor read on a plain-function constructor) returned
  // undefined instead of invoking the getter.
  var ta = new Uint8Array([1, 2, 3]);
  function BadSpecies() {}
  BadSpecies.prototype = 3; // non-object → instances are plain objects, not TypedArrays
  var orig = Object.getOwnPropertyDescriptor(Uint8Array, Symbol.species);
  Object.defineProperty(Uint8Array, Symbol.species, {
    get: function() { return BadSpecies; },
    configurable: true,
    enumerable: false
  });
  try {
    assertEq(Uint8Array[Symbol.species], BadSpecies, "GB-SPECIES-002: species getter is invoked");
    var threw = null;
    try { ta.slice(0, 2); } catch (e) { threw = e; }
    assert(threw instanceof TypeError, "GB-SPECIES-002: non-TypedArray species result → TypeError");
  } finally {
    if (orig) Object.defineProperty(Uint8Array, Symbol.species, orig);
  }
  var sub = ta.slice(0, 2);
  assertEq(Object.getPrototypeOf(sub), Uint8Array.prototype, "GB-SPECIES-002: restored species → intrinsic");
  assertEq(sub.length, 2, "GB-SPECIES-002: slice length");
})();

(function filter_species_undefined_uses_default() {
  class Sub extends Uint8Array {}
  var ta = new Sub([1, 2, 3, 4]);
  Object.defineProperty(Sub, Symbol.species, { value: undefined, configurable: true });
  var out = ta.filter(function (v) { return v % 2 === 0; });
  assertEq(Object.getPrototypeOf(out), Uint8Array.prototype, "GB-SPECIES-003: undefined species → default TypedArray");
  assertEq(out.length, 2, "GB-SPECIES-003: filtered length");
  assertEq(out[0], 2, "GB-SPECIES-003: first kept");
})();

(function set_length_of_array_like() {
  var ta = new Uint8Array(4);
  var src = { length: 2, 0: 9, 1: 8 };
  ta.set(src, 1);
  assertEq(ta[0], 0, "GB-SET-001: untouched prefix");
  assertEq(ta[1], 9, "GB-SET-001: LengthOfArrayLike element 0");
  assertEq(ta[2], 8, "GB-SET-001: LengthOfArrayLike element 1");
})();

__jacDone();
