// test_promises.js — Phase 2.8: Promise & async/await tests
// ============================================================
// Rewritten to use async/await so .then() callbacks are properly deferred
// (spec-compliant: Promise reactions run as microtasks, not synchronously).

var passed = 0;
var failed = 0;

function assert(cond, msg) {
  if (cond) {
    console.log("OK: " + msg);
    passed++;
  } else {
    console.log("FAIL: " + msg);
    failed++;
  }
}

async function main() {

// ── 1. Promise.resolve / Promise.reject ──────────────────────────────────────
  var p1 = Promise.resolve(42);
  assert(typeof p1 === "object", "Promise.resolve returns object");

  var val1 = await p1;
  assert(val1 === 42, "Promise.resolve .then receives value");

  var caught1;
  try { await Promise.reject("err"); } catch(r) { caught1 = r; }
  assert(caught1 === "err", "Promise.reject .catch receives reason");

// ── 2. new Promise(executor) ──────────────────────────────────────────────────
  var out2 = await new Promise(function(resolve) { resolve(99); });
  assert(out2 === 99, "new Promise executor resolve");

  var reason2;
  try {
    await new Promise(function(resolve, reject) { reject("no good"); });
  } catch(r) { reason2 = r; }
  assert(reason2 === "no good", "new Promise executor reject");

// ── 3. .then chaining ────────────────────────────────────────────────────────
  var result3 = await Promise.resolve(1)
    .then(function(v) { return v + 1; })
    .then(function(v) { return v * 3; });
  assert(result3 === 6, ".then chain 1→2→*3→6");

// ── 4. .then returning a Promise ─────────────────────────────────────────────
  var result4 = await Promise.resolve(5)
    .then(function(v) { return Promise.resolve(v * 2); });
  assert(result4 === 10, ".then returning Promise unwraps it");

// ── 5. .catch after rejection ────────────────────────────────────────────────
  var out5 = await Promise.reject("boom")
    .catch(function(r) { return "handled: " + r; });
  assert(out5 === "handled: boom", ".catch recovers and chains .then");

// ── 6. .finally ──────────────────────────────────────────────────────────────
  var S6a = { finallyRan: false };
  var result6a = await Promise.resolve(7)
    .finally(function() { S6a.finallyRan = true; });
  assert(S6a.finallyRan === true, ".finally handler called on fulfilled");
  assert(result6a === 7, ".finally passes value through");

  var S6b = { finallyRan: false };
  var reason6b;
  try {
    await Promise.reject("x").finally(function() { S6b.finallyRan = true; });
  } catch(r) { reason6b = r; }
  assert(S6b.finallyRan === true, ".finally handler called on rejected");
  assert(reason6b === "x", ".finally passes rejection through");

// ── 7. Promise.all ────────────────────────────────────────────────────────────
  var result7 = await Promise.all([
    Promise.resolve(1), Promise.resolve(2), Promise.resolve(3)
  ]);
  assert(result7 !== null, "Promise.all resolves");
  assert(result7[0] === 1 && result7[1] === 2 && result7[2] === 3, "Promise.all values correct");

  var reason7;
  try {
    await Promise.all([Promise.resolve(1), Promise.reject("oops")]);
  } catch(r) { reason7 = r; }
  assert(reason7 === "oops", "Promise.all rejects on first rejection");

// ── 8. Promise.allSettled ────────────────────────────────────────────────────
  var result8 = await Promise.allSettled([Promise.resolve("ok"), Promise.reject("no")]);
  assert(result8 !== null, "Promise.allSettled resolves");
  assert(result8[0].status === "fulfilled", "allSettled[0] fulfilled");
  assert(result8[0].value === "ok", "allSettled[0] value");
  assert(result8[1].status === "rejected", "allSettled[1] rejected");
  assert(result8[1].reason === "no", "allSettled[1] reason");

// ── 9. Promise.race ───────────────────────────────────────────────────────────
  var result9 = await Promise.race([Promise.resolve("first"), Promise.resolve("second")]);
  assert(result9 === "first", "Promise.race picks first settled");

// ── 10. Promise.any ───────────────────────────────────────────────────────────
  var result10 = await Promise.any([Promise.reject("a"), Promise.resolve("b")]);
  assert(result10 === "b", "Promise.any picks first fulfilled");

  var caught10 = false;
  try {
    await Promise.any([Promise.reject("a"), Promise.reject("b")]);
  } catch(e) { caught10 = true; }
  assert(caught10 === true, "Promise.any rejects when all reject");

// ── 11. async function ───────────────────────────────────────────────────────
  async function add(a, b) { return a + b; }
  var result11 = await add(3, 4);
  assert(result11 === 7, "async function wraps return in Promise");

// ── 12. async function with await ────────────────────────────────────────────
  async function double(x) {
    var v = await Promise.resolve(x * 2);
    return v;
  }
  var out12 = await double(5);
  assert(out12 === 10, "async function with await");

// ── 13. await on non-Promise ────────────────────────────────────────────────
  async function wrap(x) {
    var v = await x;
    return v + 1;
  }
  var out13 = await wrap(10);
  assert(out13 === 11, "await on non-Promise passes value through");

// ── 14. Executor throws → rejected promise ──────────────────────────────────
  var reason14;
  try {
    await new Promise(function() { throw "thrown"; });
  } catch(r) { reason14 = r; }
  assert(reason14 === "thrown", "executor throw creates rejected promise");

// ── 15. Promise.resolve(promise) returns same promise ───────────────────────
  var p15 = Promise.resolve(42);
  var p15b = Promise.resolve(p15);
  var out15a = await p15;
  var out15b = await p15b;
  assert(out15a === 42 && out15b === 42, "Promise.resolve(promise) passes through");

// ── 16. Chained async/await ────────────────────────────────────────────────
  async function step1() { return 10; }
  async function step2() {
    var v = await step1();
    return v + 5;
  }
  var out16 = await step2();
  assert(out16 === 15, "chained async/await");

} // end main

// ── Summary ──────────────────────────────────────────────────────────────────
main().then(function() {
  console.log("\n=== Promise tests: " + passed + " passed, " + failed + " failed ===");
}).catch(function(e) {
  console.log("FATAL: " + e);
  console.log("\n=== Promise tests: " + passed + " passed, " + (failed + 1) + " failed ===");
});
