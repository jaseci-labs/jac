// GC-META-001 fixture: import.meta must survive garbage collection.
//
// The realm caches one import.meta object per module (import_meta_cache) so
// `import.meta === import.meta` holds (ES §16.2.1.10). Module code usually
// drops its reference between accesses, so the cache is the ONLY thing keeping
// the object alive. Regression: gc_mark_roots did not trace import_meta_cache,
// so a collection swept the live meta object; the next `import.meta` access
// returned the recycled (empty) object — vite@6 died in constants.js on
// fileURLToPath(import.meta.url === undefined).
//
// Runs under `js_engine --gc` (the .sh wrapper forces the flag).

function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }

// 1. First access — creates and caches the meta object; keep only the string.
const url1 = import.meta.url;
if (typeof url1 !== "string" || url1.indexOf("file://") !== 0) {
  fail("GC-META-001: initial import.meta.url should be a file:// URL, got " + JSON.stringify(url1));
}

// 2. Force collections. collect() marks gc_pending; it is serviced on the next
//    dispatched opcode, so interleave with allocation churn to run several
//    full cycles deterministically.
let sink = null;
for (let round = 0; round < 3; round++) {
  __JS_ENGINE_GC.collect();
  for (let i = 0; i < 20000; i++) { sink = { i: i, a: [i, i + 1], s: "x" + i }; }
}
__JS_ENGINE_GC.collect();
for (let i = 0; i < 1000; i++) { sink = { i: i }; }

// 3. Second access goes through the realm cache — the object must be intact.
const meta = import.meta;
const url2 = import.meta.url;
if (typeof url2 !== "string" || url2.indexOf("file://") !== 0) {
  fail("GC-META-001: import.meta.url after GC should be a file:// URL, got " + JSON.stringify(url2));
}
if (url2 !== url1) {
  fail("GC-META-001: import.meta.url changed across GC: " + JSON.stringify(url1) + " -> " + JSON.stringify(url2));
}
if (Object.keys(meta).length < 1) {
  fail("GC-META-001: import.meta lost its own properties across GC (keys=" + JSON.stringify(Object.keys(meta)) + ")");
}
if (meta !== import.meta) {
  fail("GC-META-001: import.meta identity broken across GC (§16.2.1.10)");
}

console.log("GC-META-001 ok " + (sink ? "" : ""));
process.exit(0);
