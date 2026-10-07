/**
 * test_worker_threads.js — unit tests for worker_threads production implementation.
 * Run: bin/js_engine engine/tests/worker_threads/test_worker_threads.js
 */
"use strict";

var wt = require('worker_threads');
var passed = 0;
var failed = 0;

function assert(cond, msg) {
    if (cond) {
        console.log('OK: ' + msg);
        passed++;
    } else {
        console.error('FAIL: ' + msg);
        failed++;
    }
}

// WT.1 — Identity constants
assert(wt.isMainThread === true,      'isMainThread is true on main thread');
assert(wt.threadId === 0,             'threadId is 0 on main thread');
assert(wt.parentPort === null,        'parentPort is null on main thread');
assert(wt.workerData === null,        'workerData is null on main thread');
assert(wt.threadName === null,        'threadName is null on main thread');
assert(wt.isInternalThread === false, 'isInternalThread is false');
assert(typeof wt.SHARE_ENV === 'symbol', 'SHARE_ENV is a Symbol');
assert(wt.SHARE_ENV.toString() === 'Symbol(nodejs.worker_threads.SHARE_ENV)', 'SHARE_ENV value');
assert(typeof wt.resourceLimits === 'object', 'resourceLimits is an object');

// WT.4 — Environment Data
wt.setEnvironmentData('key1', 42);
assert(wt.getEnvironmentData('key1') === 42, 'setEnvironmentData / getEnvironmentData');
wt.setEnvironmentData('key1', undefined);
assert(wt.getEnvironmentData('key1') === undefined, 'setEnvironmentData(k, undefined) deletes key');

// WT.4 — Untransferable
var obj = { x: 1 };
wt.markAsUntransferable(obj);
assert(wt.isMarkedAsUntransferable(obj) === true,  'markAsUntransferable marks object');
assert(wt.isMarkedAsUntransferable({}) === false,  'unmarked object returns false');
assert(wt.isMarkedAsUntransferable(null) === false, 'null is not untransferable');

// WT.2 — MessageChannel construction
var ch = new wt.MessageChannel();
assert(ch.port1 instanceof wt.MessagePort, 'port1 is MessagePort');
assert(ch.port2 instanceof wt.MessagePort, 'port2 is MessagePort');

// WT.2 — receiveMessageOnPort (sync)
ch.port1.postMessage('sync-msg');
var recv = wt.receiveMessageOnPort(ch.port2);
assert(recv !== undefined && recv.message === 'sync-msg', 'receiveMessageOnPort returns message');
var recv2 = wt.receiveMessageOnPort(ch.port2);
assert(recv2 === undefined, 'receiveMessageOnPort returns undefined when empty');

// WT.2 — postMessage / async delivery
var received = [];
ch.port2.on('message', function(msg) { received.push(msg); });
ch.port1.postMessage('hello');
ch.port1.postMessage('world');

// WT.2 — once listener
var onceCount = 0;
ch.port2.once('message', function() { onceCount++; });
ch.port1.postMessage('once-test');

// WT.2 — untransferable postMessage throws
var untObj = {};
wt.markAsUntransferable(untObj);
var threw = false;
try { ch.port1.postMessage(untObj); } catch(e) { threw = true; }
assert(threw, 'postMessage with untransferable object throws');

// WT.3 — BroadcastChannel
var bc1 = new wt.BroadcastChannel('test-ch');
var bc2 = new wt.BroadcastChannel('test-ch');
var bc3 = new wt.BroadcastChannel('other-ch');
var bcReceived = [];
bc2.onmessage = function(ev) { bcReceived.push(ev.data); };
bc3.onmessage = function(ev) { bcReceived.push('wrong: ' + ev.data); };
bc1.postMessage('broadcast-msg');

// WT.6 — LockManager
var lockAcquired = false;
wt.locks.request('my-lock', function(lock) {
    lockAcquired = true;
    assert(lock.name === 'my-lock', 'lock.name correct');
    assert(lock.mode === 'exclusive', 'lock.mode defaults to exclusive');
    return Promise.resolve();
}).then(function() {
    assert(lockAcquired, 'lock callback was called');
});

wt.locks.query().then(function(state) {
    assert(Array.isArray(state.held),    'locks.query().held is array');
    assert(Array.isArray(state.pending), 'locks.query().pending is array');
});

// WT.6 — AbortSignal
var ac = { signal: { aborted: true } };
wt.locks.request('aborted-lock', ac, function() {
    assert(false, 'aborted lock callback should not fire');
}).catch(function(err) {
    assert(err.name === 'AbortError', 'aborted lock rejects with AbortError');
});

// WT.3 — close
bc1.close();
var closedThrew = false;
try { bc1.postMessage('after-close'); } catch(e) { closedThrew = true; }
assert(closedThrew, 'postMessage on closed BroadcastChannel throws');

// WT.2 — port.close
ch.port1.close();
// After close, posting to port2 (whose twin is now closed) should no-op
var port2PostThrew = false;
try { ch.port2.postMessage('after-twin-close'); } catch(e) { port2PostThrew = true; }
assert(!port2PostThrew, 'postMessage to closed twin is a no-op (not a throw)');

// Async checks -- run after event loop drains
setTimeout(function() {
    assert(received.indexOf('hello') >= 0, 'async message "hello" delivered');
    assert(received.indexOf('world') >= 0, 'async message "world" delivered');
    assert(onceCount === 1, 'once listener fires exactly once');
    assert(bcReceived.indexOf('broadcast-msg') >= 0, 'BroadcastChannel message delivered');
    assert(bcReceived.indexOf('wrong: broadcast-msg') < 0, 'BroadcastChannel does not cross channels');

    console.log('\n--- Summary ---');
    console.log('Passed: ' + passed + '  Failed: ' + failed);
    if (failed > 0) process.exit(1);
}, 100);
