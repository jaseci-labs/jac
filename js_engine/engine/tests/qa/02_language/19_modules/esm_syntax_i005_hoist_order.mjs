// ESM-I-005: import hoisting — binding usable textually above import line
function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error(
            "FAIL: " +
                msg +
                " | expected: " +
                JSON.stringify(expected) +
                " | actual: " +
                JSON.stringify(actual)
        );
        process.exit(1);
    }
}

assertEq(hoistVal, 1, "ESM-I-005: import binding usable before declaration line");
import { hoistVal } from "./esm_syntax_hoist_lib.mjs";

process.exit(0);
