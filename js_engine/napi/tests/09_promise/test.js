// Test: 09_promise — napi_create_promise, resolve_deferred, reject_deferred
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}

var resolved = false;
var rejected = false;
var resolvedValue = null;
var rejectedMsg = null;
var pending = 2;

function done() {
    pending--;
    if (pending === 0) {
        assert(resolved, 'fulfilled promise called .then handler');
        assert(resolvedValue === 42, '.then received correct value: ' + resolvedValue);
        assert(rejected, 'rejected promise called .catch handler');
        assert(rejectedMsg !== null && rejectedMsg.indexOf('boom') !== -1,
               '.catch received correct error message: ' + rejectedMsg);
        console.log('OK: 09_promise');
    }
}

// fulfilledWith: promise that resolves with the given value
var p1 = m.fulfilledWith(42);
assert(typeof p1 === 'object', 'fulfilledWith returns an object');
assert(typeof p1.then === 'function', 'fulfilledWith result has .then');

p1.then(function(v) {
    resolved = true;
    resolvedValue = v;
    done();
}).catch(function(e) {
    console.error('FAIL: fulfilledWith rejected unexpectedly: ' + e);
    process.exit(1);
});

// rejectedWith: promise that rejects with an Error carrying the given message
var msg = m.fulfilledWith('hello');  // also smoke-test string values
assert(typeof msg.then === 'function', 'fulfilledWith(string) has .then');

var p2 = m.rejectedWith('boom');
assert(typeof p2 === 'object', 'rejectedWith returns an object');
assert(typeof p2.catch === 'function', 'rejectedWith result has .catch');

p2.then(function() {
    console.error('FAIL: rejectedWith resolved unexpectedly');
    process.exit(1);
}).catch(function(e) {
    rejected = true;
    rejectedMsg = e.message || String(e);
    done();
});
