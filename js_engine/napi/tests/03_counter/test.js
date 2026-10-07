// Test: 03_counter — stateful counter object via napi_wrap
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}

// create with default initial value 0
var c = m.create();
assert(c.getValue() === 0, 'initial value is 0');
c.inc();
assert(c.getValue() === 1, 'after inc → 1');
c.inc();
c.inc();
assert(c.getValue() === 3, 'after 2 more incs → 3');
c.dec();
assert(c.getValue() === 2, 'after dec → 2');
c.reset();
assert(c.getValue() === 0, 'after reset → 0');

// create with initial value
var c2 = m.create(10);
assert(c2.getValue() === 10, 'initial value 10');
c2.dec();
c2.dec();
assert(c2.getValue() === 8, 'after 2 decs → 8');

// two counters are independent
var a = m.create(1);
var b = m.create(100);
a.inc();
assert(a.getValue() === 2,   'a independent: 2');
assert(b.getValue() === 100, 'b independent: still 100');

// inc returns the new value
var c3 = m.create(5);
var ret = c3.inc();
assert(ret === 6, 'inc returns new value');

console.log('OK: 03_counter');
