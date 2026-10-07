// fs/cp.js — Node-compatible fs.cp / cpSync / promises.cp
// Port of Node lib/internal/fs/cp/cp.js (fs-extra derived) over the engine's
// sync fs primitives. The async driver awaits user filters (fs.cp allows async
// filters); the sync driver rejects promise-returning filters like Node.
'use strict';

var pathMod = require('path');
var errors = require('./errors.js');

// ── SystemError-shaped factories (tests assert err.code === 'ERR_FS_CP_*') ───

function _cpErr(code, ctx) {
    var err = new Error(ctx.message);
    err.code = code;
    err.syscall = ctx.syscall || 'cp';
    if (ctx.path !== undefined) err.path = ctx.path;
    if (ctx.dest !== undefined) err.dest = ctx.dest;
    err.info = {
        code: ctx.code || 'EINVAL',
        message: ctx.message,
        path: ctx.path,
        syscall: ctx.syscall || 'cp',
        errno: ctx.errno || -22
    };
    err.errno = ctx.errno || -22;
    return err;
}

function _einval(message, path) {
    return _cpErr('ERR_FS_CP_EINVAL', { message: message, path: path, code: 'EINVAL', errno: -22 });
}

// ── Option validation (Node internal/fs/utils validateCpOptions) ─────────────

function validateCpOptions(opts) {
    if (opts === undefined) opts = {};
    // null is NOT a stand-in for defaults (Node validateObject rejects it).
    if (opts === null || typeof opts !== 'object' || Array.isArray(opts)) {
        throw errors.errInvalidArgType('options', 'Object', opts);
    }
    // Node spreads user options over the defaults, so a PRESENT key — even one
    // explicitly set to undefined — replaces the default and must validate.
    var defaults = { recursive: false, force: true, errorOnExist: false,
                     dereference: false, preserveTimestamps: false,
                     verbatimSymlinks: false };
    var out = {};
    for (var k in defaults) {
        var v = Object.prototype.hasOwnProperty.call(opts, k) ? opts[k] : defaults[k];
        if (typeof v !== 'boolean') {
            throw errors.errInvalidArgType('options.' + k, 'boolean', v);
        }
        out[k] = v;
    }
    var mode = opts.mode;
    if (mode !== undefined && mode !== null) {
        if (typeof mode !== 'number') {
            throw errors.errInvalidArgType('options.mode', 'number', mode);
        }
        if (!Number.isInteger(mode) || mode < 0 || mode > 7) {
            throw errors.errOutOfRange('options.mode', '>= 0 && <= 7', mode);
        }
    }
    if (out.dereference && out.verbatimSymlinks) {
        var eInc = new TypeError(
            "The \"dereference\" and \"verbatimSymlinks\" options are mutually exclusive");
        eInc.code = 'ERR_INCOMPATIBLE_OPTION_PAIR';
        throw eInc;
    }
    if (opts.filter !== undefined && typeof opts.filter !== 'function') {
        throw errors.errInvalidArgType('options.filter', 'function', opts.filter);
    }
    out.filter = typeof opts.filter === 'function' ? opts.filter : null;
    out.mode = typeof mode === 'number' ? mode : 0;
    return out;
}

// ── Stat helpers ─────────────────────────────────────────────────────────────

function _callType(st, name) {
    if (!st) return false;
    var fn = st[name];
    if (typeof fn === 'function') return !!fn.call(st);
    return fn === true;
}
function _isDir(st) { return _callType(st, 'isDirectory'); }
function _isFile(st) { return _callType(st, 'isFile'); }
function _isLink(st) { return _callType(st, 'isSymbolicLink'); }
function _isSocket(st) { return _callType(st, 'isSocket'); }
function _isFIFO(st) { return _callType(st, 'isFIFO'); }
function _isChar(st) { return _callType(st, 'isCharacterDevice'); }
function _isBlock(st) { return _callType(st, 'isBlockDevice'); }

function areIdentical(srcStat, destStat) {
    return !!(destStat && srcStat && destStat.ino && destStat.dev &&
        destStat.ino === srcStat.ino && destStat.dev === srcStat.dev);
}

function _normalizePathToArray(p) {
    return pathMod.resolve(p).split(pathMod.sep).filter(Boolean);
}

// True if dest is inside src (string comparison of resolved paths).
function isSrcSubdir(src, dest) {
    var srcArr = _normalizePathToArray(src);
    var destArr = _normalizePathToArray(dest);
    for (var i = 0; i < srcArr.length; i++) {
        if (destArr[i] !== srcArr[i]) return false;
    }
    return true;
}

// ── Sync engine (drives both cpSync and — via awaited filters — fs.cp) ───────
// `S` carries {fs, opts, filterFn} where filterFn(src,dest) is a SYNC decision
// function; the async driver pre-resolves user filters before invoking.

function _statNoEnt(fs, p, dereference) {
    try {
        return dereference ? fs.statSync(p) : fs.lstatSync(p);
    } catch (e) {
        if (e && e.code === 'ENOENT') return null;
        throw e;
    }
}

function _checkPathsStats(S, src, dest) {
    var srcStat = S.opts.dereference ? S.fs.statSync(src) : S.fs.lstatSync(src);
    var destStat = _statNoEnt(S.fs, dest, S.opts.dereference);
    if (destStat) {
        if (areIdentical(srcStat, destStat)) {
            throw _einval('src and dest cannot be the same', dest);
        }
        if (_isDir(srcStat) && !_isDir(destStat)) {
            throw _cpErr('ERR_FS_CP_DIR_TO_NON_DIR', {
                message: 'cannot overwrite non-directory ' + dest +
                         ' with directory ' + src,
                path: dest, code: 'EISDIR', errno: -21
            });
        }
        if (!_isDir(srcStat) && _isDir(destStat)) {
            throw _cpErr('ERR_FS_CP_NON_DIR_TO_DIR', {
                message: 'cannot overwrite directory ' + dest +
                         ' with non-directory ' + src,
                path: dest, code: 'ENOTDIR', errno: -20
            });
        }
    }
    if (_isDir(srcStat) && isSrcSubdir(src, dest)) {
        throw _einval('cannot copy ' + src + ' to a subdirectory of self ' + dest, dest);
    }
    return { srcStat: srcStat, destStat: destStat };
}

// Walk up dest's parents comparing inodes against srcStat (catches copying a
// directory into itself through renames/symlinked parents).
function _checkParentPaths(S, src, srcStat, dest) {
    var srcParent = pathMod.resolve(pathMod.dirname(src));
    var destParent = pathMod.resolve(pathMod.dirname(dest));
    if (destParent === srcParent || destParent === pathMod.parse(destParent).root) {
        return;
    }
    var destStat;
    try {
        destStat = S.fs.statSync(destParent);
    } catch (e) {
        if (e && e.code === 'ENOENT') return;
        throw e;
    }
    if (areIdentical(srcStat, destStat)) {
        throw _einval('cannot copy ' + src + ' to a subdirectory of self ' + dest, dest);
    }
    return _checkParentPaths(S, src, srcStat, destParent);
}

function _pathExists(fs, p) {
    try { fs.statSync(p); return true; }
    catch (e) { if (e && e.code === 'ENOENT') return false; throw e; }
}

function _getStatsForCopy(S, destStat, src, dest) {
    var srcStat = S.opts.dereference ? S.fs.statSync(src) : S.fs.lstatSync(src);
    if (_isDir(srcStat) && S.opts.recursive) {
        return _onDir(S, srcStat, destStat, src, dest);
    } else if (_isDir(srcStat)) {
        throw _cpErr('ERR_FS_EISDIR', {
            message: src + ' is a directory (not copied)',
            path: src, code: 'EISDIR', errno: -21
        });
    } else if (_isFile(srcStat) || _isChar(srcStat) || _isBlock(srcStat)) {
        return _onFile(S, srcStat, destStat, src, dest);
    } else if (_isLink(srcStat)) {
        return _onLink(S, destStat, src, dest);
    } else if (_isSocket(srcStat)) {
        throw _cpErr('ERR_FS_CP_SOCKET', {
            message: 'cannot copy a socket file: ' + dest, path: dest,
            code: 'EINVAL', errno: -22
        });
    } else if (_isFIFO(srcStat)) {
        throw _cpErr('ERR_FS_CP_FIFO_PIPE', {
            message: 'cannot copy a FIFO pipe: ' + dest, path: dest,
            code: 'EINVAL', errno: -22
        });
    }
    throw _cpErr('ERR_FS_CP_UNKNOWN', {
        message: 'cannot copy an unknown file type: ' + dest, path: dest,
        code: 'EINVAL', errno: -22
    });
}

function _onFile(S, srcStat, destStat, src, dest) {
    if (!destStat) return _doCopyFile(S, srcStat, src, dest);
    // dest exists
    if (S.opts.force) {
        S.fs.unlinkSync(dest);
        return _doCopyFile(S, srcStat, src, dest);
    }
    if (S.opts.errorOnExist) {
        throw _cpErr('ERR_FS_CP_EEXIST', {
            message: dest + ' already exists', path: dest,
            code: 'EEXIST', errno: -17
        });
    }
}

function _doCopyFile(S, srcStat, src, dest) {
    S.fs.copyFileSync(src, dest, S.opts.mode);
    var srcMode = typeof srcStat.mode === 'number' ? srcStat.mode : null;
    if (S.opts.preserveTimestamps) {
        // A read-only file must be made writable before utimes (open r+).
        if (srcMode !== null && (srcMode & 0o200) === 0) {
            _chmodSafe(S.fs, dest, srcMode | 0o200);
        }
        _setDestTimestamps(S.fs, src, dest);
    }
    if (srcMode !== null) _chmodSafe(S.fs, dest, srcMode);
}

function _chmodSafe(fs, dest, mode) {
    try { fs.chmodSync(dest, mode & 0o7777); } catch (_e) { /* best-effort */ }
}

function _setDestTimestamps(fs, src, dest) {
    try {
        // Re-stat: the source atime was just modified by the copy read.
        var updated = fs.statSync(src);
        var atime = updated.atime || (updated.atimeMs != null ? new Date(updated.atimeMs) : null);
        var mtime = updated.mtime || (updated.mtimeMs != null ? new Date(updated.mtimeMs) : null);
        if (atime && mtime && typeof fs.utimesSync === 'function') {
            fs.utimesSync(dest, atime, mtime);
        }
    } catch (_e) { /* best-effort */ }
}

function _onDir(S, srcStat, destStat, src, dest) {
    if (!destStat) {
        S.fs.mkdirSync(dest);
        _copyDirEntries(S, src, dest);
        if (typeof srcStat.mode === 'number') _chmodSafe(S.fs, dest, srcStat.mode);
        return;
    }
    if (S.opts.errorOnExist && !S.opts.force) {
        throw _cpErr('ERR_FS_CP_EEXIST', {
            message: dest + ' already exists', path: dest,
            code: 'EEXIST', errno: -17
        });
    }
    return _copyDirEntries(S, src, dest);
}

function _copyDirEntries(S, src, dest) {
    var entries = S.fs.readdirSync(src);
    for (var i = 0; i < entries.length; i++) {
        var name = entries[i];
        var srcItem = pathMod.join(src, name);
        var destItem = pathMod.join(dest, name);
        if (S.filterFn && !S.filterFn(srcItem, destItem)) continue;
        var checked = _checkPathsStats(S, srcItem, destItem);
        _getStatsForCopy(S, checked.destStat, srcItem, destItem);
    }
}

function _onLink(S, destStat, src, dest) {
    var resolvedSrc = S.fs.readlinkSync(src);
    if (!S.opts.verbatimSymlinks && !pathMod.isAbsolute(resolvedSrc)) {
        resolvedSrc = pathMod.resolve(pathMod.dirname(src), resolvedSrc);
    }
    if (!destStat) {
        return S.fs.symlinkSync(resolvedSrc, dest);
    }
    var resolvedDest;
    try {
        resolvedDest = S.fs.readlinkSync(dest);
    } catch (e) {
        // dest exists but is a regular file/directory
        if (e && (e.code === 'EINVAL' || e.code === 'UNKNOWN')) {
            return S.fs.symlinkSync(resolvedSrc, dest);
        }
        throw e;
    }
    if (typeof resolvedDest !== 'string') {
        // Engine readlink returns undefined (not EINVAL) for non-symlinks —
        // same meaning: dest is a regular file, let symlink throw EEXIST.
        return S.fs.symlinkSync(resolvedSrc, dest);
    }
    if (!pathMod.isAbsolute(resolvedDest)) {
        resolvedDest = pathMod.resolve(pathMod.dirname(dest), resolvedDest);
    }
    var srcIsDir = false;
    try { srcIsDir = _isDir(S.fs.statSync(src)); } catch (_e) {}
    if (srcIsDir && isSrcSubdir(resolvedSrc, resolvedDest)) {
        throw _einval('cannot copy ' + resolvedSrc +
                      ' to a subdirectory of self ' + resolvedDest, dest);
    }
    // Unlinking dest when src lives inside dest's target would break src.
    if (srcIsDir && isSrcSubdir(resolvedDest, resolvedSrc)) {
        throw _cpErr('ERR_FS_CP_SYMLINK_TO_SUBDIRECTORY', {
            message: 'cannot overwrite ' + resolvedDest + ' with ' + resolvedSrc,
            path: dest, code: 'EINVAL', errno: -22
        });
    }
    S.fs.unlinkSync(dest);
    return S.fs.symlinkSync(resolvedSrc, dest);
}

// Top-level drive shared by sync/async paths once filterFn is sync.
function _cpDrive(fs, src, dest, opts, filterFn) {
    var S = { fs: fs, opts: opts, filterFn: filterFn };
    if (filterFn && !filterFn(src, dest)) return;
    var checked = _checkPathsStats(S, src, dest);
    _checkParentPaths(S, src, checked.srcStat, dest);
    var destParent = pathMod.dirname(dest);
    if (!_pathExists(fs, destParent)) {
        fs.mkdirSync(destParent, { recursive: true });
    }
    return _getStatsForCopy(S, checked.destStat, src, dest);
}

function _syncFilter(filter) {
    if (!filter) return null;
    return function (s, d) {
        var ret = filter(s, d);
        if (ret && typeof ret.then === 'function') {
            var e = new TypeError(
                'Expected a boolean value from filter for ' + s +
                '. Received a Promise (async filter not supported in sync cp)');
            e.code = 'ERR_INVALID_RETURN_VALUE';
            throw e;
        }
        return !!ret;
    };
}

function cpSync(fs, src, dest, options) {
    var opts = validateCpOptions(options);
    return _cpDrive(fs, String(src), String(dest), opts, _syncFilter(opts.filter));
}

// Async driver: awaits the user filter per item by pre-walking with an async
// recursion mirroring the sync engine's traversal order.
// Structured with promise chains (not throws after awaits): a sync throw in a
// resumed async frame can escape the engine's unwinder when the continuation
// runs inside a native callback (see the fs.watch/net re-entry unwind bugs) —
// .then callbacks convert throws to rejections reliably.
function _cpAsync(fs, src, dest, opts) {
    var filter = opts.filter;
    var S = { fs: fs, opts: opts, filterFn: null };

    function allow(s, d) {
        if (!filter) return Promise.resolve(true);
        return Promise.resolve().then(function () {
            return filter(s, d);
        }).then(function (r) { return !!r; });
    }

    function copyItem(s, d, isTop) {
        return allow(s, d).then(function (allowed) {
            if (!allowed) return;
            var checked = _checkPathsStats(S, s, d);
            if (isTop) {
                _checkParentPaths(S, s, checked.srcStat, d);
                var destParent = pathMod.dirname(d);
                if (!_pathExists(fs, destParent)) {
                    fs.mkdirSync(destParent, { recursive: true });
                }
            }
            var srcStat = opts.dereference ? fs.statSync(s) : fs.lstatSync(s);
            if (_isDir(srcStat) && opts.recursive) {
                var destStat = checked.destStat;
                if (!destStat) {
                    fs.mkdirSync(d);
                } else if (opts.errorOnExist && !opts.force) {
                    throw _cpErr('ERR_FS_CP_EEXIST', {
                        message: d + ' already exists', path: d,
                        code: 'EEXIST', errno: -17
                    });
                }
                var entries = fs.readdirSync(s);
                var chain = Promise.resolve();
                entries.forEach(function (name) {
                    chain = chain.then(function () {
                        return copyItem(pathMod.join(s, name), pathMod.join(d, name), false);
                    });
                });
                return chain.then(function () {
                    if (!destStat && typeof srcStat.mode === 'number') {
                        _chmodSafe(fs, d, srcStat.mode);
                    }
                });
            }
            // Non-directory items share the sync handlers (no filter below here).
            return _getStatsForCopy(S, checked.destStat, s, d);
        });
    }

    return copyItem(String(src), String(dest), true);
}

function cpPromise(fs, src, dest, options) {
    var opts;
    try {
        opts = validateCpOptions(options);
    } catch (e) {
        return Promise.reject(e);
    }
    return _cpAsync(fs, src, dest, opts);
}

function cpCallback(fs, src, dest, options, callback) {
    if (typeof options === 'function') {
        callback = options;
        options = {};
    }
    if (typeof callback !== 'function') {
        throw errors.errInvalidArgType('cb', 'function', callback);
    }
    // Options validation throws synchronously (Node validateCpOptions order).
    var opts = validateCpOptions(options);
    _cpAsync(fs, src, dest, opts).then(
        function () { callback(null); },
        function (e) { callback(e); }
    );
}

module.exports = {
    cpSync: cpSync,
    cpCallback: cpCallback,
    cpPromise: cpPromise
};
