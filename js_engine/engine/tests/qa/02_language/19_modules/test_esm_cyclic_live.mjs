// ESM-C-003 / ESM-C-004: cyclic ESM with live bindings (export let)
//
// Graph:  A --(named import getLiveA)--> B --(named import liveA)--> A  (cyclic)
//
//   A: named-imports getLiveA from B, exports liveA and callGetLiveA().
//   B: named-imports liveA from A, exports liveB and getLiveA().
//
// Execution order:
//   A hoists → B hoists → B sees A cycle (liveA in TDZ) → B body runs
//   (getLiveA defined) → A body runs (liveA = 10, callGetLiveA defined).
//
// What this test validates for js_engine:
//   1. Bidirectional named-import cycles complete without crashing.
//   2. After settlement, live exports hold their final values.
//   3. B.getLiveA() reads A's live binding post-settle → returns 10.
//   4. A.callGetLiveA() → B.getLiveA() → A.liveA cross-module chain → 10.
//      (ESM-C-004b: this was broken by __jac_imp_ns_N collision; fixed in
//       compiler.na.jac ImportDeclaration handler — each module's namespace
//       globals are now prefixed with its own esm_exports_global name.)
import { liveA, callGetLiveA } from "./esm_syntax_circ_live_a.mjs";
import { liveB, getLiveA } from "./esm_syntax_circ_live_b.mjs";

function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error(
            "FAIL: " + msg +
            " | expected: " + JSON.stringify(expected) +
            " | actual: " + JSON.stringify(actual)
        );
        process.exit(1);
    }
}

// Both modules must complete initialization with their declared values.
assertEq(liveA, 10, "ESM-C-003: cyclic live export A settled to 10");
assertEq(liveB, 20, "ESM-C-004: cyclic live export B settled to 20");

// B.getLiveA() reads A's live binding through the namespace object.
// After A has fully executed (liveA = 10 assigned in A's body),
// calling B's function must reflect the post-settle value.
assertEq(getLiveA(), 10, "ESM-C-003b: B.getLiveA() reads A live binding post-settle");

// A.callGetLiveA() → B.getLiveA() → reads A.liveA through B's import namespace.
// This crosses two module boundaries: A's import of B, then B's import of A.
// Previously broken by __jac_imp_ns_N collision (two modules both generated
// __jac_imp_ns_0 for their first import, clobbering each other in vm.globals).
assertEq(callGetLiveA(), 10, "ESM-C-004b: A.callGetLiveA() -> B.getLiveA() -> A.liveA cross-chain");

process.exit(0);
