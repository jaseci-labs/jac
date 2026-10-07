// GC-LAZYSLICE-001 fixture: a long slice of a byte-clean string is a lazy view on
// its parent (jsstring.str_slice_cell), cut only when read. MagicString.indent()
// splits a chunk at every line start and slices the rest of the module off each
// time; copying those tails was O(lines x size) — 7 GB for react-dom's 620 KB
// client bundle in a vite build — and the garbage forced a full collection every
// 68 MB. Runs under `js_engine --gc`: the views must also keep their parents alive.
function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }
if (!globalThis.__JS_ENGINE_GC) fail("GC-LAZYSLICE-001: __JS_ENGINE_GC missing (not js_engine?)");
const gc = globalThis.__JS_ENGINE_GC;
function collectNow() { gc.collect(); for (let i = 0; i < 2000; i++) ({ i }); }

// 1. MagicString.indent pattern: read the original by index, slice the rest off at each line.
const lines = [];
for (let i = 0; i < 12000; i++) lines.push("  var x" + i + " = require(\"m" + (i % 50) + "\") + " + i + "; // " + "c".repeat(i % 30));
const mod = lines.join("\n");
const c0 = gc.stats().cycles;
let rest = mod, consumed = 0;
const pieces = [];
for (let i = 0; i < mod.length; i++) {
  if (mod.charCodeAt(i) === 10) {
    pieces.push(rest.slice(0, i + 1 - consumed));
    rest = rest.slice(i + 1 - consumed);
    consumed = i + 1;
  }
}
const c1 = gc.stats().cycles;
if (pieces.length !== 11999) fail("GC-LAZYSLICE-001: expected 11999 lines, got " + pieces.length);
if (pieces.join("") + rest !== mod) fail("GC-LAZYSLICE-001: pieces + rest do not rebuild the module");
// Copying every tail is ~8 GB of string bytes (over 100 collections); views copy ~0.
if (c1 - c0 > 10) fail("GC-LAZYSLICE-001: splitting a " + mod.length + "-char string took " + (c1 - c0) + " collections (tails are being copied)");

// 2. Views outlive every other reference to their parent across collections.
const kept = [], expect = [];
for (let k = 0; k < 200; k++) {
  let big = k + ":" + "q".repeat(3000 + k) + "z".repeat(2000) + ":" + k;
  kept.push(big.slice(1000, 4500 + k));
  expect.push(4500 + k - 1000);
  big = null;
}
collectNow(); collectNow();
for (let k = 0; k < 200; k++) {
  const v = kept[k];
  if (v.length !== expect[k]) fail("GC-LAZYSLICE-001: kept slice " + k + " has length " + v.length);
  if (v.indexOf("z") !== 3000 + k + String(k).length + 1 - 1000) fail("GC-LAZYSLICE-001: kept slice " + k + " has wrong text");
}

// 3. Slice of slice of slice, and ropes holding slices, read only after collections.
let chain = mod;
for (let k = 0; k < 30; k++) chain = chain.slice(101, chain.length - 57);
const rope = mod.slice(5000, 9000) + "|" + mod.slice(200000, 230000) + "|" + mod.slice(-3000);
collectNow();
if (chain !== mod.substring(30 * 101, mod.length - 30 * 57)) fail("GC-LAZYSLICE-001: chained slices lost their text");
if (rope !== mod.substring(5000, 9000) + "|" + mod.substring(200000, 230000) + "|" + mod.substring(mod.length - 3000)) fail("GC-LAZYSLICE-001: rope of slices lost its text");
console.log("ok collections " + (c1 - c0));
