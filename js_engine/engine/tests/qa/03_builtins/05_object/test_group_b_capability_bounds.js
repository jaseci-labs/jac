// Group B — explicit capability boundaries (deferred features must stay absent / non-hanging)

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_group_b_capability_bounds.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

(function atomics_wait_meta() {
  if (typeof Atomics === "undefined" || typeof Atomics.wait !== "function") return;
  assertEq(Atomics.wait.length, 4, "GB-AT-LEN-001: Atomics.wait length");
  assertEq(Atomics.waitAsync.length, 4, "GB-AT-LEN-001: Atomics.waitAsync length");
})();

(function abstract_module_source_absent() {
  assertEq(typeof globalThis.AbstractModuleSource, "undefined",
    "GB-CAP-001: AbstractModuleSource must not be exposed until module-record integration");
})();

(function atomics_nan_timeout_is_infinity() {
  if (typeof SharedArrayBuffer === "undefined" || typeof Atomics === "undefined") return;
  var sab = new SharedArrayBuffer(4);
  var i32 = new Int32Array(sab);
  i32[0] = 1;
  var threw = false;
  try {
    Atomics.wait(i32, 0, 1, NaN);
  } catch (e) {
    threw = e instanceof TypeError;
  }
  assert(threw, "GB-AT-NAN-001: matching wait throws when AgentCanSuspend is false");
  assertEq(Atomics.wait(i32, 0, 99, NaN), "not-equal", "GB-AT-NAN-001: not-equal path");
})();

(function atomics_notify_non_shared_returns_zero() {
  if (typeof Atomics === "undefined") return;
  var ab = new ArrayBuffer(8);
  var ia = new Int32Array(ab);
  assertEq(Atomics.notify(ia, 0, 1), 0, "GB-AT-NOTIFY-001: non-shared notify returns 0");
})();

(function arraybuffer_resizable_ignores_detach() {
  if (typeof ArrayBuffer !== "function") return;
  var ab = new ArrayBuffer(1, { maxByteLength: 1 });
  if (typeof globalThis.__detachArrayBuffer === "function") {
    globalThis.__detachArrayBuffer(ab);
  } else if (globalThis.$262 && typeof globalThis.$262.detachArrayBuffer === "function") {
    globalThis.$262.detachArrayBuffer(ab);
  } else {
    return;
  }
  assertEq(ab.resizable, true, "GB-AB-RES-001: resizable true after detach");
})();

(function promise_all_element_nonconstruct() {
  var resolveElement;
  var thenable = {
    then: function (fulfill) { resolveElement = fulfill; }
  };
  function NotPromise(executor) {
    executor(function () {}, function () {});
  }
  NotPromise.resolve = function (v) { return v; };
  Promise.all.call(NotPromise, [thenable]);
  assert(resolveElement != null, "GB-PALL-NC-001: element function exposed");
  assertEq(Object.prototype.hasOwnProperty.call(resolveElement, "prototype"), false,
    "GB-PALL-NC-001: no prototype own property");
  var threw = false;
  try { new resolveElement(); } catch (e) { threw = e instanceof TypeError; }
  assert(threw, "GB-PALL-NC-001: element function is not a constructor");
})();

(function bigint_toprimitive_default_hint() {
  var hint = null;
  var o = {
    [Symbol.toPrimitive]: function (h) { hint = h; return 1n; }
  };
  assertEq(BigInt(o), 1n, "GB-BI-TP-001: BigInt coerces object");
  assertEq(hint, "default", "GB-BI-TP-001: @@toPrimitive hint is default");
})();

(function shadow_realm_evaluate_syntax() {
  if (typeof ShadowRealm !== "function") return;
  var sr = new ShadowRealm();
  var threw = false;
  try { sr.evaluate("{"); } catch (e) { threw = e instanceof TypeError; }
  assertEq(threw, true, "GB-SR-SYN-001: guest SyntaxError wrapped as TypeError");
})();

(function shadow_realm_import_value_rejects() {
  if (typeof ShadowRealm !== "function") {
    __jacDone();
    return;
  }
  assertEq(typeof ShadowRealm, "function", "GB-CAP-002: ShadowRealm present");
  var sr = new ShadowRealm();
  var p = sr.importValue("./x.js", "y");
  assert(p && typeof p.then === "function", "GB-CAP-002: importValue returns a Promise");
  var settled = "pending";
  p.then(function () { settled = "fulfill"; }, function (err) {
    settled = (err && err.name === "TypeError") ? "reject-typeerror" : "reject-other";
  });
  function finish() {
    assertEq(settled, "reject-typeerror", "GB-CAP-002: importValue rejects with TypeError");
    __jacDone();
  }
  if (typeof setImmediate === "function") setImmediate(finish);
  else Promise.resolve().then(finish);
})();
