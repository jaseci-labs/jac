// Group B release performance micros — repeatable timings under fixed, bounded work.
// Soft upper bounds catch catastrophic regressions; p50/p95 are logged for CI artifacts.

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_group_b_perf_micro.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

function nowMs() {
  if (typeof performance !== "undefined" && typeof performance.now === "function") {
    return performance.now();
  }
  return Date.now();
}

function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  var idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[idx];
}

function bench(name, iters, fn, maxP95Ms) {
  var samples = [];
  var i;
  for (i = 0; i < iters; i++) {
    var t0 = nowMs();
    fn();
    samples.push(nowMs() - t0);
  }
  samples.sort(function (a, b) { return a - b; });
  var p50 = percentile(samples, 50);
  var p95 = percentile(samples, 95);
  console.log("GB-PERF " + name + " p50=" + p50.toFixed(3) + "ms p95=" + p95.toFixed(3) + "ms n=" + iters);
  assert(p95 <= maxP95Ms, "GB-PERF " + name + ": p95 " + p95.toFixed(3) + "ms exceeds " + maxP95Ms + "ms");
  return { p50: p50, p95: p95 };
}

bench("typedarray_alloc_fill", 5, function () {
  var n = 8192;
  var a = new Uint8Array(n);
  var i;
  for (i = 0; i < n; i++) a[i] = i & 0xff;
  var sum = 0;
  for (i = 0; i < n; i++) sum += a[i];
  if (sum < 0) throw new Error("unreachable");
}, 500);

bench("buffer_copy_resize", 5, function () {
  var src = new ArrayBuffer(1024, { maxByteLength: 4096 });
  var view = new Uint8Array(src);
  var i;
  for (i = 0; i < view.length; i++) view[i] = i & 0xff;
  src.resize(2048);
  var dst = new Uint8Array(2048);
  dst.set(new Uint8Array(src));
  if (dst[0] !== 0) throw new Error("copy failed");
}, 1500);

bench("map_set_mutation_iter", 5, function () {
  var map = new Map();
  var set = new Set();
  var i;
  for (i = 0; i < 1000; i++) {
    map.set(i, i);
    set.add(i);
  }
  for (i = 0; i < 500; i++) {
    map.delete(i);
    set.delete(i);
    map.set(i + 1000, i);
    set.add(i + 1000);
  }
  var n = 0;
  map.forEach(function () { n++; });
  set.forEach(function () { n++; });
  if (n < 1000) throw new Error("iteration incomplete");
}, 500);

bench("proxy_ownkeys", 5, function () {
  var target = {};
  var i;
  for (i = 0; i < 100; i++) target["k" + i] = i;
  var proxy = new Proxy(target, {
    ownKeys: function (t) {
      return Reflect.ownKeys(t);
    },
    getOwnPropertyDescriptor: function (t, k) {
      return Object.getOwnPropertyDescriptor(t, k);
    }
  });
  var keys = Reflect.ownKeys(proxy);
  if (keys.length < 100) throw new Error("ownKeys short");
  Object.keys(proxy);
}, 500);

(function fromasync_and_atomics() {
  var samples = [];
  var rounds = 3;
  var r;
  for (r = 0; r < rounds; r++) {
    var t0 = nowMs();
    var p;
    if (typeof Array.fromAsync === "function") {
      p = Array.fromAsync([1, 2, 3, 4, 5, 6, 7, 8], function (v) {
        return Promise.resolve(v * 2);
      });
    } else {
      p = Promise.resolve([2, 4, 6, 8, 10, 12, 14, 16]);
    }
    var waitP = Promise.resolve("skip");
    if (
      typeof SharedArrayBuffer !== "undefined" &&
      typeof Atomics !== "undefined" &&
      typeof Atomics.waitAsync === "function"
    ) {
      try {
        var sab = new SharedArrayBuffer(16);
        var ia = new Int32Array(sab);
        Atomics.store(ia, 0, 0);
        var wr = Atomics.waitAsync(ia, 0, 0, 5);
        waitP = wr && wr.value ? wr.value : Promise.resolve("ok");
        Atomics.notify(ia, 0, 1);
      } catch (_e) {
        waitP = Promise.resolve("skip");
      }
    }
    Promise.all([p, waitP]).then(function (results) {
      var arr = results[0];
      assert(arr && arr.length === 8 && arr[0] === 2, "GB-PERF fromAsync result");
      samples.push(nowMs() - t0);
      if (samples.length === rounds) {
        samples.sort(function (a, b) { return a - b; });
        var p50 = percentile(samples, 50);
        var p95 = percentile(samples, 95);
        console.log(
          "GB-PERF fromasync_waitasync p50=" +
            p50.toFixed(3) +
            "ms p95=" +
            p95.toFixed(3) +
            "ms n=" +
            rounds
        );
        assert(
          p95 <= 2000,
          "GB-PERF fromasync_waitasync: p95 " + p95.toFixed(3) + "ms exceeds 2000ms"
        );
        __jacDone();
      }
    }, function (err) {
      __reg.fail("GB-PERF fromasync_waitasync rejected: " + err);
      __jacDone();
    });
  }
})();
