// Test: 12_tsfn_async — TSFN with async JS callback returning a Promise
//
// Verifies:
//   1. call_js_cb can invoke an async JS function via napi_call_function
//   2. The result (inner Promise) is chained so the outer Promise resolves
//   3. The resolved value matches what the async function returned
//   4. Multiple sequential callAsync calls all resolve correctly
//   5. Process exits cleanly after all Promises settle

var m = require('./addon.node');

var passed = 0;
var failed = 0;
var total  = 3;

function assert(cond, msg) {
    if (cond) { passed++; }
    else       { failed++; console.error('FAIL: ' + msg); }
}

function finish() {
    if (passed + failed < total) return;
    if (failed === 0) {
        console.log('OK: 12_tsfn_async');
    } else {
        console.error('FAIL: ' + failed + ' assertion(s) failed');
        process.exit(1);
    }
}

// Async JS function: doubles its input and returns it after one await tick.
async function doubler(x) {
    var y = await Promise.resolve(x * 2);
    return y;
}

// Test 1: callAsync(doubler, 21) → outer Promise resolves to 42.
m.callAsync(doubler, 21).then(function(v) {
    assert(v === 42, 'callAsync(doubler, 21) resolves to 42, got ' + v);
    finish();
}).catch(function(e) {
    failed++;
    console.error('FAIL: callAsync #1 rejected:', e);
    finish();
});

// Test 2: callAsync(doubler, 7) → resolves to 14.
m.callAsync(doubler, 7).then(function(v) {
    assert(v === 14, 'callAsync(doubler, 7) resolves to 14, got ' + v);
    finish();
}).catch(function(e) {
    failed++;
    console.error('FAIL: callAsync #2 rejected:', e);
    finish();
});

// Test 3: callAsync with an async function that returns a string.
async function stringify(x) {
    return 'value=' + x;
}
m.callAsync(stringify, 99).then(function(v) {
    assert(v === 'value=99', 'callAsync(stringify, 99) resolves to "value=99", got ' + v);
    finish();
}).catch(function(e) {
    failed++;
    console.error('FAIL: callAsync #3 rejected:', e);
    finish();
});
