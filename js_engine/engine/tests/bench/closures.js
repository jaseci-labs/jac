require("./_h.js");
// Closure creation, higher-order functions, currying, captured mutable state.
function counter() { let c = 0; return () => ++c; }
function compose(f, g) { return x => f(g(x)); }
function curry3(f) { return a => b => c => f(a, b, c); }
function run(n) {
  let s = 0; const add3 = curry3((a, b, c) => a + b + c);
  for (let i = 0; i < n; i++) {
    const inc = counter(); inc(); inc();
    const h = compose(x => x + i, x => x * 2);
    s = (s + h(3) + inc() + add3(i)(1)(2)) & 0xffffff;
  }
  return s;
}
done("closures", run(N(300000)));
