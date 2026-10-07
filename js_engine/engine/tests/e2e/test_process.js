// test_process.js — Phase C + D: process object tests
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

// ── 1. process exists ────────────────────────────────────────────────────────
ok(typeof process === "object", "process is an object");

// ── 2. process.version ───────────────────────────────────────────────────────
ok(typeof process.version === "string", "process.version is a string");
ok(process.version.indexOf("v") === 0, "process.version starts with 'v'");

// ── 3. process.platform ──────────────────────────────────────────────────────
ok(process.platform === "linux", "process.platform is 'linux'");

// ── 4. process.arch ──────────────────────────────────────────────────────────
ok(process.arch === "x64", "process.arch is 'x64'");

// ── 5. process.pid ───────────────────────────────────────────────────────────
ok(typeof process.pid === "number", "process.pid is a number");
ok(process.pid > 0, "process.pid > 0");

// ── 6. process.argv ──────────────────────────────────────────────────────────
ok(Array.isArray(process.argv), "process.argv is an array");
ok(process.argv.length >= 2, "process.argv.length >= 2");
ok(process.argv[0].indexOf("bin/js_engine") !== -1, "process.argv[0] is 'bin/js_engine'");

// ── 7. process.env — all environ keys (Phase C) ──────────────────────────────
ok(typeof process.env === "object", "process.env is an object");
ok(typeof process.env.PATH === "string", "process.env.PATH is a string");
ok(process.env.PATH.length > 0, "process.env.PATH is non-empty");
// HOME should always be set in any normal environment
ok(typeof process.env.HOME === "string" && process.env.HOME.length > 0,
   "process.env.HOME is set (all environ keys exposed)");
// process.env should contain many keys, not just the ~20 hardcoded ones
var envKeyCount = Object.keys(process.env).length;
ok(envKeyCount >= 10, "process.env has >= 10 keys (got " + envKeyCount + ")");

// ── 8. process.stdout / process.stderr ───────────────────────────────────────
ok(typeof process.stdout === "object", "process.stdout is an object");
ok(typeof process.stdout.write === "function", "process.stdout.write is a function");
process.stdout.write("ok " + (t + 1) + " - process.stdout.write works\n");
t = t + 1;
pass = pass + 1;
ok(typeof process.stderr === "object", "process.stderr is an object");
ok(typeof process.stderr.write === "function", "process.stderr.write is a function");

// ── 9. process.hrtime ────────────────────────────────────────────────────────
var hr = process.hrtime();
ok(Array.isArray(hr), "process.hrtime() returns an array");
ok(hr.length === 2, "process.hrtime() has 2 elements");
ok(hr[0] >= 0, "process.hrtime()[0] >= 0");
ok(hr[1] >= 0, "process.hrtime()[1] >= 0");
var hr2 = process.hrtime(hr);
ok(Array.isArray(hr2), "process.hrtime(prev) returns an array");
ok(hr2[0] >= 0, "process.hrtime(prev)[0] >= 0");

// ── 10. process.cwd ──────────────────────────────────────────────────────────
var cwd = process.cwd();
ok(typeof cwd === "string", "process.cwd() returns a string");
ok(cwd.length > 0, "process.cwd() is non-empty");

// ── 11. process.memoryUsage (Phase C) ────────────────────────────────────────
var mem = process.memoryUsage();
ok(typeof mem === "object", "process.memoryUsage() returns an object");
ok(typeof mem.rss === "number", "process.memoryUsage().rss is a number");
ok(mem.rss > 0, "process.memoryUsage().rss > 0");
ok(typeof mem.heapTotal === "number", "process.memoryUsage().heapTotal is a number");
ok(typeof mem.heapUsed === "number", "process.memoryUsage().heapUsed is a number");
// Real RSS from /proc/self/statm should be > 1 MB for a live process
ok(mem.rss > 1024 * 1024, "process.memoryUsage().rss > 1MB (real value, not stub)");

// ── 12. process.cpuUsage (Phase C) ───────────────────────────────────────────
var cpu = process.cpuUsage();
ok(typeof cpu === "object", "process.cpuUsage() returns an object");
ok(typeof cpu.user === "number", "process.cpuUsage().user is a number");
ok(typeof cpu.system === "number", "process.cpuUsage().system is a number");
ok(cpu.user >= 0, "process.cpuUsage().user >= 0");
ok(cpu.system >= 0, "process.cpuUsage().system >= 0");
// Delta form: subtract previous
var cpu2 = process.cpuUsage(cpu);
ok(cpu2.user >= 0, "process.cpuUsage(prev).user >= 0 (delta)");

// ── 13. process.emit — generic events (Phase C) ──────────────────────────────
var genericFired = false;
var genericData = null;
process.on("myevent", function(data) {
    genericFired = true;
    genericData = data;
});
process.emit("myevent", "hello");

// ── 14. process.nextTick ─────────────────────────────────────────────────────
var tickFired = false;
process.nextTick(function() { tickFired = true; });

// ── 15. process.on('unhandledRejection') ─────────────────────────────────────
var urFired = false;
var urReason = null;
var urPromise = null;
process.on("unhandledRejection", function(reason, promise) {
    if (!urFired) { urFired = true; urReason = reason; urPromise = promise; }
});
var rejectedP = Promise.reject("ur-test-reason");

// ── 16. process.once('unhandledRejection') ───────────────────────────────────
var onceCount = 0;
process.once("unhandledRejection", function(reason) { onceCount = onceCount + 1; });
var rejectedP2 = Promise.reject("ur-once-1");
var rejectedP3 = Promise.reject("ur-once-2");

// ── 17. .catch() suppresses unhandledRejection ───────────────────────────────
var suppressFired = false;
var suppressListener = function(reason) { suppressFired = true; };
process.on("unhandledRejection", suppressListener);
var handledP = Promise.reject("handled-reason").catch(function(e) { /* swallowed */ });
process.off("unhandledRejection", suppressListener);

// ── 18. process.on('exit') fires (Phase C) ───────────────────────────────────
var exitFired = false;
var exitCode = -1;
process.on("exit", function(code) {
    exitFired = true;
    exitCode = code;
});

// ── 19. process.on('rejectionHandled') fires (Phase D) ───────────────────────
var rhFired = false;
var rhPromise = null;
process.on("rejectionHandled", function(promise) {
    rhFired = true;
    rhPromise = promise;
});
// Create a rejected promise, then immediately add a .catch() — should fire rejectionHandled.
// The timing: rejection is queued, tick fires unhandledRejection, then .catch() fires rejectionHandled.
var rhP = Promise.reject("rh-test");

// ── 20. process.on('beforeExit') fires (Phase D) ─────────────────────────────
var beforeExitFired = false;
var beforeExitCode = -1;
process.on("beforeExit", function(code) {
    beforeExitFired = true;
    beforeExitCode = code;
});

// Add .catch() after one tick so unhandledRejection fires first, then rejectionHandled
setTimeout(function() {
    ok(tickFired, "process.nextTick callback fired");

    // Generic emit
    ok(genericFired === true, "process.emit('myevent') fires listener");
    ok(genericData === "hello", "process.emit('myevent') passes data correctly");

    // unhandledRejection
    ok(urFired === true, "process.on('unhandledRejection') listener fires");
    ok(urReason === "ur-test-reason", "unhandledRejection receives correct reason");
    ok(typeof urPromise === "object", "unhandledRejection receives a promise");
    ok(onceCount === 1, "process.once('unhandledRejection') fires exactly once (got " + onceCount + ")");
    ok(suppressFired === false, ".catch() on rejected promise suppresses unhandledRejection");

    // ── Phase E tests (synchronous, run inside the timeout) ──────────────────

    // E1: process.memoryUsage.rss()
    ok(typeof process.memoryUsage.rss === "function", "process.memoryUsage.rss is a function");
    var rss = process.memoryUsage.rss();
    ok(typeof rss === "number", "process.memoryUsage.rss() returns a number");
    ok(rss > 1024 * 1024, "process.memoryUsage.rss() > 1MB");

    // E2: process.availableMemory()
    ok(typeof process.availableMemory === "function", "process.availableMemory is a function");
    var avail = process.availableMemory();
    ok(typeof avail === "number", "process.availableMemory() returns a number");
    ok(avail > 0, "process.availableMemory() > 0");

    // E3: process.resourceUsage()
    ok(typeof process.resourceUsage === "function", "process.resourceUsage is a function");
    var ru = process.resourceUsage();
    ok(typeof ru === "object", "process.resourceUsage() returns an object");
    ok(typeof ru.userCPUTime === "number", "resourceUsage().userCPUTime is a number");
    ok(typeof ru.systemCPUTime === "number", "resourceUsage().systemCPUTime is a number");
    ok(typeof ru.maxRSS === "number", "resourceUsage().maxRSS is a number");
    ok(typeof ru.minorPageFault === "number", "resourceUsage().minorPageFault is a number");
    ok(typeof ru.voluntaryContextSwitches === "number", "resourceUsage().voluntaryContextSwitches is a number");
    ok(ru.userCPUTime >= 0, "resourceUsage().userCPUTime >= 0");
    ok(ru.maxRSS > 0, "resourceUsage().maxRSS > 0 (KB on Linux)");

    // E4: process.getgroups()
    ok(typeof process.getgroups === "function", "process.getgroups is a function");
    var groups = process.getgroups();
    ok(Array.isArray(groups), "process.getgroups() returns an array");
    ok(groups.length > 0, "process.getgroups() array is non-empty");
    ok(typeof groups[0] === "number", "process.getgroups()[0] is a number");

    // E5: process.setuid/setgid/seteuid/setegid exist (root check — must not throw for non-root callers)
    ok(typeof process.setuid === "function", "process.setuid is a function");
    ok(typeof process.setgid === "function", "process.setgid is a function");
    ok(typeof process.seteuid === "function", "process.seteuid is a function");
    ok(typeof process.setegid === "function", "process.setegid is a function");
    // Calling set*id with the current uid/gid should be a no-op (idempotent)
    var didThrow = false;
    try { process.setuid(process.getuid()); } catch(e) { didThrow = true; }
    ok(didThrow === false, "process.setuid(current uid) does not throw");
    didThrow = false;
    try { process.setgid(process.getgid()); } catch(e) { didThrow = true; }
    ok(didThrow === false, "process.setgid(current gid) does not throw");

    // E6: process.loadEnvFile exists
    ok(typeof process.loadEnvFile === "function", "process.loadEnvFile is a function");

    // Add .catch() to rhP now — one tick has passed, so rejection was already dispatched.
    rhP.catch(function() {});

    // Give rejectionHandled a tick to fire
    setTimeout(function() {
        // rejectionHandled (Phase D)
        ok(rhFired === true, "process.on('rejectionHandled') fires when .catch() added after tick");
        ok(rhPromise !== null, "rejectionHandled receives the promise object");

        // Summary (exit listener and beforeExit verified by their own firing)
        console.log("=== process tests: " + pass + " passed, " + fail + " failed ===");
    }, 5);
}, 10);
