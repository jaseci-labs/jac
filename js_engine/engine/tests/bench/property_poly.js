require("./_h.js");
// Megamorphic property reads/writes: many object shapes through the same sites.
function mk(k, i) { const o = {}; o["p" + (k % 13)] = i; if (k & 1) o.q = i; o.v = i; if (k & 2) o.w = 1; return o; }
function run(n) {
  const objs = []; for (let k = 0; k < 64; k++) objs.push(mk(k, k));
  let s = 0;
  for (let i = 0; i < n; i++) { const o = objs[i & 63]; s = (s + o.v + (o.q | 0)) & 0xffffff; o.v = s & 1023; o.extra = i; }
  return s;
}
done("property_poly", run(N(1500000)));
