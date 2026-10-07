require("./_h.js");
// Map/Set with string keys (module-graph style): set/get/has/delete and iteration.
function run(n) {
  const m = new Map(), st = new Set(); let s = 0;
  for (let i = 0; i < n; i++) {
    const k = "mod/" + (i & 4095) + ".js";
    const e = m.get(k); if (e === undefined) m.set(k, { id: i, deps: [] }); else e.deps.push(i & 7);
    st.add(k); if ((i & 31) === 0) { st.delete("mod/" + ((i + 1) & 4095) + ".js"); }
    s = (s + (m.has(k) ? 1 : 0) + st.size) & 0xffffff;
  }
  for (const [k, v] of m) s = (s + k.length + v.deps.length) & 0xffffff;
  return s;
}
done("maps_sets", run(N(600000)));
