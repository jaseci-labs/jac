// Group B root-cause micro — observable ToPrimitive / ToNumber ordering

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_group_b_coercion_micro.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

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

(function to_primitive_symbol_hint() {
  var calls = [];
  var o = {
    [Symbol.toPrimitive](hint) {
      calls.push(hint);
      return hint === "number" ? 42 : "str";
    }
  };
  assertEq(Number(o), 42, "GB-COERCE-001: @@toPrimitive number hint for ToNumber");
  assertEq(String(o), "str", "GB-COERCE-001: @@toPrimitive string hint for ToString");
  assertEq(calls.length, 2, "GB-COERCE-001: both coercions invoked");
})();

(function ordinary_to_primitive_typeerror() {
  var bad = {
    valueOf: function() { return {}; },
    toString: function() { return {}; }
  };
  assertThrows(function() { Number(bad); }, TypeError, "GB-COERCE-002");
})();

(function bigint_to_number_typeerror() {
  // Number(bigint) converts (test262 Number/bigint-conversion); unary + TypeErrors.
  assertEq(Number(1n), 1, "GB-BIGINT-001: Number(1n) converts");
  assertThrows(function() { +1n; }, TypeError, "GB-BIGINT-002: unary + on BigInt");
  assertThrows(function() { +Object(1n); }, TypeError, "GB-BIGINT-003: unary + on BigInt object");
})();

(function typedarray_set_typeerror_on_bad_valueof() {
  var ta = new Uint8Array(1);
  var bad = {
    valueOf: function() { return {}; },
    toString: function() { return {}; }
  };
  assertThrows(function() { ta[0] = bad; }, TypeError, "GB-COERCE-003");
})();

(function object_is_missing_args_samevalue_undefined() {
  assertEq(Object.is(), true, "GB-OIS-001: zero-arg Object.is is SameValue(undefined, undefined)");
  assertEq(Object.is(undefined), true, "GB-OIS-002: one-arg Object.is(undefined) is true");
  assertEq(Object.is(1), false, "GB-OIS-003: one-arg Object.is(1) is SameValue(1, undefined)");
})();

__jacDone();
