require("./_h.js");
// Array literals, push, map/filter/reduce, slice/concat/join on small arrays.
function run(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    const a = [i, i + 1, i + 2, i + 3];
    const b = a.map(x => x * 2).filter(x => x & 2);
    const c = a.slice(1).concat(b);
    c.push(i & 15);
    s = (s + c.reduce((p, q) => p + q, 0) + c.length + c.indexOf(i + 2)) & 0xffffff;
  }
  return s;
}
done("alloc_arrays", run(N(200000)));
