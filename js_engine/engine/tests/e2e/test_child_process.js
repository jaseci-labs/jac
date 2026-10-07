// test_child_process.js — Node.js child_process module tests
// Tests spawnSync, exec, execSync, spawn (async), and error paths.

var cp = require("child_process");

var _passed = 0;
var _failed = 0;
var _pending = 0; // async tests in flight

function ok(cond, msg) {
    if (cond) {
        _passed = _passed + 1;
        console.log("OK  " + msg);
    } else {
        _failed = _failed + 1;
        console.log("FAIL " + msg);
    }
}

function pending() { _pending = _pending + 1; }
function done()    { _pending = _pending - 1; _maybeSummary(); }

function _maybeSummary() {
    if (_pending === 0) {
        console.log("\n=== child_process tests: " + _passed + " passed, " + _failed + " failed ===");
    }
}

// ── Module shape ─────────────────────────────────────────────────────────────

ok(typeof cp === "object",                   "cp is an object");
ok(typeof cp.spawn === "function",           "cp.spawn is a function");
ok(typeof cp.spawnSync === "function",       "cp.spawnSync is a function");
ok(typeof cp.exec === "function",            "cp.exec is a function");
ok(typeof cp.execSync === "function",        "cp.execSync is a function");
ok(typeof cp.execFile === "function",        "cp.execFile is a function");
ok(typeof cp.execFileSync === "function",    "cp.execFileSync is a function");
ok(typeof cp.ChildProcess === "function",    "cp.ChildProcess is a function");

// ── spawnSync: basic echo ─────────────────────────────────────────────────────

var r1 = cp.spawnSync("echo", ["hello", "world"]);
ok(r1.status === 0,                          "spawnSync echo exits 0");
ok(typeof r1.stdout === "string",            "spawnSync stdout is a string");
ok(r1.stdout.indexOf("hello world") >= 0,    "spawnSync stdout contains 'hello world'");
ok(r1.stderr === "",                         "spawnSync stderr is empty for echo");
ok(typeof r1.pid === "number" && r1.pid > 0, "spawnSync pid is a positive number");

// ── spawnSync: exit status ────────────────────────────────────────────────────

var r2 = cp.spawnSync("/bin/sh", ["-c", "exit 42"]);
ok(r2.status === 42,                         "spawnSync captures non-zero exit status");
ok(r2.pid > 0,                               "spawnSync non-zero exit: pid still valid");

// ── spawnSync: stderr capture ─────────────────────────────────────────────────

var r3 = cp.spawnSync("/bin/sh", ["-c", "echo error_msg >&2"]);
ok(r3.status === 0,                          "spawnSync stderr-only command exits 0");
ok(r3.stdout === "",                         "spawnSync stdout empty when writing to stderr");
ok(r3.stderr.indexOf("error_msg") >= 0,      "spawnSync stderr captured");

// ── spawnSync: stdin input ────────────────────────────────────────────────────

var r4 = cp.spawnSync("cat", [], { input: "hello from stdin\n" });
ok(r4.status === 0,                          "spawnSync with stdin input exits 0");
ok(r4.stdout.indexOf("hello from stdin") >= 0, "spawnSync cat echoes stdin");

// ── spawnSync: env passthrough ────────────────────────────────────────────────

var r5 = cp.spawnSync("/bin/sh", ["-c", "echo $TEST_VAR_XYZ"], {
    env: { TEST_VAR_XYZ: "spawntest123" }
});
ok(r5.status === 0,                          "spawnSync custom env exits 0");
ok(r5.stdout.indexOf("spawntest123") >= 0,   "spawnSync custom env variable visible to child");

// ── spawnSync: shell option ───────────────────────────────────────────────────

var r6 = cp.spawnSync("echo shell_test", { shell: true });
ok(r6.status === 0,                          "spawnSync shell:true exits 0");
ok(r6.stdout.indexOf("shell_test") >= 0,     "spawnSync shell:true runs command via shell");

// ── spawnSync: cwd option ─────────────────────────────────────────────────────

var r7 = cp.spawnSync("pwd", [], { cwd: "/tmp" });
ok(r7.status === 0,                          "spawnSync cwd option exits 0");
ok(r7.stdout.indexOf("/tmp") >= 0,           "spawnSync cwd changes working directory");

// ── execSync: basic ───────────────────────────────────────────────────────────

var out8 = cp.execSync("echo execsync_test");
ok(typeof out8 === "string",                 "execSync returns a string");
ok(out8.indexOf("execsync_test") >= 0,       "execSync captures stdout");

// ── execSync: throws on non-zero ──────────────────────────────────────────────

var didThrow9 = false;
try {
    cp.execSync("exit 1", { shell: "/bin/sh" });
} catch (e9) {
    didThrow9 = true;
    ok(e9 instanceof Error,                  "execSync error is an Error");
    ok(typeof e9.status === "number",        "execSync error has .status");
    ok(e9.status !== 0,                      "execSync error.status is non-zero");
}
ok(didThrow9,                                "execSync throws on non-zero exit");

// ── execFileSync: basic ───────────────────────────────────────────────────────

var r10 = cp.execFileSync("echo", ["execfile_test"]);
ok(typeof r10 === "string",                  "execFileSync returns a string");
ok(r10.indexOf("execfile_test") >= 0,        "execFileSync captures stdout");

// ── spawn (async): echo ───────────────────────────────────────────────────────

pending();
(function() {
    var stdout11 = "";
    var child11 = cp.spawn("echo", ["async_echo"]);
    ok(typeof child11 === "object",              "spawn returns an object");
    ok(typeof child11.pid === "number",          "spawn child.pid is a number");
    ok(child11.stdout !== null,                  "spawn child.stdout is not null");
    child11.stdout.on("data", function(d) {
        stdout11 = stdout11 + String(d);
    });
    child11.on("close", function(code11) {
        ok(code11 === 0,                         "spawn echo exits with code 0");
        ok(stdout11.indexOf("async_echo") >= 0,  "spawn echo stdout contains 'async_echo'");
        done();
    });
})();

// ── spawn (async): exit code ──────────────────────────────────────────────────

pending();
(function() {
    var child12 = cp.spawn("/bin/sh", ["-c", "exit 7"]);
    child12.on("close", function(code12) {
        ok(code12 === 7,                         "spawn exit code 7 received correctly");
        done();
    });
})();

// ── spawn (async): stderr data event ─────────────────────────────────────────

pending();
(function() {
    var stderr13 = "";
    var child13 = cp.spawn("/bin/sh", ["-c", "echo stderr_out >&2"]);
    child13.stderr.on("data", function(d) {
        stderr13 = stderr13 + String(d);
    });
    child13.on("close", function(code13) {
        ok(code13 === 0,                         "spawn stderr-only command exits 0");
        ok(stderr13.indexOf("stderr_out") >= 0,  "spawn stderr data event fires with correct data");
        done();
    });
})();

// ── spawn (async): stdin write ────────────────────────────────────────────────

pending();
(function() {
    var stdout14 = "";
    var child14 = cp.spawn("cat", []);
    child14.stdout.on("data", function(d) {
        stdout14 = stdout14 + String(d);
    });
    child14.stdin.write("stdin_write_test\n");
    child14.stdin.end();
    child14.on("close", function(code14) {
        ok(code14 === 0,                             "spawn stdin write: cat exits 0");
        ok(stdout14.indexOf("stdin_write_test") >= 0, "spawn stdin write: cat echoes stdin");
        done();
    });
})();

// ── spawn (async): shell option ───────────────────────────────────────────────

pending();
(function() {
    var stdout15 = "";
    var child15 = cp.spawn("echo shell_async", { shell: true });
    child15.stdout.on("data", function(d) {
        stdout15 = stdout15 + String(d);
    });
    child15.on("close", function(code15) {
        ok(code15 === 0,                             "spawn shell:true exits 0");
        ok(stdout15.indexOf("shell_async") >= 0,     "spawn shell:true runs via shell");
        done();
    });
})();

// ── exec (async): basic callback ─────────────────────────────────────────────

pending();
(function() {
    cp.exec("echo exec_async_test", function(err16, stdout16, stderr16) {
        ok(err16 === null,                           "exec callback: err is null on success");
        ok(typeof stdout16 === "string",             "exec callback: stdout is a string");
        ok(stdout16.indexOf("exec_async_test") >= 0, "exec callback: stdout contains output");
        ok(stderr16 === "",                          "exec callback: stderr is empty");
        done();
    });
})();

// ── exec (async): error callback ─────────────────────────────────────────────

pending();
(function() {
    cp.exec("exit 3", { shell: "/bin/sh" }, function(err17, stdout17, stderr17) {
        ok(err17 instanceof Error,                   "exec error callback: err is an Error");
        ok(typeof err17.code === "number",           "exec error callback: err.code is a number");
        ok(err17.code !== 0,                         "exec error callback: err.code is non-zero");
        done();
    });
})();

// ── execFile (async): basic callback ─────────────────────────────────────────

pending();
(function() {
    cp.execFile("echo", ["execfile_async"], function(err18, stdout18, stderr18) {
        ok(err18 === null,                            "execFile callback: err is null on success");
        ok(stdout18.indexOf("execfile_async") >= 0,  "execFile callback: stdout captured");
        done();
    });
})();

// ── spawn (async): kill() ─────────────────────────────────────────────────────

pending();
(function() {
    // Use a long-running command so we can kill it
    var child19 = cp.spawn("sleep", ["30"]);
    var closeFired = false;
    child19.on("close", function(code19, sig19) {
        closeFired = true;
        // Killed process: exit code is null and signal is set, or code is non-zero
        ok(code19 !== 0 || sig19 !== null || code19 === null,
           "spawn kill: close fires with non-zero code or signal");
        done();
    });
    // Kill shortly after spawn
    setTimeout(function() {
        var killed = child19.kill();
        ok(killed === true,                          "spawn kill() returns true");
    }, 50);
})();

// ── spawn (async): exit event fires before close ──────────────────────────────

pending();
(function() {
    var exitFired = false;
    var child20 = cp.spawn("true", []);
    child20.on("exit", function(code20) {
        exitFired = true;
        ok(code20 === 0,                             "spawn 'true': exit event code is 0");
    });
    child20.on("close", function() {
        ok(exitFired,                                "spawn 'true': exit fires before close");
        done();
    });
})();

// ── spawn (async): error on bad executable (bridge returns code 127, no error event) ──

pending();
(function() {
    var child21 = cp.spawn("/no/such/binary/exists_xyz");
    child21.on("close", function(code21) {
        // execve fails in child → _exit(127); bridge delivers close with code 127
        ok(code21 === 127,                           "spawn bad exec: close fires with code 127");
        done();
    });
})();

// ── spawnSync: multiline output ───────────────────────────────────────────────

var r22 = cp.spawnSync("/bin/sh", ["-c", "printf 'line1\\nline2\\nline3\\n'"]);
ok(r22.status === 0,                             "spawnSync multiline: exits 0");
ok(r22.stdout.indexOf("line1") >= 0,             "spawnSync multiline: line1 present");
ok(r22.stdout.indexOf("line2") >= 0,             "spawnSync multiline: line2 present");
ok(r22.stdout.indexOf("line3") >= 0,             "spawnSync multiline: line3 present");

// ── spawnSync: large output ───────────────────────────────────────────────────

var r23 = cp.spawnSync("/bin/sh", ["-c", "python3 -c \"print('x' * 10000)\""]);
ok(r23.status === 0,                             "spawnSync large output: exits 0");
ok(r23.stdout.length >= 10000,                   "spawnSync large output: >= 10000 chars received");

// ── execSync: pipeline ────────────────────────────────────────────────────────

var r24 = cp.execSync("echo hello | tr a-z A-Z");
ok(r24.indexOf("HELLO") >= 0,                    "execSync pipeline: output is uppercased");
