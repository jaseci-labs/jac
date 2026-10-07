require("./_h.js");
// Array sort with comparators (numbers, strings, objects by key).
function run(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    const a = []; for (let k = 0; k < 64; k++) a.push((rnd() >> 8) & 0xffff);
    a.sort((x, y) => x - y); s = (s + a[0] + a[63]) & 0xffffff;
    const b = a.map(x => "k" + x); b.sort(); s = (s + b[7].length) & 0xffffff;
    const c = a.map((x, k) => ({ key: x, idx: k })); c.sort((p, q) => q.key - p.key || p.idx - q.idx); s = (s + c[0].idx) & 0xffffff;
  }
  return s;
}
done("sort", run(N(6000)));
