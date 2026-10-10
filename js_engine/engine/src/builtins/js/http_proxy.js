// Internal HTTP(S) proxy client helpers for node:http / node:https.
// Implements HTTP forward proxy and HTTPS CONNECT + TLS upgrade.

var netModule = require("net");
var tlsModule = require("tls");
var core = require("http_core");

var CRLF = core.CRLF;
var _nb = __net;

function _connectResponseStatus(buf) {
    var end = buf.indexOf(CRLF + CRLF);
    if (end === -1) { return -1; }
    var head = buf.substring(0, end);
    var firstLine = head.split(CRLF)[0];
    var parts = firstLine.split(" ");
    if (parts.length < 2) { return -1; }
    var code = parseInt(parts[1], 10);
    return isNaN(code) ? -1 : code;
}

function _connectResponseOk(buf) {
    return _connectResponseStatus(buf) === 200;
}

/**
 * Apply proxy routing to connect options. Mutates req for absolute-URI mode.
 * Returns proxy config or null for direct connection.
 */
function prepareClientProxy(req, connectOpts) {
    var proxy = core.resolveClientProxy(req, connectOpts);
    if (!proxy) { return null; }
    req._proxyConfig = proxy;
    connectOpts._proxyConfig = proxy;
    // Do not use per-request TLS createConnection when tunneling via CONNECT.
    if (proxy.isHttps) {
        connectOpts._createConnection = undefined;
        connectOpts.createConnection = undefined;
    }
    if (!proxy.isHttps) {
        req._useProxyAbsoluteUri = true;
        var defaultPort = req.protocol === "https:" ? 443 : 80;
        var tport = proxy.targetPort || defaultPort;
        var auth = req.protocol || "http:";
        if (auth.charAt(auth.length - 1) !== ":") { auth = auth + ":"; }
        req._proxyAbsoluteUri = auth + "//" + proxy.targetHost + ":" + tport + req.path;
    }
    connectOpts.host = proxy.proxyHost;
    connectOpts.port = proxy.proxyPort;
    connectOpts.hostname = proxy.proxyHost;
    return proxy;
}

/**
 * createConnection hook for Agent — direct, HTTP proxy, or HTTPS CONNECT tunnel.
 */
function createProxiedConnection(options, cb) {
    var proxy = options && options._proxyConfig;
    if (proxy) {
        if (proxy.isHttps) {
            return _connectHttpsViaProxy(proxy, options, cb);
        }
        return netModule.connect(options, cb);
    }
    if (options && typeof options._createConnection === "function") {
        return options._createConnection(options, cb);
    }
    return netModule.connect(options, cb);
}

/**
 * HTTPS over HTTP proxy: return the TLS socket immediately (still connecting)
 * and invoke cb only after CONNECT + TLS handshake complete.
 */
function _connectHttpsViaProxy(proxy, options, cb) {
    var targetHost = proxy.targetHost;
    var targetPort = proxy.targetPort;
    var servername = options.servername || targetHost;
    var rejectUnauthorized = options.rejectUnauthorized !== false;

    var tlsSocket = new tlsModule.TLSSocket(null, options);
    tlsSocket._connecting = true;

    var tcpSocket = netModule.connect({
        host: proxy.proxyHost,
        port: proxy.proxyPort
    });

    var connectBuf = "";
    var tunnelReady = false;
    var finished = false;

    function fail(err) {
        if (finished) { return; }
        finished = true;
        tcpSocket.destroy();
        tlsSocket.destroy(err);
    }

    function succeed(tlsHandle) {
        if (finished) { return; }
        finished = true;
        tlsSocket._handle = tlsHandle;
        tlsSocket._connecting = false;
        tlsSocket.readable = true;
        tlsSocket.writable = true;
        tlsSocket.authorized = true;
        tlsSocket.remoteAddress = targetHost;
        tlsSocket.remotePort = targetPort;
        tlsSocket.remoteFamily = "IPv4";
        tlsSocket._startReading();
        tlsSocket.emit("secureConnect");
        tlsSocket.emit("connect");
        tlsSocket.emit("ready");
        if (typeof cb === "function") { cb(); }
    }

    tcpSocket.on("connect", function() {
        var connectReq = "CONNECT " + targetHost + ":" + String(targetPort) + " HTTP/1.1" + CRLF +
            "Host: " + targetHost + ":" + String(targetPort) + CRLF + CRLF;
        tcpSocket.write(connectReq);
    });

    tcpSocket.on("data", function(chunk) {
        if (tunnelReady) { return; }
        connectBuf = connectBuf + chunk;
        if (connectBuf.indexOf(CRLF + CRLF) === -1) { return; }
        if (!_connectResponseOk(connectBuf)) {
            var err = new Error("Proxy CONNECT failed");
            err.code = "ECONNRESET";
            fail(err);
            return;
        }
        tunnelReady = true;
        tcpSocket.removeAllListeners("data");
        tcpSocket._reading = false;
        tcpSocket._readPaused = true;
        if (typeof tcpSocket.pause === "function") {
            tcpSocket.pause();
        }

        if (!_nb.tlsWrapClientNb) {
            fail(new Error("TLS upgrade via proxy is not available"));
            return;
        }

        _nb.tlsWrapClientNb(tcpSocket._handle, servername, rejectUnauthorized,
            function(tlsHandle, errCode) {
                if (errCode !== 0 || tlsHandle === 0) {
                    var tlsErr = new Error("TLS handshake via proxy failed");
                    tlsErr.code = "ECONNRESET";
                    fail(tlsErr);
                    return;
                }
                succeed(tlsHandle);
            });
    });

    tcpSocket.on("error", function(err) {
        if (!tunnelReady) { fail(err); }
    });

    tlsSocket.on("error", function() {
        if (!finished) { tcpSocket.destroy(); }
    });

    return tlsSocket;
}

module.exports = {
    prepareClientProxy: prepareClientProxy,
    createProxiedConnection: createProxiedConnection
};
