/**
 * Regression test: globalThis.crypto is available at engine startup.
 *
 * The Web Crypto API (getRandomValues, randomUUID, subtle) must be installed
 * on globalThis before any user code runs so that scripts can call
 * crypto.getRandomValues(...) as a bare global without a preceding
 * require("crypto") or import("node:crypto").
 */
"use strict";

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/global_this_crypto");

// ── globalThis.crypto is an object ───────────────────────────────────────────
__reg.assert(
    typeof globalThis.crypto === "object" && globalThis.crypto !== null,
    "globalThis.crypto should be a non-null object"
);

// ── getRandomValues is callable ───────────────────────────────────────────────
__reg.assert(
    typeof globalThis.crypto.getRandomValues === "function",
    "globalThis.crypto.getRandomValues should be a function"
);

// ── getRandomValues fills a Uint8Array and returns it ────────────────────────
(function() {
    var arr = new Uint8Array(16);
    var ret = globalThis.crypto.getRandomValues(arr);
    __reg.assert(ret === arr, "getRandomValues must return the same TypedArray");

    var nonZero = false;
    for (var i = 0; i < arr.length; i++) { if (arr[i] !== 0) { nonZero = true; break; } }
    __reg.assert(nonZero, "getRandomValues must fill the buffer with non-zero bytes");
})();

// ── Vite startup pattern: base64url-encode 9 random bytes ────────────────────
(function() {
    var token = Buffer.from(globalThis.crypto.getRandomValues(new Uint8Array(9))).toString("base64url");
    __reg.assertEq(token.length, 12, "base64url token must be 12 chars");
    __reg.assert(/^[A-Za-z0-9_-]+$/.test(token), "token contains non-base64url chars: " + token);
})();

// ── randomUUID is callable ────────────────────────────────────────────────────
__reg.assert(
    typeof globalThis.crypto.randomUUID === "function",
    "globalThis.crypto.randomUUID should be a function"
);

// ── randomUUID returns a valid v4 UUID ───────────────────────────────────────
(function() {
    var uuid = globalThis.crypto.randomUUID();
    __reg.assertEq(typeof uuid, "string", "randomUUID must return a string");
    __reg.assertEq(uuid.length, 36, "randomUUID must be 36 chars");
    __reg.assert(
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(uuid),
        "randomUUID does not match v4 pattern: " + uuid
    );
})();

// ── subtle is defined ────────────────────────────────────────────────────────
__reg.assert(globalThis.crypto.subtle !== undefined, "globalThis.crypto.subtle must be defined");

__reg.finalize();
