// Test: 15_async_work — napi async work ops 125–128 (R2 of
// docs/ROLLUP_SUPPORT_PLAN.md). Node-oracle-validated; every assertion holds
// under real Node too (except where the comment says engine-only).
var m = require('./addon.node');

var failures = 0;
function assert(cond, msg) {
    if (!cond) { failures++; console.error('FAIL: ' + msg); }
}

var pending = 0;
function done() {
    pending--;
    if (pending === 0) {
        if (failures > 0) { process.exit(1); }
        console.log('OK: 15_async_work');
        process.exit(0); // NAPI addons hold the loop open; exit explicitly
    }
}

// ── basic promise round-trip ────────────────────────────────────────────────
pending++;
m.asyncDouble(21).then(function (v) {
    assert(v === 42, 'asyncDouble(21) resolves 42, got ' + v);
    done();
}, function (e) {
    assert(false, 'asyncDouble rejected unexpectedly: ' + e);
    done();
});

// ── complete is asynchronous w.r.t. the queueing JS ─────────────────────────
// The already-scheduled microtask (B) must run before the async-work
// completion resolution (A): complete is delivered on a later tick.
pending++;
var order = [];
var pA = m.asyncDouble(1).then(function () { order.push('A'); });
Promise.resolve().then(function () { order.push('B'); });
pA.then(function () {
    assert(order.join(',') === 'B,A', 'complete after current microtasks, got ' + order.join(','));
    done();
});

// ── R2.3: Promise.all over many queued works resolves in queue order ────────
pending++;
Promise.all([m.asyncDouble(1), m.asyncDouble(2), m.asyncDouble(3), m.asyncDouble(4)])
    .then(function (vals) {
        assert(vals.join(',') === '2,4,6,8', 'Promise.all values in order, got ' + vals.join(','));
        done();
    }, function (e) {
        assert(false, 'Promise.all rejected: ' + e);
        done();
    });

// ── rejection path through complete ─────────────────────────────────────────
pending++;
m.asyncFail(5).then(function () {
    assert(false, 'asyncFail resolved unexpectedly');
    done();
}, function (e) {
    assert(e instanceof Error, 'asyncFail rejects with Error');
    assert(e.message === 'task failed', 'asyncFail message, got ' + (e && e.message));
    done();
});

// ── cancel after queue: race-tolerant (oracle-verified both ways) ───────────
// Node: 0 (cancel won the threadpool race → complete(napi_cancelled) →
// E_CANCELLED rejection) OR 9 (work already started → normal resolution).
// Engine (sync-execute): always 9 — execute has provably run by then.
pending++;
var cq = m.cancelAfterQueue();
assert(cq.status === 0 || cq.status === 9, 'cancel status is 0 or 9, got ' + cq.status);
cq.promise.then(function (v) {
    assert(cq.status === 9, 'resolution implies cancel failed, status=' + cq.status);
    assert(v === 2, 'cancel-probe work resolves 2, got ' + v);
    done();
}, function (e) {
    assert(cq.status === 0, 'rejection implies cancel succeeded, status=' + cq.status);
    assert(e && e.code === 'E_CANCELLED', 'rejects E_CANCELLED, got ' + (e && e.code));
    done();
});

// Engine-only observation (sync-execute model): after the synchronous calls
// above, every queued execute has already run. Under Node this is racy, so
// only report it — the engine runner treats FAIL-prefixed lines as failures,
// notes are informational.
console.log('note: executeCalls after queueing = ' + m.executeCalls());
