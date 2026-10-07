// Test: 11_tsfn — basic ThreadSafeFunction cross-thread → JS callback
//
// Verifies:
//   1. napi_create/release_threadsafe_function lifecycle
//   2. napi_call_threadsafe_function from a pthread delivers calls to JS thread
//   3. call_js_cb receives and unpacks data correctly
//   4. JS callback is invoked with the right argument for each call
//   5. Process exits cleanly after all callbacks fire (loop not stuck)

var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}

var received = [];
var N = 5;

function onCall(idx) {
    received.push(idx);
    if (received.length === N) {
        received.sort(function(a, b) { return a - b; });
        assert(received.length === N, 'received ' + N + ' callbacks');
        for (var i = 0; i < N; i++) {
            assert(received[i] === i, 'callback index ' + i + ' correct');
        }
        console.log('OK: 11_tsfn');
    }
}

m.runCallbacks(onCall, N, null);
