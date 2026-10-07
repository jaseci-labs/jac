// ESM-B-C5: assigning to an import binding must throw TypeError (§10.4.6).
// The compiler emits POP + LOAD_GLOBAL TypeError + CALL + THROW at compile
// time, so the throw is unconditional — no silent STORE_GLOBAL fallback.
import { counter } from "./esm_syntax_lib.mjs";

function assert(cond, msg) {
    if (!cond) {
        console.error("FAIL: " + msg);
        process.exit(1);
    }
}

// Reading the import binding must work.
assert(typeof counter === "number", "ESM-B-C5: import binding is readable");

// Assigning to an import binding must throw TypeError.
var threw = false;
var errMsg = "";
try {
    counter = 99; // compiler turns this into: POP + throw new TypeError(...)
} catch (e) {
    threw = e instanceof TypeError;
    errMsg = e ? String(e.message) : "";
}
assert(threw, "ESM-B-C5: assignment to import binding throws TypeError (got: " + errMsg + ")");

// The original binding value must be unchanged.
assert(counter === 0, "ESM-B-C5: import binding unchanged after failed assignment (got: " + counter + ")");
