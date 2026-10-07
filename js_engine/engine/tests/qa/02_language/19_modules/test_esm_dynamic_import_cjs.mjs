// MOD-DYNCJS-*: import() of a CommonJS `.js` file (no package "type") loads it as
// CJS, like Node: module/exports/require/__dirname are bound and the namespace's
// default is module.exports. Regression: every import() target was forced onto the
// ESM path, so @vitejs/plugin-react's `import("react-refresh/babel")` threw
// "require is not defined in ES module scope" and the dev server 500'd every .jsx.
function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(a, b, msg) {
    if (a !== b) { console.error("FAIL: " + msg + " | expected " + JSON.stringify(b) + " got " + JSON.stringify(a)); process.exit(1); }
}

const plain = await import("./mod_dynimp_cjs_plain.fixture.js");
assertEq(typeof plain.default, "function", "MOD-DYNCJS-001: module.exports function is the default export");
assertEq(plain.default(), "plain", "MOD-DYNCJS-001: default export callable");

const viaRequire = await import("./mod_dynimp_cjs_require.fixture.js");
assertEq(viaRequire.default, plain.default, "MOD-DYNCJS-002: 'use strict' + require() re-export shares the CJS module");

const named = await import("./mod_dynimp_cjs_named.fixture.js");
assertEq(named.default.answer, 42, "MOD-DYNCJS-003: exports.x on the default export");
assertEq(named.answer, 42, "MOD-DYNCJS-003: exports.x as a named export");
assertEq(named.default.where, "string", "MOD-DYNCJS-003: __dirname bound inside the CJS module");

// A plain script (no CJS bindings, no import/export) still evaluates.
await import("./mod_dynimp_script.fixture.js");
assertEq(globalThis.__dynimpScript, 1, "MOD-DYNCJS-004: script-code target evaluates");

let caught = null;
try { await import("./mod_dynimp_cjs_missing.fixture.js"); } catch (e) { caught = e; }
assert(caught !== null, "MOD-DYNCJS-005: a missing target rejects");

process.exit(0);
