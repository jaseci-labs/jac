// ────────────────────────────────────────────────────────────────────────────
// builtins/js/os.js — Node.js `os` module
//
// Pure JavaScript implementation of the os API.
// Loaded by `require("os")` / `require("node:os")`.
//
// On Linux, reads from /proc for dynamic system info (the same source
// that libuv uses under the hood).
//
// Node.js reference: https://nodejs.org/api/os.html
// Bun reference:     bun/src/js/node/os.ts
// ────────────────────────────────────────────────────────────────────────────

var fs = require("fs");

// ── Helpers ─────────────────────────────────────────────────────────────────

function _readProc(path) {
    var data = fs.readFileSync(path, "utf8");
    if (data === undefined || data === null) { return ""; }
    // Trim trailing newline
    if (data.length > 0 && data[data.length - 1] === "\n") {
        return data.substring(0, data.length - 1);
    }
    return data;
}

function _readProcRaw(path) {
    var data = fs.readFileSync(path, "utf8");
    if (data === undefined || data === null) { return ""; }
    return data;
}

// ── Simple queries ──────────────────────────────────────────────────────────

function platform() {
    return process.platform;
}

function arch() {
    return process.arch;
}

function type() {
    return _readProc("/proc/sys/kernel/ostype");
}

function release() {
    return _readProc("/proc/sys/kernel/osrelease");
}

function hostname() {
    return _readProc("/proc/sys/kernel/hostname");
}

function homedir() {
    var h = process.env.HOME;
    if (h !== undefined && h !== "") { return h; }
    return "/";
}

function tmpdir() {
    var t = process.env.TMPDIR;
    if (t !== undefined && t !== "") { return t; }
    var t2 = process.env.TMP;
    if (t2 !== undefined && t2 !== "") { return t2; }
    var t3 = process.env.TEMP;
    if (t3 !== undefined && t3 !== "") { return t3; }
    return "/tmp";
}

function endianness() {
    // Check using typed array byte order detection
    // On little-endian (x86, arm-le): "LE", on big-endian: "BE"
    // Since we're targeting x86_64 Linux for now, hardcode LE.
    // TODO: detect at runtime when we support big-endian platforms.
    return "LE";
}

// ── Memory ──────────────────────────────────────────────────────────────────

function _parseMemInfo() {
    var raw = _readProcRaw("/proc/meminfo");
    if (raw === "") { return {}; }
    var result = {};
    var lines = raw.split("\n");
    var i = 0;
    while (i < lines.length) {
        var line = lines[i];
        var colonIdx = line.indexOf(":");
        if (colonIdx > 0) {
            var key = line.substring(0, colonIdx).trim();
            var valPart = line.substring(colonIdx + 1).trim();
            // Values are in kB, extract the number
            var spaceIdx = valPart.indexOf(" ");
            var numStr = valPart;
            if (spaceIdx > 0) {
                numStr = valPart.substring(0, spaceIdx);
            }
            result[key] = parseInt(numStr, 10);
        }
        i = i + 1;
    }
    return result;
}

function totalmem() {
    var info = _parseMemInfo();
    var kB = info["MemTotal"];
    if (kB === undefined) { return 0; }
    return kB * 1024;
}

function freemem() {
    var info = _parseMemInfo();
    var kB = info["MemAvailable"];
    if (kB === undefined) {
        kB = info["MemFree"];
    }
    if (kB === undefined) { return 0; }
    return kB * 1024;
}

// ── Uptime ──────────────────────────────────────────────────────────────────

function uptime() {
    var raw = _readProc("/proc/uptime");
    if (raw === "") { return 0; }
    var spaceIdx = raw.indexOf(" ");
    if (spaceIdx > 0) {
        return parseFloat(raw.substring(0, spaceIdx));
    }
    return parseFloat(raw);
}

// ── Load average ────────────────────────────────────────────────────────────

function loadavg() {
    var raw = _readProc("/proc/loadavg");
    if (raw === "") { return [0, 0, 0]; }
    var parts = raw.split(" ");
    var one = 0;
    var five = 0;
    var fifteen = 0;
    if (parts.length >= 1) { one = parseFloat(parts[0]); }
    if (parts.length >= 2) { five = parseFloat(parts[1]); }
    if (parts.length >= 3) { fifteen = parseFloat(parts[2]); }
    return [one, five, fifteen];
}

// ── CPUs ────────────────────────────────────────────────────────────────────

function cpus() {
    var result = [];

    // Parse model name and speed from /proc/cpuinfo
    var cpuinfo = _readProcRaw("/proc/cpuinfo");
    var models = [];
    var speeds = [];
    if (cpuinfo !== "") {
        var lines = cpuinfo.split("\n");
        var i = 0;
        while (i < lines.length) {
            var line = lines[i];
            if (line.indexOf("model name") === 0) {
                var colonIdx = line.indexOf(":");
                if (colonIdx > 0) {
                    models.push(line.substring(colonIdx + 2));
                }
            }
            if (line.indexOf("cpu MHz") === 0) {
                var colonIdx2 = line.indexOf(":");
                if (colonIdx2 > 0) {
                    speeds.push(Math.floor(parseFloat(line.substring(colonIdx2 + 2))));
                }
            }
            i = i + 1;
        }
    }

    // Parse per-CPU times from /proc/stat
    var statRaw = _readProcRaw("/proc/stat");
    var cpuTimes = [];
    if (statRaw !== "") {
        var slines = statRaw.split("\n");
        var j = 0;
        while (j < slines.length) {
            var sline = slines[j];
            // Lines like "cpu0 12345 ..." — skip the aggregate "cpu " line
            if (sline.indexOf("cpu") === 0 && sline.indexOf("cpu ") !== 0) {
                var parts = sline.split(" ");
                // parts[0] = "cpuN", parts[1..] = user nice system idle iowait irq softirq ...
                // Node.js reports: user, nice, sys, idle, irq
                // Values are in jiffies (typically 1/100 sec = 10ms each)
                var user = 0;
                var nice = 0;
                var sys = 0;
                var idle = 0;
                var irq = 0;
                if (parts.length > 1) { user = parseInt(parts[1], 10) * 10; }
                if (parts.length > 2) { nice = parseInt(parts[2], 10) * 10; }
                if (parts.length > 3) { sys = parseInt(parts[3], 10) * 10; }
                if (parts.length > 4) { idle = parseInt(parts[4], 10) * 10; }
                if (parts.length > 6) { irq = parseInt(parts[6], 10) * 10; }
                cpuTimes.push({ user: user, nice: nice, sys: sys, idle: idle, irq: irq });
            }
            j = j + 1;
        }
    }

    // Build result array
    var numCpus = cpuTimes.length;
    if (numCpus === 0) { numCpus = models.length; }
    var k = 0;
    while (k < numCpus) {
        var model = (k < models.length) ? models[k] : "unknown";
        var speed = (k < speeds.length) ? speeds[k] : 0;
        var times = (k < cpuTimes.length) ? cpuTimes[k] : { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 };
        result.push({ model: model, speed: speed, times: times });
        k = k + 1;
    }

    return result;
}

// ── User info ───────────────────────────────────────────────────────────────

function userInfo(options) {
    var encoding = "utf8";
    if (options && options.encoding) {
        encoding = options.encoding;
    }

    var uid = -1;
    var gid = -1;
    var username = "";
    var home = homedir();
    var shell = "";

    // Try reading from environment and /proc
    if (process.env.USER !== undefined) { username = process.env.USER; }
    if (process.env.SHELL !== undefined) { shell = process.env.SHELL; }
    if (process.env.UID !== undefined) { uid = parseInt(process.env.UID, 10); }

    // Read /proc/self/status for uid/gid
    var status = _readProcRaw("/proc/self/status");
    if (status !== "") {
        var lines = status.split("\n");
        var i = 0;
        while (i < lines.length) {
            var line = lines[i];
            if (line.indexOf("Uid:") === 0) {
                var parts = line.substring(4).trim().split("\t");
                if (parts.length > 0) { uid = parseInt(parts[0], 10); }
            }
            if (line.indexOf("Gid:") === 0) {
                var parts2 = line.substring(4).trim().split("\t");
                if (parts2.length > 0) { gid = parseInt(parts2[0], 10); }
            }
            i = i + 1;
        }
    }

    if (encoding === "buffer") {
        var B = globalThis.Buffer;
        return {
            uid: uid,
            gid: gid,
            username: B.from(username),
            homedir: B.from(home),
            shell: B.from(shell)
        };
    }

    return {
        uid: uid,
        gid: gid,
        username: username,
        homedir: home,
        shell: shell
    };
}

// ── Network interfaces ──────────────────────────────────────────────────────

function networkInterfaces() {
    // Parse /proc/net/dev for interface names and /proc/net/if_inet6 for IPv6
    var result = {};

    var devRaw = _readProcRaw("/proc/net/dev");
    if (devRaw !== "") {
        var lines = devRaw.split("\n");
        var i = 0;
        while (i < lines.length) {
            var line = lines[i].trim();
            var colonIdx = line.indexOf(":");
            if (colonIdx > 0 && i >= 2) {
                var ifname = line.substring(0, colonIdx).trim();
                // We can't get IP addresses from /proc/net/dev alone,
                // so return interface names with empty address arrays.
                // Full IP resolution would need ioctl or libuv bindings.
                if (result[ifname] === undefined) {
                    result[ifname] = [];
                }
            }
            i = i + 1;
        }
    }

    return result;
}

// ── Constants ───────────────────────────────────────────────────────────────

var constants = {
    signals: {
        SIGHUP:    1,
        SIGINT:    2,
        SIGQUIT:   3,
        SIGILL:    4,
        SIGTRAP:   5,
        SIGABRT:   6,
        SIGBUS:    7,
        SIGFPE:    8,
        SIGKILL:   9,
        SIGUSR1:  10,
        SIGSEGV:  11,
        SIGUSR2:  12,
        SIGPIPE:  13,
        SIGALRM:  14,
        SIGTERM:  15,
        SIGCHLD:  17,
        SIGCONT:  18,
        SIGSTOP:  19,
        SIGTSTP:  20,
        SIGTTIN:  21,
        SIGTTOU:  22,
        SIGURG:   23,
        SIGXCPU:  24,
        SIGXFSZ:  25,
        SIGVTALRM: 26,
        SIGPROF:  27,
        SIGWINCH: 28,
        SIGIO:    29,
        SIGPWR:   30,
        SIGSYS:   31
    },
    errno: {
        EPERM:    1,
        ENOENT:   2,
        ESRCH:    3,
        EINTR:    4,
        EIO:      5,
        ENXIO:    6,
        E2BIG:    7,
        ENOEXEC:  8,
        EBADF:    9,
        ECHILD:  10,
        EAGAIN:  11,
        ENOMEM:  12,
        EACCES:  13,
        EFAULT:  14,
        ENOTBLK: 15,
        EBUSY:   16,
        EEXIST:  17,
        EXDEV:   18,
        ENODEV:  19,
        ENOTDIR: 20,
        EISDIR:  21,
        EINVAL:  22,
        ENFILE:  23,
        EMFILE:  24,
        ENOTTY:  25,
        ETXTBSY: 26,
        EFBIG:   27,
        ENOSPC:  28,
        ESPIPE:  29,
        EROFS:   30,
        EMLINK:  31,
        EPIPE:   32,
        EDOM:    33,
        ERANGE:  34
    }
};

// ── Export ───────────────────────────────────────────────────────────────────

module.exports = {
    platform:          platform,
    arch:              arch,
    type:              type,
    release:           release,
    hostname:          hostname,
    homedir:           homedir,
    tmpdir:            tmpdir,
    endianness:        endianness,
    cpus:              cpus,
    totalmem:          totalmem,
    freemem:           freemem,
    uptime:            uptime,
    loadavg:           loadavg,
    networkInterfaces: networkInterfaces,
    userInfo:          userInfo,
    constants:         constants,
    EOL:               "\n",
    devNull:           "/dev/null"
};
