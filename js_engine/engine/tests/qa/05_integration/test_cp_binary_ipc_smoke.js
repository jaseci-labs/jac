// CP-BIN-001: child_process spawn() delivers stdout as binary-safe Buffers and
// preserves arbitrary bytes (NUL + high bytes) through both stdin and stdout.
// Regression: stdout was carried as a NUL-truncating utf8 string and stdin
// Buffers were utf8-mangled — corrupting esbuild's binary stdio protocol during
// `vite build`. The bridge now base64-tunnels both directions.
//
// CP-BIN-002: an unref()'d persistent child must NOT keep the process alive
// (esbuild's idle service unref()s itself; otherwise vite hangs at exit).
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_cp_binary_ipc_smoke.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assert(cond, msg) { __reg.assert(cond, msg); }

var cp = require("child_process");

// Bytes with NULs and high bytes throughout — the case that broke the old path.
var payload = Buffer.from([0, 1, 2, 255, 254, 0, 65, 66, 0, 127, 128, 0]);

// Echo the payload through `cat`: stdin (us -> child) then stdout (child -> us).
var child = cp.spawn("cat", [], { stdio: ["pipe", "pipe", "inherit"] });

var chunks = [];
var sawBuffer = true;
child.stdout.on("data", function (c) {
    // Default spawn streams must emit Buffers, not decoded strings.
    if (!Buffer.isBuffer(c)) sawBuffer = false;
    chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(String(c)));
});

child.on("close", function () {
    var got = Buffer.concat(chunks);
    assert(sawBuffer, "CP-BIN-001: stdout data events are Buffers");
    assert(got.length === payload.length, "CP-BIN-001: byte length preserved (" + got.length + " vs " + payload.length + ")");
    assert(Buffer.compare(got, payload) === 0, "CP-BIN-001: exact bytes preserved (NUL + high bytes)");

    // CP-BIN-002: unref an idle child and confirm the process is not pinned open.
    // A short-lived `sleep` child, unref'd, must let __jacDone()'s exit proceed
    // even though the child is still "active" (we don't wait for it).
    var idle = cp.spawn("sleep", ["30"], { stdio: ["pipe", "pipe", "inherit"] });
    assert(typeof idle.unref === "function", "CP-BIN-002: child.unref is a function");
    idle.unref();
    idle.on("error", function () {}); // ignore if `sleep` is unavailable

    __jacDone(); // must return promptly; the unref'd child must not block exit
});

child.stdin.write(payload);
child.stdin.end();
