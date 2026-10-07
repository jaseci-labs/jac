// MOD-011: default export  MOD-012: default import
import defaultVal, { PI } from "./mod_esm_lib.fixture.mjs";

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error("FAIL: " + msg + " | expected: " + JSON.stringify(expected) + " | actual: " + JSON.stringify(actual));
        process.exit(1);
    }
}

assertEq(defaultVal, "default-export", "MOD-011: default export value");
assertEq(PI, 3.14159,                  "MOD-012: named + default import together");

process.exit(0);
