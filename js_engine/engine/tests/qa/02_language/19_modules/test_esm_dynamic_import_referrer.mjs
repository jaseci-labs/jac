// MOD-DYNREF-001: a relative `import('./x')` and `import.meta.url` inside a
// non-entry module resolve against THAT module's directory, not the process
// entry. Regression: the referrer came from the per-module __filename global,
// which is restored once a module's top-level code finishes — so an exported
// (async) function's `import()` resolved against the entry dir. This broke
// vite/rollup loading nested chunk modules.
import { load } from "./mod_dynref_mid.fixture.mjs";

function assertEq(a, b, msg) {
    if (a !== b) { console.error("FAIL: " + msg + " | expected " + JSON.stringify(b) + " got " + JSON.stringify(a)); process.exit(1); }
}

// mod_dynref_mid lives here and imports ./dynref/leaf.fixture.mjs relative to
// itself; import.meta.url must be the mid module, not this test file.
load().then(function (r) {
    assertEq(r, "LEAF via mod_dynref_mid.fixture.mjs",
             "MOD-DYNREF-001: relative dynamic import + import.meta.url resolve against the importing module");
    process.exit(0);
}).catch(function (e) {
    console.error("FAIL: MOD-DYNREF-001: " + (e && e.message));
    process.exit(1);
});
