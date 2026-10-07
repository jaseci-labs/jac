// Nested Proxy + spread/assign trap-awareness (production hardening)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
  "regression/02_language/20_prototypes/test_proxy_nested_and_spread.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, ErrType, msg) { __reg.assertThrows(fn, ErrType, msg); }

var onJacEngine = __jacHarness.isJacEngineRunner();

// Nested proxy: outer empty handler, inner get trap must run
(function nested_get() {
  var innerSeen = false;
  var inner = new Proxy({ x: 1 }, {
    get: function (t, k) {
      innerSeen = true;
      return t[k];
    },
  });
  var outer = new Proxy(inner, {});
  assertEq(outer.x, 1, "nested get: value");
  assert(innerSeen, "nested get: inner trap invoked");
})();

// get trap returns undefined on non-writable non-configurable data property
(function get_undefined_forward() {
  var t = {};
  Object.defineProperty(t, "frozen", { value: 42, writable: false, configurable: false });
  var p = new Proxy(t, {
    get: function () {
      return undefined;
    },
  });
  // Both lanes: the engine now enforces the §10.5.8 get-trap invariant (the
  // former onJacEngine lenient branch expected the pre-fix forwarding).
  assertThrows(
    function () {
      return p.frozen;
    },
    TypeError,
    "get undefined throws on non-writable non-configurable"
  );
})();

// Spread copies keys from proxy ownKeys trap
(function spread_ownKeys() {
  var p = new Proxy({}, {
    ownKeys: function () {
      return ["a", "b"];
    },
    get: function (t, k) {
      return k === "a" ? 1 : 2;
    },
    getOwnPropertyDescriptor: function (_t, k) {
      return { enumerable: true, configurable: true };
    },
  });
  var o = { ...p };
  assertEq(o.a, 1, "spread: key a");
  assertEq(o.b, 2, "spread: key b");
})();

// Object.assign respects proxy get/set on source
(function assign_from_proxy() {
  var p = new Proxy({ a: 1 }, {
    get: function (t, k) {
      return t[k] * 10;
    },
    ownKeys: function (t) {
      return Reflect.ownKeys(t);
    },
    getOwnPropertyDescriptor: function (_t, k) {
      return { enumerable: true, configurable: true };
    },
  });
  var dest = {};
  Object.assign(dest, p);
  assertEq(dest.a, 10, "assign from proxy get trap");
})();

__jacDone();
