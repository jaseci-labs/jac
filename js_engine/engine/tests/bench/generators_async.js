require("./_h.js");
// Generator pipelines and async/await over resolved promises.
function* range(a, b) { for (let i = a; i < b; i++) yield i; }
function* map(it, f) { for (const v of it) yield f(v); }
function* filter(it, f) { for (const v of it) if (f(v)) yield v; }
async function step(x) { return (await x) + 1; }
async function run(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    for (const v of filter(map(range(0, 16), x => x * 3), x => x & 1)) s = (s + v) & 0xffffff;
    s = (s + await step(i & 7) + await Promise.resolve(2)) & 0xffffff;
  }
  return s;
}
run(N(40000)).then(v => done("generators_async", v));
