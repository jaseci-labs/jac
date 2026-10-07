require("./_h.js");
// Class hierarchy with polymorphic method/getter dispatch over mixed instances (AST-like).
class Node { constructor(v) { this.v = v; this.included = false; } get kind() { return "node"; } eval() { return this.v; } include() { this.included = true; } }
class Lit extends Node { get kind() { return "lit"; } }
class Add extends Node { constructor(a, b) { super(0); this.a = a; this.b = b; } get kind() { return "add"; } eval() { return this.a.eval() + this.b.eval(); } }
class Mul extends Node { constructor(a, b) { super(0); this.a = a; this.b = b; } get kind() { return "mul"; } eval() { return (this.a.eval() * this.b.eval()) & 0xffff; } }
class Neg extends Node { constructor(a) { super(0); this.a = a; } get kind() { return "neg"; } eval() { return -this.a.eval(); } }
function build(d, i) { if (d === 0) return new Lit((i + d) & 15); const k = (i + d) % 3; return k === 0 ? new Add(build(d - 1, i + 1), build(d - 1, i + 2)) : k === 1 ? new Mul(build(d - 1, i + 3), new Lit(2)) : new Neg(build(d - 1, i + 4)); }
function run(n) {
  let s = 0; const trees = []; for (let i = 0; i < 16; i++) trees.push(build(6, i));
  for (let i = 0; i < n; i++) { const t = trees[i & 15]; t.include(); s = (s + t.eval() + t.kind.length + (t instanceof Add ? 1 : 0)) & 0xffffff; }
  return s;
}
done("classes", run(N(150000)));
