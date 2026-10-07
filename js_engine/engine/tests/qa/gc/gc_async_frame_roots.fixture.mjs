// GC-ASYNC-001 fixture: a SUSPENDED async frame must survive collection.
//
// When an async function `await`s a pending promise, its frame is snapshotted
// into a JSGeneratorState (realm.generators) referenced only by an integer
// index inside the promise's async-resume reaction marker — not by any
// traceable JSValue. Regression: gc_mark_roots never rooted these, so a
// collection while the frame was suspended let gc_sweep_generators reclaim the
// live state and clear its `locals` to []. On resume, the first LOAD/STORE_LOCAL
// hit an empty locals list → "list assignment index out of range" (vite@6
// config load: async `bundleConfigFile` under --gc).
//
// This drives that exact sequence: start an async fn with several locals, let
// it suspend on a pending promise, run heavy allocation churn + forced GC while
// it is suspended, then resolve and resume. Without the fix the locals are gone
// and the resumed body crashes.
//
// Runs under `js_engine --gc` (the .sh wrapper forces the flag).

function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }

let resolveGate;
const gate = new Promise((r) => { resolveGate = r; });

async function work(seed) {
  // Eight locals whose values must survive the await across GC.
  const a = seed + 1;
  const b = seed + 2;
  const c = seed + 3;
  const d = seed + 4;
  const e = seed + 5;
  const f = seed + 6;
  const g = seed + 7;
  const h = seed + 8;
  await gate;                 // suspend on a genuinely pending promise
  // Post-resume STORE_LOCALs + reads — these index frame.locals, which would be
  // empty if the suspended state had been swept.
  const s1 = a + b + c + d;
  const s2 = e + f + g + h;
  return s1 + s2;             // seed*8 + 36
}

const seed = 10;
const wp = work(seed);        // runs synchronously to `await gate`, then suspends

// The async frame is now suspended and reachable only via the pending `gate`
// promise's reaction. Churn hard + collect so a swept state's slot is recycled.
let sink = null;
for (let round = 0; round < 4; round++) {
  __JS_ENGINE_GC.collect();
  for (let i = 0; i < 60000; i++) { sink = { i: i, a: [i, i + 1], s: "w" + i, n: { d: i } }; }
}
__JS_ENGINE_GC.collect();
for (let i = 0; i < 60000; i++) { sink = { i: i, e: ["z", i] }; }

resolveGate();                // settle the promise → schedule work()'s resume
let result;
try {
  result = await wp;          // top-level await: drive the resume
} catch (err) {
  fail("GC-ASYNC-001: resume threw (suspended frame swept): " + (err && err.message ? err.message : err));
}

const expected = seed * 8 + 36; // 116
if (result !== expected) {
  fail("GC-ASYNC-001: wrong result after GC across await: expected " + expected + " got " + JSON.stringify(result));
}

console.log("GC-ASYNC-001 ok " + (sink ? "" : ""));
process.exit(0);
