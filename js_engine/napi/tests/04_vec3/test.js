// Test: 04_vec3 — 3D vector math via NAPI object property get/set
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}
function assertClose(a, b, msg) {
    if (Math.abs(a - b) > 1e-9) { console.error('FAIL: ' + msg + ' (got ' + a + ', expected ' + b + ')'); process.exit(1); }
}

// create
var v = m.create(1, 2, 3);
assertClose(v.x, 1, 'create x');
assertClose(v.y, 2, 'create y');
assertClose(v.z, 3, 'create z');

// add
var u = m.create(4, 5, 6);
var sum = m.add(v, u);
assertClose(sum.x, 5, 'add x');
assertClose(sum.y, 7, 'add y');
assertClose(sum.z, 9, 'add z');

// dot product
// (1,0,0)·(0,1,0) = 0
var i_hat = m.create(1, 0, 0);
var j_hat = m.create(0, 1, 0);
assertClose(m.dot(i_hat, j_hat), 0, 'orthogonal dot product = 0');
// (1,2,3)·(4,5,6) = 4+10+18 = 32
assertClose(m.dot(v, u), 32, 'dot(v,u) = 32');

// magnitude
// magnitude of (3,4,0) = 5
var v345 = m.create(3, 4, 0);
assertClose(m.magnitude(v345), 5, 'magnitude(3,4,0) = 5');
assertClose(m.magnitude(m.create(0, 0, 0)), 0, 'magnitude of zero vector = 0');

// scale
var scaled = m.scale(m.create(1, 2, 3), 2);
assertClose(scaled.x, 2, 'scale x');
assertClose(scaled.y, 4, 'scale y');
assertClose(scaled.z, 6, 'scale z');

console.log('OK: 04_vec3');
