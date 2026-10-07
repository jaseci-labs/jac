// Phase 1A — async scheduling comprehensive (Node / ECMA-262 job queues)
// Spec refs: node:process.nextTick, queueMicrotask, Promise jobs, timers

var __jacHarness = require("../../_harness/regression_case.cjs");
var orderUtil = require("../../_harness/order_capture.cjs");
var __reg = __jacHarness.createTestCase(
  "regression/02_language/17_promises/test_async_scheduling_phase1.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() {
  __reg.finalize(__jacOrigExit);
}
function assert(cond, msg) {
  __reg.assert(cond, msg);
}
function assertEq(actual, expected, msg) {
  __reg.assertEq(actual, expected, msg);
}

async function runPositiveCases() {
  // P1-001: nextTick before Promise.then (Node process.nextTick)
  var o1 = orderUtil.createOrder();
  Promise.resolve().then(function () {
    o1.push("micro");
  });
  process.nextTick(function () {
    o1.push("nextTick");
  });
  await orderUtil.waitMacrotick(30);
  orderUtil.assertBefore(o1, "nextTick", "micro", assert, "P1-001: nextTick before micro");

  // P1-002: registration FIFO on unified microtask queue (qm then prom)
  if (typeof queueMicrotask === "function") {
    var o2 = orderUtil.createOrder();
    queueMicrotask(function () {
      o2.push("qm");
    });
    await Promise.resolve().then(function () {
      o2.push("prom");
    });
    assert(o2.indexOf("qm") !== -1 && o2.indexOf("prom") !== -1, "P1-002: both ran");
    orderUtil.assertBefore(o2, "qm", "prom", assert, "P1-002: qm before prom (FIFO)");
  }

  // P1-003: microtasks before macrotask
  var o3 = orderUtil.createOrder();
  setTimeout(function () {
    o3.push("macro");
  }, 0);
  await Promise.resolve().then(function () {
    o3.push("micro");
  });
  assert(o3.indexOf("micro") !== -1 && o3.indexOf("macro") === -1, "P1-003: micro before macro fires");
  await orderUtil.waitMacrotick(30);
  assert(o3.indexOf("macro") !== -1, "P1-003: macro eventually ran");
  orderUtil.assertBefore(o3, "micro", "macro", assert, "P1-003: micro before macro in log");

  // P1-004: nested Promise microtasks drain before macro
  var o4 = orderUtil.createOrder();
  setTimeout(function () {
    o4.push("macro");
  }, 0);
  await Promise.resolve().then(function () {
    o4.push("a");
    return Promise.resolve().then(function () {
      o4.push("b");
    });
  });
  orderUtil.assertBefore(o4, "a", "b", assert, "P1-004: nested order");
  await orderUtil.waitMacrotick(30);
  orderUtil.assertBefore(o4, "b", "macro", assert, "P1-004: nested before macro");

  // P1-005: multiple .then on same fulfilled promise — FIFO
  var o5 = orderUtil.createOrder();
  var p5 = Promise.resolve();
  p5.then(function () {
    o5.push("1");
  });
  p5.then(function () {
    o5.push("2");
  });
  await p5;
  assertEq(orderUtil.joinOrder(o5), "1,2", "P1-005: then FIFO");
}

async function runNegativeCases() {
  // N1-001: invalid queueMicrotask argument — Node semantics (sync TypeError)
  if (typeof queueMicrotask === "function") {
    var threwSync = false;
    try {
      queueMicrotask(null);
    } catch (e) {
      threwSync = true;
    }
    assert(threwSync, "N1-001: queueMicrotask(null) throws synchronously");
  }

  // N1-002: microtask catch does not block subsequent microtasks
  var log = [];
  Promise.resolve().then(function () {
    try {
      throw new Error("boom");
    } catch (e) {
      log.push("caught");
    }
  });
  Promise.resolve().then(function () {
    log.push("after");
  });
  await Promise.resolve();
  assertEq(log.join(","), "caught,after", "N1-002: later microtask still runs");

  // N1-003: await Promise executor + setTimeout resolve path (timer → resolve fn)
  var oTimer = orderUtil.createOrder();
  await new Promise(function (resolve) {
    setTimeout(function () {
      oTimer.push("resolved");
      resolve(1);
    }, 10);
  });
  assert(oTimer.indexOf("resolved") !== -1, "N1-003: timer resolve path");
}

async function runVariationCases() {
  // V1-001: cross-queue scheduling from nextTick
  var o6 = orderUtil.createOrder();
  process.nextTick(function () {
    o6.push("nt");
    Promise.resolve().then(function () {
      o6.push("from-nt");
    });
  });
  await orderUtil.waitMacrotick(30);
  orderUtil.assertBefore(o6, "nt", "from-nt", assert, "V1-001: nextTick then micro from nt");

  // V1-002: re-entrant nextTick drains in same checkpoint
  var o7 = orderUtil.createOrder();
  process.nextTick(function () {
    o7.push("a");
    process.nextTick(function () {
      o7.push("b");
    });
  });
  await orderUtil.waitMacrotick(30);
  orderUtil.assertBefore(o7, "a", "b", assert, "V1-002: nested nextTick order");
}

async function main() {
  await runPositiveCases();
  await runNegativeCases();
  await runVariationCases();
  __jacDone();
}

main().catch(function (e) {
  console.error("FAIL: phase1 scheduling: " + e);
  __reg.bump();
  __jacDone();
});
