// GC-PKG-001 fixture: package "exports"-map resolution must survive GC.
//
// The resolver caches each parsed package.json as a JSValue object tree in
// the glob dict _PKG_JSON_CACHE (module_resolver.jac). A glob dict is
// invisible to gc_mark_roots, so unless every cached object is explicitly
// pinned, a collection sweeps the parsed exports map while the cache still
// points at the (recycled) slot — later subpath resolution against the SAME
// package walks garbage and fails with "Cannot find module '<target>' in
// package". This is the vite@6 `--gc` failure on 'vite/module-runner'.
//
// Order matters: the FIRST import caches the parsed package.json; the
// collections run; the SECOND (subpath) import re-reads the cached object.
//
// Runs under `js_engine --gc` (the .sh wrapper forces the flag).

function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }

// 1. Bare import — parses and caches rpkg/package.json, resolves "." target.
const idx = await import("rpkg");
if (idx.who !== "rpkg-index") fail("GC-PKG-001: bare specifier resolved wrong module: " + JSON.stringify(idx.who));

// 2. Force collections with allocation churn (collect() is serviced on the
//    next dispatched opcode). The post-collect churn is deliberately heavy —
//    a swept-but-not-yet-reused slot still reads as the old object, so the
//    bug only manifests once the freed slots are RECYCLED by new objects
//    (matching the vite build's allocation pressure).
let sink = null;
for (let round = 0; round < 4; round++) {
  __JS_ENGINE_GC.collect();
  for (let i = 0; i < 60000; i++) { sink = { i: i, a: [i, i + 1], s: "z" + i, n: { d: i } }; }
}
__JS_ENGINE_GC.collect();
for (let i = 0; i < 60000; i++) { sink = { i: i, e: ["x", i] }; }

// 3. Subpath imports re-read the CACHED parsed package.json exports map.
const run = await import("rpkg/runner");
if (run.runner !== "rpkg-runner") fail("GC-PKG-001: exports subpath './runner' broken after GC: " + JSON.stringify(run.runner));
const ex = await import("rpkg/extra");
if (ex.extra !== "rpkg-extra") fail("GC-PKG-001: exports subpath './extra' broken after GC: " + JSON.stringify(ex.extra));

console.log("GC-PKG-001 ok " + (sink ? "" : ""));
process.exit(0);
