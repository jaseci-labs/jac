// fs.js — Extends the native fs global with:
//   - fs.promises namespace (Promise-wrapped sync methods)
//   - fs.createWriteStream write()/end() method wiring
//
// This file is loaded as a JS builtin by _require_module when
// require("fs") is called. It augments the existing globalThis.fs
// object and re-exports it.

var nativeFs = globalThis.fs;
var nodeUrl = require("url");
var nodePath = require("path");
var _fsErrors = require("./fs/errors.js");
var _fsVal = require("./fs/validators.js");
var _fhMod = require("./fs/filehandle.js");
var _streamsMod = require("./fs/streams.js");

// Ensure Buffer is available globally (loaded lazily via require caching)
if (!globalThis.Buffer) { require("buffer"); }

function _fsPathArg(path, name) {
    name = name || "path";
    _fsVal.validatePath(path, name);
    var out = path;
    // Node: only URL objects are converted — string args are always OS paths
    // (even if they look like "file://..."; see test-fs-whatwg-url.js).
    if (path && typeof path === "object" && typeof path.href === "string") {
        if (path.protocol && path.protocol !== "file:") {
            var schemeErr = new TypeError('The URL must be of scheme file');
            schemeErr.code = 'ERR_INVALID_URL_SCHEME';
            throw schemeErr;
        }
        if (typeof path.protocol === "string" || path.href.indexOf("file:") === 0) {
            out = nodeUrl.fileURLToPath(path);
        } else {
            var schemeErr2 = new TypeError('The URL must be of scheme file');
            schemeErr2.code = 'ERR_INVALID_URL_SCHEME';
            throw schemeErr2;
        }
    }
    // Percent-encoded nulls (%00) become real NULs after fileURLToPath.
    if (typeof out === "string") {
        _fsVal.validateNullBytes(out, name);
        // Match Node path.normalize: collapse // so "file://x" and "file:/x" agree.
        out = nodePath.normalize(out);
    }
    return out;
}

// The native async fs bridge reports failures as a null-prototype record
// {message, code, errno, syscall, path} — not an Error: no stack, no
// toString (String(err) threw "Cannot convert object to primitive value"),
// and `err instanceof Error` was false. Node hands callbacks an Error.
function _asFsError(err) {
    if (!err || typeof err !== "object" || err instanceof Error) { return err; }
    var e = _fsErrors.errnoException(err.code, err.syscall, err.path,
                                      err.dest !== undefined ? err.dest : null, err.message);
    if (err.errno !== undefined) { e.errno = err.errno; }
    return e;
}

function _requireCb(cb) {
    cb = _fsVal.makeCallback(cb);
    return function (err) {
        if (err && typeof err === "object" && !(err instanceof Error)) {
            arguments[0] = _asFsError(err);
        }
        return cb.apply(this, arguments);
    };
}

// ── Validation wrappers for natives with little JS polish ────────────────────
(function _installFsValidators() {
    ["chownSync", "chown", "lchownSync", "lchown"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = name.indexOf("Sync") === -1;
        nativeFs[name] = function (path, uid, gid, callback) {
            path = _fsPathArg(path);
            _fsVal.validateUidGid(uid, "uid");
            _fsVal.validateUidGid(gid, "gid");
            if (isAsync) {
                callback = _requireCb(callback);
                return orig.call(nativeFs, path, uid, gid, callback);
            }
            return orig.call(nativeFs, path, uid, gid);
        };
    });

    ["chmodSync", "chmod"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = name.indexOf("Sync") === -1;
        nativeFs[name] = function (path, mode, callback) {
            path = _fsPathArg(path);
            _fsVal.validateMode(mode, "mode");
            if (isAsync) {
                callback = _requireCb(arguments[arguments.length - 1]);
                return orig.call(nativeFs, path, mode, callback);
            }
            return orig.call(nativeFs, path, mode);
        };
    });

    ["fchmodSync", "fchmod"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = name.indexOf("Sync") === -1;
        nativeFs[name] = function (fd, mode, callback) {
            _fsVal.validateFd(fd);
            _fsVal.validateMode(mode, "mode");
            if (isAsync) {
                callback = _requireCb(arguments[arguments.length - 1]);
                return orig.call(nativeFs, fd, mode, callback);
            }
            return orig.call(nativeFs, fd, mode);
        };
    });

    ["fchownSync", "fchown"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = name.indexOf("Sync") === -1;
        nativeFs[name] = function (fd, uid, gid, callback) {
            _fsVal.validateFd(fd);
            _fsVal.validateUidGid(uid, "uid");
            _fsVal.validateUidGid(gid, "gid");
            if (isAsync) {
                callback = _requireCb(callback);
                return orig.call(nativeFs, fd, uid, gid, callback);
            }
            return orig.call(nativeFs, fd, uid, gid);
        };
    });

    (function () {
        var origSync = nativeFs.closeSync;
        var orig = nativeFs.close;
        if (typeof origSync === "function") {
            nativeFs.closeSync = function (fd) {
                _fsVal.validateFd(fd);
                return origSync.call(nativeFs, fd);
            };
        }
        if (typeof orig === "function") {
            nativeFs.close = function (fd, callback) {
                _fsVal.validateFd(fd);
                if (callback !== undefined) callback = _requireCb(callback);
                return orig.call(nativeFs, fd, callback);
            };
        }
    })();

    ["fsyncSync", "fsync", "fdatasyncSync", "fdatasync"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = name.indexOf("Sync") === -1;
        nativeFs[name] = function (fd, callback) {
            _fsVal.validateFd(fd);
            if (isAsync) {
                callback = _requireCb(callback);
                return orig.call(nativeFs, fd, callback);
            }
            return orig.call(nativeFs, fd);
        };
    });

    (function () {
        var origSync = nativeFs.openSync;
        var orig = nativeFs.open;
        if (typeof origSync === "function") {
            nativeFs.openSync = function (path, flags, mode) {
                path = _fsPathArg(path);
                if (mode !== undefined) mode = _fsVal.validateMode(mode, "mode");
                return origSync.call(nativeFs, path, flags, mode);
            };
        }
        if (typeof orig === "function") {
            nativeFs.open = function (path, flags, mode, callback) {
                path = _fsPathArg(path);
                if (typeof flags === "function") { callback = flags; flags = undefined; mode = undefined; }
                else if (typeof mode === "function") { callback = mode; mode = undefined; }
                callback = _requireCb(callback);
                if (mode !== undefined) mode = _fsVal.validateMode(mode, "mode");
                return orig.call(nativeFs, path, flags, mode, callback);
            };
        }
    })();

    ["renameSync", "rename"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = name.indexOf("Sync") === -1;
        nativeFs[name] = function (oldPath, newPath, callback) {
            oldPath = _fsPathArg(oldPath, "oldPath");
            newPath = _fsPathArg(newPath, "newPath");
            if (isAsync) {
                callback = _requireCb(callback);
                return orig.call(nativeFs, oldPath, newPath, callback);
            }
            return orig.call(nativeFs, oldPath, newPath);
        };
    });

    ["readlinkSync", "readlink", "unlink", "rmdir", "access", "accessSync"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = !/Sync$/.test(name);
        nativeFs[name] = function (path) {
            path = _fsPathArg(path);
            var args = Array.prototype.slice.call(arguments);
            args[0] = path;
            if (name === "readlink" || name === "readlinkSync") {
                var encOpt = args[1];
                if (typeof encOpt === "string") {
                    args[1] = _fsVal.validateEncoding(encOpt, "encoding");
                } else if (encOpt && typeof encOpt === "object" && encOpt.encoding != null) {
                    encOpt.encoding = _fsVal.validateEncoding(encOpt.encoding, "encoding");
                }
            }
            if (isAsync) {
                args[args.length - 1] = _requireCb(args[args.length - 1]);
            }
            return orig.apply(nativeFs, args);
        };
    });

    (function () {
        var origSync = nativeFs.symlinkSync;
        var orig = nativeFs.symlink;
        function _validateSymlinkType(type) {
            // Functions are skipped: the engine's promise machinery can leak an
            // internal continuation as a trailing arg through _promisifyVoid.
            if (type !== undefined && type !== null && typeof type !== "function" &&
                type !== "dir" && type !== "file" && type !== "junction") {
                throw _fsErrors.errInvalidArgValue(
                    "type", type, "must be one of: 'dir', 'file', 'junction'");
            }
        }
        function _symlinkEexistGuard(target, path) {
            var st;
            try { st = _nativeLstatSync(path); } catch (_eL) { st = undefined; }
            if (st !== undefined && st !== null) {
                throw _fsErrors.errnoException(
                    "EEXIST", "symlink", target, path,
                    "EEXIST: file already exists, symlink '" + target + "' -> '" + path + "'");
            }
        }
        if (typeof origSync === "function") {
            nativeFs.symlinkSync = function (target, path, type) {
                target = _fsPathArg(target, "target");
                path = _fsPathArg(path);
                _validateSymlinkType(type);
                _symlinkEexistGuard(target, path);
                return origSync.call(nativeFs, target, path, type);
            };
        }
        if (typeof orig === "function") {
            nativeFs.symlink = function (target, path, type, callback) {
                target = _fsPathArg(target, "target");
                path = _fsPathArg(path);
                if (typeof type === "function") { callback = type; type = undefined; }
                _validateSymlinkType(type);
                callback = _requireCb(callback);
                try { _symlinkEexistGuard(target, path); }
                catch (eG) { _scheduleNextTick(function () { callback(eG); }); return; }
                return orig.call(nativeFs, target, path, type, callback);
            };
        }
    })();

    // Path + callback wrappers for remaining async/sync entry points
    ["unlinkSync", "rmdirSync", "mkdtempSync", "mkdtemp",
     "writeFile", "appendFile", "readdir", "mkdir", "rm",
     "realpath", "copyFile", "copyFileSync"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = !/Sync$/.test(name);
        nativeFs[name] = function (path) {
            // writeFile/appendFile accept an fd in place of a path (legacy Node API).
            var isFdPath = (name === "writeFile" || name === "appendFile") &&
                           typeof path === "number";
            if (!isFdPath) {
                path = _fsPathArg(path);
            }
            var args = Array.prototype.slice.call(arguments);
            args[0] = path;
            if (name === "copyFile" || name === "copyFileSync") {
                var flags = args[2];
                if (name === "copyFile" && typeof flags === "function") flags = undefined;
                if (flags !== undefined && flags !== null) {
                    _fsVal.validateInteger(flags, "mode", 0, 7);
                }
                if (typeof args[1] !== "undefined") {
                    args[1] = _fsPathArg(args[1]);
                }
                // The native copyfile clobbers the destination unconditionally;
                // enforce COPYFILE_EXCL and read-only-destination semantics here.
                // Sync form throws; async form reports through the callback.
                var _cfDest = args[1];
                var _cfErr = null;
                var _cfStat = null;
                try { _cfStat = nativeFs.statSync(_cfDest, { throwIfNoEntry: false }); } catch (_c0) {}
                if (_cfStat) {
                    if (flags && (flags & 1)) {  // COPYFILE_EXCL
                        _cfErr = _fsErrors.errnoException(
                            "EEXIST", "copyfile", path, _cfDest,
                            "EEXIST: file already exists, copyfile '" + path + "' -> '" + _cfDest + "'");
                    } else {
                        var _cfFd = -1;
                        try { _cfFd = nativeFs.openSync(_cfDest, "r+"); }
                        catch (_c1) {
                            if (_c1 && (_c1.code === "EACCES" || _c1.code === "EPERM")) {
                                _cfErr = _fsErrors.errnoException(
                                    "EACCES", "copyfile", path, _cfDest,
                                    "EACCES: permission denied, copyfile '" + path + "' -> '" + _cfDest + "'");
                            }
                        }
                        if (_cfFd >= 0) { try { nativeFs.closeSync(_cfFd); } catch (_c2) {} }
                    }
                }
                if (_cfErr) {
                    if (name === "copyFileSync") { throw _cfErr; }
                    var _cfCb = _requireCb(args[args.length - 1]);
                    _scheduleNextTick(function () { _cfCb(_cfErr); });
                    return;
                }
            }
            // Validate string encoding options before native (assert-encoding-error).
            if (name === "writeFile" || name === "appendFile" ||
                name === "readdir" || name === "realpath" || name === "mkdtemp" ||
                name === "mkdtempSync") {
                var optArg = args[1];
                if (name === "writeFile" || name === "appendFile") {
                    // writeFile(path, data, encoding?, cb) — data must be a string
                    // or ArrayBufferView (never ToString-coerced).
                    if (typeof args[1] !== "string" && !ArrayBuffer.isView(args[1])) {
                        throw _fsErrors.errInvalidArgType(
                            "data",
                            "string or an instance of Buffer, TypedArray, or DataView",
                            args[1]);
                    }
                    if (typeof args[2] === "string") {
                        args[2] = _fsVal.validateEncoding(args[2], "encoding");
                    } else if (args[2] && typeof args[2] === "object" && args[2].encoding != null) {
                        args[2].encoding = _fsVal.validateEncoding(args[2].encoding, "encoding");
                    }
                } else if (typeof optArg === "string") {
                    args[1] = _fsVal.validateEncoding(optArg, "encoding");
                } else if (optArg && typeof optArg === "object" && optArg.encoding != null &&
                           typeof optArg.encoding === "string") {
                    optArg.encoding = _fsVal.validateEncoding(optArg.encoding, "encoding");
                }
            }
            if (isAsync) {
                // The callback is always mandatory — a trailing non-function
                // (or a missing one) throws before any I/O.
                args[args.length - 1] = _requireCb(args[args.length - 1]);
            }
            if (isFdPath) {
                return _writeFileFdImpl(name, args);
            }
            return orig.apply(nativeFs, args);
        };
    });

    // exists / existsSync: Node does NOT throw on NUL paths — returns false.
    (function () {
        var _exSync = nativeFs.existsSync;
        nativeFs.existsSync = function (path) {
            try {
                if (typeof path === "string" && path.indexOf("\0") !== -1) return false;
                path = _fsPathArg(path);
            } catch (_e) {
                return false;
            }
            if (typeof _exSync === "function") return !!_exSync.call(nativeFs, path);
            try { nativeFs.accessSync(path); return true; } catch (_a) { return false; }
        };
        nativeFs.exists = function (path, callback) {
            // Node: the callback is mandatory (maybeCallback) even though the
            // result is delivered Node-style-less (single boolean).
            _fsVal.validateFunction(callback, "cb");
            var exists = false;
            try {
                exists = nativeFs.existsSync(path);
            } catch (_e2) { exists = false; }
            _scheduleNextTick(function () { callback(exists); });
        };
    })();

    ["fstatSync", "fstat", "ftruncateSync", "ftruncate", "futimesSync", "futimes"].forEach(function (name) {
        var orig = nativeFs[name];
        if (typeof orig !== "function") return;
        var isAsync = !/Sync$/.test(name);
        nativeFs[name] = function (fd) {
            _fsVal.validateFd(fd);
            var args = Array.prototype.slice.call(arguments);
            if (isAsync) {
                args[args.length - 1] = _requireCb(args[args.length - 1]);
            }
            return orig.apply(nativeFs, args);
        };
    });
})();

function _readFileFromFdSync(fd, options) {
    _fsVal.validateFd(fd);
    var encoding = null;
    if (typeof options === "string") {
        encoding = _fsVal.validateEncoding(options, "encoding");
    } else if (options && typeof options === "object") {
        if (options.encoding !== undefined && options.encoding !== null) {
            encoding = _fsVal.validateEncoding(options.encoding, "encoding");
        }
    } else if (options !== undefined && options !== null) {
        throw _fsErrors.errInvalidArgType("options", "string or Object", options);
    }
    var buf = Buffer.alloc(64 * 1024);
    var total = 0;
    while (true) {
        if (total >= buf.length) {
            var bigger = Buffer.alloc(buf.length * 2);
            buf.copy(bigger, 0, 0, total);
            buf = bigger;
        }
        var n = nativeFs.readSync(fd, buf, total, buf.length - total, null);
        if (n <= 0) break;
        total += n;
    }
    var out = buf.slice(0, total);
    if (encoding && encoding !== "buffer") return out.toString(encoding);
    return out;
}

nativeFs._toUnixTimestamp = function (time) {
    // Match Node lib/internal/fs/utils.js toUnixTimestamp.
    if (typeof time === "string" && +time == time) {
        return +time;
    }
    if (typeof time === "number" && Number.isFinite(time)) {
        // Negative timestamps normalize to "now" (seconds).
        if (time < 0) {
            return Date.now() / 1000;
        }
        return time;
    }
    if (time instanceof Date) {
        return time.getTime() / 1000;
    }
    throw _fsErrors.errInvalidArgType("time", "Date or Time in seconds", time);
};

// ── Node-compat wrappers ─────────────────────────────────────────────────────
// readFileSync: return Buffer when no encoding, string when encoding given
var _nativeReadFileSync = nativeFs.readFileSync;
nativeFs.readFileSync = function(path, options) {
    if (typeof path === "number") {
        return _readFileFromFdSync(path, options);
    }
    path = _fsPathArg(path);
    var encoding = null;
    if (typeof options === "string") {
        encoding = _fsVal.validateEncoding(options, "encoding");
    } else if (options && typeof options === "object") {
        if (options.encoding !== undefined && options.encoding !== null) {
            encoding = _fsVal.validateEncoding(options.encoding, "encoding");
        }
    } else if (options !== undefined && options !== null) {
        throw _fsErrors.errInvalidArgType("options", "string or Object", options);
    }
    // Native _read_file_sync_str truncates at NUL (C-string), so binary files
    // like .wasm must be read via open+read into a Buffer.
    if (!encoding || encoding === "buffer") {
        var stBin = nativeFs.statSync(path);
        if (!stBin) {
            var errBin = new Error("ENOENT: no such file or directory, open '" + path + "'");
            errBin.code = "ENOENT";
            errBin.path = path;
            errBin.syscall = "open";
            throw errBin;
        }
        var sizeBin = stBin.size | 0;
        var fdBin = nativeFs.openSync(path, "r");
        try {
            var Bbin = globalThis.Buffer;
            var bufBin = Bbin && Bbin.alloc ? Bbin.alloc(sizeBin) : new Uint8Array(sizeBin);
            var nBin = nativeFs.readSync(fdBin, bufBin, 0, sizeBin, 0);
            if (nBin < sizeBin && bufBin.subarray) return bufBin.subarray(0, nBin);
            return bufBin;
        } finally {
            nativeFs.closeSync(fdBin);
        }
    }
    var content = _nativeReadFileSync(path);
    if (content === undefined) {
        var err = new Error("ENOENT: no such file or directory, open '" + path + "'");
        err.code = "ENOENT";
        err.path = path;
        err.syscall = "open";
        throw err;
    }
    return content;
};

var _nativeReadFileCb = nativeFs.readFile;
nativeFs.readFile = function (path, options, callback) {
    if (typeof path === "number") {
        var cb = callback;
        var opts = options;
        if (typeof options === "function") {
            cb = options;
            opts = undefined;
        }
        cb = _requireCb(cb);
        _scheduleNextTick(function () {
            try {
                cb(null, _readFileFromFdSync(path, opts));
            } catch (e) {
                cb(e);
            }
        });
        return;
    }
    var args = Array.prototype.slice.call(arguments);
    args[0] = _fsPathArg(path);
    if (typeof options === "string") {
        args[1] = _fsVal.validateEncoding(options, "encoding");
    } else if (options && typeof options === "object" && options.encoding != null) {
        options.encoding = _fsVal.validateEncoding(options.encoding, "encoding");
    }
    var last = args[args.length - 1];
    if (typeof last === "function" || last === undefined || last === null) {
        args[args.length - 1] = _requireCb(last);
    }
    return _nativeReadFileCb.apply(nativeFs, args);
};

// ── writeFile/appendFile with a file descriptor (legacy Node API) ────────────
// Writes at the fd's current position and never closes the fd.
function _writeFileFdSync(fd, data, encoding) {
    var buf = typeof data === 'string'
        ? Buffer.from(data, encoding || 'utf8')
        : data;
    var off = 0;
    while (off < buf.length) {
        var n = nativeFs.writeSync(fd, buf, off, buf.length - off);
        if (n <= 0) break;
        off += n;
    }
}

function _wfEncodingOf(options) {
    if (typeof options === 'string') return options;
    if (options && typeof options === 'object' && options.encoding != null) return options.encoding;
    return 'utf8';
}

// args = [fd, data, options?, callback] (callback already validated).
function _writeFileFdImpl(name, args) {
    var fd = args[0];
    var data = args[1];
    var callback = args[args.length - 1];
    var options = args.length > 3 ? args[2] : undefined;
    _scheduleNextTick(function () {
        try {
            _writeFileFdSync(fd, data, _wfEncodingOf(options));
            callback(null);
        } catch (e) {
            callback(e);
        }
    });
}

(function () {
    var _origWriteFileSync = nativeFs.writeFileSync;
    var _origAppendFileSync = nativeFs.appendFileSync;
    function _wrapSyncFileWriter(orig, isAppend) {
        return function (path, data, options) {
            if (typeof data !== 'string' && !ArrayBuffer.isView(data)) {
                throw _fsErrors.errInvalidArgType(
                    'data', 'string or an instance of Buffer, TypedArray, or DataView', data);
            }
            if (typeof path === 'number') {
                return _writeFileFdSync(path, data, _wfEncodingOf(options));
            }
            path = _fsPathArg(path);
            if (typeof options === 'string') {
                options = _fsVal.validateEncoding(options, 'encoding');
            } else if (options && typeof options === 'object' && options.encoding != null) {
                options.encoding = _fsVal.validateEncoding(options.encoding, 'encoding');
            }
            return orig.call(nativeFs, path, data, options);
        };
    }
    if (typeof _origWriteFileSync === 'function') {
        nativeFs.writeFileSync = _wrapSyncFileWriter(_origWriteFileSync, false);
    }
    if (typeof _origAppendFileSync === 'function') {
        nativeFs.appendFileSync = _wrapSyncFileWriter(_origAppendFileSync, true);
    }
})();

var _nativeUnlinkSync = nativeFs.unlinkSync;
nativeFs.unlinkSync = function(path) {
    path = _fsPathArg(path);
    if (!nativeFs.existsSync(path)) {
        var err = new Error("ENOENT: no such file or directory, unlink '" + path + "'");
        err.code = "ENOENT";
        err.path = path;
        err.syscall = "unlink";
        throw err;
    }
    return _nativeUnlinkSync(path);
};

// Dirent objects for readdir({ withFileTypes: true })
function Dirent(name, parentPath) {
    this.name = name;
    this.path = parentPath;
    var fullPath = parentPath + "/" + name;
    var st = nativeFs.lstatSync(fullPath);
    this._mode = st ? (st.mode || 0) : 0;
}
Dirent.prototype.isFile = function() { return (this._mode & 0xF000) === 0x8000; };
Dirent.prototype.isDirectory = function() { return (this._mode & 0xF000) === 0x4000; };
Dirent.prototype.isSymbolicLink = function() { return (this._mode & 0xF000) === 0xA000; };
Dirent.prototype.isFIFO = function() { return (this._mode & 0xF000) === 0x1000; };
Dirent.prototype.isSocket = function() { return (this._mode & 0xF000) === 0xC000; };
Dirent.prototype.isCharacterDevice = function() { return (this._mode & 0xF000) === 0x2000; };
Dirent.prototype.isBlockDevice = function() { return (this._mode & 0xF000) === 0x6000; };

var _nativeReaddirSync = nativeFs.readdirSync;
nativeFs.readdirSync = function(path, options) {
    path = _fsPathArg(path);
    var encoding = "utf8";
    var withFileTypes = false;
    if (typeof options === "string") {
        encoding = _fsVal.validateEncoding(options, "encoding");
        options = { encoding: encoding };
    } else if (options && typeof options === "object") {
        if (options.encoding != null) {
            encoding = _fsVal.validateEncoding(options.encoding, "encoding");
            options.encoding = encoding;
        }
        withFileTypes = !!options.withFileTypes;
    }
    var result = _nativeReaddirSync(path);
    if (result === undefined) {
        var err = new Error("ENOENT: no such file or directory, scandir '" + path + "'");
        err.code = "ENOENT";
        err.path = path;
        err.syscall = "scandir";
        throw err;
    }
    if (withFileTypes) {
        var dirents = [];
        for (var di = 0; di < result.length; di++) {
            dirents.push(new Dirent(result[di], path));
        }
        return dirents;
    }
    if (encoding === "buffer") {
        var bufs = [];
        for (var bi = 0; bi < result.length; bi++) {
            bufs.push(Buffer.from(String(result[bi])));
        }
        return bufs;
    }
    if (encoding === "utf16le") {
        var u16 = [];
        for (var ui = 0; ui < result.length; ui++) {
            u16.push(Buffer.from(String(result[ui]), "utf8").toString("utf16le"));
        }
        return u16;
    }
    return result;
};

// The callback form shares the sync form's option handling (withFileTypes,
// encoding); the native readdir only ever yields names.
var _nativeReaddirCb = nativeFs.readdir;
nativeFs.readdir = function(path, options, callback) {
    var opts = typeof options === "function" ? undefined : options;
    var cb = typeof options === "function" ? options : callback;
    var shaped = opts && typeof opts === "object" &&
                 (opts.withFileTypes || opts.encoding === "buffer");
    if (!shaped || typeof cb !== "function") {
        return _nativeReaddirCb.apply(this, arguments);
    }
    var dir = _fsPathArg(path);
    return _nativeReaddirCb.call(this, path, function(err, names) {
        if (err) { cb(err); return; }
        var out = [];
        for (var i = 0; i < names.length; i++) {
            out.push(opts.withFileTypes
                ? new Dirent(names[i], dir)
                : Buffer.from(String(names[i])));
        }
        cb(null, out);
    });
};

var _nativeMkdirSync = nativeFs.mkdirSync;
nativeFs.mkdirSync = function(path, options) {
    path = _fsPathArg(path);
    var recursive = false;
    if (options && typeof options === "object" && options.recursive) {
        recursive = true;
    }
    if (recursive) {
        var parts = path.split("/");
        var current = "";
        var firstCreated = undefined;
        var compIdx = -1;
        var lastComp = parts.length - 1;
        while (lastComp > 0 && !parts[lastComp]) lastComp--;  // trailing slash
        for (var mi = 0; mi < parts.length; mi++) {
            if (!parts[mi]) { if (mi === 0) current += "/"; continue; }
            compIdx = mi;
            current = (current === "/" || current === "") ? current + parts[mi]
                      : current + "/" + parts[mi];
            var st = nativeFs.statSync(current, { throwIfNoEntry: false });
            if (st) {
                if (!st.isDirectory()) {
                    // Node: a non-directory at the FINAL component is EEXIST;
                    // in the middle of the walk it is ENOTDIR.
                    var ndCode = (mi === lastComp) ? "EEXIST" : "ENOTDIR";
                    var ndMsg = ndCode === "EEXIST"
                        ? "EEXIST: file already exists, mkdir '" + current + "'"
                        : "ENOTDIR: not a directory, mkdir '" + current + "'";
                    throw _fsErrors.errnoException(ndCode, "mkdir", current, null, ndMsg);
                }
                continue;
            }
            try { _nativeMkdirSync(current); }
            catch (e) { if (e.code !== "EEXIST") throw e; }
            if (firstCreated === undefined) { firstCreated = current; }
        }
        return firstCreated;
    }
    // Non-recursive: an existing entry (dir or file) is EEXIST.
    var stEx = nativeFs.statSync(path, { throwIfNoEntry: false });
    if (stEx) {
        throw _fsErrors.errnoException(
            "EEXIST", "mkdir", path, null,
            "EEXIST: file already exists, mkdir '" + path + "'");
    }
    return _nativeMkdirSync(path, options);
};


// The native stat/lstat return undefined for EVERY failure, losing the errno.
// Recover the one distinguishable-from-JS case: paths exceeding NAME_MAX (255
// bytes/component) or PATH_MAX (4096) are ENAMETOOLONG, not ENOENT.
function _nameTooLong(path) {
    if (typeof path !== 'string') return false;
    if (path.length > 4096) return true;
    var parts = path.split('/');
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].length > 255) return true;
    }
    return false;
}

function _statMissingErr(syscall, path) {
    if (_nameTooLong(path)) {
        return _fsErrors.errnoException(
            "ENAMETOOLONG", syscall, path, null,
            "ENAMETOOLONG: name too long, " + syscall + " '" + path + "'");
    }
    return _fsErrors.errnoException(
        "ENOENT", syscall, path, null,
        "ENOENT: no such file or directory, " + syscall + " '" + path + "'");
}

// statSync/lstatSync: convert isFile/isDirectory/isSymbolicLink to methods
function _wrapStat(stat) {
    if (stat === undefined) return undefined;
    var _isFile    = stat.isFile;
    var _isDir     = stat.isDirectory;
    var _isSymlink = stat.isSymbolicLink;
    var _isBlk     = stat.isBlockDevice;
    var _isChr     = stat.isCharacterDevice;
    var _isFifo    = stat.isFIFO;
    var _isSock    = stat.isSocket;
    stat.isFile            = function() { return _isFile    === true; };
    stat.isDirectory       = function() { return _isDir     === true; };
    stat.isSymbolicLink    = function() { return _isSymlink === true; };
    stat.isBlockDevice     = function() { return _isBlk     === true; };
    stat.isCharacterDevice = function() { return _isChr     === true; };
    stat.isFIFO            = function() { return _isFifo    === true; };
    stat.isSocket          = function() { return _isSock    === true; };
    // Convert ms timestamps to Date objects
    if (typeof stat.mtimeMs === 'number') {
        stat.atime     = new Date(stat.atimeMs);
        stat.mtime     = new Date(stat.mtimeMs);
        stat.ctime     = new Date(stat.ctimeMs);
        stat.birthtime = new Date(stat.birthtimeMs);
    }
    return stat;
}

var _nativeStatSync = nativeFs.statSync;
nativeFs.statSync = function(path, options) {
    path = _fsPathArg(path);
    var throwIfNoEntry = !options || options.throwIfNoEntry !== false;
    var result = _nativeStatSync(path);
    if (result === undefined || result === null) {
        if (!throwIfNoEntry) return undefined;
        throw _statMissingErr("stat", path);
    }
    return _wrapStat(result);
};

var _nativeRmSync = nativeFs.rmSync;
// Capture natives BEFORE wrapping — recursive rm must not call through wrappers
// that may be re-entered if fs.js is evaluated more than once on the same object.
var _nativeLstatSync = nativeFs.lstatSync;
var _nativeRmdirSyncRaw = nativeFs.rmdirSync;
function _rmRecursive(p, _seen) {
    // Use lstat so symlink-to-directory is unlinked, not walked (avoids cycles).
    var st;
    try { st = _wrapStat(_nativeLstatSync(p)); } catch (e) {
        if (e && e.code === "ENOENT") return;
        throw e;
    }
    if (!st) return;
    if (typeof st.isSymbolicLink === "function" ? st.isSymbolicLink() : st.isSymbolicLink) {
        _nativeUnlinkSync(p);
        return;
    }
    if (typeof st.isDirectory === "function" ? st.isDirectory() : st.isDirectory) {
        if (!_seen) _seen = Object.create(null);
        var key = String(st.dev) + ":" + String(st.ino);
        if (_seen[key]) return;
        _seen[key] = true;
        var entries = _nativeReaddirSync(p);
        if (!entries) {
            // Native returns undefined on error; try rmdir anyway.
            try { _nativeRmdirSyncRaw(p); } catch (_) {}
            return;
        }
        for (var ri = 0; ri < entries.length; ri++) {
            var name = entries[ri];
            if (name === "." || name === "..") continue;
            _rmRecursive(p + "/" + name, _seen);
        }
        _nativeRmdirSyncRaw(p);
    } else {
        _nativeUnlinkSync(p);
    }
}
nativeFs.rmSync = function(path, options) {
    path = _fsPathArg(path);
    var force = options && options.force;
    var recursive = options && options.recursive;
    // Node: rm on a directory without recursive is SystemError ERR_FS_EISDIR.
    if (!recursive) {
        var stDir = null;
        try { stDir = _wrapStat(_nativeLstatSync(path)); } catch (_eD) {}
        if (stDir && stDir.isDirectory()) {
            var eIs = new Error(
                "Path is a directory: rm returned EISDIR (is a directory) " + path);
            eIs.code = "ERR_FS_EISDIR";
            eIs.info = { code: "EISDIR", message: "is a directory", path: path,
                         syscall: "rm", errno: -21 };
            eIs.syscall = "rm";
            throw eIs;
        }
    }
    try {
        if (recursive) { _rmRecursive(path); }
        else { _nativeRmSync(path); }
    } catch (e) {
        if (force && e.code === "ENOENT") return;
        throw e;
    }
};

// fs.rmdir(path, { recursive: true }) — deprecated (DEP0147) but still
// functional: ENOENT for a missing path, ENOTDIR for a file, else rm -rf.
var _rmdirRecursiveWarned = false;
function _rmdirRecursiveDeprecate() {
    if (_rmdirRecursiveWarned) return;
    _rmdirRecursiveWarned = true;
    if (typeof process !== "undefined" && typeof process.emitWarning === "function") {
        process.emitWarning(
            "In future versions of Node.js, fs.rmdir(path, { recursive: true }) " +
            "will be removed. Use fs.rm(path, { recursive: true }) instead",
            "DeprecationWarning", "DEP0147");
    }
}

function _rmdirRecursiveSyncImpl(path) {
    _rmdirRecursiveDeprecate();
    var st = null;
    try { st = _wrapStat(_nativeLstatSync(path)); } catch (_eR) {}
    if (!st) {
        throw _fsErrors.errnoException(
            "ENOENT", "rmdir", path, null,
            "ENOENT: no such file or directory, rmdir '" + path + "'");
    }
    if (!st.isDirectory()) {
        throw _fsErrors.errnoException(
            "ENOTDIR", "rmdir", path, null,
            "ENOTDIR: not a directory, rmdir '" + path + "'");
    }
    _rmRecursive(path);
}

(function () {
    var _wrappedRmdirSync = nativeFs.rmdirSync;
    nativeFs.rmdirSync = function (path, options) {
        if (options && typeof options === "object" && options.recursive) {
            return _rmdirRecursiveSyncImpl(_fsPathArg(path));
        }
        return _wrappedRmdirSync.call(nativeFs, path);
    };
    var _wrappedRmdir = nativeFs.rmdir;
    nativeFs.rmdir = function (path, options, callback) {
        if (typeof options === "function") { callback = options; options = undefined; }
        if (options && typeof options === "object" && options.recursive) {
            callback = _requireCb(callback);
            var rp = _fsPathArg(path);
            _scheduleNextTick(function () {
                try { _rmdirRecursiveSyncImpl(rp); callback(null); }
                catch (e) { callback(e); }
            });
            return;
        }
        return _wrappedRmdir.call(nativeFs, path, callback);
    };
})();

var _nativeStat = nativeFs.stat;
nativeFs.stat = function(path, options, callback) {
    if (typeof options === 'function') { callback = options; options = {}; }
    _nativeStat(_fsPathArg(path), function(err, result) {
        if (err) { callback(_asFsError(err)); } else { callback(null, _wrapStat(result)); }
    });
};

nativeFs.lstatSync = function(path, options) {
    path = _fsPathArg(path);
    var throwIfNoEntry = !options || options.throwIfNoEntry !== false;
    var result = _nativeLstatSync(path);
    if (result === undefined || result === null) {
        if (!throwIfNoEntry) return undefined;
        throw _statMissingErr("lstat", path);
    }
    return _wrapStat(result);
};

var _nativeLstat = nativeFs.lstat;
nativeFs.lstat = function(path, options, callback) {
    if (typeof options === 'function') { callback = options; options = {}; }
    var lp = _fsPathArg(path);
    _nativeLstat(lp, function(err, result) {
        if (err) { callback(_asFsError(err)); return; }
        if (result === undefined || result === null) {
            callback(_fsErrors.errnoException(
                "ENOENT", "lstat", lp, null,
                "ENOENT: no such file or directory, lstat '" + lp + "'"));
            return;
        }
        callback(null, _wrapStat(result));
    });
};

// ── fs.promises ──────────────────────────────────────────────────────────────

var promises = {};

promises.readFile = function(path, options) {
    return new Promise(function(resolve, reject) {
        try {
            var result = nativeFs.readFileSync(path, options);
            if (result === undefined) {
                var err = new Error("ENOENT: no such file or directory, open '" + path + "'");
                err.code = "ENOENT";
                err.path = path;
                reject(err);
            } else {
                resolve(result);
            }
        } catch (e) {
            reject(e);
        }
    });
};

promises.writeFile = function(path, data, options) {
    // FileHandle dispatch (Node: fs.promises.writeFile(handle, data, opts))
    if (path && typeof path === 'object' && typeof path.writeFile === 'function' && typeof path.fd === 'number') {
        return path.writeFile(data, options);
    }
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.writeFileSync(path, data, options);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.appendFile = function(path, data) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.appendFileSync(path, data);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.stat = function(path) {
    return new Promise(function(resolve, reject) {
        var result = nativeFs.statSync(path);
        if (result === undefined) {
            var err = new Error("ENOENT: no such file or directory, stat '" + path + "'");
            err.code = "ENOENT";
            reject(err);
        } else {
            resolve(result);
        }
    });
};

promises.lstat = function(path) {
    return new Promise(function(resolve, reject) {
        var result = nativeFs.lstatSync(path);
        if (result === undefined) {
            var err = new Error("ENOENT: no such file or directory, lstat '" + path + "'");
            err.code = "ENOENT";
            reject(err);
        } else {
            resolve(result);
        }
    });
};

promises.unlink = function(path) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.unlinkSync(path);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.readdir = function(path, options) {
    return new Promise(function(resolve, reject) {
        try {
            var result = nativeFs.readdirSync(path, options);
            resolve(result);
        } catch (e) {
            reject(e);
        }
    });
};

promises.mkdir = function(path, options) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.mkdirSync(path, options);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.rmdir = function(path) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.rmdirSync(path);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.rename = function(oldPath, newPath) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.renameSync(oldPath, newPath);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.copyFile = function(src, dest) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.copyFileSync(src, dest);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.chmod = function(path, mode) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.chmodSync(path, mode);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.access = function(path, mode) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.accessSync(path, mode);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.mkdtemp = function(prefix, options) {
    return new Promise(function(resolve, reject) {
        try {
            var result = nativeFs.mkdtempSync(prefix, options);
            resolve(result === undefined ? prefix + 'XXXXXX' : result);
        } catch (e) {
            reject(e);
        }
    });
};

promises.rm = function(path, options) {
    return new Promise(function(resolve, reject) {
        try {
            nativeFs.rmSync(path, options);
            resolve(undefined);
        } catch (e) {
            reject(e);
        }
    });
};

promises.realpath = function(path, options) {
    return new Promise(function(resolve, reject) {
        try {
            var result = nativeFs.realpathSync(path, options);
            if (result === undefined) {
                var err = new Error("ENOENT: no such file or directory, realpath '" + path + "'");
                err.code = "ENOENT";
                reject(err);
            } else {
                resolve(result);
            }
        } catch (e) {
            reject(e);
        }
    });
};

function _makeFileHandle(fd) {
    return _fhMod.makeFileHandle(fd, nativeFs, _streamClasses);
}

promises.open = function(path, flags, mode) {
    return new Promise(function(resolve, reject) {
        try {
            var fd = nativeFs.openSync(
                _fsPathArg(path),
                flags !== undefined ? flags : 'r',
                mode !== undefined ? mode : 438
            );
            resolve(_makeFileHandle(fd));
        } catch (e) {
            reject(e);
        }
    });
};

promises.close = function(fd) {
    return new Promise(function(resolve) {
        nativeFs.closeSync(fd);
        resolve(undefined);
    });
};

nativeFs.promises = promises;

// ── fs.constants (Node v24 Linux values) ─────────────────────────────────────
var FS_CONSTANTS = Object.create(null);
FS_CONSTANTS.F_OK = 0; FS_CONSTANTS.R_OK = 4; FS_CONSTANTS.W_OK = 2; FS_CONSTANTS.X_OK = 1;
FS_CONSTANTS.COPYFILE_EXCL = 1; FS_CONSTANTS.COPYFILE_FICLONE = 2; FS_CONSTANTS.COPYFILE_FICLONE_FORCE = 4;
FS_CONSTANTS.O_RDONLY = 0; FS_CONSTANTS.O_WRONLY = 1; FS_CONSTANTS.O_RDWR = 2;
FS_CONSTANTS.O_CREAT = 64; FS_CONSTANTS.O_EXCL = 128; FS_CONSTANTS.O_NOCTTY = 256;
FS_CONSTANTS.O_TRUNC = 512; FS_CONSTANTS.O_APPEND = 1024; FS_CONSTANTS.O_DIRECTORY = 65536;
FS_CONSTANTS.O_NOATIME = 262144; FS_CONSTANTS.O_NOFOLLOW = 131072;
FS_CONSTANTS.O_SYNC = 1052672; FS_CONSTANTS.O_DSYNC = 4096;
FS_CONSTANTS.O_DIRECT = 16384; FS_CONSTANTS.O_NONBLOCK = 2048;
FS_CONSTANTS.S_IFMT = 61440; FS_CONSTANTS.S_IFREG = 32768; FS_CONSTANTS.S_IFDIR = 16384;
FS_CONSTANTS.S_IFCHR = 8192; FS_CONSTANTS.S_IFBLK = 24576; FS_CONSTANTS.S_IFIFO = 4096;
FS_CONSTANTS.S_IFLNK = 40960; FS_CONSTANTS.S_IFSOCK = 49152;
FS_CONSTANTS.S_IRWXU = 448; FS_CONSTANTS.S_IRUSR = 256; FS_CONSTANTS.S_IWUSR = 128;
FS_CONSTANTS.S_IXUSR = 64; FS_CONSTANTS.S_IRWXG = 56; FS_CONSTANTS.S_IRGRP = 32;
FS_CONSTANTS.S_IWGRP = 16; FS_CONSTANTS.S_IXGRP = 8; FS_CONSTANTS.S_IRWXO = 7;
FS_CONSTANTS.S_IROTH = 4; FS_CONSTANTS.S_IWOTH = 2; FS_CONSTANTS.S_IXOTH = 1;
FS_CONSTANTS.UV_FS_SYMLINK_DIR = 1; FS_CONSTANTS.UV_FS_SYMLINK_JUNCTION = 2;
FS_CONSTANTS.UV_DIRENT_UNKNOWN = 0; FS_CONSTANTS.UV_DIRENT_FILE = 1;
FS_CONSTANTS.UV_DIRENT_DIR = 2; FS_CONSTANTS.UV_DIRENT_LINK = 3;
FS_CONSTANTS.UV_DIRENT_FIFO = 4; FS_CONSTANTS.UV_DIRENT_SOCKET = 5;
FS_CONSTANTS.UV_DIRENT_CHAR = 6; FS_CONSTANTS.UV_DIRENT_BLOCK = 7;
nativeFs.constants = FS_CONSTANTS;
promises.constants = FS_CONSTANTS;
nativeFs.Dirent = Dirent;

// Deprecated fs.F_OK / R_OK / W_OK / X_OK (DEP0176) — non-writable accessors.
(function() {
    var _accessKeys = ['F_OK', 'R_OK', 'W_OK', 'X_OK'];
    for (var ai = 0; ai < _accessKeys.length; ai++) {
        (function(key) {
            var warned = false;
            Object.defineProperty(nativeFs, key, {
                configurable: true,
                enumerable: true,
                get: function() {
                    if (!warned && typeof process !== 'undefined' && process.emitWarning) {
                        warned = true;
                        process.emitWarning(
                            'fs.' + key + ' is deprecated, use fs.constants.' + key + ' instead',
                            'DeprecationWarning',
                            'DEP0176'
                        );
                    }
                    return FS_CONSTANTS[key];
                },
                set: function() {
                    throw new TypeError('Cannot set property ' + key + ' of #<Object> which has only a getter');
                }
            });
        })(_accessKeys[ai]);
    }
})();

// ── fs.watch / fs.watchFile / fs.unwatchFile / fs.promises.watch ─────────────
var EventEmitter = require("events").EventEmitter;
var _watchersById = {};
var _watchBridgeInstalled = false;

function FSWatcher() {
    EventEmitter.init.call(this);
    this._listener = undefined;
    this._encoding = "utf8";
    this._closed = false;
    this._ignore = undefined;
    this._watchId = undefined;
    this._nativeHandle = undefined;
}
FSWatcher.prototype = Object.create(EventEmitter.prototype);
FSWatcher.prototype.constructor = FSWatcher;

function _scheduleNextTick(fn) {
    if (typeof process !== "undefined" && typeof process.nextTick === "function") {
        process.nextTick(fn);
    } else {
        setTimeout(fn, 0);
    }
}

FSWatcher.prototype.close = function () {
    if (this._closed) { return this; }
    this._closed = true;
    var wid = this._watchId;
    var self = this;
    if (this._childWatchers) {
        for (var cwi = 0; cwi < this._childWatchers.length; cwi = cwi + 1) {
            try { this._childWatchers[cwi].close(); } catch (_cw) { /* ignore */ }
        }
        this._childWatchers = [];
    }
    this._watchedDirs = undefined;
    if (this._abortListener && this._abortSignal) {
        try {
            this._abortSignal.removeEventListener("abort", this._abortListener);
        } catch (_e) { /* ignore */ }
        this._abortListener = undefined;
        this._abortSignal = undefined;
    }
    if (this._nativeHandle) {
        try {
            nativeFs.__jacWatchClose.call(this._nativeHandle);
        } catch (_closeErr) { /* ignore double-close / teardown races */ }
        this._nativeHandle = undefined;
    }
    this._listener = undefined;
    if (wid !== undefined) {
        delete _watchersById[wid];
    }
    this._watchId = undefined;
    _scheduleNextTick(function () {
        self.emit("close");
    });
    return this;
};

FSWatcher.prototype.ref = function () {
    if (!this._closed && this._nativeHandle) {
        nativeFs.__jacWatchRef.call(this._nativeHandle);
    }
    return this;
};

FSWatcher.prototype.unref = function () {
    if (!this._closed && this._nativeHandle) {
        nativeFs.__jacWatchUnref.call(this._nativeHandle);
    }
    return this;
};

function StatWatcher() {
    EventEmitter.init.call(this);
    this._timerHandle = undefined;
}
StatWatcher.prototype = Object.create(EventEmitter.prototype);
StatWatcher.prototype.constructor = StatWatcher;

StatWatcher.prototype.ref = function () {
    if (this._timerHandle && typeof this._timerHandle.ref === "function") {
        this._timerHandle.ref();
    }
    return this;
};

StatWatcher.prototype.unref = function () {
    if (this._timerHandle && typeof this._timerHandle.unref === "function") {
        this._timerHandle.unref();
    }
    return this;
};

StatWatcher.prototype.stop = function () {
    if (this._path && _watchFileState[this._path]) {
        nativeFs.unwatchFile(this._path);
    }
};

function _watchErrFromNative(obj) {
    if (!obj) { return new Error("Unknown watch error"); }
    if (obj instanceof Error) { return obj; }
    var msg = obj.message || obj.code || "watch error";
    var err = new Error(msg);
    if (obj.code) { err.code = obj.code; }
    if (obj.errno !== undefined) { err.errno = obj.errno; }
    if (obj.syscall) { err.syscall = obj.syscall; }
    if (obj.path) { err.path = obj.path; }
    return err;
}

function _installWatchBridge() {
    if (_watchBridgeInstalled) { return; }
    _watchBridgeInstalled = true;
    globalThis.__jacFsWatchBridge = function (id, event, a1, a2) {
        var w = _watchersById[id];
        if (!w) { return; }
        if (w._closed && event !== "close") { return; }
        if (event === "change") {
            var evType = a1;
            var fn = a2;
            if (fn === undefined || fn === null) {
                fn = undefined;
            } else if (typeof fn === "string" && globalThis.Buffer) {
                if (w._encoding === "buffer") {
                    fn = globalThis.Buffer.from(fn);
                } else if (w._encoding && w._encoding !== "utf8" && w._encoding !== "utf-8") {
                    // Re-encode filename into the requested Buffer encoding
                    try {
                        fn = globalThis.Buffer.from(fn, "utf8").toString(w._encoding);
                    } catch (_encErr) { /* keep utf8 string */ }
                }
            }
            w._dispatchWatchEvent(evType, fn);
        } else if (event === "error") {
            w.emit("error", _watchErrFromNative(a1));
        } else if (event === "close") {
            if (!w._closed) {
                w._closed = true;
                delete _watchersById[id];
                w.emit("close");
            }
        }
    };
}

FSWatcher.prototype._dispatchWatchEvent = function (eventType, filename) {
    if (this._closed) { return; }
    if (filename !== undefined && filename !== null) {
        var nm = typeof filename === "string" ? filename : String(filename);
        if (_shouldIgnore(this._ignore, nm)) { return; }
    }
    this.emit("change", eventType, filename);
    if (typeof this._listener === "function") {
        this._listener(eventType, filename);
    }
    if (this._asyncQueue) {
        for (var qi = 0; qi < this._asyncQueue.length; qi = qi + 1) {
            this._asyncQueue[qi]({ eventType: eventType, filename: filename });
        }
        this._asyncQueue = [];
    }
    if (this._asyncWaiters && this._asyncWaiters.length > 0) {
        var waiter = this._asyncWaiters.shift();
        waiter({ eventType: eventType, filename: filename });
    }
};

function _parseWatchArgs(filename, options, listener) {
    var opts = { persistent: true, recursive: false, encoding: "utf8", signal: undefined, ignore: undefined };
    var cb = listener;
    if (typeof options === "function") { cb = options; options = null; }
    else if (typeof options === "string") { opts.encoding = options; options = null; }
    else if (options && typeof options === "object") {
        if (options.persistent !== undefined) { opts.persistent = !!options.persistent; }
        if (options.recursive !== undefined) { opts.recursive = !!options.recursive; }
        if (options.encoding !== undefined) { opts.encoding = options.encoding; }
        if (options.signal !== undefined) { opts.signal = options.signal; }
        if (options.ignore !== undefined) {
            var ig = options.ignore;
            var okIgnore = typeof ig === "function" || ig instanceof RegExp || typeof ig === "string" ||
                (ig && typeof ig === "object" && typeof ig.length === "number");
            if (!okIgnore) {
                throw _fsErrors.errInvalidArgType("options.ignore", "string or RegExp or Function or Array", ig);
            }
            _validateWatchIgnore(ig);
            opts.ignore = ig;
        }
    }
    return { path: _fsPathArg(filename), opts: opts, listener: cb };
}

function _validateWatchIgnore(ignore) {
    if (ignore === undefined || ignore === null) { return; }
    function checkOne(v, name) {
        if (typeof v === "string") {
            if (v === "") { throw _fsErrors.errInvalidArgValue(name, v); }
            return;
        }
        if (v instanceof RegExp) { return; }
        if (typeof v === "function") { return; }  // predicate ignores are allowed
        throw _fsErrors.errInvalidArgType(name, "string or an instance of RegExp", v);
    }
    if (Array.isArray(ignore)) {
        for (var vi = 0; vi < ignore.length; vi++) {
            checkOne(ignore[vi], "options.ignore[" + vi + "]");
        }
        return;
    }
    checkOne(ignore, "options.ignore");
}

function _looksLikeGlobPattern(pattern) {
    return typeof pattern === "string" && /[*?]/.test(pattern);
}

function _globToRegExp(pattern) {
    // Minimal glob → RegExp for watch ignore (supports *, **, ?, and path seps).
    var s = String(pattern);
    var out = "^";
    var i = 0;
    while (i < s.length) {
        var c = s.charAt(i);
        if (c === "*" && s.charAt(i + 1) === "*") {
            out += ".*";
            i += 2;
            if (s.charAt(i) === "/") i += 1;
            continue;
        }
        if (c === "*") { out += "[^/]*"; i += 1; continue; }
        if (c === "?") { out += "[^/]"; i += 1; continue; }
        if ("+.^${}()|[]\\".indexOf(c) >= 0) out += "\\" + c;
        else out += c;
        i += 1;
    }
    out += "$";
    return new RegExp(out);
}

function _shouldIgnore(ignore, name) {
    if (ignore === undefined || ignore === null) { return false; }
    if (typeof ignore === "function") {
        try { return !!ignore(name); } catch (_e) { return false; }
    }
    if (ignore && typeof ignore.test === "function" &&
        (ignore instanceof RegExp || Object.prototype.toString.call(ignore) === "[object RegExp]")) {
        try { return !!ignore.test(name); } catch (_e2) { return false; }
    }
    if (typeof ignore === "string") {
        if (_looksLikeGlobPattern(ignore)) {
            try { return _globToRegExp(ignore).test(name); } catch (_globE) { return false; }
        }
        if (ignore === name) return true;
        if (name.indexOf(ignore) >= 0) return true;
        if (ignore.length > 1 && ignore.charAt(0) === "*" && ignore.charAt(1) === ".") {
            var suf = ignore.slice(1);
            return name.length >= suf.length && name.slice(name.length - suf.length) === suf;
        }
        return false;
    }
    if (ignore && typeof ignore.length === "number") {
        var i = 0;
        while (i < ignore.length) {
            if (_shouldIgnore(ignore[i], name)) { return true; }
            i = i + 1;
        }
    }
    return false;
}

function _startRecursivePolyfill(watcher, rootPath, opts) {
    if (!opts.recursive) { return; }
    watcher._childWatchers = watcher._childWatchers || [];
    watcher._watchedDirs = watcher._watchedDirs || {};
    var rootResolved = nodePath.resolve(rootPath);

    function watchDir(dirPath) {
        if (watcher._closed) { return; }
        var key = nodePath.resolve(dirPath);
        if (watcher._watchedDirs[key]) { return; }
        watcher._watchedDirs[key] = true;
        try {
            var child = _createFsWatcher(key, { persistent: opts.persistent, recursive: false },
                function (ev, fn) {
                    if (watcher._closed) { return; }
                    var reported = fn;
                    if (reported !== undefined && reported !== null) {
                        reported = nodePath.join(nodePath.relative(rootResolved, key), String(reported));
                        reported = reported.split(nodePath.sep).join("/");
                    }
                    watcher._dispatchWatchEvent(ev, reported);
                    if (ev === "rename" && fn !== undefined && fn !== null) {
                        try {
                            var full = nodePath.join(key, String(fn));
                            if (nativeFs.existsSync(full)) {
                                var st = nativeFs.lstatSync(full);
                                if (st && typeof st.isDirectory === "function" && st.isDirectory() &&
                                    !(typeof st.isSymbolicLink === "function" && st.isSymbolicLink())) {
                                    watchDir(full);
                                }
                            }
                        } catch (_ne) { /* ignore */ }
                    }
                }, true);
            watcher._childWatchers.push(child);
        } catch (_we) { /* ignore */ }

        try {
            var entries = nativeFs.readdirSync(key);
            var ei = 0;
            while (ei < entries.length) {
                var sub = nodePath.join(key, entries[ei]);
                try {
                    var st2 = nativeFs.lstatSync(sub);
                    if (st2 && typeof st2.isDirectory === "function" && st2.isDirectory() &&
                        !(typeof st2.isSymbolicLink === "function" && st2.isSymbolicLink())) {
                        watchDir(sub);
                    }
                } catch (_se) { /* ignore */ }
                ei = ei + 1;
            }
        } catch (_re) { /* ignore */ }
    }

    try {
        var rootSt = nativeFs.lstatSync(rootResolved);
        if (rootSt && typeof rootSt.isDirectory === "function" && rootSt.isDirectory()) {
            watchDir(rootResolved);
        }
    } catch (_rs) { /* ignore */ }
}

function _watchAbortError(signal) {
    var err;
    if (signal && signal.reason instanceof Error) {
        err = signal.reason;
    } else {
        err = new Error("The operation was aborted");
    }
    err.name = "AbortError";
    return err;
}

function _createFsWatcher(filename, options, listener, skipRecursivePolyfill) {
    _installWatchBridge();
    var parsed = _parseWatchArgs(filename, options, listener);
    var enc = parsed.opts.encoding;
    if (enc === undefined || enc === null) { enc = "utf8"; }
    if (typeof enc !== "string") {
        throw new TypeError(
            'The "options.encoding" property must be of type string. Received type ' + typeof enc
        );
    }
    // Same encoding allow-list as readFile/etc (assert-encoding-error).
    enc = _fsVal.validateEncoding(enc, "encoding");
    parsed.opts.encoding = enc;

    var watcher = new FSWatcher();
    watcher._listener = parsed.listener;
    watcher._encoding = enc;
    watcher._ignore = parsed.opts.ignore;

    var nativeHandle = nativeFs.__jacWatchStart(
        parsed.path,
        globalThis.__jacFsWatchBridge,
        parsed.opts.recursive ? true : false,
        parsed.opts.persistent ? true : false
    );
    if (!nativeHandle) {
        throw new Error("watch failed for " + parsed.path);
    }
    if (nativeHandle._watchError) {
        throw _watchErrFromNative(nativeHandle._watchError);
    }
    if (nativeHandle._watchId === undefined) {
        var fail = new Error("watch failed for " + parsed.path);
        fail.code = "ENOENT";
        fail.syscall = "watch";
        fail.path = parsed.path;
        throw fail;
    }
    _watchersById[nativeHandle._watchId] = watcher;
    watcher._watchId = nativeHandle._watchId;
    watcher._nativeHandle = nativeHandle;

    if (parsed.opts.signal) {
        if (parsed.opts.signal.aborted) {
            _scheduleNextTick(function () { watcher.close(); });
        } else if (typeof parsed.opts.signal.addEventListener === "function") {
            watcher._abortSignal = parsed.opts.signal;
            watcher._abortListener = function () { watcher.close(); };
            parsed.opts.signal.addEventListener("abort", watcher._abortListener);
        }
    }
    if (!skipRecursivePolyfill) {
        _startRecursivePolyfill(watcher, parsed.path, parsed.opts);
    }
    return watcher;
}

nativeFs.watch = function (filename, options, listener) {
    return _createFsWatcher(filename, options, listener, false);
};

var _watchFileState = {};

function _zeroStats(bigint) {
    var z = (bigint && typeof BigInt === "function") ? BigInt(0) : 0;
    return {
        dev: z, ino: z, mode: z, nlink: z, uid: z, gid: z, rdev: z,
        size: z, blksize: z, blocks: z,
        atimeMs: z, mtimeMs: z, ctimeMs: z, birthtimeMs: z,
        atime: new Date(0), mtime: new Date(0), ctime: new Date(0), birthtime: new Date(0),
        isFile: function () { return false; },
        isDirectory: function () { return false; },
        isSymbolicLink: function () { return false; }
    };
}

function _statsAsBigint(st) {
    if (!st || typeof BigInt !== "function") { return st; }
    var out = {};
    var keys = ["dev", "ino", "mode", "nlink", "uid", "gid", "rdev", "size", "blksize", "blocks",
        "atimeMs", "mtimeMs", "ctimeMs", "birthtimeMs"];
    var ki = 0;
    while (ki < keys.length) {
        var k = keys[ki];
        var kv = st[k] === undefined || st[k] === null ? 0 : st[k];
        // BigInt() rejects non-integers, and the *Ms times carry sub-millisecond
        // fractions: Node's bigint stats hold whole milliseconds there (the
        // fraction lives in *Ns). This threw for every real file, which
        // watchFile's tick() then misreported as "file missing".
        out[k] = BigInt(typeof kv === "number" ? Math.trunc(kv) : kv);
        ki = ki + 1;
    }
    out.atime = st.atime;
    out.mtime = st.mtime;
    out.ctime = st.ctime;
    out.birthtime = st.birthtime;
    out.isFile = st.isFile;
    out.isDirectory = st.isDirectory;
    out.isSymbolicLink = st.isSymbolicLink;
    return out;
}

function _enhanceStats(st, bigint) {
    if (!st) { return _zeroStats(bigint); }
    if (typeof st.isFile !== "function") {
        var isF = st.isFile; var isD = st.isDirectory; var isL = st.isSymbolicLink;
        st.isFile = function () { return !!isF; };
        st.isDirectory = function () { return !!isD; };
        st.isSymbolicLink = function () { return !!isL; };
    }
    if (st.mtimeMs === undefined && st.mtime !== undefined) { st.mtimeMs = st.mtime; }
    if (bigint) { return _statsAsBigint(st); }
    return st;
}

function _statKey(st) {
    if (!st) { return "0:0:0"; }
    return String(st.mtimeMs || 0) + ":" + String(st.size || 0) + ":" + String(st.mode || 0);
}

nativeFs.watchFile = function (filename, options, listener) {
    var path = _fsPathArg(filename);
    var opts = { persistent: true, interval: 5007, bigint: false };
    var cb = listener;
    if (typeof options === "function") { cb = options; options = null; }
    else if (options && typeof options === "object") {
        if (options.persistent !== undefined) { opts.persistent = !!options.persistent; }
        if (options.interval !== undefined) { opts.interval = +options.interval; }
        if (options.bigint !== undefined) { opts.bigint = !!options.bigint; }
    }
    if (typeof cb !== "function") { throw _fsErrors.errInvalidArgType("listener", "function", cb); }
    if (!(opts.interval > 0)) { throw new RangeError("interval must be > 0"); }

    if (!_watchFileState[path]) {
        _watchFileState[path] = {
            listeners: [],
            timerHandle: undefined,
            prev: _zeroStats(opts.bigint),
            interval: opts.interval,
            bigint: opts.bigint,
            enoentEmitted: false,
            watcher: undefined
        };
    }
    var state = _watchFileState[path];
    state.bigint = opts.bigint;
    state.interval = opts.interval;
    state.listeners.push(cb);
    if (state.timerHandle) { clearInterval(state.timerHandle); }

    if (!state.watcher) {
        state.watcher = new StatWatcher();
        state.watcher._path = path;
    }

    var tick = function () {
        var curr;
        var missing = false;
        try {
            var rawStat = nativeFs.statSync(path);
            if (rawStat === undefined || rawStat === null) {
                missing = true;
                curr = _zeroStats(state.bigint);
            } else {
                curr = _enhanceStats(rawStat, state.bigint);
            }
        } catch (e) {
            missing = true;
            curr = _zeroStats(state.bigint);
        }
        var prev = state.prev;
        var changed = _statKey(curr) !== _statKey(prev);
        if (missing) {
            if (!state.enoentEmitted) {
                var li0 = 0;
                while (li0 < state.listeners.length) {
                    state.listeners[li0](curr, prev);
                    li0 = li0 + 1;
                }
                state.prev = curr;
                state.enoentEmitted = true;
            }
            return;
        }
        if (state.enoentEmitted) { state.enoentEmitted = false; }
        if (changed) {
            var li = 0;
            while (li < state.listeners.length) {
                state.listeners[li](curr, prev);
                li = li + 1;
            }
            state.prev = curr;
        }
    };
    state.timerHandle = setInterval(tick, state.interval);
    state.watcher._timerHandle = state.timerHandle;
    if (!opts.persistent && typeof state.timerHandle.unref === "function") {
        state.timerHandle.unref();
    }
    // Record the baseline instead of running tick() synchronously. Node never
    // calls a watchFile listener from inside watchFile(): it fires on the first
    // change a later poll sees (or once, asynchronously, with zeroed stats for
    // a file missing at start). The synchronous tick compared the real stat
    // against the zeroed initial `prev`, so every existing file "changed" and
    // the listener ran before watchFile() returned — chokidar (Vite's dev
    // watcher when server.watch.usePolling is set, as jac's dev config does)
    // builds the object its listener reads around the watchFile() call, and
    // crashed on `cont.rawEmitters` of undefined.
    if (!state.primed) {
        state.primed = true;
        var base = null;
        try {
            var raw0 = nativeFs.statSync(path);
            if (raw0 !== undefined && raw0 !== null) { base = _enhanceStats(raw0, state.bigint); }
        } catch (e0) { base = null; }
        if (base !== null) {
            state.prev = base;
        } else {
            setTimeout(tick, 0);
        }
    }
    return state.watcher;
};

nativeFs.unwatchFile = function (filename, listener) {
    var path = _fsPathArg(filename);
    var state = _watchFileState[path];
    if (!state) { return; }
    if (typeof listener === "function") {
        var out = [];
        var i = 0;
        while (i < state.listeners.length) {
            if (state.listeners[i] !== listener) { out.push(state.listeners[i]); }
            i = i + 1;
        }
        state.listeners = out;
        if (state.listeners.length === 0) {
            if (state.timerHandle) { clearInterval(state.timerHandle); }
            delete _watchFileState[path];
        }
    } else {
        if (state.timerHandle) { clearInterval(state.timerHandle); }
        delete _watchFileState[path];
    }
};

function _createPromisesWatchIterable(filename, options) {
    var parsed = _parseWatchArgs(filename, options, undefined);
    var closed = false;
    var queue = [];
    var waiters = [];
    var watcher;
    var failErr = null;

    function rejectAll(err) {
        if (closed) { return; }
        closed = true;
        failErr = err;
        if (watcher) {
            try { watcher.close(); } catch (_wc) { /* ignore */ }
            watcher = null;
        }
        while (waiters.length > 0) {
            var w = waiters.shift();
            if (w.reject) { w.reject(err); }
        }
    }

    function pushEvent(ev) {
        if (closed) { return; }
        if (waiters.length > 0) {
            var waiter = waiters.shift();
            if (waiter.resolve) { waiter.resolve(ev); }
        } else {
            queue.push(ev);
        }
    }

    try {
        var watchOpts = {
            persistent: parsed.opts.persistent,
            recursive: parsed.opts.recursive,
            encoding: parsed.opts.encoding,
            ignore: parsed.opts.ignore
        };
        watcher = nativeFs.watch(parsed.path, watchOpts, function (eventType, fn) {
            pushEvent({ eventType: eventType, filename: fn });
        });
    } catch (watchErr) {
        watcher = null;
        failErr = watchErr;
    }

    function resolveWaitersDone() {
        while (waiters.length > 0) {
            var w = waiters.shift();
            if (w.resolve) { w.resolve({ __done: true }); }
        }
    }

    function closeAll() {
        if (closed) { return; }
        closed = true;
        if (watcher) {
            try { watcher.close(); } catch (_c) { /* ignore */ }
            watcher = null;
        }
        if (!failErr) {
            resolveWaitersDone();
        }
    }

    if (parsed.opts.signal) {
        if (parsed.opts.signal.aborted) {
            failErr = _watchAbortError(parsed.opts.signal);
            closeAll();
        } else if (typeof parsed.opts.signal.addEventListener === "function") {
            parsed.opts.signal.addEventListener("abort", function () {
                rejectAll(_watchAbortError(parsed.opts.signal));
            });
        }
    }

    if (watcher && typeof watcher.on === "function") {
        watcher.on("error", function (err) {
            rejectAll(err);
            if (watcher) {
                try { watcher.close(); } catch (_ce) { /* ignore */ }
            }
        });
        watcher.on("close", function () {
            if (!closed) {
                closeAll();
            }
        });
    }

    var iter = {
        next: function () {
            if (failErr) { return Promise.reject(failErr); }
            if (closed) { return Promise.resolve({ value: undefined, done: true }); }
            if (queue.length > 0) {
                return Promise.resolve({ value: queue.shift(), done: false });
            }
            return new Promise(function (resolve, reject) {
                waiters.push({ resolve: resolve, reject: reject });
            }).then(function (v) {
                if (closed && failErr) { throw failErr; }
                if (closed || (v && v.__done)) { return { value: undefined, done: true }; }
                return { value: v, done: false };
            });
        },
        return: function () {
            closeAll();
            return Promise.resolve({ value: undefined, done: true });
        },
        throw: function (err) {
            rejectAll(err || _watchAbortError(null));
            return Promise.reject(err || failErr);
        }
    };
    if (typeof Symbol !== "undefined" && Symbol.asyncIterator) {
        iter[Symbol.asyncIterator] = function () { return iter; };
    }
    return iter;
}

promises.watch = function (filename, options) {
    var iter = _createPromisesWatchIterable(filename, options);
    // Node returns an async iterable directly (has [Symbol.asyncIterator]).
    return iter;
};

// ── createReadStream / createWriteStream (stream.Readable / Writable) ────────

function nextTick(fn) {
    if (typeof process !== "undefined" && typeof process.nextTick === "function") {
        process.nextTick(fn);
    } else {
        setTimeout(fn, 0);
    }
}

_streamsMod.installStreams(nativeFs, {
    nextTick: nextTick,
    pathArg: _fsPathArg
});
var _streamClasses = {
    ReadStream: nativeFs.ReadStream,
    WriteStream: nativeFs.WriteStream
};

// fs.realpathSync.native — Vite safeRealpathSync expects this sub-property
if (typeof nativeFs.realpathSync === "function") {
    var _nativeRealpathSync = nativeFs.realpathSync;
    nativeFs.realpathSync = function(path, options) {
        path = _fsPathArg(path);
        if (typeof options === "string") {
            options = _fsVal.validateEncoding(options, "encoding");
        } else if (options && typeof options === "object" && options.encoding != null) {
            options.encoding = _fsVal.validateEncoding(options.encoding, "encoding");
        }
        return _nativeRealpathSync(path, options);
    };
    nativeFs.realpathSync.native = nativeFs.realpathSync;
}

// ── FS-READ-FD / FS-WRITE-FD: read/write/readv/writev (+Sync) ─────────────────
// Native bridge: __readPtr / __writePtr / __readvPtr / __writevPtr (+ Async)
// operate on raw Buffer backing-store pointers.

function _bufferPtrLen(buffer, offset, length) {
    if (!buffer || typeof buffer.length !== 'number') {
        var e = new TypeError('The "buffer" argument must be an instance of Buffer or Uint8Array');
        e.code = 'ERR_INVALID_ARG_TYPE';
        throw e;
    }
    var off = 0;
    if (offset !== undefined && offset !== null) {
        if (typeof offset === 'bigint') off = Number(offset);
        else off = Number(offset);
        if (off !== off || off < 0) off = 0;
        off = Math.floor(off);
    }
    var len;
    if (length === undefined || length === null) {
        len = buffer.length - off;
    } else {
        if (typeof length === 'bigint') len = Number(length);
        else len = Number(length);
        if (len !== len || len < 0) len = 0;
        len = Math.floor(len);
    }
    if (buffer.length === 0 && len > 0) {
        var ee = new Error("The argument 'buffer' is empty and cannot be written. Received Uint8Array(0) []");
        ee.code = 'ERR_INVALID_ARG_VALUE';
        throw ee;
    }
    if (off > buffer.length || off + len > buffer.length) {
        var re = new RangeError('The value of "offset" + "length" is out of range');
        re.code = 'ERR_OUT_OF_RANGE';
        throw re;
    }
    var ab = buffer._buffer || buffer.buffer;
    var baseOff = buffer._byteOffset || buffer.byteOffset || 0;
    if (!ab || !ab._ptr) {
        var tmp = __buf.alloc(len + 1);
        for (var i = 0; i < len; i++) __buf.setByte(tmp, i, buffer[off + i] & 0xff);
        return { ptr: tmp, len: len, tmp: tmp, offset: off };
    }
    return { ptr: ab._ptr + baseOff + off, len: len, tmp: 0, offset: off };
}

function _posOrNeg1(position) {
    if (position === undefined || position === null) return -1;
    if (typeof position === 'bigint') {
        // libuv offset is int64; coerce bigint without bitwise truncation
        if (position < BigInt(0)) return -1;
        return Number(position);
    }
    var n = Number(position);
    if (n !== n) return -1;
    return n;
}

function _fdErr(code, syscall, message) {
    var err = new Error(message || (code + ', ' + syscall));
    err.code = code;
    err.syscall = syscall;
    return err;
}

// Shared Node-order validation for read/readSync/write paths once overloads are
// resolved: offset integer >= 0, length defaulted, empty-buffer guard, bounds,
// position integer/bigint >= -1. Returns {offset, length, position} normalized.
function _validateReadArgs(buffer, offset, length, position) {
    _fsVal.validateBuffer(buffer, 'buffer');
    if (offset === undefined || offset === null) {
        offset = 0;
    } else {
        _fsVal.validateInteger(offset, 'offset', 0);
    }
    if (length === undefined || length === null) {
        length = buffer.byteLength - offset;
    }
    if (length !== 0) {
        if (buffer.byteLength === 0) {
            var ee = new TypeError(
                "The argument 'buffer' is empty and cannot be written. Received " +
                (buffer.constructor ? buffer.constructor.name : 'Uint8Array') +
                '(0) []');
            ee.code = 'ERR_INVALID_ARG_VALUE';
            throw ee;
        }
        _fsVal.validateOffsetLengthRead(offset, length, buffer.byteLength);
    }
    if (position === undefined || position === null) position = -1;
    _fsVal.validatePosition(position, 'position', length);
    return { offset: offset, length: length, position: position };
}

nativeFs.readSync = function(fd, buffer, offset, length, position) {
    _fsVal.validateFd(fd);
    _fsVal.validateBuffer(buffer, 'buffer');
    // Overloads:
    //   readSync(fd, buffer, offset, length, position)
    //   readSync(fd, buffer, options)  options: {offset,length,position}
    if (arguments.length <= 3 || (typeof offset === 'object' && offset !== null)) {
        if (offset !== undefined && offset !== null) {
            _fsVal.validateOptionsObject(offset, 'options');
        }
        var o = offset || {};
        position = o.position;
        length = o.length;
        offset = o.offset;
    }
    var v = _validateReadArgs(buffer, offset, length, position);
    if (v.length === 0) return 0;
    var info = _bufferPtrLen(buffer, v.offset, v.length);
    var n = nativeFs.__readPtr(fd, info.ptr, info.len, _posOrNeg1(v.position));
    if (info.tmp) {
        for (var i = 0; i < (n > 0 ? n : 0); i++) buffer[info.offset + i] = __buf.getByte(info.tmp, i);
        __buf.free(info.tmp);
    }
    if (n < 0) throw _fdErr('EBADF', 'read', 'EBADF: bad file descriptor, read');
    return n;
};

// Node-order validation for the ArrayBufferView write path.
function _validateWriteArgs(buffer, offset, length, position) {
    if (position === undefined) position = null;
    if (offset === undefined || offset === null) {
        offset = 0;
    } else {
        _fsVal.validateInteger(offset, 'offset', 0);
    }
    if (typeof length !== 'number') length = buffer.byteLength - offset;
    _fsVal.validateOffsetLengthWrite(offset, length, buffer.byteLength);
    if (position === null) position = -1;
    _fsVal.validatePosition(position, 'position', length);
    return { offset: offset, length: length, position: position };
}

nativeFs.writeSync = function(fd, buffer, offset, length, position) {
    _fsVal.validateFd(fd);
    if (ArrayBuffer.isView(buffer)) {
        // writeSync(fd, buffer[, offset[, length[, position]]]) or (fd, buffer, options)
        if (typeof offset === 'object' && offset !== null) {
            var wo = offset;
            position = wo.position;
            length = wo.length;
            offset = wo.offset;
        }
        var v = _validateWriteArgs(buffer, offset, length, position);
        offset = v.offset; length = v.length; position = v.position;
    } else if (typeof buffer === 'string') {
        // writeSync(fd, string[, position[, encoding]])
        var enc = _fsVal.validateEncoding(
            typeof length === 'string' ? length : 'utf8', 'encoding');
        var pos = offset;
        buffer = Buffer.from(buffer, enc);
        offset = 0;
        length = buffer.length;
        position = (typeof pos === 'number' || typeof pos === 'bigint') ? pos : -1;
    } else {
        // Node validateStringAfterArrayBufferView — no ToString coercion.
        throw _fsErrors.errInvalidArgType(
            'buffer', 'string or an instance of Buffer, TypedArray, or DataView', buffer);
    }
    var info = _bufferPtrLen(buffer, offset, length);
    var n = nativeFs.__writePtr(fd, info.ptr, info.len, _posOrNeg1(position));
    if (info.tmp) __buf.free(info.tmp);
    if (n < 0) throw _fdErr('EBADF', 'write', 'EBADF: bad file descriptor, write');
    return n;
};

nativeFs.read = function(fd, buffer, offset, length, position, callback) {
    _fsVal.validateFd(fd);
    // Overloads matching Node lib/fs.js read():
    //   read(fd, buffer, offset, length, position, cb)
    //   read(fd, cb) / read(fd, bufferOrParams, cb) / read(fd, buffer, options, cb)
    var argc = arguments.length;
    if (argc <= 4) {
        var params;
        if (argc === 4) {
            // (fd, buffer, options, cb)
            if (offset !== undefined && offset !== null) {
                _fsVal.validateOptionsObject(offset, 'options');
            }
            callback = length;
            params = offset;
        } else if (argc === 3) {
            // (fd, bufferOrParams, cb)
            if (!ArrayBuffer.isView(buffer)) {
                params = buffer;
                if (params !== undefined && params !== null) {
                    _fsVal.validateOptionsObject(params, 'options');
                }
                buffer = (params && params.buffer !== undefined) ? params.buffer : Buffer.alloc(16384);
            }
            callback = offset;
        } else {
            // (fd, cb)
            callback = buffer;
            buffer = Buffer.alloc(16384);
        }
        var p = params || {};
        offset = p.offset;
        length = p.length;
        position = p.position;
    }
    // Node order: buffer type first, then callback, then offset/length/position.
    _fsVal.validateBuffer(buffer, 'buffer');
    callback = _requireCb(callback);
    var v = _validateReadArgs(buffer, offset, length, position);
    if (v.length === 0) {
        nextTick(function() { callback(null, 0, buffer); });
        return;
    }
    var info = _bufferPtrLen(buffer, v.offset, v.length);
    nativeFs.__readPtrAsync(fd, info.ptr, info.len, _posOrNeg1(v.position), function(err, bytesRead) {
        if (info.tmp) {
            if (!err && bytesRead > 0) {
                for (var i = 0; i < bytesRead; i++) buffer[info.offset + i] = __buf.getByte(info.tmp, i);
            }
            __buf.free(info.tmp);
        }
        callback(err, bytesRead, buffer);
    });
};

nativeFs.write = function(fd, buffer, offset, length, position, callback) {
    _fsVal.validateFd(fd);
    if (ArrayBuffer.isView(buffer)) {
        // write(fd, buffer[, offset[, length[, position]]], cb) or (fd, buffer, options, cb)
        if (typeof offset === 'function') {
            callback = offset; offset = undefined; length = undefined; position = undefined;
        } else if (typeof offset === 'object' && offset !== null) {
            callback = length;
            var wo2 = offset;
            position = wo2.position;
            length = wo2.length;
            offset = wo2.offset;
        } else if (typeof length === 'function') {
            callback = length; length = undefined; position = undefined;
        } else if (typeof position === 'function') {
            callback = position; position = undefined;
        }
        callback = _requireCb(callback);
        // Offset/length/position validation throws synchronously (Node order).
        var v = _validateWriteArgs(buffer, offset, length, position);
        offset = v.offset; length = v.length; position = v.position;
    } else if (typeof buffer === 'string') {
        // write(fd, string[, position[, encoding]], callback)
        var enc = 'utf8';
        var pos = null;
        if (typeof offset === 'function') {
            callback = offset; offset = undefined;
        } else if (typeof length === 'function') {
            callback = length;
            if (typeof offset === 'string') { enc = offset; }
            else { pos = offset; }
            offset = undefined; length = undefined;
        } else if (typeof position === 'function') {
            callback = position;
            if (typeof length === 'string') { enc = length; pos = offset; }
            else { pos = offset; }
            offset = undefined; length = undefined; position = undefined;
        }
        callback = _requireCb(callback);
        enc = _fsVal.validateEncoding(enc, 'encoding');
        buffer = Buffer.from(buffer, enc);
        offset = 0;
        length = buffer.length;
        position = pos;
    } else {
        // Node validateStringAfterArrayBufferView — no ToString coercion.
        throw _fsErrors.errInvalidArgType(
            'buffer', 'string or an instance of Buffer, TypedArray, or DataView', buffer);
    }
    var info = _bufferPtrLen(buffer, offset, length);
    nativeFs.__writePtrAsync(fd, info.ptr, info.len, _posOrNeg1(position), function(err, bytesWritten) {
        if (info.tmp) __buf.free(info.tmp);
        callback(err, bytesWritten, buffer);
    });
};

function _packBuffers(buffers) {
    if (!Array.isArray(buffers)) {
        var e = new TypeError('The "buffers" argument must be an instance of Array');
        e.code = 'ERR_INVALID_ARG_TYPE';
        throw e;
    }
    var args = [];
    var tmps = [];
    for (var i = 0; i < buffers.length; i++) {
        var info = _bufferPtrLen(buffers[i], 0, buffers[i].length);
        args.push(info.ptr, info.len);
        if (info.tmp) tmps.push({ tmp: info.tmp, buf: buffers[i], idx: i });
    }
    return { flat: args, nbufs: buffers.length, tmps: tmps };
}

nativeFs.readvSync = function(fd, buffers, position) {
    _fsVal.validateFd(fd);
    _fsVal.validateBufferArray(buffers);
    var pack = _packBuffers(buffers);
    var callArgs = [fd, _posOrNeg1(position), pack.nbufs].concat(pack.flat);
    var n = nativeFs.__readvPtr.apply(nativeFs, callArgs);
    for (var t = 0; t < pack.tmps.length; t++) {
        var tm = pack.tmps[t];
        var blen = tm.buf.length;
        var copy = n > 0 ? Math.min(blen, n) : 0;
        // Approximate scatter for tmp buffers — only used in fallback path
        for (var i = 0; i < copy; i++) tm.buf[i] = __buf.getByte(tm.tmp, i);
        __buf.free(tm.tmp);
    }
    if (n < 0) throw _fdErr('EBADF', 'readv', 'EBADF: bad file descriptor, readv');
    return n;
};

nativeFs.writevSync = function(fd, buffers, position) {
    _fsVal.validateFd(fd);
    _fsVal.validateBufferArray(buffers);
    var pack = _packBuffers(buffers);
    var callArgs = [fd, _posOrNeg1(position), pack.nbufs].concat(pack.flat);
    var n = nativeFs.__writevPtr.apply(nativeFs, callArgs);
    for (var t = 0; t < pack.tmps.length; t++) __buf.free(pack.tmps[t].tmp);
    if (n < 0) throw _fdErr('EBADF', 'writev', 'EBADF: bad file descriptor, writev');
    return n;
};

nativeFs.readv = function(fd, buffers, position, callback) {
    _fsVal.validateFd(fd);
    _fsVal.validateBufferArray(buffers);
    if (typeof position === 'function') { callback = position; position = undefined; }
    callback = _requireCb(callback);
    var pack = _packBuffers(buffers);
    var callArgs = [fd, _posOrNeg1(position), pack.nbufs].concat(pack.flat);
    callArgs.push(function(err, bytesRead) {
        for (var t = 0; t < pack.tmps.length; t++) {
            var tm = pack.tmps[t];
            if (!err && bytesRead > 0) {
                var copy = Math.min(tm.buf.length, bytesRead);
                for (var i = 0; i < copy; i++) tm.buf[i] = __buf.getByte(tm.tmp, i);
            }
            __buf.free(tm.tmp);
        }
        callback(err, bytesRead, buffers);
    });
    nativeFs.__readvPtrAsync.apply(nativeFs, callArgs);
};

nativeFs.writev = function(fd, buffers, position, callback) {
    _fsVal.validateFd(fd);
    _fsVal.validateBufferArray(buffers);
    if (typeof position === 'function') { callback = position; position = undefined; }
    callback = _requireCb(callback);
    var pack = _packBuffers(buffers);
    var callArgs = [fd, _posOrNeg1(position), pack.nbufs].concat(pack.flat);
    callArgs.push(function(err, bytesWritten) {
        for (var t = 0; t < pack.tmps.length; t++) __buf.free(pack.tmps[t].tmp);
        callback(err, bytesWritten, buffers);
    });
    nativeFs.__writevPtrAsync.apply(nativeFs, callArgs);
};

// ── FS-CP: cp / cpSync / promises.cp ─────────────────────────────────────────
var _cpImpl = require('./fs/cp.js');
nativeFs.cpSync = function(src, dest, options) {
    return _cpImpl.cpSync(nativeFs, _fsPathArg(src), _fsPathArg(dest), options);
};
nativeFs.cp = function(src, dest, options, callback) {
    if (typeof options === 'function') {
        callback = options;
        options = {};
    }
    return _cpImpl.cpCallback(nativeFs, _fsPathArg(src), _fsPathArg(dest), options, callback);
};
promises.cp = function(src, dest, options) {
    return _cpImpl.cpPromise(nativeFs, _fsPathArg(src), _fsPathArg(dest), options);
};

// ── Long-tail: fstat / truncate / utimes / link / fsync / fchmod / fchown ─────

/** Convert Node utimes time arg (Date | number seconds | numeric string) → seconds. */
function _toUnixSeconds(t) {
    // +0.5ms before the native's truncating double→timespec conversion:
    // ms/1000 rounds DOWN in binary (…928.999999ns), losing 1ms on stat readback.
    if (t instanceof Date) return (t.getTime() + 0.5) / 1000;
    if (typeof t === 'string') return Number(t);
    return Number(t);
}

var _nativeFstatSync = nativeFs.fstatSync;
nativeFs.fstatSync = function(fd) {
    var result = _nativeFstatSync(fd);
    if (result === undefined || result === null) {
        throw _fdErr('EBADF', 'fstat', 'EBADF: bad file descriptor, fstat');
    }
    return _wrapStat(result);
};

var _nativeFstat = nativeFs.fstat;
nativeFs.fstat = function(fd, options, callback) {
    if (typeof options === 'function') { callback = options; options = {}; }
    if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    _nativeFstat(fd, function(err, result) {
        if (err) { callback(_asFsError(err)); } else { callback(null, _wrapStat(result)); }
    });
};

var _nativeTruncateSync = nativeFs.truncateSync;
var _nativeFtruncateSync = nativeFs.ftruncateSync;
nativeFs.truncateSync = function(path, len) {
    if (len === undefined) len = 0;
    _fsVal.validateInteger(len, 'len');
    if (typeof path === 'number') {
        return _nativeFtruncateSync(path, len);
    }
    return _nativeTruncateSync(_fsPathArg(path), len);
};
nativeFs.ftruncateSync = function(fd, len) {
    _fsVal.validateFd(fd);
    if (len === undefined) len = 0;
    _fsVal.validateInteger(len, 'len');
    return _nativeFtruncateSync(fd, len);
};

var _nativeTruncate = nativeFs.truncate;
var _nativeFtruncate = nativeFs.ftruncate;
nativeFs.truncate = function(path, len, callback) {
    if (typeof len === 'function') { callback = len; len = 0; }
    if (len === undefined) len = 0;
    _fsVal.validateInteger(len, 'len');
    callback = _requireCb(callback);
    if (typeof path === 'number') {
        return _nativeFtruncate(path, len, callback);
    }
    return _nativeTruncate(_fsPathArg(path), len, callback);
};
nativeFs.ftruncate = function(fd, len, callback) {
    if (typeof len === 'function') { callback = len; len = 0; }
    _fsVal.validateFd(fd);
    if (len === undefined) len = 0;
    _fsVal.validateInteger(len, 'len');
    callback = _requireCb(callback);
    return _nativeFtruncate(fd, len, callback);
};

var _nativeUtimesSync = nativeFs.utimesSync;
var _nativeFutimesSync = nativeFs.futimesSync;
var _nativeLutimesSync = nativeFs.lutimesSync;
nativeFs.utimesSync = function(path, atime, mtime) {
    return _nativeUtimesSync(_fsPathArg(path), _toUnixSeconds(atime), _toUnixSeconds(mtime));
};
nativeFs.futimesSync = function(fd, atime, mtime) {
    return _nativeFutimesSync(fd, _toUnixSeconds(atime), _toUnixSeconds(mtime));
};
nativeFs.lutimesSync = function(path, atime, mtime) {
    return _nativeLutimesSync(_fsPathArg(path), _toUnixSeconds(atime), _toUnixSeconds(mtime));
};

var _nativeUtimes = nativeFs.utimes;
var _nativeFutimes = nativeFs.futimes;
var _nativeLutimes = nativeFs.lutimes;
nativeFs.utimes = function(path, atime, mtime, callback) {
    callback = _requireCb(callback);
    return _nativeUtimes(_fsPathArg(path), _toUnixSeconds(atime), _toUnixSeconds(mtime), callback);
};
nativeFs.futimes = function(fd, atime, mtime, callback) {
    _fsVal.validateFd(fd);
    callback = _requireCb(callback);
    return _nativeFutimes(fd, _toUnixSeconds(atime), _toUnixSeconds(mtime), callback);
};
nativeFs.lutimes = function(path, atime, mtime, callback) {
    callback = _requireCb(callback);
    return _nativeLutimes(_fsPathArg(path), _toUnixSeconds(atime), _toUnixSeconds(mtime), callback);
};

var _nativeLinkSync = nativeFs.linkSync;
nativeFs.linkSync = function(existingPath, newPath) {
    return _nativeLinkSync(_fsPathArg(existingPath, "existingPath"), _fsPathArg(newPath, "newPath"));
};
var _nativeLink = nativeFs.link;
nativeFs.link = function(existingPath, newPath, callback) {
    existingPath = _fsPathArg(existingPath, "existingPath");
    newPath = _fsPathArg(newPath, "newPath");
    callback = _requireCb(callback);
    return _nativeLink(existingPath, newPath, callback);
};

var _nativeLchownSync = nativeFs.lchownSync;
nativeFs.lchownSync = function(path, uid, gid) {
    path = _fsPathArg(path);
    _fsVal.validateUidGid(uid, 'uid');
    _fsVal.validateUidGid(gid, 'gid');
    return _nativeLchownSync(path, uid, gid);
};
var _nativeLchown = nativeFs.lchown;
nativeFs.lchown = function(path, uid, gid, callback) {
    path = _fsPathArg(path);
    _fsVal.validateUidGid(uid, 'uid');
    _fsVal.validateUidGid(gid, 'gid');
    callback = _requireCb(callback);
    return _nativeLchown(path, uid, gid, callback);
};

function _promisifyVoid(fn) {
    return function() {
        var args = Array.prototype.slice.call(arguments);
        return new Promise(function(resolve, reject) {
            try {
                var ret = fn.apply(nativeFs, args);
                resolve(ret);
            } catch (e) { reject(e); }
        });
    };
}

promises.fstat = function(fd) {
    return new Promise(function(resolve, reject) {
        try { resolve(nativeFs.fstatSync(fd)); } catch (e) { reject(e); }
    });
};
promises.truncate = _promisifyVoid(function(path, len) { return nativeFs.truncateSync(path, len); });
promises.ftruncate = _promisifyVoid(function(fd, len) { return nativeFs.ftruncateSync(fd, len); });
promises.utimes = _promisifyVoid(function(path, a, m) { return nativeFs.utimesSync(path, a, m); });
promises.futimes = _promisifyVoid(function(fd, a, m) { return nativeFs.futimesSync(fd, a, m); });
promises.lutimes = _promisifyVoid(function(path, a, m) { return nativeFs.lutimesSync(path, a, m); });
promises.link = _promisifyVoid(function(a, b) { return nativeFs.linkSync(a, b); });
promises.fsync = _promisifyVoid(function(fd) { return nativeFs.fsyncSync(fd); });
promises.fdatasync = _promisifyVoid(function(fd) { return nativeFs.fdatasyncSync(fd); });
promises.fchmod = _promisifyVoid(function(fd, mode) { return nativeFs.fchmodSync(fd, mode); });
promises.fchown = _promisifyVoid(function(fd, uid, gid) { return nativeFs.fchownSync(fd, uid, gid); });
promises.lchown = _promisifyVoid(function(path, uid, gid) { return nativeFs.lchownSync(path, uid, gid); });
promises.chown = _promisifyVoid(function(path, uid, gid) { return nativeFs.chownSync(path, uid, gid); });
promises.symlink = _promisifyVoid(function(target, path, type) { return nativeFs.symlinkSync(target, path, type); });
promises.readlink = function(path, options) {
    return new Promise(function(resolve, reject) {
        try { resolve(nativeFs.readlinkSync(path, options)); } catch (e) { reject(e); }
    });
};

// ── opendir / Dir (thin JS over readdir) ──────────────────────────────────────

function Dir(path, options) {
    if (path === undefined) {
        var em = new TypeError('The "path" argument must be specified');
        em.code = 'ERR_MISSING_ARGS';
        throw em;
    }
    this._dirPath = path;
    this._entries = null;
    this._index = 0;
    this._closed = false;
    this._options = options || {};
}

// `path` is a prototype accessor with a brand check (Node throws
// ERR_INVALID_THIS when read off Dir.prototype directly).
Object.defineProperty(Dir.prototype, 'path', {
    configurable: true,
    enumerable: true,
    get: function () {
        if (!(this instanceof Dir)) {
            var et = new TypeError('Value of "this" must be of type Dir');
            et.code = 'ERR_INVALID_THIS';
            throw et;
        }
        return this._dirPath;
    }
});

Dir.prototype.readSync = function() {
    if (this._closed) {
        var err = new Error('Directory handle was closed');
        err.code = 'ERR_DIR_CLOSED';
        throw err;
    }
    if (this._entries === null) {
        var opts = { withFileTypes: true };
        if (this._options.encoding) opts.encoding = this._options.encoding;
        this._entries = nativeFs.readdirSync(this._dirPath, opts);
        this._index = 0;
    }
    if (this._index >= this._entries.length) return null;
    var ent = this._entries[this._index];
    this._index = this._index + 1;
    return ent;
};

Dir.prototype.read = function(callback) {
    var self = this;
    if (typeof callback === 'function') {
        try {
            var ent = self.readSync();
            _scheduleNextTick(function() { callback(null, ent); });
        } catch (e) {
            _scheduleNextTick(function() { callback(e); });
        }
        return;
    }
    return new Promise(function(resolve, reject) {
        try { resolve(self.readSync()); } catch (e) { reject(e); }
    });
};

Dir.prototype.closeSync = function() {
    this._closed = true;
    this._entries = null;
};

Dir.prototype.close = function(callback) {
    var self = this;
    self.closeSync();
    if (typeof callback === 'function') {
        _scheduleNextTick(function() { callback(null); });
        return;
    }
    return Promise.resolve();
};

Dir.prototype[Symbol.asyncIterator] = function() {
    var self = this;
    return {
        next: function() {
            return self.read().then(function(value) {
                if (value === null) {
                    return self.close().then(function() {
                        return { value: undefined, done: true };
                    });
                }
                return { value: value, done: false };
            });
        },
        return: function() {
            return self.close().then(function() {
                return { value: undefined, done: true };
            });
        }
    };
};

if (typeof Symbol !== 'undefined' && Symbol.asyncDispose) {
    Dir.prototype[Symbol.asyncDispose] = function() { return this.close(); };
}

nativeFs.Dir = Dir;

nativeFs.opendirSync = function(path, options) {
    path = _fsPathArg(path);
    if (options && typeof options === 'object' && options.encoding != null) {
        _fsVal.validateEncoding(options.encoding, 'encoding');
    } else if (typeof options === 'string') {
        _fsVal.validateEncoding(options, 'encoding');
    }
    // Validate directory exists / is readable via readdir
    nativeFs.readdirSync(path);
    return new Dir(path, options);
};

nativeFs.opendir = function(path, options, callback) {
    if (typeof options === 'function') { callback = options; options = {}; }
    path = _fsPathArg(path);
    if (typeof callback === 'function') {
        try {
            var dir = nativeFs.opendirSync(path, options);
            _scheduleNextTick(function() { callback(null, dir); });
        } catch (e) {
            _scheduleNextTick(function() { callback(e); });
        }
        return;
    }
    return new Promise(function(resolve, reject) {
        try { resolve(nativeFs.opendirSync(path, options)); } catch (e) { reject(e); }
    });
};

promises.opendir = function(path, options) {
    return nativeFs.opendir(path, options);
};

// ── glob / globSync (basic * and ** support) ─────────────────────────────────

function _globMatch(pattern, name) {
    // Convert simple glob to RegExp: * → [^/]*, ? → [^/], ** handled by walker
    var i = 0;
    var re = '^';
    while (i < pattern.length) {
        var c = pattern[i];
        if (c === '*') {
            re += '[^/]*';
        } else if (c === '?') {
            re += '[^/]';
        } else if ('+()|^$\\.[]{}'.indexOf(c) >= 0) {
            re += '\\' + c;
        } else {
            re += c;
        }
        i = i + 1;
    }
    re += '$';
    return new RegExp(re).test(name);
}

function _globWalk(base, parts, partIdx, out, opts) {
    if (partIdx >= parts.length) {
        out.push(base);
        return;
    }
    var part = parts[partIdx];
    if (part === '**') {
        // Match zero or more directories
        _globWalk(base, parts, partIdx + 1, out, opts);
        var entries;
        try { entries = nativeFs.readdirSync(base); } catch (_e) { return; }
        if (!entries) return;
        for (var i = 0; i < entries.length; i++) {
            var name = entries[i];
            if (name === '.' || name === '..') continue;
            var child = base === '/' ? '/' + name : base + '/' + name;
            var st;
            try { st = nativeFs.lstatSync(child); } catch (_e2) { continue; }
            if (!st) continue;
            var isDir = typeof st.isDirectory === 'function' ? st.isDirectory() : st.isDirectory;
            var isLink = typeof st.isSymbolicLink === 'function' ? st.isSymbolicLink() : st.isSymbolicLink;
            if (isDir && !isLink) {
                _globWalk(child, parts, partIdx, out, opts);
            }
        }
        return;
    }
    var ents;
    try { ents = nativeFs.readdirSync(base); } catch (_e3) { return; }
    if (!ents) return;
    for (var j = 0; j < ents.length; j++) {
        var nm = ents[j];
        if (nm === '.' || nm === '..') continue;
        if (!_globMatch(part, nm)) continue;
        var full = base === '/' ? '/' + nm : base + '/' + nm;
        if (partIdx === parts.length - 1) {
            out.push(full);
        } else {
            var st2;
            try { st2 = nativeFs.lstatSync(full); } catch (_e4) { continue; }
            if (!st2) continue;
            var isD = typeof st2.isDirectory === 'function' ? st2.isDirectory() : st2.isDirectory;
            if (isD) _globWalk(full, parts, partIdx + 1, out, opts);
        }
    }
}

function _globSyncImpl(pattern, options) {
    options = options || {};
    pattern = String(pattern);
    var cwd = (options.cwd && String(options.cwd)) || (typeof process !== 'undefined' && process.cwd ? process.cwd() : '.');
    // Absolute pattern
    var base = cwd;
    var rel = pattern;
    if (pattern.charAt(0) === '/') {
        base = '/';
        rel = pattern.slice(1);
    }
    var parts = rel.split('/').filter(function(p) { return p.length > 0; });
    var out = [];
    _globWalk(base === '.' ? '.' : base, parts, 0, out, options);
    // Normalize './' prefix away for relative results when cwd-based
    if (base !== '/') {
        var prefix = base === '.' ? './' : base + '/';
        for (var k = 0; k < out.length; k++) {
            if (out[k].indexOf(prefix) === 0) {
                out[k] = out[k].slice(prefix.length);
            } else if (base !== '.' && out[k].indexOf(base + '/') === 0) {
                out[k] = out[k].slice(base.length + 1);
            }
        }
    }
    return out;
}

nativeFs.globSync = function(pattern, options) {
    return _globSyncImpl(pattern, options);
};

nativeFs.glob = function(pattern, options, callback) {
    if (typeof options === 'function') { callback = options; options = {}; }
    if (typeof callback === 'function') {
        try {
            var result = _globSyncImpl(pattern, options);
            _scheduleNextTick(function() { callback(null, result); });
        } catch (e) {
            _scheduleNextTick(function() { callback(e); });
        }
        return;
    }
    // Async iterator form (Node 22+): return async iterable
    var matches = null;
    var idx = 0;
    var iter = {
        next: function() {
            if (matches === null) {
                try { matches = _globSyncImpl(pattern, options); }
                catch (e) { return Promise.reject(e); }
            }
            if (idx >= matches.length) {
                return Promise.resolve({ value: undefined, done: true });
            }
            var v = matches[idx];
            idx = idx + 1;
            return Promise.resolve({ value: v, done: false });
        }
    };
    if (typeof Symbol !== "undefined" && Symbol.asyncIterator) {
        iter[Symbol.asyncIterator] = function() { return iter; };
    }
    return iter;
};

promises.glob = function(pattern, options) {
    return Promise.resolve(_globSyncImpl(pattern, options));
};

// ── openAsBlob ───────────────────────────────────────────────────────────────

nativeFs.openAsBlob = function(path, options) {
    path = _fsPathArg(path);
    var type = (options && options.type) ? String(options.type) : '';
    return Promise.resolve().then(function() {
        var data = nativeFs.readFileSync(path);
        var BlobCtor = globalThis.Blob;
        if (!BlobCtor) throw new Error('Blob is not available');
        return new BlobCtor([data], { type: type });
    });
};

// Path-coerce native statfs; add frsize + bigint option (Node StatsFs shape)
(function () {
    function _polishStatFs(raw, bigint) {
        if (!raw || typeof raw !== "object") return raw;
        var fr = raw.frsize !== undefined ? raw.frsize : raw.bsize;
        var keys = ["type", "bsize", "frsize", "blocks", "bfree", "bavail", "files", "ffree"];
        var src = {
            type: raw.type, bsize: raw.bsize, frsize: fr,
            blocks: raw.blocks, bfree: raw.bfree, bavail: raw.bavail,
            files: raw.files, ffree: raw.ffree
        };
        var out = {};
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            var v = src[k];
            if (v === undefined || v === null) v = 0;
            out[k] = bigint ? BigInt(Math.trunc(Number(v))) : Number(v);
        }
        return out;
    }
    if (typeof nativeFs.statfsSync === "function") {
        var _sfs = nativeFs.statfsSync;
        nativeFs.statfsSync = function (path, options) {
            var bigint = options && options.bigint;
            return _polishStatFs(_sfs.call(nativeFs, _fsPathArg(path)), !!bigint);
        };
    }
    if (typeof nativeFs.statfs === "function") {
        var _sfa = nativeFs.statfs;
        nativeFs.statfs = function (path, options, callback) {
            if (typeof options === "function") { callback = options; options = undefined; }
            path = _fsPathArg(path);
            callback = _requireCb(callback);
            var bigint = options && options.bigint;
            return _sfa.call(nativeFs, path, function (err, stats) {
                if (err) return callback(err);
                callback(null, _polishStatFs(stats, !!bigint));
            });
        };
    }
})();

// ── writeFile / appendFile mode + encoding polish ────────────────────────────
(function () {
    var _wfSync = nativeFs.writeFileSync;
    nativeFs.writeFileSync = function (path, data, options) {
        path = _fsPathArg(path);
        var mode = 438;
        var enc = 'utf8';
        var flag = 'w';
        if (typeof options === 'string') {
            enc = _fsVal.validateEncoding(options, 'encoding');
        } else if (options && typeof options === 'object') {
            if (options.encoding !== undefined && options.encoding !== null) {
                enc = _fsVal.validateEncoding(options.encoding, 'encoding');
            }
            if (options.mode !== undefined) {
                _fsVal.validateMode(options.mode, 'mode');
                mode = typeof options.mode === 'string' ? parseInt(options.mode, 8) : options.mode;
            }
            if (options.flag !== undefined) flag = options.flag;
        }
        var buf;
        if (Buffer.isBuffer(data)) buf = data;
        else if (data instanceof Uint8Array) buf = Buffer.from(data);
        else buf = Buffer.from(data === undefined || data === null ? '' : String(data), enc);
        // Honor mode via open+write when possible
        var fd = nativeFs.openSync(path, flag, mode);
        try {
            nativeFs.ftruncateSync(fd, 0);
            var off = 0;
            while (off < buf.length) {
                var n = nativeFs.writeSync(fd, buf, off, buf.length - off, off);
                if (n <= 0) break;
                off += n;
            }
            if (options && typeof options === 'object' && options.flush === true) {
                if (typeof nativeFs.fsyncSync === 'function') nativeFs.fsyncSync(fd);
            }
        } finally {
            nativeFs.closeSync(fd);
        }
    };

    var _afSync = nativeFs.appendFileSync;
    nativeFs.appendFileSync = function (path, data, options) {
        path = _fsPathArg(path);
        var mode = 438;
        var enc = 'utf8';
        if (typeof options === 'string') {
            enc = _fsVal.validateEncoding(options, 'encoding');
        } else if (options && typeof options === 'object') {
            if (options.encoding !== undefined && options.encoding !== null) {
                enc = _fsVal.validateEncoding(options.encoding, 'encoding');
            }
            if (options.mode !== undefined) {
                _fsVal.validateMode(options.mode, 'mode');
                mode = typeof options.mode === 'string' ? parseInt(options.mode, 8) : options.mode;
            }
        }
        var buf;
        if (Buffer.isBuffer(data)) buf = data;
        else if (data instanceof Uint8Array) buf = Buffer.from(data);
        else buf = Buffer.from(data === undefined || data === null ? '' : String(data), enc);
        var fd = nativeFs.openSync(path, 'a', mode);
        try {
            var off = 0;
            while (off < buf.length) {
                var n = nativeFs.writeSync(fd, buf, off, buf.length - off, null);
                if (n <= 0) break;
                off += n;
            }
            if (options && typeof options === 'object' && options.flush === true) {
                if (typeof nativeFs.fsyncSync === 'function') nativeFs.fsyncSync(fd);
            }
        } finally {
            nativeFs.closeSync(fd);
        }
    };
    // Keep native fallback refs unused-warning free
    void _wfSync; void _afSync;
})();

// Encoding aliases on string writeSync path
(function () {
    var _wSync = nativeFs.writeSync;
    nativeFs.writeSync = function (fd, buffer, offset, length, position) {
        if (typeof buffer === 'string') {
            var enc = 'utf8';
            var pos = offset;
            if (typeof length === 'string') { enc = length; }
            else if (typeof position === 'string') { enc = position; }
            else if (typeof offset === 'string') { enc = offset; pos = undefined; }
            enc = _fsVal.validateEncoding(enc, 'encoding');
            buffer = Buffer.from(buffer, enc);
            offset = 0;
            length = buffer.length;
            position = (typeof pos === 'number') ? pos : undefined;
            return _wSync.call(nativeFs, fd, buffer, offset, length, position);
        }
        return _wSync.apply(nativeFs, arguments);
    };
})();

// mkdtempDisposableSync — Node 22+ disposable temp dir
nativeFs.mkdtempDisposableSync = function (prefix, options) {
    var dir = nativeFs.mkdtempSync(prefix, options);
    var obj = {
        path: dir,
        remove: function () {
            try { nativeFs.rmSync(dir, { recursive: true, force: true }); } catch (_e) {}
        }
    };
    if (typeof Symbol !== 'undefined' && Symbol.dispose) {
        obj[Symbol.dispose] = function () { obj.remove(); };
    }
    return obj;
};

// promises.statfs
if (typeof nativeFs.statfsSync === 'function') {
    promises.statfs = function (path) {
        return new Promise(function (resolve, reject) {
            try { resolve(nativeFs.statfsSync(_fsPathArg(path))); }
            catch (e) { reject(e); }
        });
    };
}

// Re-export the augmented fs object
module.exports = nativeFs;
