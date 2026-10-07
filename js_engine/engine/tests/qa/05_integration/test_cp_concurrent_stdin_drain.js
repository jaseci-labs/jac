// CP-DRAIN-001..003: writing to a child's stdin while the child is still
// writing replies must not deadlock. Regression: the stdin pipe was blocking
// and nothing drained the child's stdout during a write, so once the child
// blocked on its full 64KB stdout pipe both sides waited forever (rollup
// renders chunks in parallel → several MB-size esbuild transform requests in
// flight → vite:esbuild-transpile renderChunk never settled). The writer is
// now non-blocking and drains stdout/stderr while waiting for POLLOUT.
var cp = require("child_process");
var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_cp_concurrent_stdin_drain.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }
function assert(cond, msg) { __reg.assert(cond, msg); }

var guard = setTimeout(function () { assert(false, "CP-DRAIN-000: timeout (deadlock?)"); __jacDone(); }, 20000);

// 1) three 300KB writes back-to-back (900KB > any pipe), then read everything back.
var c = cp.spawn("cat");
var got = 0, chunks = [];
c.stdout.on("data", function (d) { got += d.length; chunks.push(d); });
var payloads = [0, 1, 2].map(function (k) { return Buffer.alloc(300000, 65 + k); });
payloads.forEach(function (p) { c.stdin.write(p); });
c.stdin.end();
c.on("close", function () {
    assert(got === 900000, "CP-DRAIN-001: all 900000 bytes echoed back (got " + got + ")");
    var all = Buffer.concat(chunks);
    assert(all.equals(Buffer.concat(payloads)), "CP-DRAIN-002: bytes and order preserved across concurrent writes");
    // 2) idle child (unref'd, no traffic) is ref'd again and answers a large write.
    var c2 = cp.spawn("cat"); c2.unref();
    setTimeout(function () {
        var got2 = 0;
        c2.ref();
        c2.stdout.on("data", function (d) { got2 += d.length; if (got2 === 400000) { assert(true, "CP-DRAIN-003: 400KB answered after idle+ref"); c2.kill(); clearTimeout(guard); __jacDone(); } });
        c2.stdin.write(Buffer.alloc(400000, 90));
    }, 500);
});
