require("./_h.js");
// Short-lived objects with 3-6 properties, some kept alive (GC pressure), reads back.
function Point(x, y) { this.x = x; this.y = y; this.z = x ^ y; }
function run(n) {
  const keep = []; let s = 0;
  for (let i = 0; i < n; i++) {
    const o = { a: i, b: i + 1, c: "s" + (i & 7), d: null, e: i & 1 ? true : false };
    const p = new Point(i, s & 1023);
    s = (s + o.a + o.b + p.z + (o.e ? 1 : 0)) & 0xffffff;
    if ((i & 63) === 0) keep.push(o, p);
    if (keep.length > 4096) keep.length = 0;
  }
  return s + keep.length;
}
done("alloc_objects", run(N(600000)));
