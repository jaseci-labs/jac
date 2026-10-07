// Test: 05_stats — descriptive statistics on JS arrays
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}
function assertClose(a, b, msg) {
    if (Math.abs(a - b) > 1e-9) { console.error('FAIL: ' + msg + ' (got ' + a + ', expected ' + b + ')'); process.exit(1); }
}

var data = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3];

// sum
assertClose(m.sum([1, 2, 3, 4, 5]), 15, 'sum [1..5]');
assertClose(m.sum(data), 39, 'sum of data');
assertClose(m.sum([]), 0, 'sum of empty array');
assertClose(m.sum([42]), 42, 'sum of single element');
assertClose(m.sum([-1, 1]), 0, 'sum of negatives');

// mean
assertClose(m.mean([1, 2, 3, 4, 5]), 3, 'mean [1..5] = 3');
assertClose(m.mean([10, 20]), 15, 'mean [10,20] = 15');
assertClose(m.mean([7]), 7, 'mean of single element');

// min
assertClose(m.min(data), 1, 'min of data');
assertClose(m.min([5, 3, 8, 1, 9]), 1, 'min picks smallest');
assertClose(m.min([-5, -1, -10]), -10, 'min with negatives');

// max
assertClose(m.max(data), 9, 'max of data');
assertClose(m.max([5, 3, 8, 1, 9]), 9, 'max picks largest');
assertClose(m.max([-5, -1, -10]), -1, 'max with negatives');

console.log('OK: 05_stats');
