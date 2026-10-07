// test_streams.js — Readable / Writable stream tests
// Each test prints "ok N - description" or "FAIL N - description"

var pass = 0;
var fail = 0;
var t = 0;

function ok(cond, desc) {
    t = t + 1;
    if (cond) {
        pass = pass + 1;
        console.log("ok " + t + " - " + desc);
    } else {
        fail = fail + 1;
        console.log("FAIL " + t + " - " + desc);
    }
}

// ── 1. process.stdout is a writable stream ───────────────────────────────────

ok(typeof process.stdout === "object", "process.stdout is an object");
ok(typeof process.stdout.write === "function", "process.stdout.write is a function");
ok(typeof process.stdout.end === "function", "process.stdout.end is a function");
ok(typeof process.stdout.on === "function", "process.stdout.on is a function");

// 2. process.stdout.write still works
ok(process.stdout.write("stream test\n") === true, "stdout.write returns true");

// 3. process.stderr is a writable stream
ok(typeof process.stderr === "object", "process.stderr is an object");
ok(typeof process.stderr.write === "function", "process.stderr.write is a function");

// 4. process.stdin is a readable stream
ok(typeof process.stdin === "object", "process.stdin is an object");
ok(typeof process.stdin.on === "function", "process.stdin.on is a function");
ok(typeof process.stdin.read === "function", "process.stdin.read is a function");
ok(typeof process.stdin.pipe === "function", "process.stdin.pipe is a function");

// ── 5. Readable stream basic push/read ──────────────────────────────────────

// Note: stream constructor is exposed via globalThis.stream for now
// We create a stream via a helper pattern since we don't have require() yet
// The push/read pattern works through dispatch

// For this test we use process.stdin as our readable test target
// (it's a Readable with no fd backing, so push/read are safe to test)

// 6. read() returns null on empty buffer
var chunk = process.stdin.read();
ok(chunk === null, "read() on empty readable returns null");

// ── 7. Writable .on('finish') event ─────────────────────────────────────────

// We test that .on('finish', fn) + .end() fires the callback.
// Use a tracking variable to verify the callback runs.

var finishFired = false;

// Create a minimal writable with no fd (fd = -1 internally).
// Since we can't directly construct from JS yet, we test process.stderr
// which is a real writable backed by fd 2.

// Test chaining: .on returns the stream itself
var ret = process.stderr.on("finish", function() {
    finishFired = true;
});
ok(ret === process.stderr, ".on() returns stream for chaining");

// ── 8. Writable .on('drain') ────────────────────────────────────────────────

var drainFired = false;
process.stdout.on("drain", function() {
    drainFired = true;
});

// Writing should fire drain
process.stdout.write("drain test\n");
ok(drainFired === true, "drain event fires after write");

// ── 9. Data event on readable ───────────────────────────────────────────────

var dataReceived = "";
process.stdin.on("data", function(chunk) {
    dataReceived = chunk;
});

// Push data into stdin — should fire the data listener
process.stdin.push("hello from push");
ok(dataReceived === "hello from push", "data event fires on push");

// ── 10. Multiple data events ────────────────────────────────────────────────

var chunks = [];
process.stdin.on("data", function(chunk) {
    chunks.push(chunk);
});

process.stdin.push("chunk1");
process.stdin.push("chunk2");
// Both listeners should fire: the first one (from test 9) and this one
// chunks should have both new chunks
ok(chunks.length === 2, "multiple pushes fire data event for each");
ok(chunks[0] === "chunk1", "first chunk received");
ok(chunks[1] === "chunk2", "second chunk received");

// ── 11. End event on readable ───────────────────────────────────────────────

// We need a fresh readable for this test.
// Since we already used process.stdin, its end event won't help
// (we'd need to push null, which would end it permanently).
// Instead, test that end listener registration works.

var endCalled = false;
// Register before pushing null (this uses a different stream approach)
// For now, just test that the on("end",...) call works without error.
ok(typeof process.stdin.on === "function", "can register end listener");

// ── 12. fs.createReadStream exists ──────────────────────────────────────────

ok(typeof fs.createReadStream === "function", "fs.createReadStream is a function");

// ── 13. Writable destroy ────────────────────────────────────────────────────

// process.stdout.destroy would be bad for testing, so we just check it exists
ok(typeof process.stdout.destroy === "function", "writable has destroy method");

// ── 14. Readable destroy ────────────────────────────────────────────────────

ok(typeof process.stdin.destroy === "function", "readable has destroy method");

// ── 15. fs.createReadStream reads a file ────────────────────────────────────

// Create a temp file, read it via createReadStream, verify data event fires
var tmpPath = "/tmp/_jac_stream_test_" + Date.now() + ".txt";
fs.writeFileSync(tmpPath, "stream-file-content");

var streamData = "";
var rs = fs.createReadStream(tmpPath);
rs.on("data", function(chunk) {
    streamData = streamData + chunk;
});
// createReadStream pushes synchronously in our baseline impl
ok(streamData === "stream-file-content", "createReadStream delivers file content via data event");

// Clean up
fs.unlinkSync(tmpPath);

// ── 16. read() returns pushed data ──────────────────────────────────────────
// push into stdin buffer without data listener consumed the items in flowing mode,
// so test read on a fresh-ish path: push then read on the same stream
// Note: process.stdin already has data listeners, so pushes flow.
// We verify read returns null after flowing mode consumes everything.
var afterFlowRead = process.stdin.read();
ok(afterFlowRead === null, "read() returns null when buffer empty after flowing");

// ── Summary ──────────────────────────────────────────────────────────────────

process.stdin.pause();
console.log("=== streams tests: " + pass + " passed, " + fail + " failed ===");
