// RT-090 through RT-099: Globals absent in js_engine — verify graceful access (no crash/hang).
//
// For each name we check that typeof access does not throw.
// Where a name is ALSO absent in standard Node.js (verified), we assert it is "undefined".
// Where Node.js provides the name but js_engine does not, we only verify no crash occurs.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/01_runtime/10_missing_globals/test_missing_globals.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

// RT-090: atob / btoa — present in Node.js 16+; absent in js_engine
// Only verify access does not throw; do not assert on value.
void (typeof atob);
void (typeof btoa);

// RT-091: TextEncoder / TextDecoder
// Node.js exposes these as globals; js_engine may not (only via require('util')).
// Accept any value — just verify no crash.
void (typeof TextEncoder);
void (typeof TextDecoder);

// RT-092: structuredClone — present in Node.js 17+; absent in js_engine
void (typeof structuredClone);

// RT-093: Blob / File / FormData
// Blob and FormData exist in Node.js; File may be absent (older Node) or a global (Node 20+).
void (typeof Blob);
void (typeof File);
void (typeof FormData);

// RT-094: crypto / Crypto / CryptoKey / SubtleCrypto
// crypto (object) exists in Node.js; constructor globals may appear on newer Node (undici/webcrypto).
void (typeof crypto);
void (typeof Crypto);
void (typeof CryptoKey);
void (typeof SubtleCrypto);

// RT-095: Event / EventTarget / CustomEvent
// Event and EventTarget exist in Node.js; CustomEvent may be absent or global depending on Node.
void (typeof Event);
void (typeof EventTarget);
void (typeof CustomEvent);

// RT-096: MessageChannel / MessagePort / BroadcastChannel — all present in Node.js
void (typeof MessageChannel);
void (typeof MessagePort);
void (typeof BroadcastChannel);

// RT-097: navigator / Navigator — Node.js 24+ exposes these; localStorage / sessionStorage stay absent
void (typeof navigator);
void (typeof Navigator);
assert(typeof localStorage === "undefined",   "RT-097: typeof localStorage === 'undefined'");
assert(typeof sessionStorage === "undefined", "RT-097: typeof sessionStorage === 'undefined'");

// RT-098: ReadableStream / WritableStream / TransformStream — present in Node.js 16+
void (typeof ReadableStream);
void (typeof WritableStream);
void (typeof TransformStream);

// RT-099: WebAssembly / DOMException — WebAssembly is present in Node.js; DOMException too
void (typeof WebAssembly);
void (typeof DOMException);

__jacDone();
