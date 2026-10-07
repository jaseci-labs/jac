// GC-NATIVE-001 fixture: a native builtin's IN-FLIGHT values must survive a
// collection that fires during its callback VM re-entry.
//
// Array.prototype.map (and filter/flatMap/reduce/Array.from) allocate their
// result/accumulator in native (jac) locals, then re-enter the VM per element
// to run the callback. Those locals are invisible to the GC root walk, so a
// collection landing inside a callback swept the LIVE result array mid-loop —
// it read back as a cleared non-array with later elements re-appended.
// Real-world: vite's cac Option `names = raw.split(",").map(...)` corrupted
// this way (option.name stored undefined → the alignment-sensitive
// `checkOptionValue` "reading 'split'" crash on real jac-client apps).
//
// Deterministic forcing: __JS_ENGINE_GC.collect() inside the callback marks
// gc_pending, serviced at the next dispatch-loop safepoint — which is INSIDE
// the map re-entry, no timing alignment needed. Churn afterwards recycles any
// wrongly-freed slots so corruption becomes visible.
//
// Runs under `js_engine --gc` (the .sh wrapper forces the flag).

function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }

function churn() {
  let s = null;
  for (let k = 0; k < 30000; k++) { s = { k: k, a: [k, k + 1], t: "c" + k }; }
  return s ? 1 : 0;
}

// ── map: result array must survive a mid-loop collection ────────────────────
const src = [];
for (let i = 0; i < 40; i++) src.push(i);
const out = src.map((v, i) => {
  if (i === 5) { __JS_ENGINE_GC.collect(); churn(); }
  return v * 2;
});
if (!Array.isArray(out)) fail("GC-NATIVE-001: map result is not an Array after mid-loop GC");
if (out.length !== 40) fail("GC-NATIVE-001: map result length " + out.length + " !== 40 after mid-loop GC");
for (let i = 0; i < 40; i++) {
  if (out[i] !== i * 2) fail("GC-NATIVE-001: map result[" + i + "] = " + JSON.stringify(out[i]) + " !== " + (i * 2));
}

// ── filter: same for its result array ───────────────────────────────────────
const evens = src.filter((v, i) => {
  if (i === 5) { __JS_ENGINE_GC.collect(); churn(); }
  return v % 2 === 0;
});
if (!Array.isArray(evens) || evens.length !== 20) {
  fail("GC-NATIVE-001: filter result corrupted after mid-loop GC (len=" + (evens && evens.length) + ")");
}

// ── reduce: OBJECT accumulator must survive between callback re-entries ─────
const acc = src.reduce((a, v, i) => {
  if (i === 5) { __JS_ENGINE_GC.collect(); churn(); }
  a.sum += v;
  return a;
}, { sum: 0 });
const wantSum = (39 * 40) / 2;
if (!acc || typeof acc !== "object" || acc.sum !== wantSum) {
  fail("GC-NATIVE-001: reduce accumulator corrupted after mid-loop GC (sum=" + (acc && acc.sum) + " want " + wantSum + ")");
}

// ── Array.from(iterable, mapFn): result must survive iterator re-entries ────
function* gen() { for (let i = 0; i < 30; i++) yield i; }
const fromRes = Array.from(gen(), (v, i) => {
  if (i === 5) { __JS_ENGINE_GC.collect(); churn(); }
  return v + 100;
});
if (!Array.isArray(fromRes) || fromRes.length !== 30 || fromRes[29] !== 129) {
  fail("GC-NATIVE-001: Array.from result corrupted after mid-loop GC (len=" + (fromRes && fromRes.length) + ")");
}

// ── the exact cac shape from vite, end to end ───────────────────────────────
const removeBrackets = (v) => v.replace(/[<[].+/, "").trim();
const names = removeBrackets("--assetsDir <dir>").split(",").map((v, i) => {
  __JS_ENGINE_GC.collect(); churn();
  return v.trim().replace(/^-{1,2}/, "");
});
const name = names[names.length - 1];
if (name !== "assetsDir") fail("GC-NATIVE-001: cac-shape name = " + JSON.stringify(name) + " !== 'assetsDir'");

console.log("GC-NATIVE-001 ok");
process.exit(0);
