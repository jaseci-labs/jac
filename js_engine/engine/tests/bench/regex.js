require("./_h.js");
// Regex test/exec/replace/split over synthetic source text (tokenizer-ish).
function run(n) {
  const src = "import { a, b } from './x.js'; export const value = foo(1, 2) + bar.baz * 3; // comment\n";
  const ident = /[A-Za-z_$][\w$]*/g, num = /\d+/g, imp = /^import\s+\{([^}]*)\}\s+from\s+'([^']+)'/;
  let s = 0;
  for (let i = 0; i < n; i++) {
    const line = src.replace("value", "v" + (i & 63));
    const m = imp.exec(line); s = (s + (m ? m[2].length : 0)) & 0xffffff;
    const ids = line.match(ident); s = (s + ids.length) & 0xffffff;
    s = (s + line.replace(num, "0").length + line.split(/\s+/).length + (/export/.test(line) ? 1 : 0)) & 0xffffff;
  }
  return s;
}
done("regex", run(N(60000)));
