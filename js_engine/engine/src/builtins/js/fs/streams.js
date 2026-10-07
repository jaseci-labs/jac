// fs/streams.js — ReadStream / WriteStream with patchable open + destroy/autoClose
'use strict';

var _errors = require('./errors.js');
var _validators = require('./validators.js');

function installStreams(nativeFs, helpers) {
    var nodeStream = require('stream');
    var Readable = nodeStream.Readable;
    var Writable = nodeStream.Writable;
    var nextTick = helpers.nextTick;
    var pathArg = helpers.pathArg;

    function _invalidFsProp(name, actual) {
        var suffix;
        if (actual === null || actual === undefined) {
            suffix = ' Received ' + actual;
        } else if (typeof actual === 'string') {
            suffix = " Received type string ('" + actual + "')";
        } else {
            suffix = ' Received type ' + typeof actual + ' (' + String(actual) + ')';
        }
        var err = new TypeError(
            'The "options.fs.' + name + '" property must be of type function.' + suffix
        );
        err.code = 'ERR_INVALID_ARG_TYPE';
        return err;
    }

    function _validateFsMethod(fsImpl, name, required) {
        var fn = fsImpl[name];
        // undefined = omitted (ok unless required). null / non-function = always invalid.
        if (fn === undefined) {
            if (required) { throw _invalidFsProp(name, fn); }
            return;
        }
        if (typeof fn !== 'function') {
            throw _invalidFsProp(name, fn);
        }
    }

    function _pickFs(options) {
        var fsImpl = (options && options.fs) ? options.fs : nativeFs;
        return fsImpl;
    }

    function _fsStreamOpts(path, options) {
        var opts = {
            path: path !== undefined && path !== null ? pathArg(path) : null,
            fd: null,
            handle: null,
            flags: 'r',
            mode: 438,
            autoClose: true,
            emitClose: true,
            start: undefined,
            end: Infinity,
            encoding: null,
            highWaterMark: 64 * 1024,
            flush: false,
            fs: null
        };
        if (options === undefined || options === null) {
            return opts;
        }
        if (typeof options === 'string') {
            opts.encoding = options;
        } else if (typeof options === 'object') {
            if (options.fd !== undefined && options.fd !== null) {
                var optFd = options.fd;
                if (typeof optFd === 'object' && optFd !== null &&
                    typeof optFd.fd === 'number') {
                    // FileHandle (fs.promises.open) — stream drives its raw fd.
                    opts.handle = optFd;
                    opts.fd = optFd.fd;
                } else if (typeof optFd !== 'number') {
                    throw _errors.errInvalidArgType(
                        'fd', 'number or an instance of FileHandle', optFd);
                } else {
                    if (!Number.isInteger(optFd) || optFd < 0) {
                        throw _errors.errOutOfRange('fd', '>= 0 && <= 2147483647', optFd);
                    }
                    opts.fd = optFd;
                }
            }
            if (options.flags !== undefined) opts.flags = options.flags;
            if (options.mode !== undefined) {
                opts.mode = _validators.validateMode(options.mode, 'mode');
            }
            if (options.autoClose !== undefined) opts.autoClose = !!options.autoClose;
            if (options.emitClose !== undefined) opts.emitClose = !!options.emitClose;
            if (options.start !== undefined) {
                _validators.validateInteger(options.start, 'start', 0);
                opts.start = options.start;
            }
            if (options.end !== undefined && options.end !== Infinity) {
                _validators.validateInteger(options.end, 'end', 0);
                opts.end = options.end;
            }
            if (opts.start !== undefined && opts.end !== Infinity && opts.start > opts.end) {
                throw _errors.errOutOfRange(
                    'start', '<= "end" (here: ' + opts.end + ')', opts.start);
            }
            if (options.encoding !== undefined) opts.encoding = options.encoding;
            if (options.highWaterMark !== undefined) opts.highWaterMark = options.highWaterMark;
            if (options.flush !== undefined && options.flush !== null) opts.flush = !!options.flush;
            if (options.fs !== undefined) opts.fs = options.fs;
        } else {
            throw _errors.errInvalidArgType('options', 'string or Object', options);
        }
        if (opts.encoding !== undefined && opts.encoding !== null) {
            opts.encoding = _validators.validateEncoding(opts.encoding, 'encoding');
        }
        return opts;
    }

    // autoClose lives behind a prototype accessor with a brand check — Node
    // throws ERR_INVALID_THIS when it is read off the prototype directly.
    function _defineAutoClose(Ctor) {
        Object.defineProperty(Ctor.prototype, 'autoClose', {
            configurable: true,
            enumerable: true,
            get: function () {
                if (!(this instanceof Ctor)) {
                    var eg = new TypeError('Value of "this" must be of type ' + Ctor.name);
                    eg.code = 'ERR_INVALID_THIS';
                    throw eg;
                }
                return this._autoClose;
            },
            set: function (v) {
                if (!(this instanceof Ctor)) {
                    var es = new TypeError('Value of "this" must be of type ' + Ctor.name);
                    es.code = 'ERR_INVALID_THIS';
                    throw es;
                }
                this._autoClose = v;
            }
        });
    }

    function _emitOpenReady(self) {
        nextTick(function () {
            if (self.destroyed) return;
            self.emit('open', self.fd);
            self.emit('ready');
            if (typeof self.read === 'function') {
                self.read(0);
            }
        });
    }

    function ReadStream(path, options) {
        if (!(this instanceof ReadStream)) {
            return new ReadStream(path, options);
        }
        var opts = _fsStreamOpts(path, options);
        if (opts.flags === undefined || opts.flags === null) opts.flags = 'r';
        this._fs = _pickFs(opts);
        _validateFsMethod(this._fs, 'open', opts.fd == null);
        _validateFsMethod(this._fs, 'read', true);
        if (opts.autoClose !== false) {
            _validateFsMethod(this._fs, 'close', true);
        }

        Readable.call(this, {
            highWaterMark: opts.highWaterMark,
            encoding: opts.encoding || undefined,
            emitClose: opts.emitClose
        });
        // Readable() assigns a no-op instance _read that shadows prototype._read.
        delete this._read;
        if (ReadStream.prototype._destroy) {
            delete this._destroy;
        }
        this.path = opts.path;
        this.fd = opts.fd != null ? opts.fd : null;
        this.flags = opts.flags;
        this.mode = opts.mode;
        this.autoClose = opts.autoClose;
        this.bytesRead = 0;
        this._pos = typeof opts.start === 'number' ? opts.start : null;
        this._end = typeof opts.end === 'number' ? opts.end : Infinity;
        this._opening = false;
        this._opened = this.fd !== null && this.fd !== undefined;
        if (this._opened) {
            _emitOpenReady(this);
        } else if (this.path !== null) {
            this.open();
        }
    }
    ReadStream.prototype = Object.create(Readable.prototype);
    ReadStream.prototype.constructor = ReadStream;
    _defineAutoClose(ReadStream);

    Object.defineProperty(ReadStream.prototype, 'pending', {
        configurable: true,
        enumerable: true,
        get: function () { return this.fd === null || this.fd === undefined; }
    });

    ReadStream.prototype.open = function () {
        var self = this;
        if (self._opened || self._opening || self.destroyed) return;
        self._opening = true;
        var fsImpl = self._fs;
        fsImpl.open(self.path, self.flags, self.mode, function (er, fd) {
            self._opening = false;
            if (er) {
                nextTick(function () {
                    if (typeof self.destroy === 'function') self.destroy(er);
                    else self.emit('error', er);
                });
                return;
            }
            self.fd = fd;
            self._opened = true;
            _emitOpenReady(self);
        });
    };

    ReadStream.prototype._read = function (size) {
        if (this.destroyed) return;
        if (this.fd === null || this.fd === undefined || this.fd < 0) {
            return;
        }
        var toRead = size;
        if (this._pos !== null && this._end !== Infinity) {
            var remaining = this._end - this._pos + 1;
            if (remaining <= 0) { this.push(null); return; }
            if (toRead > remaining) toRead = remaining;
        }
        if (toRead <= 0) toRead = 64 * 1024;
        var buf = Buffer.alloc(toRead);
        var self = this;
        var pos = this._pos;
        this._fs.read(this.fd, buf, 0, toRead, pos, function (er, bytesRead) {
            if (self.destroyed) return;
            if (er && er.code === 'EAGAIN' && !self._eagainRetried) {
                self._eagainRetried = true;
                return self._fs.read(self.fd, buf, 0, toRead, pos, function (er2, br2) {
                    self._eagainRetried = false;
                    if (er2) {
                        self.destroy(er2);
                        return;
                    }
                    if (br2 > 0) {
                        if (self._pos !== null) self._pos += br2;
                        self.bytesRead += br2;
                        self.push(buf.slice(0, br2));
                    } else {
                        self.push(null);
                    }
                });
            }
            if (er) {
                self.destroy(er);
                return;
            }
            if (bytesRead > 0) {
                if (self._pos !== null) self._pos += bytesRead;
                self.bytesRead += bytesRead;
                self.push(buf.slice(0, bytesRead));
            } else {
                self.push(null);
            }
        });
    };

    ReadStream.prototype._destroy = function (err, cb) {
        var self = this;
        function done(closeErr) {
            cb(err || closeErr || null);
        }
        if (this.autoClose && this.fd !== null && this.fd !== undefined && this.fd >= 0) {
            var fd = this.fd;
            this.fd = null;
            var closeFn = this._fs.close;
            if (typeof closeFn === 'function' && closeFn.length >= 2) {
                closeFn.call(this._fs, fd, done);
            } else {
                try {
                    if (typeof nativeFs.closeSync === 'function') nativeFs.closeSync(fd);
                    done(null);
                } catch (e) { done(e); }
            }
        } else {
            done(null);
        }
    };

    ReadStream.prototype.close = function (cb) {
        this.destroy(null, cb);
    };

    function WriteStream(path, options) {
        if (!(this instanceof WriteStream)) {
            return new WriteStream(path, options);
        }
        var opts = _fsStreamOpts(path, options);
        if (opts.flags === undefined || opts.flags === null || opts.flags === 'r') opts.flags = 'w';
        this._fs = _pickFs(opts);
        _validateFsMethod(this._fs, 'open', opts.fd == null);
        // null overrides must throw for the named property (not fall through to writev).
        if (this._fs.write !== undefined) {
            _validateFsMethod(this._fs, 'write', true);
        } else {
            _validateFsMethod(this._fs, 'writev', true);
        }
        if (this._fs.writev !== undefined) {
            _validateFsMethod(this._fs, 'writev', true);
        }
        if (opts.autoClose !== false) {
            _validateFsMethod(this._fs, 'close', true);
        }
        if (opts.flush) {
            _validateFsMethod(this._fs, 'fsync', true);
        }

        Writable.call(this, {
            highWaterMark: opts.highWaterMark,
            emitClose: opts.emitClose,
            decodeStrings: true
        });
        delete this._write;
        if (WriteStream.prototype._destroy) {
            delete this._destroy;
        }
        this.path = opts.path;
        this.fd = opts.fd != null ? opts.fd : null;
        this.flags = opts.flags;
        this.mode = opts.mode;
        this.autoClose = opts.autoClose;
        this.flush = opts.flush;
        this.bytesWritten = 0;
        this._pos = typeof opts.start === 'number' ? opts.start : null;
        this._opening = false;
        this._opened = this.fd !== null && this.fd !== undefined;
        if (this._opened) {
            nextTick(function () {
                if (!this.destroyed) {
                    this.emit('open', this.fd);
                    this.emit('ready');
                }
            }.bind(this));
        } else if (this.path !== null) {
            this.open();
        }
    }
    WriteStream.prototype = Object.create(Writable.prototype);
    WriteStream.prototype.constructor = WriteStream;
    _defineAutoClose(WriteStream);

    Object.defineProperty(WriteStream.prototype, 'pending', {
        configurable: true,
        enumerable: true,
        get: function () { return this.fd === null || this.fd === undefined; }
    });

    WriteStream.prototype.open = function () {
        var self = this;
        if (self._opened || self._opening || self.destroyed) return;
        self._opening = true;
        self._fs.open(self.path, self.flags, self.mode, function (er, fd) {
            self._opening = false;
            if (er) {
                nextTick(function () {
                    if (typeof self.destroy === 'function') self.destroy(er);
                    else self.emit('error', er);
                });
                return;
            }
            self.fd = fd;
            self._opened = true;
            nextTick(function () {
                if (!self.destroyed) {
                    self.emit('open', fd);
                    self.emit('ready');
                }
            });
        });
    };

    function _writeOnce(self, chunk, encoding, callback, retried) {
        try {
            if (!Buffer.isBuffer(chunk)) chunk = Buffer.from(chunk, encoding || 'utf8');
            var n = self._fs.writeSync(self.fd, chunk, 0, chunk.length, self._pos);
            if (self._pos !== null) self._pos += n;
            self.bytesWritten += n;
            callback();
        } catch (err) {
            if (!retried && err && err.code === 'EAGAIN') {
                return _writeOnce(self, chunk, encoding, callback, true);
            }
            callback(err);
        }
    }

    WriteStream.prototype._write = function (chunk, encoding, callback) {
        if (this.fd === null || this.fd === undefined || this.fd < 0) {
            var self = this;
            this.once('open', function () {
                self._write(chunk, encoding, callback);
            });
            return;
        }
        var fsImpl = this._fs;
        if (typeof fsImpl.write === 'function' && fsImpl.write.length >= 6) {
            var self2 = this;
            var buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk, encoding || 'utf8');
            fsImpl.write(this.fd, buf, 0, buf.length, this._pos, function (er, written) {
                if (er && er.code === 'EAGAIN' && !self2._eagainRetried) {
                    self2._eagainRetried = true;
                    return fsImpl.write(self2.fd, buf, 0, buf.length, self2._pos, function (er2, w2) {
                        self2._eagainRetried = false;
                        if (er2) return callback(er2);
                        if (self2._pos !== null) self2._pos += w2;
                        self2.bytesWritten += w2;
                        callback();
                    });
                }
                self2._eagainRetried = false;
                if (er) return callback(er);
                if (self2._pos !== null) self2._pos += written;
                self2.bytesWritten += written;
                callback();
            });
            return;
        }
        _writeOnce(this, chunk, encoding, callback, false);
    };

    WriteStream.prototype._destroy = function (err, cb) {
        var self = this;
        function closeFd(flushErr) {
            if (self.autoClose && self.fd !== null && self.fd !== undefined && self.fd >= 0) {
                var fd = self.fd;
                self.fd = null;
                var closeFn = self._fs.close;
                if (typeof closeFn === 'function' && closeFn.length >= 2) {
                    closeFn.call(self._fs, fd, function (closeErr) {
                        cb(err || flushErr || closeErr || null);
                    });
                } else {
                    try {
                        if (typeof nativeFs.closeSync === 'function') nativeFs.closeSync(fd);
                        cb(err || flushErr || null);
                    } catch (e) { cb(err || flushErr || e); }
                }
            } else {
                cb(err || flushErr || null);
            }
        }
        if (self.flush && self.fd !== null && self.fd !== undefined && self.fd >= 0) {
            var fsync = self._fs.fsync;
            if (typeof fsync === 'function' && fsync.length >= 2) {
                fsync.call(self._fs, self.fd, function (flushErr) { closeFd(flushErr); });
            } else {
                try {
                    if (typeof self._fs.fsyncSync === 'function') self._fs.fsyncSync(self.fd);
                    closeFd(null);
                } catch (e) { closeFd(e); }
            }
        } else {
            closeFd(null);
        }
    };

    WriteStream.prototype.close = function (cb) {
        this.destroy(null, cb);
    };

    nativeFs.ReadStream = ReadStream;
    nativeFs.WriteStream = WriteStream;
    nativeFs.FileReadStream = ReadStream;
    nativeFs.FileWriteStream = WriteStream;

    nativeFs.createReadStream = function (path, options) {
        return new ReadStream(path, options);
    };

    nativeFs.createWriteStream = function (path, options) {
        return new WriteStream(path, options);
    };

    return { ReadStream: ReadStream, WriteStream: WriteStream };
}

module.exports = {
    installStreams: installStreams
};
