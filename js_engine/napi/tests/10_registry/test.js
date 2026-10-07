// Test: 10_registry — string key→value store backed by napi_wrap C struct
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}

// create an empty registry
var r = m.create();
assert(typeof r === 'object', 'create returns object');
assert(m.size(r) === 0, 'initial size = 0');

// has: missing keys return false
assert(m.has(r, 'foo') === false, 'has missing key = false');

// set and get a value
m.set(r, 'foo', 'bar');
assert(m.size(r) === 1, 'size after one set = 1');
assert(m.has(r, 'foo') === true, 'has foo after set = true');
assert(m.get(r, 'foo') === 'bar', 'get foo = bar');

// get missing key returns undefined
assert(m.get(r, 'missing') === undefined, 'get missing = undefined');

// update existing key (size stays the same)
m.set(r, 'foo', 'newbar');
assert(m.size(r) === 1, 'size unchanged after update');
assert(m.get(r, 'foo') === 'newbar', 'get updated value');

// multiple keys
m.set(r, 'alpha', 'A');
m.set(r, 'beta', 'B');
m.set(r, 'gamma', 'C');
assert(m.size(r) === 4, 'size after 3 more sets = 4');
assert(m.get(r, 'alpha') === 'A', 'get alpha');
assert(m.get(r, 'beta') === 'B', 'get beta');
assert(m.get(r, 'gamma') === 'C', 'get gamma');

// two independent registries
var r2 = m.create();
m.set(r2, 'x', 'y');
assert(m.size(r) === 4, 'r1 unaffected by r2');
assert(m.size(r2) === 1, 'r2 has its own data');
assert(m.get(r2, 'foo') === undefined, 'r2 does not see r1 keys');

// empty string key and value
m.set(r, '', 'empty_key');
assert(m.has(r, '') === true, 'empty string key exists');
assert(m.get(r, '') === 'empty_key', 'get empty string key');

console.log('OK: 10_registry');
