require("./_h.js");
// Call-heavy recursion: fib, ackermann-lite, mutual recursion, deep tail-shaped loops.
function fib(n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
function isEven(n) { return n === 0 ? true : isOdd(n - 1); } function isOdd(n) { return n === 0 ? false : isEven(n - 1); }
function ack(m, n) { return m === 0 ? n + 1 : n === 0 ? ack(m - 1, 1) : ack(m - 1, ack(m, n - 1)); }
function run(n) { let s = 0; for (let i = 0; i < n; i++) { s = (s + fib(16) + (isEven(200 + (i & 7)) ? 1 : 0) + ack(2, 3 + (i & 3))) & 0xffffff; } return s; }
done("recursion", run(N(300)));
