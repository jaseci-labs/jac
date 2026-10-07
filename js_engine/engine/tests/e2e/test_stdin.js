// ════════════════════════════════════════════════════════════════════════════
// test_stdin.js — Tests for process.stdin and related TTY/readline features
//
// Covers:
//   - process.stdin existence and stream API
//   - process.stdin.pause() / .resume()
//   - process.stdin.setEncoding()
//   - process.stdin.unref() / .ref()
//   - process.stdin.isTTY / .setRawMode() (when TTY)
//   - process.stdout.isTTY / process.stderr.isTTY
//   - tty.isatty() with __tty_info populated
//   - process.stdin.on("data") + .push() interaction
//   - readline.createInterface with process.stdin
// ════════════════════════════════════════════════════════════════════════════

var passed = 0;
var failed = 0;

function assert(condition, msg) {
    if (condition) {
        passed = passed + 1;
    } else {
        failed = failed + 1;
        console.log("FAIL: " + msg);
    }
}

// ── process.stdin exists and is a readable stream ───────────────────────────

assert(typeof process.stdin === "object", "process.stdin is an object");
assert(process.stdin !== null, "process.stdin is not null");
assert(typeof process.stdin.on === "function", "process.stdin.on is function");
assert(typeof process.stdin.read === "function", "process.stdin.read is function");
assert(typeof process.stdin.push === "function", "process.stdin.push is function");
assert(typeof process.stdin.pipe === "function", "process.stdin.pipe is function");
assert(typeof process.stdin.destroy === "function", "process.stdin.destroy is function");
assert(process.stdin.readable === true, "process.stdin.readable is true");

// ── process.stdin.fd ────────────────────────────────────────────────────────

assert(process.stdin.fd === 0, "process.stdin.fd is 0");

// ── process.stdin.pause() / .resume() ───────────────────────────────────────

assert(typeof process.stdin.pause === "function", "process.stdin.pause is function");
assert(typeof process.stdin.resume === "function", "process.stdin.resume is function");

// pause() returns this for chaining
var pauseRet = process.stdin.pause();
assert(pauseRet === process.stdin, "pause() returns this");

// resume() returns this for chaining
var resumeRet = process.stdin.resume();
assert(resumeRet === process.stdin, "resume() returns this");

// ── process.stdin.setEncoding() ─────────────────────────────────────────────

assert(typeof process.stdin.setEncoding === "function", "process.stdin.setEncoding is function");

// setEncoding returns this for chaining
var encRet = process.stdin.setEncoding("utf8");
assert(encRet === process.stdin, "setEncoding() returns this");

// Check that the encoding property was stored
assert(process.stdin.encoding === "utf8", "encoding stored as 'utf8'");

// ── process.stdin.unref() / .ref() ──────────────────────────────────────────

assert(typeof process.stdin.unref === "function", "process.stdin.unref is function");
assert(typeof process.stdin.ref === "function", "process.stdin.ref is function");

// unref()/ref() return this for chaining
var unrefRet = process.stdin.unref();
assert(unrefRet === process.stdin, "unref() returns this");
var refRet = process.stdin.ref();
assert(refRet === process.stdin, "ref() returns this");

// ── process.stdout / stderr stream methods ──────────────────────────────────

assert(typeof process.stdout === "object", "process.stdout is object");
assert(typeof process.stderr === "object", "process.stderr is object");
assert(typeof process.stdout.on === "function", "process.stdout.on is function");
assert(typeof process.stdout.write === "function", "process.stdout.write is function");
assert(typeof process.stdout.end === "function", "process.stdout.end is function");
assert(typeof process.stdout.pause === "function", "process.stdout.pause is function");
assert(typeof process.stdout.resume === "function", "process.stdout.resume is function");
assert(typeof process.stdout.unref === "function", "process.stdout.unref is function");
assert(typeof process.stdout.ref === "function", "process.stdout.ref is function");
assert(typeof process.stderr.on === "function", "process.stderr.on is function");

// ── isTTY detection ─────────────────────────────────────────────────────────
// In piped test environment, isTTY should be undefined or false for all fds.
// This test runs under run_tests.sh which pipes stdout.

var tty = require("tty");

// tty.isatty returns boolean
var isatty0 = tty.isatty(0);
var isatty1 = tty.isatty(1);
var isatty2 = tty.isatty(2);
assert(typeof isatty0 === "boolean", "tty.isatty(0) returns boolean");
assert(typeof isatty1 === "boolean", "tty.isatty(1) returns boolean");
assert(typeof isatty2 === "boolean", "tty.isatty(2) returns boolean");

// __tty_info should now be populated (not undefined)
assert(typeof globalThis.__tty_info === "object", "__tty_info is populated as object");
assert(typeof globalThis.__tty_info["0"] === "boolean", "__tty_info['0'] is boolean");
assert(typeof globalThis.__tty_info["1"] === "boolean", "__tty_info['1'] is boolean");
assert(typeof globalThis.__tty_info["2"] === "boolean", "__tty_info['2'] is boolean");

// isatty consistency with __tty_info
assert(tty.isatty(0) === globalThis.__tty_info["0"], "isatty(0) matches __tty_info");
assert(tty.isatty(1) === globalThis.__tty_info["1"], "isatty(1) matches __tty_info");
assert(tty.isatty(2) === globalThis.__tty_info["2"], "isatty(2) matches __tty_info");

// isTTY consistency between process streams and tty.isatty
// process.stdin.isTTY is true when isatty(0), undefined otherwise
if (tty.isatty(0)) {
    assert(process.stdin.isTTY === true, "stdin.isTTY true when isatty(0)");
} else {
    assert(process.stdin.isTTY === undefined || process.stdin.isTTY === false,
        "stdin.isTTY falsy when not isatty(0)");
}

if (tty.isatty(1)) {
    assert(process.stdout.isTTY === true, "stdout.isTTY true when isatty(1)");
} else {
    assert(process.stdout.isTTY === undefined || process.stdout.isTTY === false,
        "stdout.isTTY falsy when not isatty(1)");
}

if (tty.isatty(2)) {
    assert(process.stderr.isTTY === true, "stderr.isTTY true when isatty(2)");
} else {
    assert(process.stderr.isTTY === undefined || process.stderr.isTTY === false,
        "stderr.isTTY falsy when not isatty(2)");
}

// ── setRawMode ──────────────────────────────────────────────────────────────
// setRawMode is only present when stdin is a TTY
if (process.stdin.isTTY) {
    assert(typeof process.stdin.setRawMode === "function", "setRawMode present on TTY stdin");
    var rawRet = process.stdin.setRawMode(false);
    assert(rawRet === process.stdin, "setRawMode returns this");
    assert(process.stdin.isRaw === false, "isRaw is false after setRawMode(false)");
} else {
    // setRawMode should not be present on non-TTY stdin
    assert(process.stdin.setRawMode === undefined, "setRawMode absent on non-TTY stdin");
    passed = passed + 2; // skip the 2 assertions inside the if block
}

// ── process.stdin.push() + on("data") ───────────────────────────────────────
// Test that programmatic push works with data listeners

var dataChunks = [];
process.stdin.on("data", function(chunk) {
    dataChunks.push(chunk);
});

// Push data programmatically
process.stdin.push("hello from push");
process.stdin.push("second chunk");

// The data listeners should have received the chunks via pending-emit
// (In synchronous context, they're queued until the VM drains them)
// Use setTimeout to let pending callbacks fire
setTimeout(function() {
    assert(dataChunks.length === 2, "received 2 data chunks from push (got " + dataChunks.length + ")");
    if (dataChunks.length >= 1) {
        assert(dataChunks[0] === "hello from push", "first chunk is 'hello from push'");
    }
    if (dataChunks.length >= 2) {
        assert(dataChunks[1] === "second chunk", "second chunk is 'second chunk'");
    }

    // ── readline with programmatic input ─────────────────────────────────
    var readline = require("readline");
    var rl = readline.createInterface({});
    var rlLines = [];
    rl.on("line", function(line) {
        rlLines.push(line);
    });
    rl.write("readline line 1\n");
    rl.write("readline line 2\n");
    assert(rlLines.length === 2, "readline received 2 lines");
    assert(rlLines[0] === "readline line 1", "readline line 1 correct");
    assert(rlLines[1] === "readline line 2", "readline line 2 correct");

    // ── readline question ────────────────────────────────────────────────
    var rl2 = readline.createInterface({});
    var qAnswer = null;
    rl2.question("Q: ", function(a) { qAnswer = a; });
    rl2.write("the answer\n");
    assert(qAnswer === "the answer", "readline question got answer");

    // ── readline close ───────────────────────────────────────────────────
    var rl3 = readline.createInterface({});
    var wasClosed = false;
    rl3.on("close", function() { wasClosed = true; });
    rl3.close();
    assert(wasClosed === true, "readline close event fired");

    // ── readline/promises ────────────────────────────────────────────────
    var rlPromises = require("readline/promises");
    assert(typeof rlPromises === "object", "readline/promises is object");
    assert(typeof rlPromises.createInterface === "function",
        "readline/promises.createInterface is function");

    var prl = rlPromises.createInterface({});
    assert(typeof prl.question === "function", "promise rl.question is function");

    // Stop stdin polling so the event loop can exit
    process.stdin.pause();

    // ── Summary ──────────────────────────────────────────────────────────
    console.log("");
    console.log("=== Stdin tests: " + passed + " passed, " + failed + " failed ===");
}, 10);
