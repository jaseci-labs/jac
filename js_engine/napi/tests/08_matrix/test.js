// Test: 08_matrix — 2×2 matrix operations (mul, det, transpose)
// Matrices are flat 4-element arrays [a00, a01, a10, a11]
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}
function assertClose(a, b, msg) {
    if (Math.abs(a - b) > 1e-9) { console.error('FAIL: ' + msg + ' (got ' + a + ', expected ' + b + ')'); process.exit(1); }
}
function assertMatClose(got, expected, msg) {
    for (var i = 0; i < 4; i++)
        assertClose(got[i], expected[i], msg + '[' + i + ']');
}

var I = [1, 0, 0, 1]; // identity
var A = [1, 2, 3, 4];
var B = [5, 6, 7, 8];

// mul: identity times anything = anything
assertMatClose(m.mul(I, A), A, 'I*A = A');
assertMatClose(m.mul(A, I), A, 'A*I = A');

// mul: [[1,2],[3,4]] * [[5,6],[7,8]]
// = [[1*5+2*7, 1*6+2*8], [3*5+4*7, 3*6+4*8]]
// = [[19, 22], [43, 50]]
var AB = m.mul(A, B);
assertClose(AB[0], 19, 'AB[0,0]');
assertClose(AB[1], 22, 'AB[0,1]');
assertClose(AB[2], 43, 'AB[1,0]');
assertClose(AB[3], 50, 'AB[1,1]');

// det: det(I) = 1
assertClose(m.det(I), 1, 'det(I) = 1');
// det([[1,2],[3,4]]) = 1*4 - 2*3 = -2
assertClose(m.det(A), -2, 'det(A) = -2');
// det([[2,0],[0,3]]) = 6
assertClose(m.det([2, 0, 0, 3]), 6, 'det diagonal = 6');

// transpose: transpose(I) = I
assertMatClose(m.transpose(I), I, 'transpose(I) = I');
// transpose([[1,2],[3,4]]) = [[1,3],[2,4]]
assertMatClose(m.transpose(A), [1, 3, 2, 4], 'transpose(A)');
// transpose twice = identity
assertMatClose(m.transpose(m.transpose(A)), A, 'transpose twice = original');

console.log('OK: 08_matrix');
