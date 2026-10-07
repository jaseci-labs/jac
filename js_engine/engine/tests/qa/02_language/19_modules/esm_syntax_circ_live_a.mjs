// ESM-C-003: cyclic live binding — module A
// A imports getLiveA from B (named import, creating a true bidirectional cycle).
// Execution order: A hoists → B hoists → A hoists (cycle detected, B runs
// with A's liveA still uninitialized) → B body runs → A body runs.
// callGetLiveA() reads A's import of getLiveA from B's export namespace;
// since B's body already ran, getLiveA is live and returns A.liveA = 10.
import { getLiveA } from "./esm_syntax_circ_live_b.mjs";

export let liveA = 10;
export function callGetLiveA() { return getLiveA(); }
