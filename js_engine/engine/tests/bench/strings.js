require("./_h.js");
// Concatenation, template literals, split/join, indexOf, slice, charCodeAt scanning, toUpperCase.
function run(n) {
  let s = 0; const words = ["alpha", "beta", "gamma", "delta", "epsilon"];
  for (let i = 0; i < n; i++) {
    const w = words[i % 5];
    const t = `${w}-${i & 255}:${w.length}`;
    const u = t + "/" + w.toUpperCase() + "/" + (i & 7);
    const parts = u.split("/");
    s = (s + parts.length + u.indexOf(":") + parts.join("|").length + u.slice(2, 9).length) & 0xffffff;
    let h = 0; for (let k = 0; k < u.length; k++) h = (h * 31 + u.charCodeAt(k)) & 0xffff;
    s = (s + h) & 0xffffff;
  }
  return s;
}
done("strings", run(N(200000)));
