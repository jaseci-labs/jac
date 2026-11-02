// fs/filehandle.js — Node-compatible FileHandle for fs.promises.open
'use strict';

function makeFileHandle(fd, nativeFs, streamClasses) {
    var handle = {
        fd: fd,
        read: function (buffer, offset, length, position) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try {
                    if (buffer === undefined || (typeof buffer === 'object' && buffer !== null &&
                        !Buffer.isBuffer(buffer) && !(buffer instanceof Uint8Array) &&
                        typeof buffer.length !== 'number')) {
                        var opts = buffer || {};
                        buffer = opts.buffer || Buffer.alloc(16384);
                        offset = opts.offset;
                        length = opts.length;
                        position = opts.position;
                    }
                    var bytesRead = nativeFs.readSync(self.fd, buffer, offset, length, position);
                    resolve({ bytesRead: bytesRead, buffer: buffer });
                } catch (e) { reject(e); }
            });
        },
        write: function (buffer, offset, length, position) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try {
                    if (typeof buffer === 'string') {
                        var enc = 'utf8';
                        if (typeof offset === 'string') {
                            enc = offset; offset = undefined; length = undefined; position = undefined;
                        } else if (typeof length === 'string') {
                            enc = length; length = undefined;
                        }
                        buffer = Buffer.from(String(buffer), enc);
                        offset = 0;
                        length = buffer.length;
                    } else if (buffer && typeof buffer === 'object' && !Buffer.isBuffer(buffer) &&
                               !(buffer instanceof Uint8Array) && buffer.buffer === undefined &&
                               typeof buffer.length !== 'number') {
                        var wopts = buffer;
                        buffer = wopts.buffer;
                        offset = wopts.offset;
                        length = wopts.length;
                        position = wopts.position;
                    }
                    var bytesWritten = nativeFs.writeSync(self.fd, buffer, offset, length, position);
                    resolve({ bytesWritten: bytesWritten, buffer: buffer });
                } catch (e) { reject(e); }
            });
        },
        readv: function (buffers, position) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try {
                    var bytesRead = nativeFs.readvSync(self.fd, buffers, position);
                    resolve({ bytesRead: bytesRead, buffers: buffers });
                } catch (e) { reject(e); }
            });
        },
        writev: function (buffers, position) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try {
                    var bytesWritten = nativeFs.writevSync(self.fd, buffers, position);
                    resolve({ bytesWritten: bytesWritten, buffers: buffers });
                } catch (e) { reject(e); }
            });
        },
        close: function () {
            var self = this;
            return new Promise(function (res, rej) {
                try {
                    if (self.fd >= 0) {
                        nativeFs.closeSync(self.fd);
                        self.fd = -1;
                    }
                    res();
                } catch (e) { rej(e); }
            });
        },
        stat: function () {
            var self = this;
            return new Promise(function (resolve, reject) {
                try { resolve(nativeFs.fstatSync(self.fd)); } catch (e) { reject(e); }
            });
        },
        truncate: function (len) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try { nativeFs.ftruncateSync(self.fd, len !== undefined ? len : 0); resolve(); }
                catch (e) { reject(e); }
            });
        },
        utimes: function (atime, mtime) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try { nativeFs.futimesSync(self.fd, atime, mtime); resolve(); }
                catch (e) { reject(e); }
            });
        },
        sync: function () {
            var self = this;
            return new Promise(function (resolve, reject) {
                try { nativeFs.fsyncSync(self.fd); resolve(); } catch (e) { reject(e); }
            });
        },
        datasync: function () {
            var self = this;
            return new Promise(function (resolve, reject) {
                try { nativeFs.fdatasyncSync(self.fd); resolve(); } catch (e) { reject(e); }
            });
        },
        chmod: function (mode) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try { nativeFs.fchmodSync(self.fd, mode); resolve(); } catch (e) { reject(e); }
            });
        },
        chown: function (uid, gid) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try { nativeFs.fchownSync(self.fd, uid, gid); resolve(); } catch (e) { reject(e); }
            });
        },
        writeFile: function (data, options) {
            var self = this;
            var enc = 'utf8';
            var signal = undefined;
            if (typeof options === 'string') enc = options;
            else if (options && typeof options === 'object') {
                if (options.encoding) enc = options.encoding;
                if (options.signal) signal = options.signal;
            }

            function abortErr() {
                var e = new Error('The operation was aborted');
                e.name = 'AbortError';
                e.code = 'ABORT_ERR';
                return e;
            }
            function checkAbort() {
                if (signal && signal.aborted) throw (signal.reason || abortErr());
            }
            function chunkToBuf(chunk) {
                if (typeof chunk === 'string') return Buffer.from(chunk, enc);
                if (Buffer.isBuffer(chunk)) return chunk;
                if (chunk instanceof Uint8Array) return Buffer.from(chunk);
                var err = new TypeError(
                    'The "chunk" argument must be of type string or an instance of Buffer, ' +
                    'TypedArray, or DataView. Received ' + typeof chunk
                );
                err.code = 'ERR_INVALID_ARG_TYPE';
                throw err;
            }
            function writeAt(buf, pos) {
                var o = 0;
                var p = pos;
                while (o < buf.length) {
                    checkAbort();
                    var n = nativeFs.writeSync(self.fd, buf, o, buf.length - o, p);
                    if (n <= 0) break;
                    o += n;
                    p += n;
                }
                return p;
            }
            function isAsyncIterable(x) {
                return x && typeof x === 'object' &&
                    typeof Symbol !== 'undefined' && Symbol.asyncIterator &&
                    typeof x[Symbol.asyncIterator] === 'function';
            }
            function isIterable(x) {
                return x && typeof x === 'object' &&
                    typeof Symbol !== 'undefined' && Symbol.iterator &&
                    typeof x[Symbol.iterator] === 'function' &&
                    !Buffer.isBuffer(x) && !(x instanceof Uint8Array) &&
                    typeof x.pipe !== 'function';
            }

            if (signal && signal.aborted) {
                return Promise.reject(signal.reason || abortErr());
            }

            // Streams / async iterables / sync iterables
            if (isAsyncIterable(data) || (data && typeof data.pipe === 'function') || isIterable(data)) {
                return (async function () {
                    checkAbort();
                    try { nativeFs.ftruncateSync(self.fd, 0); } catch (_t) {}
                    var pos = 0;
                    var aborted = false;
                    var onAbort = null;
                    if (signal && typeof signal.addEventListener === 'function') {
                        onAbort = function () { aborted = true; };
                        signal.addEventListener('abort', onAbort, { once: true });
                    }
                    try {
                        if (aborted || (signal && signal.aborted)) throw (signal.reason || abortErr());

                        if (isAsyncIterable(data)) {
                            for await (var chunk of data) {
                                if (aborted || (signal && signal.aborted)) throw (signal.reason || abortErr());
                                pos = writeAt(chunkToBuf(chunk), pos);
                            }
                        } else if (data && typeof data.pipe === 'function') {
                            await new Promise(function (resolve, reject) {
                                var done = false;
                                function finish(err) {
                                    if (done) return;
                                    done = true;
                                    if (err) reject(err); else resolve();
                                }
                                data.on('data', function (chunk) {
                                    try {
                                        if (aborted || (signal && signal.aborted)) {
                                            finish(signal.reason || abortErr());
                                            return;
                                        }
                                        pos = writeAt(chunkToBuf(chunk), pos);
                                    } catch (e) { finish(e); }
                                });
                                data.on('error', finish);
                                data.on('end', function () { finish(null); });
                                if (typeof data.resume === 'function') data.resume();
                            });
                        } else {
                            for (var chunk2 of data) {
                                if (aborted || (signal && signal.aborted)) throw (signal.reason || abortErr());
                                pos = writeAt(chunkToBuf(chunk2), pos);
                            }
                        }
                    } finally {
                        if (signal && onAbort && typeof signal.removeEventListener === 'function') {
                            try { signal.removeEventListener('abort', onAbort); } catch (_r) {}
                        }
                    }
                })();
            }

            // Buffer/string path — yield once so nextTick abort can win (Node race).
            return (async function () {
                if (typeof data !== 'string' && !Buffer.isBuffer(data) && !(data instanceof Uint8Array)) {
                    var te = new TypeError(
                        'The "data" argument must be of type string or an instance of Buffer, ' +
                        'TypedArray, DataView, or Iterable. Received ' + typeof data
                    );
                    te.code = 'ERR_INVALID_ARG_TYPE';
                    throw te;
                }
                if (signal) {
                    await new Promise(function (r) {
                        if (typeof setImmediate === 'function') setImmediate(r);
                        else process.nextTick(r);
                    });
                    checkAbort();
                }
                var buf = typeof data === 'string' ? Buffer.from(data, enc)
                    : (Buffer.isBuffer(data) ? data : Buffer.from(data));
                try { nativeFs.ftruncateSync(self.fd, 0); } catch (_t2) {}
                // Chunked write so abort can interrupt large payloads.
                var pos = 0;
                var CHUNK = 64 * 1024;
                while (pos < buf.length) {
                    checkAbort();
                    var end = pos + CHUNK;
                    if (end > buf.length) end = buf.length;
                    writeAt(buf.slice(pos, end), pos);
                    pos = end;
                    if (signal && pos < buf.length) {
                        await new Promise(function (r) { process.nextTick(r); });
                    }
                }
            })();
        },
        appendFile: function (data, options) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try {
                    var enc = 'utf8';
                    if (typeof options === 'string') enc = options;
                    else if (options && typeof options === 'object' && options.encoding) {
                        enc = options.encoding;
                    }
                    var buf;
                    if (typeof data === 'string') {
                        buf = Buffer.from(data, enc);
                    } else if (Buffer.isBuffer(data)) {
                        buf = data;
                    } else if (data instanceof Uint8Array) {
                        buf = Buffer.from(data);
                    } else {
                        buf = Buffer.from(String(data), enc);
                    }
                    var st = nativeFs.fstatSync(self.fd);
                    var pos = (st && typeof st.size === 'number') ? st.size : 0;
                    var off = 0;
                    while (off < buf.length) {
                        var n = nativeFs.writeSync(self.fd, buf, off, buf.length - off, pos + off);
                        if (n <= 0) break;
                        off += n;
                    }
                    resolve();
                } catch (e) { reject(e); }
            });
        },
        readFile: function (options) {
            var self = this;
            return new Promise(function (resolve, reject) {
                try {
                    var enc = null;
                    if (typeof options === 'string') enc = options;
                    else if (options && typeof options === 'object' && options.encoding) {
                        enc = options.encoding;
                    }
                    var st = nativeFs.fstatSync(self.fd);
                    var size = st && typeof st.size === 'number' ? st.size : 0;
                    if (size < 0) size = 0;
                    var buf = Buffer.alloc(size > 0 ? size : 64 * 1024);
                    var pos = 0;
                    var total = 0;
                    while (true) {
                        if (total >= buf.length) {
                            var bigger = Buffer.alloc(buf.length * 2);
                            buf.copy(bigger, 0, 0, total);
                            buf = bigger;
                        }
                        var n = nativeFs.readSync(self.fd, buf, total, buf.length - total, pos);
                        if (n <= 0) break;
                        total += n;
                        pos += n;
                    }
                    var out = buf.slice(0, total);
                    if (enc) resolve(out.toString(enc));
                    else resolve(out);
                } catch (e) { reject(e); }
            });
        }
    };
    if (typeof Symbol !== 'undefined' && Symbol.asyncDispose) {
        handle[Symbol.asyncDispose] = function () { return handle.close(); };
    }
    if (streamClasses && streamClasses.ReadStream && streamClasses.WriteStream) {
        handle.createReadStream = function (options) {
            options = options || {};
            var opts = Object.assign({}, options, { fd: fd, autoClose: false });
            return new streamClasses.ReadStream(null, opts);
        };
        handle.createWriteStream = function (options) {
            options = options || {};
            var opts = Object.assign({}, options, { fd: fd, autoClose: false });
            return new streamClasses.WriteStream(null, opts);
        };
    }
    return handle;
}

module.exports = { makeFileHandle: makeFileHandle };
