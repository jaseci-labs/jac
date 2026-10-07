require("./_h.js");
// A hand-written JS-like tokenizer over generated source: charCodeAt scanning, slices, token objects.
function gen(lines) { let s = ""; for (let i = 0; i < lines; i++) s += "const v" + i + " = foo(v" + (i & 7) + ", 'str" + i + "', " + (i * 3) + ") + bar.baz[" + i + "];\n"; return s; }
function tokenize(src) {
  const toks = []; let i = 0; const n = src.length;
  while (i < n) {
    const c = src.charCodeAt(i);
    if (c === 32 || c === 10) { i++; continue; }
    if ((c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c === 95) { let j = i + 1; while (j < n) { const d = src.charCodeAt(j); if (!((d >= 97 && d <= 122) || (d >= 65 && d <= 90) || (d >= 48 && d <= 57) || d === 95)) break; j++; } toks.push({ t: "id", v: src.slice(i, j), s: i }); i = j; continue; }
    if (c >= 48 && c <= 57) { let j = i + 1; while (j < n && src.charCodeAt(j) >= 48 && src.charCodeAt(j) <= 57) j++; toks.push({ t: "num", v: src.slice(i, j), s: i }); i = j; continue; }
    if (c === 39) { let j = i + 1; while (j < n && src.charCodeAt(j) !== 39) j++; toks.push({ t: "str", v: src.slice(i + 1, j), s: i }); i = j + 1; continue; }
    toks.push({ t: "p", v: src[i], s: i }); i++;
  }
  return toks;
}
function run(n) { const src = gen(200); let s = 0; for (let i = 0; i < n; i++) { const t = tokenize(src); s = (s + t.length + t[i % t.length].v.length) & 0xffffff; } return s; }
done("tokenizer", run(N(150)));
