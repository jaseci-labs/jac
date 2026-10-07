// MOD-010: named exports  MOD-012: named imports and rename
import { PI, double, Point } from "./mod_esm_lib.fixture.mjs";
import { PI as myPI } from "./mod_esm_lib.fixture.mjs";

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error("FAIL: " + msg + " | expected: " + JSON.stringify(expected) + " | actual: " + JSON.stringify(actual));
        process.exit(1);
    }
}

assertEq(PI, 3.14159,   "MOD-010/012: named export PI");
assertEq(double(5), 10, "MOD-010/012: named export function");
var p = new Point(1, 2);
assertEq(p.toString(), "(1,2)", "MOD-010/012: named export class");
assertEq(myPI, 3.14159, "MOD-012: import with rename");

process.exit(0);
