// MOD-CJSREEXP-001: `export { x as y } from './cjs'` — a renamed (indirect)
// re-export whose SOURCE is a CommonJS module. ResolveExport must succeed for
// the aliased name and the value must flow through the CJS module's
// dynamically-synthesized namespace.
//
// Regression: esm_resolve_export walked only the source's ESM I:/L:/T: export
// metadata, which a CJS module has none of, so it returned "null" →
// "The requested module does not provide an export named 'y'". A DIRECT
// `import { x } from './cjs'` already worked; only the re-export-with-rename
// form was broken. This is exactly vite@6's
//   export { version as esbuildVersion } from 'esbuild';
// which made `js_engine node_modules/vite/bin/vite.js build` fail to load the
// config. Runs byte-identically under Node and js_engine.
import { renamedVersion, name } from "./mod_cjs_reexport_lib.fixture.mjs";
import * as ns from "./mod_cjs_reexport_lib.fixture.mjs";

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(a, b, msg) {
    if (a !== b) { console.error("FAIL: " + msg + " | expected " + JSON.stringify(b) + " got " + JSON.stringify(a)); process.exit(1); }
}

// Renamed indirect re-export from CJS resolves and carries the value.
assertEq(renamedVersion, "9.9.9", "MOD-CJSREEXP-001: renamed re-export from CJS binds the value");
// Same-name indirect re-export from CJS resolves too.
assertEq(name, "cjs-fixture", "MOD-CJSREEXP-001: same-name re-export from CJS binds the value");
// Namespace of the re-exporting ESM module exposes both under their export names.
assertEq(ns.renamedVersion, "9.9.9", "MOD-CJSREEXP-001: namespace exposes renamed re-export");
assertEq(ns.name, "cjs-fixture", "MOD-CJSREEXP-001: namespace exposes same-name re-export");
// The ORIGINAL source name must NOT leak under the re-exporter's namespace.
assertEq(ns.version, undefined, "MOD-CJSREEXP-001: source name 'version' is not re-exported (only the alias)");

process.exit(0);
