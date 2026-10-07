// Test: 01_math — factorial, gcd, clamp
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}
function assertClose(a, b, msg) {
    if (Math.abs(a - b) > 1e-9) { console.error('FAIL: ' + msg + ' (got ' + a + ', expected ' + b + ')'); process.exit(1); }
}

// factorial
assert(m.factorial(0) === 1,           'factorial(0) === 1');
assert(m.factorial(1) === 1,           'factorial(1) === 1');
assert(m.factorial(5) === 120,         'factorial(5) === 120');
assert(m.factorial(10) === 3628800,    'factorial(10) === 3628800');
assert(m.factorial(20) === 2432902008176640000, 'factorial(20)');

// gcd
assert(m.gcd(12, 8) === 4,   'gcd(12,8) === 4');
assert(m.gcd(7, 3) === 1,    'gcd(7,3) === 1');
assert(m.gcd(100, 75) === 25,'gcd(100,75) === 25');
assert(m.gcd(0, 5) === 5,    'gcd(0,5) === 5');
assert(m.gcd(-12, 8) === 4,  'gcd(-12,8) === 4');

// clamp
assertClose(m.clamp(5, 0, 10),  5,  'clamp inside range');
assertClose(m.clamp(-1, 0, 10), 0,  'clamp below min');
assertClose(m.clamp(15, 0, 10), 10, 'clamp above max');
assertClose(m.clamp(0, 0, 10),  0,  'clamp at min');
assertClose(m.clamp(10, 0, 10), 10, 'clamp at max');

try { m.factorial(21); } catch(e) { threw = true; }

console.log('OK: 01_math');
