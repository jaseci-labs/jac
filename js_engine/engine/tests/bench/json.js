require("./_h.js");
// JSON.stringify / JSON.parse round trips of nested data.
function run(n) {
  let s = 0;
  const data = { name: "pkg", version: "1.2.3", deps: {}, files: [] };
  for (let i = 0; i < 40; i++) { data.deps["dep" + i] = "^" + i + ".0.0"; data.files.push({ path: "src/f" + i + ".js", size: i * 17, tags: ["a", "b"] }); }
  for (let i = 0; i < n; i++) {
    data.version = "1.2." + (i & 255);
    const t = JSON.stringify(data); const back = JSON.parse(t);
    s = (s + t.length + back.files.length + back.files[i & 31].size) & 0xffffff;
  }
  return s;
}
done("json", run(N(6000)));
