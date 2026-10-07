// VIT-CRP-001: Vite/SSR-style crypto smoke (hash + randomUUID)
var crypto = require("crypto");

var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase(
    "regression/05_integration/test_vite_crypto_smoke.js"
);
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assert(cond, msg) { __reg.assert(cond, msg); }

var id = crypto.randomUUID();
assert(id.length === 36, "VIT-CRP-001: randomUUID");

var h = crypto.createHash("sha256").update("vite").digest("hex");
assert(h.length === 64, "VIT-CRP-002: sha256 hex length");

__jacDone();
