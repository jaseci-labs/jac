/**
 * child_process.js — Node.js v22 `child_process` / `node:child_process`
 *
 * Native primitives via globalThis.__cp (libc fork/exec bridge).
 */

var EventEmitter = require("events");
var stream = require("stream");
var Readable = stream.Readable;
var Writable = stream.Writable;

var _drainRegistered = false;

function _cp() {
    if (!globalThis.__cp) {
        throw new Error("child_process: __cp native bridge is not available");
    }
    if (!_drainRegistered && typeof globalThis.__cp.registerDrain === "function") {
        globalThis.__cp.registerDrain(_globalDrain);
        _drainRegistered = true;
    }
    return globalThis.__cp;
}

function _getBuffer() {
    if (typeof globalThis !== "undefined" && globalThis.Buffer) {
        return globalThis.Buffer;
    }
    try {
        return require("buffer").Buffer;
    } catch (e) {
        return null;
    }
}

var Buffer = _getBuffer();

function _envToBlock(env) {
    if (!env) return "";
    var keys = Object.keys(env);
    var out = "";
    var i;
    for (i = 0; i < keys.length; i++) {
        var k = keys[i];
        out = out + k + "=" + String(env[k]) + "\n";
    }
    return out;
}

/**
 * Ensure LD_LIBRARY_PATH contains absolute js_engine lib dirs so child engines
 * resolve bare sonames (libnapi_shim.so, …) even when options.cwd differs
 * from the project root. Derived from process.execPath → <root>/bin/….
 */
function _ensureLibPath(env) {
    var out = env ? Object.assign({}, env) : {};
    var exec = (typeof process !== "undefined" && process.execPath) ? String(process.execPath) : "";
    var root = "";
    if (exec) {
        // execPath is …/bin/js_engine[.bin]; parent of bin/ is project root.
        var slash = exec.lastIndexOf("/");
        if (slash > 0) {
            var binDir = exec.substring(0, slash);
            var slash2 = binDir.lastIndexOf("/");
            if (slash2 >= 0) root = binDir.substring(0, slash2);
        }
    }
    if (!root) return out;
    var need = root + "/lib:" + root + "/lib/llhttp/lib";
    var cur = out.LD_LIBRARY_PATH ? String(out.LD_LIBRARY_PATH) : "";
    if (!cur) {
        out.LD_LIBRARY_PATH = need;
    } else if (cur.indexOf(root + "/lib") < 0) {
        out.LD_LIBRARY_PATH = need + ":" + cur;
    }
    return out;
}

function _defaultEnv() {
    return _envToBlock(_ensureLibPath(process.env));
}

function _normalizeOptions(options) {
    options = options || {};
    var envObj = options.env !== undefined ? options.env : process.env;
    return {
        cwd: options.cwd || "",
        env: _envToBlock(_ensureLibPath(envObj)),
        input: options.input !== undefined ? String(options.input) : "",
        maxBuffer: options.maxBuffer !== undefined ? options.maxBuffer : 1024 * 1024,
        shell: options.shell,
        timeout: options.timeout || 0,
        encoding: options.encoding || "utf8",
        detached: !!options.detached
    };
}

var _activeHandles = {};
var _drainScheduled = false;

function _toBufferOrString(data, encoding) {
    if (Buffer && Buffer.from && encoding !== "utf8" && encoding !== "utf-8") {
        try {
            return Buffer.from(data, encoding);
        } catch (e) {}
    }
    return data;
}

// Decode a base64 stdout/stderr chunk (from the native bridge, binary-safe) into
// a Buffer. Falls back to the raw string if Buffer is unavailable.
function _b64ToChunk(b64) {
    if (Buffer && Buffer.from) {
        try { return Buffer.from(b64, "base64"); } catch (e) {}
    }
    return b64;
}

function _globalDrain() {
    _drainScheduled = false;
    var evs = _cp().pollEvents();
    var i;
    for (i = 0; i < evs.length; i++) {
        var e = evs[i];
        var child = _activeHandles[e.handle];
        if (!child) continue;
        if (e.event === "spawn") {
            child.emit("spawn");
        } else if ((e.event === "stdout_b64" || e.event === "stdout") && child.stdout) {
            // stdout_b64 carries base64 (binary-safe from the native bridge);
            // decode to a Buffer. Legacy "stdout" (utf8 str) still handled.
            var chunk = e.event === "stdout_b64" ? _b64ToChunk(e.arg0) : _toBufferOrString(e.arg0, child._encoding);
            // Push into real Readable so pipe/setEncoding/read work. The stream's
            // own encoding (set via _makeChildStdout / setEncoding) decodes the
            // Buffer to a string when the caller requested a string encoding.
            if (typeof child.stdout.push === "function") {
                child.stdout.push(chunk);
            } else {
                child.stdout.emit("data", chunk);
            }
        } else if ((e.event === "stderr_b64" || e.event === "stderr") && child.stderr) {
            var chunkErr = e.event === "stderr_b64" ? _b64ToChunk(e.arg0) : _toBufferOrString(e.arg0, child._encoding);
            if (typeof child.stderr.push === "function") {
                child.stderr.push(chunkErr);
            } else {
                child.stderr.emit("data", chunkErr);
            }
        } else if (e.event === "error") {
            var err = new Error(e.arg0 || "spawn error");
            child.emit("error", err);
        } else if (e.event === "exit") {
            var code = e.arg0 === "" ? null : parseInt(e.arg0, 10);
            var sig = e.arg1 === "" ? null : e.arg1;
            child.exitCode = code;
            child.signalCode = sig;
            child.emit("exit", code, sig);
        } else if (e.event === "close") {
            var c2 = e.arg0 === "" ? null : parseInt(e.arg0, 10);
            var s2 = e.arg1 === "" ? null : e.arg1;
            // Signal EOF on stdio streams.
            if (child.stdout && typeof child.stdout.push === "function") {
                child.stdout.push(null);
            }
            if (child.stderr && typeof child.stderr.push === "function") {
                child.stderr.push(null);
            }
            if (child.stdin && typeof child.stdin.end === "function" &&
                child.stdin.writable !== false) {
                try { child.stdin.end(); } catch (_e) { /* ignore */ }
            }
            child.emit("close", c2, s2);
            delete _activeHandles[e.handle];
        }
    }
    // Only keep the self-rescheduling drain loop (which pins the event loop
    // alive via setImmediate) running while there is at least one REF'd active
    // child. A persistent unref'd child (e.g. esbuild's service, which unref()s
    // itself when idle and only ref()s during an active build) must NOT keep the
    // process alive — otherwise `vite build` hangs forever at exit polling the
    // idle esbuild binary's pings.
    var hasRefdActive = false;
    for (var k in _activeHandles) {
        if (_activeHandles.hasOwnProperty(k) && !_activeHandles[k]._unrefed) {
            hasRefdActive = true;
            break;
        }
    }
    if (hasRefdActive) {
        _scheduleDrain();
    }
}

function _scheduleDrain() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    // Prefer setImmediate so drain keeps running after I/O; nextTick alone can stop
    // while a child has exited but pipe EOF has not been polled yet.
    if (typeof setImmediate === "function") {
        setImmediate(_globalDrain);
    } else {
        process.nextTick(_globalDrain);
    }
}

function ChildProcess() {
    EventEmitter.init.call(this);
    this.stdin = null;
    this.stdout = null;
    this.stderr = null;
    this.stdio = [null, null, null];
    this.pid = undefined;
    this.exitCode = null;
    this.signalCode = null;
    this.killed = false;
    this.spawnfile = "";
    this.spawnargs = [];
    this.connected = false;
    this._handleId = 0;
    this._encoding = "utf8";
    this._unrefed = false;
}

ChildProcess.prototype = Object.create(EventEmitter.prototype);
ChildProcess.prototype.constructor = ChildProcess;

ChildProcess.prototype.kill = function (signal) {
    if (this._handleId) {
        this.killed = _cp().spawnKill(this._handleId);
    }
    return this.killed;
};

ChildProcess.prototype.ref = function () {
    this._unrefed = false;
    if (this._handleId) {
        try { var cp = _cp(); if (typeof cp.ref === "function") cp.ref(this._handleId); } catch (_e) {}
    }
    // Re-refing may need the drain loop restarted.
    _scheduleDrain();
    return this;
};
ChildProcess.prototype.unref = function () {
    // Mark unref'd: the drain loop (_globalDrain) stops pinning the event loop
    // alive for this child, and its poll handles are dropped from uv keep-alive.
    // A persistent idle child (esbuild's service) then no longer blocks exit.
    this._unrefed = true;
    if (this._handleId) {
        try { var cp = _cp(); if (typeof cp.unref === "function") cp.unref(this._handleId); } catch (_e) {}
    }
    return this;
};

function _makeChildStdout(encoding) {
    var r = new Readable({
        read: function () { /* push-driven from native drain */ }
    });
    if (encoding && encoding !== "buffer") {
        try { r.setEncoding(encoding); } catch (_e) { /* ignore */ }
    }
    return r;
}

function _makeChildStderr(encoding) {
    return _makeChildStdout(encoding);
}

function _makeChildStdin(hid) {
    var ended = false;
    return new Writable({
        write: function (chunk, enc, cb) {
            if (ended) {
                if (typeof cb === "function") {
                    cb(new Error("write after end"));
                }
                return;
            }
            // Binary stdin (e.g. esbuild's request packets: length headers + NUL)
            // must not go through the utf8-string write path, which corrupts it.
            // Send Buffers/typed-arrays as base64 → the bridge decodes to raw
            // bytes (spawnWriteStdinB64). Strings keep the plain path.
            try {
                var cp = _cp();
                if (typeof chunk !== "string" && chunk && typeof cp.spawnWriteStdinB64 === "function"
                    && globalThis.Buffer && globalThis.Buffer.isBuffer && (globalThis.Buffer.isBuffer(chunk) || chunk instanceof Uint8Array)) {
                    var b64 = globalThis.Buffer.from(chunk).toString("base64");
                    cp.spawnWriteStdinB64(hid, b64);
                } else {
                    var s;
                    if (typeof chunk === "string") {
                        s = chunk;
                    } else if (chunk && typeof chunk.toString === "function") {
                        s = chunk.toString(enc || "utf8");
                    } else {
                        s = String(chunk);
                    }
                    cp.spawnWriteStdin(hid, s);
                }
            } catch (err) {
                if (typeof cb === "function") { cb(err); return; }
                throw err;
            }
            if (typeof cb === "function") { cb(); }
        },
        final: function (cb) {
            ended = true;
            try {
                _cp().spawnStdinEnd(hid);
            } catch (err) {
                if (typeof cb === "function") { cb(err); return; }
            }
            if (typeof cb === "function") { cb(); }
        }
    });
}

function spawn(command, args, options) {
    if (args && typeof args === "object" && !Array.isArray(args)) {
        options = args;
        args = [];
    }
    if (typeof args === "function") {
        options = {};
        args = [];
    }
    if (!args) args = [];
    options = _normalizeOptions(options);

    var file = command;
    var argv = args.slice();
    if (options.shell) {
        var shell = typeof options.shell === "string" ? options.shell : "/bin/sh";
        var cmd = command;
        if (argv.length) cmd = cmd + " " + argv.join(" ");
        file = shell;
        argv = ["-c", cmd];
    }

    var child = new ChildProcess();
    child.spawnfile = file;
    child.spawnargs = [file].concat(argv);
    // Node's spawn() streams emit Buffers by default (no stream encoding); only
    // exec/execFile/spawnSync default to utf8 text. An explicit options.encoding
    // still applies (setEncoding on the Readable). "buffer" => leave as Buffers.
    child._encoding = options.encoding || "buffer";

    var hid = _cp().spawnAsync(
        file, argv, options.cwd, options.env,
        options.detached ? 1 : 0
    );
    if (hid < 0) {
        child.stdin = _makeChildStdin(-1);
        child.stdout = _makeChildStdout(child._encoding);
        child.stderr = _makeChildStderr(child._encoding);
        child.stdio = [child.stdin, child.stdout, child.stderr];
        process.nextTick(function () {
            child.emit("error", new Error("spawn " + file + " EAGAIN"));
        });
        return child;
    }
    child._handleId = hid;
    child.pid = _cp().getPid(hid);
    child.stdin = _makeChildStdin(hid);
    child.stdout = _makeChildStdout(child._encoding);
    child.stderr = _makeChildStderr(child._encoding);
    child.stdio = [child.stdin, child.stdout, child.stderr];
    _activeHandles[hid] = child;
    _scheduleDrain();
    return child;
}

function spawnSync(command, args, options) {
    if (args && typeof args === "object" && !Array.isArray(args)) {
        options = args;
        args = [];
    }
    if (!args) args = [];
    options = _normalizeOptions(options);

    var file = command;
    var argv = args.slice();
    if (options.shell) {
        var shell = typeof options.shell === "string" ? options.shell : "/bin/sh";
        var cmd = command;
        if (argv.length) cmd = cmd + " " + argv.join(" ");
        file = shell;
        argv = ["-c", cmd];
    }

    var res = _cp().spawnSync(file, argv, options.cwd, options.env, options.input, options.maxBuffer);

    var stdout = res.stdout;
    var stderr = res.stderr;
    if (Buffer && options.encoding === "buffer") {
        stdout = Buffer.from(res.stdout, "utf8");
        stderr = Buffer.from(res.stderr, "utf8");
    }

    return {
        pid: res.pid,
        output: [null, stdout, stderr],
        stdout: stdout,
        stderr: stderr,
        status: res.status,
        signal: res.signal,
        error: undefined
    };
}

function exec(command, options, callback) {
    if (typeof options === "function") {
        callback = options;
        options = {};
    }
    options = options || {};
    options.shell = options.shell !== false ? (options.shell || "/bin/sh") : false;
    if (!options.shell) options.shell = "/bin/sh";

    var child = spawn(command, [], options);
    var stdout = "";
    var stderr = "";

    child.stdout.on("data", function (c) {
        stdout = stdout + String(c);
    });
    child.stderr.on("data", function (c) {
        stderr = stderr + String(c);
    });

    child.on("close", function (code) {
        var err = null;
        if (code !== 0 && code !== null) {
            err = new Error("Command failed: " + command);
            err.code = code;
            err.stdout = stdout;
            err.stderr = stderr;
        }
        if (callback) callback(err, stdout, stderr);
    });

    return child;
}

function execSync(command, options) {
    options = options || {};
    options.shell = options.shell !== false ? (options.shell || "/bin/sh") : false;
    if (!options.shell) options.shell = "/bin/sh";
    var res = spawnSync(command, [], options);
    if (res.status !== 0 && res.status !== null) {
        var err = new Error("Command failed: " + command);
        err.status = res.status;
        err.stdout = res.stdout;
        err.stderr = res.stderr;
        throw err;
    }
    return res.stdout;
}

function execFile(file, args, options, callback) {
    if (typeof args === "function") {
        callback = args;
        args = [];
        options = {};
    } else if (typeof options === "function") {
        callback = options;
        options = {};
    }
    if (!args) args = [];
    options = options || {};

    var child = spawn(file, args, options);
    var stdout = "";
    var stderr = "";

    child.stdout.on("data", function (c) { stdout = stdout + String(c); });
    child.stderr.on("data", function (c) { stderr = stderr + String(c); });

    child.on("close", function (code) {
        var err = null;
        if (code !== 0 && code !== null) {
            err = new Error("Command failed: " + file);
            err.code = code;
        }
        if (callback) callback(err, stdout, stderr);
    });
    return child;
}

function execFileSync(file, args, options) {
    if (args && typeof args === "object" && !args.length && args.constructor === Object) {
        options = args;
        args = [];
    }
    if (typeof args === "function") {
        options = {};
        args = [];
    }
    if (!args) args = [];
    options = _normalizeOptions(options);
    var res = spawnSync(file, args, options);
    if (res.status !== 0 && res.status !== null) {
        var err = new Error("Command failed: " + file);
        err.status = res.status;
        err.stdout = res.stdout;
        err.stderr = res.stderr;
        throw err;
    }
    return res.stdout;
}

function fork(modulePath, args, options) {
    if (typeof args === "object" && args && !args.length && args.constructor === Object) {
        options = args;
        args = [];
    }
    if (!args) args = [];
    options = options || {};
    options.shell = false;
    var execPath = process.execPath || "bin/js_engine";
    return spawn(execPath, [modulePath].concat(args), options);
}

module.exports = {
    spawn: spawn,
    spawnSync: spawnSync,
    exec: exec,
    execSync: execSync,
    execFile: execFile,
    execFileSync: execFileSync,
    fork: fork,
    ChildProcess: ChildProcess
};
