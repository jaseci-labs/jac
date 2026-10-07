require("./_h.js");
// Numeric kernels on typed arrays: 3x3 matrix multiply chains, byte checksums.
function run(n) {
  const m = new Float64Array(9), r = new Float64Array(9), bytes = new Uint8Array(1024);
  for (let k = 0; k < 9; k++) m[k] = (k + 1) / 10; for (let k = 0; k < 1024; k++) bytes[k] = k & 255;
  let s = 0;
  for (let i = 0; i < n; i++) {
    for (let a = 0; a < 3; a++) for (let b = 0; b < 3; b++) { let t = 0; for (let c = 0; c < 3; c++) t += m[a * 3 + c] * m[c * 3 + b]; r[a * 3 + b] = t % 7; }
    let h = 0; for (let k = 0; k < 1024; k += 4) h = (h + bytes[k] * 3 + bytes[k + 1]) & 0xffff;
    s = (s + ((r[4] * 1000) | 0) + h) & 0xffffff;
  }
  return s;
}
done("typed_arrays", run(N(40000)));
