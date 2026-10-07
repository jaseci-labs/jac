// SCP-M-002: import declarations are hoisted — binding usable before source line of import
function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(a, e, msg) {
    if (a !== e) { console.error("FAIL: " + msg + " | expected: " + JSON.stringify(e) + " | actual: " + JSON.stringify(a)); process.exit(1); }
}

assertEq(scpMExported, 100, "SCP-M-002: imported binding visible before import line in source");
import { scpMExported } from "./test_scope_esm_export.mjs";

process.exit(0);
