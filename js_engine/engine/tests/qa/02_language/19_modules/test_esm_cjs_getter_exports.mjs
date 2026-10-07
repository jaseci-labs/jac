// MOD-CJSGET-001: named imports from a CJS module whose named exports are
// enumerable GETTERS on module.exports (the tsc/esbuild `__toCommonJS` pattern)
// must bind to the getter's live value, not undefined. Regression: the CJS→ESM
// namespace copy read each key with a raw non-observable get (returns undefined
// for an accessor slot), so `import { transform } from 'esbuild'` bound to
// undefined → "transform$1 is not a function" in vite's esbuild plugin.
import esbuildLike, { transform, build } from "./mod_cjs_getter_exports.fixture.cjs";
import * as ns from "./mod_cjs_getter_exports.fixture.cjs";

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(a, b, msg) {
    if (a !== b) { console.error("FAIL: " + msg + " | expected " + JSON.stringify(b) + " got " + JSON.stringify(a)); process.exit(1); }
}

// Named imports resolve the getter value.
assert(typeof transform === "function", "MOD-CJSGET-001: named import transform is a function");
assert(typeof build === "function", "MOD-CJSGET-001: named import build is a function");
assertEq(transform("x"), "T:x", "MOD-CJSGET-001: named import transform() works");

// Namespace access resolves the getter too.
assert(typeof ns.transform === "function", "MOD-CJSGET-001: ns.transform is a function");

// Default import (the CJS exports object) still exposes the getters.
assert(typeof esbuildLike.transform === "function", "MOD-CJSGET-001: default.transform is a function");
assertEq(esbuildLike.build("o"), "B:o", "MOD-CJSGET-001: default.build() works");

process.exit(0);
