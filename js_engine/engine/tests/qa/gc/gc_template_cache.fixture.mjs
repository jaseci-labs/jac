// GC-TMPL-001 fixture: tagged-template site arrays must survive GC.
//
// The realm caches the frozen strings array per template SITE
// (realm.template_cache) so every evaluation of the site yields the SAME
// array (ES §13.2.8.4 GetTemplateObject). Between evaluations the cache is
// typically the only reference. Regression class: an unrooted cache lets a
// collection sweep the live array; the next evaluation hands back a recycled
// object — identity breaks and the cooked/raw strings read as garbage.
//
// Runs under `js_engine --gc` (the .sh wrapper forces the flag).

function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }

function tag(strings) { return strings; }
function site() { return tag`hello ${1} world`; }

// Baseline: same-site identity with no GC in between. Evaluate inside a
// function so the array references are FRAME LOCALS that die on return —
// a module-level const would root the array through the VM frame for the
// whole run and the cache entry could never be (incorrectly) swept.
function baseline() {
  const x = site();
  const y = site();
  if (x !== y) fail("GC-TMPL-001: same-site template arrays must be identical (baseline)");
  if (x[0] !== "hello " || x[1] !== " world") {
    fail("GC-TMPL-001: baseline cooked strings wrong: " + JSON.stringify([x[0], x[1]]));
  }
  return x[0]; // primitive only — no object ref escapes
}
const cooked0 = baseline();

// The cache is now the only reference. Force collections with enough
// allocation churn afterwards to REUSE any incorrectly-freed slots.
let sink = null;
for (let round = 0; round < 3; round++) {
  __JS_ENGINE_GC.collect();
  for (let i = 0; i < 50000; i++) { sink = { i: i, s: "y" + i, l: [i] }; }
}
__JS_ENGINE_GC.collect();
for (let i = 0; i < 50000; i++) { sink = { i: i, a: [i, "r" + i] }; }

// Re-evaluate the site: cache must still hold the intact array.
const b = site();
if (b[0] !== "hello " || b[1] !== " world") {
  fail("GC-TMPL-001: cooked strings corrupted after GC: " + JSON.stringify([b[0], b[1]]));
}
if (!b.raw || b.raw[0] !== "hello " || b.raw[1] !== " world") {
  fail("GC-TMPL-001: raw strings corrupted after GC: " + JSON.stringify(b.raw && [b.raw[0], b.raw[1]]));
}
if (b.length !== 2) fail("GC-TMPL-001: template array length changed after GC: " + b.length);
if (b[0] !== cooked0) fail("GC-TMPL-001: cooked[0] changed across GC");
// And identity across evaluations still holds after collections.
const c = site();
if (b !== c) fail("GC-TMPL-001: same-site identity broken after GC");

console.log("GC-TMPL-001 ok " + (sink ? "" : ""));
process.exit(0);
