// GC-STRBYTES-001 fixture: heap-string BYTES must drive collections. The object
// trigger counts allocations, so a slice-heavy phase with almost no objects
// (rollup's render: magic-string / sourcemap chains over MB chunks) never
// collected — 1GB of discarded slices grew RSS by ~770MB with zero cycles and
// vite's build:render+write OOM'd at 12.6GB. Runs under `js_engine --gc`.
function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }
if (!globalThis.__JS_ENGINE_GC) fail("GC-STRBYTES-001: __JS_ENGINE_GC missing (not js_engine?)");
const c0 = __JS_ENGINE_GC.stats().cycles;
const big = "abcdefghij".repeat(100000);           // 1MB
let n = 0;
// toUpperCase always builds a new 500KB string; a bare slice() no longer does
// (a long slice is a lazy view on `big`, see jsstring.str_slice_cell).
for (let i = 0; i < 400; i++) n += big.slice(i, i + 500000).toUpperCase().length;   // 200MB+ of string garbage, no objects
const c1 = __JS_ENGINE_GC.stats().cycles;
if (!(c1 > c0)) fail("GC-STRBYTES-001: 200MB of discarded strings triggered no collection (cycles " + c0 + " -> " + c1 + ")");
if (n !== 400 * 500000) fail("GC-STRBYTES-001: slice lengths wrong " + n);
console.log("ok cycles " + c0 + " -> " + c1);
