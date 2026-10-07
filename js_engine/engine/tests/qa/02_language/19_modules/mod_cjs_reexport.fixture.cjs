"use strict";
// CJS module with plain-value named exports, re-exported (with rename) by an
// ESM module in test_esm_cjs_reexport_rename.mjs. Mirrors esbuild's shape, whose
// `version` vite re-exports as `export { version as esbuildVersion } from 'esbuild'`.
module.exports.version = "9.9.9";
module.exports.name = "cjs-fixture";
