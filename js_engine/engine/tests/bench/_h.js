// shared helpers: deterministic PRNG and N scaling (argv[2] = scale, default 1)
var __scale = (typeof process !== "undefined" && process.argv && process.argv[2]) ? Number(process.argv[2]) : 1;
function N(base) { return Math.max(1, Math.floor(base * __scale)); }
var __seed = 123456789;
function rnd() { __seed = (__seed * 1103515245 + 12345) & 0x7fffffff; return __seed; }
function done(name, checksum) { console.log(name + " " + checksum); }
// CommonJS: make the helpers visible to the requiring workload.
globalThis.N = N; globalThis.rnd = rnd; globalThis.done = done;
