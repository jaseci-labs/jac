// Regression: Atomics.waitAsync's 'timed-out' promise must not settle before
// the requested timeout elapses on the wall clock (Date.now) — the underlying
// timer could fire a few ms early relative to Date.now, so the resolution is
// re-armed for any shortfall. Every test262 Atomics/waitAsync
// no-spurious-wakeup test measures `lapse >= TIMEOUT`; an early resolve made
// them all fail. Also covers the synchronous not-equal / already-timed-out
// fast paths. (The $262.agent.timeouts host object is covered by test262.)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/19_atomics/test_atomics_waitasync_timeout.js");
var __jacOrigExit = process.exit.bind(process);
function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function finish() { __reg.finalize(__jacOrigExit); }

if (typeof Atomics === "undefined" || typeof Atomics.waitAsync !== "function" ||
    typeof SharedArrayBuffer === "undefined") {
  // Environment without SAB/Atomics.waitAsync — nothing to assert, pass cleanly.
  finish();
} else {
  var i32a = new Int32Array(new SharedArrayBuffer(Int32Array.BYTES_PER_ELEMENT * 4));

  // ATM-WA-001 — value mismatch resolves synchronously with 'not-equal'.
  var r1 = Atomics.waitAsync(i32a, 1, 999, 100); // index 1 holds 0, expected 999
  assertEq(r1.async, false, "ATM-WA-001: mismatch is synchronous");
  assertEq(r1.value, "not-equal", "ATM-WA-001: mismatch value is 'not-equal'");

  // ATM-WA-002 — zero/negative timeout resolves synchronously 'timed-out'.
  var r2 = Atomics.waitAsync(i32a, 0, 0, 0); // matches (0==0), t<=0 → timed-out now
  assertEq(r2.async, false, "ATM-WA-002: t<=0 is synchronous");
  assertEq(r2.value, "timed-out", "ATM-WA-002: t<=0 value is 'timed-out'");

  // ATM-WA-003 — a finite timeout arms an async wait whose promise resolves
  // 'timed-out' NOT EARLIER than the requested delay (measured with Date.now).
  var TIMEOUT = 60;
  var before = Date.now();
  var r3 = Atomics.waitAsync(i32a, 0, 0, TIMEOUT); // matches → real wait
  assertEq(r3.async, true, "ATM-WA-003: finite-timeout wait is async");
  assert(r3.value && typeof r3.value.then === "function", "ATM-WA-003: .value is a promise");
  r3.value.then(function (v) {
    var lapse = Date.now() - before;
    assertEq(v, "timed-out", "ATM-WA-003: resolves 'timed-out'");
    assert(lapse >= TIMEOUT, "ATM-WA-003: lapse (" + lapse + ") >= TIMEOUT (" + TIMEOUT + ")");
    finish();
  }, function (e) {
    assert(false, "ATM-WA-003: wait promise rejected: " + e);
    finish();
  });
}
