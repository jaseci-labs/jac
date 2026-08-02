#!/usr/bin/env node
/**
 * Node host for xop_wasm_call: instantiate a wasm32 module and time export calls.
 *
 * Usage:
 *   node harness/wasm_host.mjs <wasm-path> <work> <calls>
 *
 * Prints the interopbench result protocol (digest + ns + m: lines).
 */
import { readFileSync } from "node:fs";
import { performance } from "node:perf_hooks";

const [wasmPath, workArg, callsArg] = process.argv.slice(2);
if (!wasmPath || !workArg || !callsArg) {
  console.error("usage: wasm_host.mjs <wasm> <work> <calls>");
  process.exit(2);
}

const work = Number(workArg);
const calls = Number(callsArg);
if (!Number.isInteger(work) || work < 1 || !Number.isInteger(calls) || calls < 1) {
  console.error("work and calls must be positive integers");
  process.exit(2);
}

let mem;
const dec = new TextDecoder();
const jac_host1 = new Proxy(
  {
    write: (fd, ptr, n) => {
      dec.decode(new Uint8Array(mem.buffer, ptr, n));
      return n;
    },
    fflush: () => 0,
    getenv: () => 0,
    abort: () => {
      throw new Error("wasm abort");
    },
  },
  { get: (t, k) => t[k] ?? ((...a) => 0) },
);

const bytes = readFileSync(wasmPath);
let instance;
try {
  ({ instance } = await WebAssembly.instantiate(bytes, { jac_host1 }));
} catch {
  const env = new Proxy(
    {},
    {
      get: (_t, k) => {
        if (k === "then") return undefined;
        return (..._a) => 0;
      },
    },
  );
  ({ instance } = await WebAssembly.instantiate(bytes, { env, jac_host1 }));
}
const e = instance.exports;
mem = e.memory;
if (typeof e.__jac_glob_init === "function") {
  e.__jac_glob_init();
}
const compute = e.bench_compute;
if (typeof compute !== "function") {
  console.error("wasm module missing bench_compute export");
  process.exit(2);
}

const bench = (w, c) => {
  let checksum = 0;
  for (let callNo = 0; callNo < c; callNo += 1) {
    const seed = BigInt(callNo + 1);
    const out = Number(compute(seed, BigInt(w)));
    checksum = (checksum + out) % 2147483648;
  }
  return checksum;
};

bench(work, 1);
const t0 = performance.now();
const checksum = bench(work, calls);
const elapsedNs = Math.round((performance.now() - t0) * 1e6);

console.log(`wasm:${checksum}`);
console.log(`m:per_call_ns=${Math.floor(elapsedNs / calls)}`);
console.log(`ns=${elapsedNs}`);
