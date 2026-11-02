// node:dgram — UDP datagram sockets (Wave 7 MVP)
// Wraps native __net UDP bridge with Node.js EventEmitter API.
//
// Reference: https://nodejs.org/api/dgram.html
var EventEmitter = require("events");
var Buffer = require("buffer").Buffer;
var _nb = __net;

var BIND_STATE_UNBOUND = 0;
var BIND_STATE_BINDING = 1;
var BIND_STATE_BOUND = 2;

function _err(code, message, name) {
    var Ctor = name === "TypeError" ? TypeError : Error;
    var err = new Ctor(message);
    err.code = code;
    return err;
}

function _typeSuffix(actual) {
    if (actual === undefined) {
        return "undefined";
    }
    if (actual === null) {
        return "null";
    }
    var t = typeof actual;
    if (t === "string") {
        return "type string ('" + actual + "')";
    }
    if (t === "number" || t === "boolean" || t === "bigint") {
        return "type " + t + " (" + String(actual) + ")";
    }
    return "type " + t + " (" + String(actual) + ")";
}

function _errInvalidArgType(name, expected, actual) {
    return _err(
        "ERR_INVALID_ARG_TYPE",
        'The "' + name + '" argument must be of type ' + expected + ". Received " +
            _typeSuffix(actual),
        "TypeError"
    );
}

function _errno(syscall, code) {
    var err = new Error(syscall + " " + (code || "EBADF"));
    err.code = code || "EBADF";
    err.syscall = syscall;
    err.errno = -1;
    return err;
}

function _isUint32(n) {
    return typeof n === "number" && n === n && n >= 0 && n <= 0xffffffff && Math.floor(n) === n;
}

function _toBuffer(msg) {
    if (Buffer.isBuffer(msg)) {
        return msg;
    }
    if (typeof msg === "string") {
        return Buffer.from(msg, "utf8");
    }
    if (Array.isArray(msg)) {
        // list of Buffer/string — concatenate
        var parts = [];
        var total = 0;
        for (var i = 0; i < msg.length; i++) {
            var p = _toBuffer(msg[i]);
            parts.push(p);
            total += p.length;
        }
        var out = Buffer.allocUnsafe(total);
        var off = 0;
        for (var j = 0; j < parts.length; j++) {
            parts[j].copy(out, off);
            off += parts[j].length;
        }
        return out;
    }
    if (msg && typeof msg === "object" && typeof msg.byteLength === "number") {
        return Buffer.from(msg);
    }
    throw _err("ERR_INVALID_ARG_TYPE",
        'The "msg" argument must be of type string or an instance of Buffer',
        "TypeError");
}

function _sliceLatin1(buf, offset, length) {
    if (buf.length === 0 || length === 0) {
        return "";
    }
    return buf.toString("latin1", offset, offset + length);
}

function Socket(type, listener) {
    EventEmitter.init.call(this);
    var options = null;
    if (type !== null && typeof type === "object") {
        options = type;
        type = options.type;
    }
    if (type !== "udp4" && type !== "udp6") {
        throw _err(
            "ERR_SOCKET_BAD_TYPE",
            "Bad socket type specified. Valid types are: udp4, udp6",
            "TypeError"
        );
    }
    if (options) {
        if (options.recvBufferSize !== undefined && !_isUint32(options.recvBufferSize)) {
            throw _err("ERR_INVALID_ARG_TYPE",
                'The "options.recvBufferSize" argument must be of type number.',
                "TypeError");
        }
        if (options.sendBufferSize !== undefined && !_isUint32(options.sendBufferSize)) {
            throw _err("ERR_INVALID_ARG_TYPE",
                'The "options.sendBufferSize" argument must be of type number.',
                "TypeError");
        }
    }
    this.type = type;
    this._handle = 0;
    this._bindState = BIND_STATE_UNBOUND;
    this._receiving = false;
    this._closed = false;
    this._connected = false;
    this._remotePort = 0;
    this._remoteAddr = null;
    this._recvBufSize = options && options.recvBufferSize;
    this._sendBufSize = options && options.sendBufferSize;
    this._family = type === "udp6" ? "IPv6" : "IPv4";
    if (typeof listener === "function") {
        this.on("message", listener);
    }
}
Socket.prototype = Object.create(EventEmitter.prototype);
Socket.prototype.constructor = Socket;

Socket.prototype._ensureHandle = function () {
    if (this._handle) {
        return this._handle;
    }
    if (this._closed) {
        throw _err("ERR_SOCKET_DGRAM_NOT_RUNNING", "Not running", "Error");
    }
    var h = _nb.udpCreate(this.type);
    if (!h) {
        throw _errno("socket", "EINVAL");
    }
    this._handle = h;
    if (this._recvBufSize) {
        _nb.udpSetRecvBuf(h, this._recvBufSize);
    }
    if (this._sendBufSize) {
        _nb.udpSetSendBuf(h, this._sendBufSize);
    }
    return h;
};

Socket.prototype._startReceiving = function () {
    var self = this;
    if (self._receiving || self._closed || !self._handle) {
        return;
    }
    self._receiving = true;
    function onMsg(errCode, data, address, port) {
        self._receiving = false;
        if (self._closed || !self._handle) {
            return;
        }
        if (errCode && errCode !== 0) {
            var err = _errno("recv", "EIO");
            err.errno = errCode;
            self.emit("error", err);
            return;
        }
        var buf = Buffer.from(data || "", "latin1");
        var family = self._family;
        var rinfo = {
            address: address || (family === "IPv6" ? "::" : "0.0.0.0"),
            family: family,
            port: port | 0,
            size: buf.length
        };
        self.emit("message", buf, rinfo);
        // Re-arm for the next datagram
        if (!self._closed && self._handle && self._bindState === BIND_STATE_BOUND) {
            self._startReceiving();
        }
    }
    _nb.udpRecvNb(self._handle, onMsg);
};

/**
 * bind([port][, address][, callback])
 * bind(options[, callback])
 */
Socket.prototype.bind = function () {
    var self = this;
    if (self._bindState !== BIND_STATE_UNBOUND) {
        throw _err("ERR_SOCKET_ALREADY_BOUND", "Socket is already bound", "Error");
    }
    var port = 0;
    var address = "";
    var callback = null;
    if (typeof arguments[0] === "object" && arguments[0] !== null &&
        typeof arguments[0] !== "function") {
        var opts = arguments[0];
        port = opts.port || 0;
        address = opts.address || "";
        callback = arguments[1];
    } else {
        if (typeof arguments[0] === "function") {
            callback = arguments[0];
        } else {
            if (arguments[0] !== undefined && arguments[0] !== null) {
                port = arguments[0] | 0;
            }
            if (typeof arguments[1] === "function") {
                callback = arguments[1];
            } else if (typeof arguments[1] === "string") {
                address = arguments[1];
                if (typeof arguments[2] === "function") {
                    callback = arguments[2];
                }
            }
        }
    }
    if (callback) {
        self.once("listening", callback);
    }
    self._bindState = BIND_STATE_BINDING;
    var handle;
    try {
        handle = self._ensureHandle();
    } catch (e) {
        self._bindState = BIND_STATE_UNBOUND;
        setTimeout(function () { self.emit("error", e); }, 0);
        return self;
    }
    var boundPort = _nb.udpBind(handle, address, port, 0);
    if (boundPort < 0) {
        self._bindState = BIND_STATE_UNBOUND;
        var berr = _errno("bind", "EADDRINUSE");
        setTimeout(function () { self.emit("error", berr); }, 0);
        return self;
    }
    self._bindState = BIND_STATE_BOUND;
    setTimeout(function () {
        if (self._closed) {
            return;
        }
        self.emit("listening");
        self._startReceiving();
    }, 0);
    return self;
};

/**
 * send(msg[, offset, length][, port][, address][, callback])
 * Overloaded Node signatures.
 */
Socket.prototype.send = function (msg) {
    var self = this;
    if (self._closed) {
        throw _err("ERR_SOCKET_DGRAM_NOT_RUNNING", "Not running", "Error");
    }
    var buf = _toBuffer(msg);
    var offset = 0;
    var length = buf.length;
    var port = 0;
    var address = undefined;
    var callback = null;
    var args = arguments;
    var argc = args.length;

    // Detect offset/length form: send(msg, offset, length, ...)
    if (argc >= 3 && typeof args[1] === "number" && typeof args[2] === "number") {
        offset = args[1] | 0;
        length = args[2] | 0;
        var i = 3;
        if (i < argc && typeof args[i] === "number") {
            port = args[i] | 0;
            i++;
        }
        if (i < argc && typeof args[i] === "string") {
            address = args[i];
            i++;
        }
        if (i < argc && typeof args[i] === "function") {
            callback = args[i];
        }
    } else {
        // send(msg[, port][, address][, callback])
        var j = 1;
        if (j < argc && typeof args[j] === "number") {
            port = args[j] | 0;
            j++;
        }
        if (j < argc && typeof args[j] === "string") {
            address = args[j];
            j++;
        }
        if (j < argc && typeof args[j] === "function") {
            callback = args[j];
        }
    }

    if (offset < 0 || length < 0 || offset + length > buf.length) {
        throw _err("ERR_BUFFER_OUT_OF_BOUNDS", "Attempt to write outside buffer bounds", "RangeError");
    }

    if (self._connected) {
        // Connected sockets: port/address must be omitted; use stored remote.
        if (port !== 0 || address !== undefined) {
            throw _err(
                "ERR_SOCKET_DGRAM_IS_CONNECTED",
                "A destination address was already specified. " +
                    "Must provide either a connected or non-connected socket",
                "Error"
            );
        }
        port = self._remotePort;
        address = self._remoteAddr;
    } else {
        if (port === 0 && address === undefined) {
            throw _err("ERR_MISSING_ARGS", 'The "port" argument or the "address" argument is missing', "TypeError");
        }
        if (typeof port !== "number" || port !== port) {
            throw _errInvalidArgType("port", "number", port);
        }
        if (address === undefined || address === null) {
            address = self.type === "udp6" ? "::1" : "127.0.0.1";
        }
        if (typeof address !== "string") {
            throw _errInvalidArgType("address", "string", address);
        }
    }

    // Implicit bind if needed
    if (self._bindState === BIND_STATE_UNBOUND) {
        self.bind(0);
    }

    var handle = self._ensureHandle();
    var payload = _sliceLatin1(buf, offset, length);

    function doSend() {
        if (self._closed) {
            if (callback) {
                callback(_err("ERR_SOCKET_DGRAM_NOT_RUNNING", "Not running", "Error"));
            }
            return;
        }
        _nb.udpSendNb(handle, payload, port, address, function (bytesWritten, errCode) {
            if (typeof callback === "function") {
                if (errCode && errCode !== 0) {
                    var serr = _errno("send", "EIO");
                    serr.errno = errCode;
                    callback(serr);
                } else {
                    callback(null, bytesWritten);
                }
            } else if (errCode && errCode !== 0) {
                var e2 = _errno("send", "EIO");
                e2.errno = errCode;
                self.emit("error", e2);
            }
        });
    }

    if (self._bindState === BIND_STATE_BINDING) {
        self.once("listening", doSend);
    } else {
        doSend();
    }
    return undefined;
};

/**
 * Legacy sendto(msg, offset, length, port, address[, callback])
 * Requires offset/length/port/address.
 */
Socket.prototype.sendto = function (msg, offset, length, port, address, callback) {
    if (typeof offset !== "number") {
        throw _errInvalidArgType("offset", "number", offset);
    }
    if (typeof length !== "number") {
        throw _errInvalidArgType("length", "number", length);
    }
    if (typeof port !== "number") {
        throw _errInvalidArgType("port", "number", port);
    }
    if (typeof address !== "string") {
        throw _errInvalidArgType("address", "string", address);
    }
    return this.send(msg, offset, length, port, address, callback);
};

Socket.prototype.close = function (callback) {
    var self = this;
    if (callback) {
        self.once("close", callback);
    }
    if (self._closed) {
        return self;
    }
    self._closed = true;
    self._receiving = false;
    if (self._handle) {
        _nb.udpClose(self._handle);
        self._handle = 0;
    }
    self._bindState = BIND_STATE_UNBOUND;
    setTimeout(function () {
        self.emit("close");
    }, 0);
    return self;
};

Socket.prototype.address = function () {
    if (this._bindState !== BIND_STATE_BOUND || !this._handle) {
        throw _errno("getsockname", "EBADF");
    }
    var addr = _nb.udpAddress(this._handle);
    if (!addr) {
        throw _errno("getsockname", "EBADF");
    }
    return addr;
};

Socket.prototype.setBroadcast = function (flag) {
    if (this._bindState !== BIND_STATE_BOUND || !this._handle) {
        throw _errno("setBroadcast", "EBADF");
    }
    var rc = _nb.udpSetBroadcast(this._handle, !!flag);
    if (rc !== 0) {
        throw _errno("setBroadcast", "EINVAL");
    }
    return undefined;
};

Socket.prototype.setTTL = function (ttl) {
    if (!this._handle) {
        this._ensureHandle();
    }
    var rc = _nb.udpSetTTL(this._handle, ttl | 0);
    if (rc !== 0) {
        throw _errno("setTTL", "EINVAL");
    }
    return ttl;
};

Socket.prototype.getRecvBufferSize = function () {
    if (!this._handle) {
        throw _errno("getRecvBufferSize", "EBADF");
    }
    return _nb.udpGetRecvBuf(this._handle);
};

Socket.prototype.getSendBufferSize = function () {
    if (!this._handle) {
        throw _errno("getSendBufferSize", "EBADF");
    }
    return _nb.udpGetSendBuf(this._handle);
};

Socket.prototype.setRecvBufferSize = function (size) {
    this._ensureHandle();
    return _nb.udpSetRecvBuf(this._handle, size | 0);
};

Socket.prototype.setSendBufferSize = function (size) {
    this._ensureHandle();
    return _nb.udpSetSendBuf(this._handle, size | 0);
};

Socket.prototype.ref = function () { return this; };
Socket.prototype.unref = function () { return this; };

// Multicast stubs — not in MVP scope
Socket.prototype.addMembership = function () {
    throw _err("ERR_SOCKET_DGRAM_NOT_RUNNING", "addMembership not implemented (TODO multicast)", "Error");
};
Socket.prototype.dropMembership = function () {
    throw _err("ERR_SOCKET_DGRAM_NOT_RUNNING", "dropMembership not implemented (TODO multicast)", "Error");
};
Socket.prototype.addSourceSpecificMembership = function () {
    throw _err("ERR_SOCKET_DGRAM_NOT_RUNNING", "addSourceSpecificMembership not implemented", "Error");
};
Socket.prototype.dropSourceSpecificMembership = function () {
    throw _err("ERR_SOCKET_DGRAM_NOT_RUNNING", "dropSourceSpecificMembership not implemented", "Error");
};
Socket.prototype.setMulticastTTL = function () { return 1; };
Socket.prototype.setMulticastLoopback = function () { return true; };
Socket.prototype.setMulticastInterface = function () { return undefined; };

/**
 * connect(port[, address][, callback])
 * Stores a default remote; subsequent send() calls omit port/address.
 */
Socket.prototype.connect = function (port, address, callback) {
    var self = this;
    if (typeof address === "function") {
        callback = address;
        address = undefined;
    }
    if (self._closed) {
        throw _err("ERR_SOCKET_DGRAM_NOT_RUNNING", "Not running", "Error");
    }
    if (self._connected) {
        throw _err("ERR_SOCKET_DGRAM_IS_CONNECTED", "Already connected", "Error");
    }
    if (typeof port !== "number" || port !== port || port < 0 || port > 65535) {
        throw _errInvalidArgType("port", "number", port);
    }
    if (address === undefined || address === null) {
        address = self.type === "udp6" ? "::1" : "127.0.0.1";
    }
    if (typeof address !== "string") {
        throw _errInvalidArgType("address", "string", address);
    }
    if (typeof callback === "function") {
        self.once("connect", callback);
    }

    function finishConnect() {
        if (self._closed) {
            return;
        }
        self._connected = true;
        self._remotePort = port | 0;
        self._remoteAddr = address;
        self.emit("connect");
    }

    // Implicit bind if needed (Node connect() binds to an ephemeral port)
    if (self._bindState === BIND_STATE_UNBOUND) {
        self.bind(0);
    }
    if (self._bindState === BIND_STATE_BINDING) {
        self.once("listening", finishConnect);
    } else {
        setTimeout(finishConnect, 0);
    }
    return undefined;
};

Socket.prototype.disconnect = function () {
    if (!this._connected) {
        throw _err("ERR_SOCKET_DGRAM_NOT_CONNECTED", "Not connected", "Error");
    }
    this._connected = false;
    this._remotePort = 0;
    this._remoteAddr = null;
    return undefined;
};

Socket.prototype.remoteAddress = function () {
    if (!this._connected) {
        throw _err("ERR_SOCKET_DGRAM_NOT_CONNECTED", "Not connected", "Error");
    }
    return {
        address: this._remoteAddr,
        family: this.type === "udp6" ? "IPv6" : "IPv4",
        port: this._remotePort
    };
};

function createSocket(type, listener) {
    return new Socket(type, listener);
}

module.exports = {
    createSocket: createSocket,
    Socket: Socket
};
