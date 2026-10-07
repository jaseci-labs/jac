// Intermediate ESM module that re-exports names FROM a CommonJS module.
// This is the pattern vite uses in dist/node/index.js:
//   export { version as esbuildVersion } from 'esbuild';
// Both the renamed indirect export and the plain (same-name) one must resolve
// through the CJS source's dynamically-synthesized namespace.
export { version as renamedVersion } from "./mod_cjs_reexport.fixture.cjs";
export { name } from "./mod_cjs_reexport.fixture.cjs";
