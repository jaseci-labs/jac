// ────────────────────────────────────────────────────────────────────────────
// js_tests/test_os.js — Tests for the node:os module
// ────────────────────────────────────────────────────────────────────────────

var os = require("os");

var pass = 0;
var fail = 0;

function ok(cond, msg) {
    if (cond) {
        pass = pass + 1;
    } else {
        console.log("FAIL: " + msg);
        fail = fail + 1;
    }
}

// ── 1. Static exports ───────────────────────────────────────────────────────

ok(typeof os === "object", "os is an object");
ok(typeof os.platform === "function", "os.platform is a function");
ok(typeof os.arch === "function", "os.arch is a function");
ok(typeof os.type === "function", "os.type is a function");
ok(typeof os.release === "function", "os.release is a function");
ok(typeof os.hostname === "function", "os.hostname is a function");
ok(typeof os.homedir === "function", "os.homedir is a function");
ok(typeof os.tmpdir === "function", "os.tmpdir is a function");
ok(typeof os.endianness === "function", "os.endianness is a function");
ok(typeof os.cpus === "function", "os.cpus is a function");
ok(typeof os.totalmem === "function", "os.totalmem is a function");
ok(typeof os.freemem === "function", "os.freemem is a function");
ok(typeof os.uptime === "function", "os.uptime is a function");
ok(typeof os.loadavg === "function", "os.loadavg is a function");
ok(typeof os.userInfo === "function", "os.userInfo is a function");
ok(typeof os.networkInterfaces === "function", "os.networkInterfaces is a function");

// ── 2. os.platform() ───────────────────────────────────────────────────────

var plat = os.platform();
ok(plat === "linux", "os.platform() === 'linux', got: " + plat);

// ── 3. os.arch() ────────────────────────────────────────────────────────────

var ar = os.arch();
ok(typeof ar === "string" && ar.length > 0, "os.arch() returns non-empty string");
ok(ar === "x64" || ar === "arm64" || ar === "arm" || ar === "ia32", "os.arch() is a known arch: " + ar);

// ── 4. os.type() ────────────────────────────────────────────────────────────

var osType = os.type();
ok(osType === "Linux", "os.type() === 'Linux', got: " + osType);

// ── 5. os.release() ─────────────────────────────────────────────────────────

var rel = os.release();
ok(typeof rel === "string" && rel.length > 0, "os.release() returns non-empty string");
ok(rel.indexOf(".") >= 0, "os.release() contains a dot (version format): " + rel);

// ── 6. os.hostname() ────────────────────────────────────────────────────────

var hn = os.hostname();
ok(typeof hn === "string" && hn.length > 0, "os.hostname() returns non-empty string");

// ── 7. os.homedir() ─────────────────────────────────────────────────────────

var hd = os.homedir();
ok(typeof hd === "string" && hd.length > 0, "os.homedir() returns non-empty string");
ok(hd[0] === "/", "os.homedir() starts with /: " + hd);

// ── 8. os.tmpdir() ──────────────────────────────────────────────────────────

var td = os.tmpdir();
ok(typeof td === "string" && td.length > 0, "os.tmpdir() returns non-empty string");
ok(td === "/tmp" || td[0] === "/", "os.tmpdir() is /tmp or starts with /");

// ── 9. os.endianness() ──────────────────────────────────────────────────────

var end = os.endianness();
ok(end === "LE" || end === "BE", "os.endianness() returns 'LE' or 'BE': " + end);

// ── 10. os.EOL ──────────────────────────────────────────────────────────────

ok(os.EOL === "\n", "os.EOL is '\\n'");

// ── 11. os.devNull ──────────────────────────────────────────────────────────

ok(os.devNull === "/dev/null", "os.devNull is '/dev/null'");

// ── 12. os.totalmem() ───────────────────────────────────────────────────────

var tm = os.totalmem();
ok(typeof tm === "number", "os.totalmem() returns a number");
ok(tm > 0, "os.totalmem() > 0: " + tm);
ok(tm > 1000000, "os.totalmem() > 1MB (sanity): " + tm);

// ── 13. os.freemem() ────────────────────────────────────────────────────────

var fm = os.freemem();
ok(typeof fm === "number", "os.freemem() returns a number");
ok(fm > 0, "os.freemem() > 0: " + fm);
ok(fm <= tm, "os.freemem() <= os.totalmem()");

// ── 14. os.uptime() ─────────────────────────────────────────────────────────

var up = os.uptime();
ok(typeof up === "number", "os.uptime() returns a number");
ok(up > 0, "os.uptime() > 0: " + up);

// ── 15. os.loadavg() ────────────────────────────────────────────────────────

var la = os.loadavg();
ok(Array.isArray(la), "os.loadavg() returns an array");
ok(la.length === 3, "os.loadavg() has 3 elements");
ok(typeof la[0] === "number", "os.loadavg()[0] is a number");
ok(typeof la[1] === "number", "os.loadavg()[1] is a number");
ok(typeof la[2] === "number", "os.loadavg()[2] is a number");
ok(la[0] >= 0, "os.loadavg()[0] >= 0");

// ── 16. os.cpus() ───────────────────────────────────────────────────────────

var cpuList = os.cpus();
ok(Array.isArray(cpuList), "os.cpus() returns an array");
ok(cpuList.length > 0, "os.cpus() has at least 1 entry");

var cpu0 = cpuList[0];
ok(typeof cpu0 === "object", "cpus()[0] is an object");
ok(typeof cpu0.model === "string", "cpus()[0].model is a string");
ok(cpu0.model.length > 0, "cpus()[0].model is non-empty");
ok(typeof cpu0.speed === "number", "cpus()[0].speed is a number");
ok(typeof cpu0.times === "object", "cpus()[0].times is an object");
ok(typeof cpu0.times.user === "number", "cpus()[0].times.user is a number");
ok(typeof cpu0.times.nice === "number", "cpus()[0].times.nice is a number");
ok(typeof cpu0.times.sys === "number", "cpus()[0].times.sys is a number");
ok(typeof cpu0.times.idle === "number", "cpus()[0].times.idle is a number");
ok(typeof cpu0.times.irq === "number", "cpus()[0].times.irq is a number");

// ── 17. os.userInfo() ───────────────────────────────────────────────────────

var ui = os.userInfo();
ok(typeof ui === "object", "os.userInfo() returns an object");
ok(typeof ui.uid === "number", "userInfo().uid is a number");
ok(typeof ui.gid === "number", "userInfo().gid is a number");
ok(typeof ui.username === "string", "userInfo().username is a string");
ok(ui.username.length > 0, "userInfo().username is non-empty");
ok(typeof ui.homedir === "string", "userInfo().homedir is a string");
ok(typeof ui.shell === "string", "userInfo().shell is a string");

// ── 18. os.networkInterfaces() ──────────────────────────────────────────────

var ni = os.networkInterfaces();
ok(typeof ni === "object", "os.networkInterfaces() returns an object");
// Should have at least "lo" on Linux
var niKeys = Object.keys(ni);
ok(niKeys.length > 0, "os.networkInterfaces() has at least 1 interface");

// ── 19. os.constants ────────────────────────────────────────────────────────

ok(typeof os.constants === "object", "os.constants is an object");
ok(typeof os.constants.signals === "object", "os.constants.signals is an object");
ok(os.constants.signals.SIGTERM === 15, "SIGTERM === 15");
ok(os.constants.signals.SIGKILL === 9, "SIGKILL === 9");
ok(os.constants.signals.SIGINT === 2, "SIGINT === 2");
ok(typeof os.constants.errno === "object", "os.constants.errno is an object");
ok(os.constants.errno.ENOENT === 2, "ENOENT === 2");
ok(os.constants.errno.EACCES === 13, "EACCES === 13");

// ── 20. require("node:os") alias ────────────────────────────────────────────

var os2 = require("node:os");
ok(os2.platform() === "linux", "require('node:os').platform() works");

// ── Summary ─────────────────────────────────────────────────────────────────

console.log("");
console.log("=== os tests: " + pass + " passed, " + fail + " failed ===");
