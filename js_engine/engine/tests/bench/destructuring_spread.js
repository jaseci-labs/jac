require("./_h.js");
// Destructuring (params, arrays, objects, defaults, rest) and spread calls/literals.
function f({ a, b = 2, ...rest }, [x, , z = 9], ...more) { return a + b + x + z + rest.c + more.length; }
function run(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    const o = { a: i, c: 1, d: 2 }; const arr = [i, 0, i & 3];
    s = (s + f(o, arr, 1, 2, 3) + Math.max(...arr) + [...arr, ...arr].length) & 0xffffff;
    const { a, ...others } = o; const [p, q] = arr; s = (s + a + p + q + Object.keys(others).length) & 0xffffff;
  }
  return s;
}
done("destructuring_spread", run(N(200000)));
