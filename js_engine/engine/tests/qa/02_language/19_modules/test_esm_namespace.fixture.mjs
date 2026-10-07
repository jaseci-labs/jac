// MOD-013: namespace import (import * as mod)
import * as lib from "./mod_esm_lib.fixture.mjs";

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error("FAIL: " + msg + " | expected: " + JSON.stringify(expected) + " | actual: " + JSON.stringify(actual));
        process.exit(1);
    }
}

assertEq(lib.PI, 3.14159,   "MOD-013: namespace import PI");
assertEq(lib.double(3), 6,  "MOD-013: namespace import function");
assertEq(typeof lib.default, "string", "MOD-013: namespace includes default");

process.exit(0);
