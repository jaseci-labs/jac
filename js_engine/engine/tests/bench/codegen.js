require("./_h.js");
// Code generation: building output text from parts with arrays + join, indentation, replacements (magic-string-like).
function emit(fnCount) {
  const out = []; let indent = "";
  for (let i = 0; i < fnCount; i++) {
    out.push(indent + "function f" + i + "(a, b) {"); indent += "  ";
    for (let k = 0; k < 8; k++) out.push(indent + "const x" + k + " = a * " + k + " + b;");
    out.push(indent + "return x0 + x7;"); indent = indent.slice(2); out.push(indent + "}");
  }
  return out.join("\n");
}
function run(n) { let s = 0; for (let i = 0; i < n; i++) { const code = emit(40).replace(/const/g, "let"); s = (s + code.length + code.split("\n").length) & 0xffffff; } return s; }
done("codegen", run(N(400)));
