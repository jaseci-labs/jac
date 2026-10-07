// ESM-C-003: cyclic live binding — module B
// B runs first (triggered by A's import hoisting).
// At this point A's body has NOT yet run, so liveA is in TDZ / undefined.
// getLiveA() is a closure over A's live binding: calling it AFTER A settles
// must return 10, proving the live-binding read goes through the namespace object.
import { liveA } from "./esm_syntax_circ_live_a.mjs";

export let liveB = 20;

export function getLiveA() {
    return liveA;
}
